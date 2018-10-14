# ex: syntax=ruby ts=2 sw=2 et
require 'puppet/property/boolean'
Puppet::Type.newtype(:network_interface) do
  @doc = "A network interface"

  autorequire(:network_interface) do
    [@parameters[:vlan_master].value]
  end

  ensurable

  newparam :name do
    isnamevar
  end

  newproperty :method do
    newvalues(:dhcp, :static, :loopback, :manual, :tunnel)
  end

  newproperty :address do
    defaultto :absent
  end

  newproperty :gateway do
    defaultto :absent
  end

  newproperty (:name_servers, :array_matching => :all) do
    defaultto []
  end

  newproperty :search_domain do
    defaultto :absent
  end

  newproperty :domain_name do
    defaultto :absent
  end

  newproperty(:onboot, :parent => Puppet::Property::Boolean) do
    defaultto false
  end

  newproperty(:hotplug, :parent => Puppet::Property::Boolean) do
    defaultto false
  end

  newproperty(:alternate_addresses, :array_matching => :all) do
    defaultto []
  end

  newproperty(:bond_members, :array_matching => :all) do
    defaultto []
  end

  newproperty(:vlan_master) do
    defaultto :absent
  end

  newproperty(:options) do
    validate do |value|
      raise Puppet::Error, 'options must be specified as a hash' unless value.is_a? Hash
    end
    defaultto {}
  end
end
