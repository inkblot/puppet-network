# ex: syntax=ruby ts=2 sw=2 et
Puppet::Type.newtype(:network_route) do
  @doc = "A network route"

  autorequire(:network_interface) do
    if @parameters[:ensure].value == :present
      [ @parameters[:device].value ]
    else
      []
    end
  end

  ensurable do
    newvalue(:present) do
      provider.create
    end

    newvalue(:absent) do
      provider.destroy
    end

    newvalue(:blackhole) do
      provider.blackhole
    end

    def retrieve
      if provider.exists?
        :present
      elsif provider.blackhole?
        :blackhole
      else
        :absent
      end
    end
  end

  newparam :network do
    isnamevar
  end

  newproperty :device do
    defaultto ''
  end
  
  newproperty :gateway do
    defaultto ''
  end

  newproperty :source do
    defaultto ''
  end

  newproperty :metric do
    defaultto ''
  end

end
