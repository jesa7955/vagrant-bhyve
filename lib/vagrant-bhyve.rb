require "pathname"

require "vagrant-bhyve/version"

module VagrantPlugin
  module Bhyve
    lib_path = Pathname.new(File.expand_path("../vagrant-bhyve", __FILE__))


    # This function returns the path to the source of this plugin
    #
    # @return [Pathname]
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path("../.../", __FILE__))
    end
  end
end
