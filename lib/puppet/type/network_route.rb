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

  autorequire(:route_table) do
    unless /\A[0-9]+\Z/ === @parameters[:table].value
      [ @parameters[:table].value ]
    else
      []
    end
  end

  autorequire(:route_protocol) do
    unless /\A[0-9]+\Z/ === @parameters[:protocol].value
      [ @parameters[:protocol].value ]
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

  def self.title_patterns
    identity = lambda { |x| x }
    [
      [
        /\A(\S+)\Z/,
        [
          [ :network, identity ]
        ]
      ],
      [
        /\A(\S+) (\S+)\Z/,
        [
          [ :network, identity ],
          [ :table, identity ]
        ]
      ]
    ]
  end

  newparam :network do
    isnamevar
  end

  newparam :table do
    isnamevar
    defaultto 'main'
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

  newproperty :protocol do
    defaultto 'boot'
  end

end
