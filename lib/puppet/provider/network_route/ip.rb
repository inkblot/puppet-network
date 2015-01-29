# ex: syntax=ruby ts=2 sw=2 et

Puppet::Type.type(:network_route).provide(:ip) do

  defaultfor :operatingsystem => 'Linux'
  commands :ip => 'ip'

  mk_resource_methods

  def initialize(value = {})
    super(value)
    @property_flush = {}
    @filled = false
  end

  def fill_properties
    unless @filled
      @property_hash = self.class.route(resource[:network], resource[:table])
      @filled = true
    end
  end

  def exists?
    fill_properties
    @property_hash[:ensure] == :present
  end

  def blackhole?
    fill_properties
    @property_hash[:ensure] == :blackhole
  end

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def blackhole
    @property_flush[:ensure] = :blackhole
  end

  def self.instances
    routes.collect do |route|
      new(route)
    end
  end

  def flush
    if @property_flush[:ensure] == :absent
      do_destroy
      return
    elsif @property_flush[:ensure] == :present
      do_create
    elsif @property_flush[:ensure] == :blackhole
      do_create
    else @property_flush.size > 0
      do_destroy
      do_create
    end
    @property_hash = self.class.route_properties_from_resource(resource)
  end

private

  def self.route_properties_from_resource(resource)
    {
      :provider => :ip,
      :ensure => resource[:ensure],
      :network => resource[:network],
      :table => resource[:table],
      :device => resource[:device],
      :gateway => resource[:gateway],
      :source => resource[:source],
      :metric => resource[:metric],
      :protocol => resource[:protocol]
    }
  end

  def self.route_properties_from_route(route)
    network = /\// =~ route['route'] ? route['route'] : "#{route['route']}/32"
    {
      :provider => :ip,
      :ensure => route[:ensure],
      :network => network,
      :table => route['table'] || 'main',
      :device => route['dev'] || '',
      :gateway => route['via'] || '',
      :source => route['src'] || '',
      :metric => route['metric'] || '',
      :protocol => route['proto'] || 'boot'
    }
  end

  def self.route(network, table = 'main')
    marks = ip('route', 'show', network, 'table', table).split(/\n/).map do |route|
      parse_route(route)
    end.compact
    if marks.empty?
      { :ensure => :absent, :network => network, :table => table }
    else
      marks.first
    end
  end

  def self.routes
    ip('route', 'show', 'table', 'all').split(/\n/).map do |route|
      parse_route(route)
    end.compact
  end

  def self.parse_route(route)
      case route
      when /\btable\s+(local|unspec)\b/
        return nil
      when /^blackhole /
        route_hash = Hash[*[:ensure, :blackhole, 'route', route.split(/ +/)[1..-1]].flatten]
      else
        route_hash = Hash[*[:ensure, :present, 'route', route.split(/ +/)].flatten]
      end
      route_properties_from_route(route_hash)
  end

  def do_create
    args = [ 'route', 'add' ]
    if @property_flush[:ensure] == :blackhole or resource[:ensure] == :blackhole
      args << 'blackhole'
    end
    args << resource[:network]
    if @property_flush[:ensure] == :present
      unless resource[:device] == ''
        args << 'dev'
        args << resource[:device]
      end
      unless resource[:source] == ''
        args << 'src'
        args << resource[:source]
      end
      unless resource[:gateway] == ''
        args << 'via'
        args << resource[:gateway]
      end
    end
    unless resource[:metric] == ''
      args << 'metric'
      args << resource[:metric]
    end
    args << 'table'
    args << resource[:table]
    args << 'proto'
    args << resource[:protocol]
    ip(args)
  end

  def do_destroy
    ip('route', 'del', resource[:network], 'table', resource[:table])
  end

end
