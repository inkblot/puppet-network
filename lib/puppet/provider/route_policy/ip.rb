# ex: syntax=ruby ts=2 sw=2 et

Puppet::Type.type(:route_policy).provide(:ip) do

  defaultfor :operatingsystem => 'Linux'
  commands :ip => 'ip'

  mk_resource_methods

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def self.instances
    rules.collect do |rule|
      new(rule_properties_from_rule(rule))
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.pref]
        resource.provider = prov
      end
    end
  end

  def flush
    if @property_flush[:ensure] == :absent
      do_destroy
      return
    elsif @property_flush[:ensure] == :present
      do_create
    else @property_flush.size > 0
      do_destroy
      do_create
    end
    @property_hash = self.class.rule_properties_from_resource(resource)
  end

private

  def self.rule_properties_from_resource(resource)
    {
      :provider => :ip,
      :ensure => resource[:ensure],
      :pref => resource[:pref],
      :from => resource[:from],
      :to => resource[:to],
      :fwmark => resource[:fwmark],
      :table => resource[:table]
    }
  end

  def self.rule_properties_from_rule(rule)
    fwmark = rule.include?('fwmark') ? rule['fwmark'].hex.to_s : :absent
    {
      :provider => :ip,
      :ensure => rule[:ensure],
      :pref => rule['pref'],
      :from => rule['from'],
      :to => rule['to'] || :absent,
      :fwmark => fwmark,
      :table => rule['lookup'],
    }
  end

  def self.rules
    ip('rule', 'show').split(/\n/).map do |rule|
      rule_hash = Hash[*[:ensure, :present, 'pref', rule.split(/\s+/)].flatten]
      rule_hash['pref'].sub!(/:$/, '')
      rule_hash
    end
  end

  def do_create
    args = [ 'rule', 'add', 'pref', resource[:pref], 'from', resource[:from] ]
    unless resource[:to] == :absent
      args << 'to'
      args << resource[:to]
    end
    unless resource[:fwmark] == :absent
      args << 'fwmark'
      args << "0x#{resource[:fwmark].to_i(16)}"
    end
    args << 'table'
    args << resource[:table]
    ip(args)
  end

  def do_destroy
    ip('rule', 'del', 'pref', resource[:pref])
  end
end
