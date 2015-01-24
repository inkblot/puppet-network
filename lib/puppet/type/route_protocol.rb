# ex: syntax=ruby ts=2 sw=2 et
Puppet::Type.newtype(:route_protocol) do
  @doc = "A routing table"

  ensurable

  newparam :name do
    isnamevar
  end

  newproperty :number do
    isrequired
  end
end
