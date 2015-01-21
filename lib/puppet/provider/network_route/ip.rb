# ex: syntax=ruby ts=2 sw=2 et
require 'json'

Puppet::Type.type(:network_route).provide(:ip) do

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

  def blackhole?
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
      new(route_properties_from_route(route))
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.network]
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
      :device => resource[:device],
      :gateway => resource[:gateway],
      :source => resource[:source],
      :metric => resource[:metric]
    }
  end

  def self.route_properties_from_route(route)
    network = /\// =~ route['route'] ? route['route'] : "#{route['route']}/32"
    {
      :provider => :ip,
      :ensure => route[:ensure],
      :network => network,
      :device => route['dev'] || '',
      :gateway => route['via'] || '',
      :source => route['src'] || '',
      :metric => route['metric'] || ''
    }
  end

  def self.routes
    ip('route', 'show').split(/\n/).map do |route|
      case route
      when /^blackhole /
        Hash[*[:ensure, :blackhole, 'route', route.split(/ +/)[1..-1]].flatten]
      else
        Hash[*[:ensure, :present, 'route', route.split(/ +/)].flatten]
      end
    end
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
    ip(args)
  end

  def do_destroy
    ip('route', 'del', resource[:network])
  end

end
