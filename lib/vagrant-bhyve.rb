require "pathname"
require "vagrant-bhyve/version"

module VagrantPlugin
  module ProviderBhyve
    lib_path = Pathname.new(File.expand_path("../vagrant-bhyve", __FILE__))
    autoload :Action, lib_path.join('action')
    autoload :Driver, lib_path.join('driver')
    autoload :Errors, lib_path.join('errors')
    autoload :Util, lib_path.join('util')


    # This function returns the path to the source of this plugin
    #
    # @return [Pathname]
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path("../.../", __FILE__))
    end
  end
end
