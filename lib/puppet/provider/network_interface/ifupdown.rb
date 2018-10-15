# ex: syntax=ruby ts=2 sw=2 et
require 'puppetx/filemapper'
Puppet::Type.type(:network_interface).provide(:ifupdown) do

  include PuppetX::FileMapper

  commands :ifup => 'ifup', :ifdown => 'ifdown'

  def select_file
    '/etc/network/interfaces'
  end

  def self.target_files
    [ '/etc/network/interfaces' ]
  end

  def self.parse_file(filename, contents)
    parse_interfaces_from_file(ParsedData.new, filename, contents).to_interfaces.map &:to_hash
  end

  def self.parse_interfaces_from_file(parsed_data, filename, contents)
    lines = contents.lines
    currently = lambda { |pd, line| parse_top_level_line(pd, line) }
    lines.each do |line|
      # Obliterate the comments
      line.sub!(/#.*$/, '')

      # Skip white space
      next if line =~ /^\s*$/

      # Run the current parser on the current line
      ( reprocess_line, new_parser ) = currently.call(parsed_data, line)
      unless new_parser.nil?
        currently = new_parser
      end
      if reprocess_line
        redo
      end
    end
    parsed_data
  end

  def self.parse_top_level_line(parsed_data, line)
    case line
    when /^\s*(allow-\S+|auto)\s/
      words = line.split(/\s+/)
      allowup = words[0].gsub(/^allow-/, '').intern
      words.slice(1..-1).each do |name|
        parsed_data.allowup << [ name, allowup ]
      end

    when /^\s*iface\s/
      parts = line.split(/\s+/)
      name = parts[1]
      family = parts[2].intern
      method = parts[3].intern
      instance = Instance.new(name, family, method)

      # xenial cloudimg has lo defined twice
      unless instance.name == 'lo' && parsed_data.instances.any? { |i| instance.name == 'lo' && instance.method == :loopback }
        parsed_data.instances << instance
      end
      return [ false, lambda { |parsed_file, line| parse_interface_line(parsed_file, line, instance) } ]

    when /^\s*source\s/
      parts = line.split(/\s+/)
      source_glob = parts[1]
      source_additional_files(parsed_data, source_glob)

    when /^\s*mapping\s/
      raise Puppet::DevError, "Mappings are not yet supported"

    else
      raise Puppet::Error, "Unknown top level configuration: #{line.inspect}"

    end
    [ false, nil ]
  end

  def self.parse_interface_line(parsed_file, line, interface)
    case line
    # These mark the end of the current interface
    when /\s*(iface|auto|source|allow-\S+)\s/
      [ true, lambda { |parsed_file, line| parse_top_level_line(parsed_file, line) } ]

    else
      (key, value) = line.strip.split(/\s+/, 2)
      setter = "#{key}=".intern
      if interface.respond_to? setter
        interface.send setter, value
      else
        interface.options[key] = value
      end
      [ false, nil ]
    end
  end

  def self.source_additional_files(parsed_data, glob)
    Dir.glob(glob).inject(parsed_data) do |parsed_data, filename|
      parse_interfaces_from_file(parsed_data, filename, IO.read(filename))
    end
  end

  def self.family_of(method, addr)
    case method
    when :static
      ipaddr = IPAddr.new(addr)
      if ipaddr.ipv4?
        'inet'
      elsif ipaddr.ipv6?
        'inet6'
      else
        raise Puppet::Error, "Can't determine address family: #{addr}"
      end
    else
      'inet'
    end
  end

  def self.address_of(cidr)
    (addr, prefixlen) = cidr.split(/\//)
    addr
  end

  def self.netmask_of(cidr)
    (addr, prefixlen) = cidr.split(/\//)
    ipaddr = IPAddr.new(addr)
    if ipaddr.ipv4?
      IPAddr.new('255.255.255.255').mask(prefixlen).to_s
    elsif ipaddr.ipv6?
      prefixlen
    else
      raise Puppet::Error, "Can't determine address family: #{cidr}"
    end
  end

  def to_config
    return '' unless self.ensure == :present
    config = []
    config << "auto #{name}" unless !onboot || (!bond_members.empty? && method == :manual)
    config << "allow-hotplug #{name}" if hotplug
    config << "iface #{name} #{self.class.family_of(method, address)} #{method}"
    if [ :static, :tunnel ].include?(method)
      config << "    address #{self.class.address_of(address)}" unless address == :absent
      config << "    netmask #{self.class.netmask_of(address)}" unless address == :absent
      config << "    gateway #{gateway}" unless gateway == :absent
    end
    config << "    dns-domain #{domain_name}" unless domain_name == :absent
    unless name_servers == :absent
        name_servers.each do |ns|
            config << "    dns-nameserver #{ns}"
        end
    end
    config << "    dns-search #{search_domain}" unless search_domain == :absent
    config << "    vlan-raw-device #{vlan_master}" unless vlan_master == :absent
    config << options.map { |k,v| "    #{k} #{v}" }.join("\n")  unless options == nil

    alternate_addresses.each do |alt_addr|
      config << ''
      config << "iface #{name} #{self.class.family_of(:static, alt_addr)} static"
      config << "    address #{self.class.address_of(alt_addr)}"
      config << "    netmask #{self.class.netmask_of(alt_addr)}"
    end

    bond_members.each do |member|
      config << ''
      config << "auto #{member}" if onboot && method == :manual
      config << "iface #{member} inet manual"
      config << "    bond-master #{name}"
    end
    config.join("\n")
  end

  def self.format_file(filename, providers)
    "#{providers.map(&:to_config).join("\n\n")}\n"
  end

  def flush
    begin
      ifdown(resource[:name])
    rescue Puppet::ExecutionFailure
      # ignored
    end
    super
    ifup(resource[:name]) if resource[:ensure] == :present
  end

  class Instance
    attr_reader :name, :family, :method, :options

    def initialize(name, family, method)
      @name = name
      @family = family
      @method = method
      @options = {}
    end

    def alternate?
      @method == :static && options.reject { |k,v| ['address', 'netmask'].member? k }.empty?
    end
  end

  class ParsedData
    attr_accessor :allowup, :instances

    def initialize
      @allowup = []
      @instances = []
    end

    def to_interfaces
      @instances.map { |inst| inst.name }.uniq.map do |name|
        next if @instances.detect { |instance| instance.name === name && instance.options.member?('bond-master') }
        bond_members = @instances.select { |instance| instance.options['bond-master'] === name }
        bond_allowups = bond_members.map do |member|
          allowups_for(member.name)
        end.inject(nil) do |bond_allowups, member_allowups|
          if bond_allowups.nil?
            member_allowups
          else
            bond_allowups & member_allowups if bond_allowups
          end
        end
        bond_allowups = [] if bond_allowups.nil?

        allowups =  bond_allowups | allowups_for(name)
        instances = @instances.select { |instance| instance.name === name }
        Interface.new name, allowups, instances, bond_members
      end.reject { |iface| iface.nil? }
    end

    def allowups_for(name)
      @allowup.select { |allowup| allowup[0] === name }.map { |allowup| allowup[1] }
    end
  end

  class Interface
    def initialize(name, allowups, instances, bond_members)
      @instances = instances

      @provider = :ifupdown
      @ensure = :present
      @name = name
      @onboot = allowups.member? :auto
      @hotplug = allowups.member? :hotplug

      alt_insts = select_instances(:alternate?, true)
      primaries = instances - alt_insts
      if primaries.one?
        primary = primaries.first
      elsif primaries.empty?
        primary = alt_insts.sort_by { |i| i.options['address'] }.first
        alt_insts = alt_insts - [ primary ]
      else
        raise Puppet::Error, "No discernable primary instance for interface #{@name}"
      end

      raise Puppet::Error, "Primary instance for lo must use loopback method" unless @name != 'lo' || primary.method == :loopback
      raise Puppet::Error, "Loopback method is not applicable to #{@name}" unless primary.method != :loopback || @name == 'lo'

      @method = primary.method
      @address = to_cidr(primary.options['address'], primary.options['netmask'])
      @gateway = primary.options['gateway']
      @name_servers = primary.options['dns-nameservers']
      @search_domain = primary.options['dns-search']
      @domain_name = primary.options['dns-domain']
      @vlan_master = primary.options['vlan-raw-device']
      @options = primary.options.reject do |k,v|
        %w(address netmask gateway dns-nameservers dns-search dns-domain vlan-raw-device).member? k
      end

      @alternate_addresses = alt_insts.map do |instance|
        to_cidr(instance.options['address'], instance.options['netmask'])
      end

      @bond_members = bond_members.map &:name
    end

    def to_cidr(address, netmask)
      if address && netmask
        "#{address}/#{IPAddr.new(netmask).to_i.to_s(2).count('1')}"
      else
        nil
      end
    end

    def select_instances(prop, value, comp = :===)
      @instances.select { |instance| instance.send(prop).send(comp, value) }
    end

    def self.resource_properties=(props)
      @@resource_properties = props
    end

    def self.resource_properties
      @@resource_properties
    end
  end

  Interface.resource_properties = [ resource_type.validproperties, resource_type.parameters ].flatten

  Interface.class_eval do
    attr_reader :name, *resource_properties

    def default_for(prop)
      case prop
      when :options
        {}
      when :bond_members
        []
      else
        :absent
      end
    end

    def to_hash
      [ :name, self.class.resource_properties ].flatten.inject({}) do |hash, prop|
        value = send prop
        hash[prop] = value unless value.nil?
        hash[prop] = default_for(prop) if value.nil?
        hash
      end
    end
  end
end
