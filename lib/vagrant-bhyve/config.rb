require "vagrant"

module VagrantPlugins
  module ProviderBhyve
    class Config < Vagrant.plugin('2', :config)
      # Loader used to load kernel before invoking bhyve.(grub2-bhyve or bhyveload)
      attr_accessor :loader
      
      # Resources needed for the VM.
      
      # Specify the number of virtual CPUs.
      attr_accessor :cpus
      # Specify the size of guest physical memory.
      attr_accessor :memory
      # Specify virtual devices will be attached to bhyve's emulated
      # PCI bus. Network interface and disk will both attched as this kind
      # of devices.
      attr_accessor :pcis
      # Specify console device which will be attached to the VM
      attr_accessor :lpc
      attr_accessor :hostbridge

      def initialize
	@loader		= UNSET_VALUE
	@cpus		= UNSET_VALUE
	@memory		= UNSET_VALUE
	@pcis		= UNSET_VALUE
	@lpc		= UNSET_VALUE
	@hostbridge	= UNSET_VALUE
      end

    end
  end
end
