# ex: syntax=ruby ts=2 sw=2 et
Puppet::Type.newtype(:network_route) do
  @doc = "A network route"

  autorequire(:network_interface) do
    [ @parameters[:device].value ]
  end

  ensurable

  newparam :network do
    isnamevar
  end

  newproperty :device do
    isrequired
  end
  
  newproperty :gateway do
    defaultto ''
  end

  newproperty :source do
    defaultto ''
  end

end
