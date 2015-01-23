# ex: syntax=ruby si sw=2 ts=2 et
require 'puppetx/filemapper'
Puppet::Type.type(:route_table).provide(:iproute) do

  include PuppetX::FileMapper

  confine :exists => '/etc/iproute2/rt_tables'

  def select_file
    '/etc/iproute2/rt_tables'
  end

  def self.target_files
    [ '/etc/iproute2/rt_tables' ]
  end

  def self.parse_file(filename, contents)
    contents.lines.map do |line|
      case line
      when /^([0-9]+)\s+([a-z]+)$/
        {
          :provider => :iproute,
          :ensure   => :present,
          :name     => $2,
          :number   => $1,
        }
      else
        nil
      end
    end.compact
  end

  def self.format_file(filename, providers)
    providers.map(&:to_config).join
  end

  def to_config
    return "#{number} #{name}\n"
  end
end
