# ex: syntax=ruby ts=2 sw=2 et
Puppet::Type.newtype(:route_policy) do
  @doc = 'A route policy'

  autorequire(:route_table) do
    unless /\A[0-9]+\Z/ === @parameters[:table].value
      [ @parameters[:table].value ]
    else
      []
    end
  end

  ensurable

  newparam :pref do
    isnamevar
  end

  newproperty :from do
    defaultto 'all'
  end

  newproperty :to do
    defaultto :absent
  end

  newproperty :fwmark do
    defaultto :absent
  end

  newproperty :table
end
