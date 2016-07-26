require "vagrant"

module VagrantPlugins
  module ProviderBhyve
    class Config < Vagrant.plugin('2', :config)
      # Loader used to load kernel before invoking bhyve.(grub2-bhyve or bhyveload)
      attr_accessor :loader
      
      # Guest like CentOS-6 requires a customized grub config file
      attr_accessor :grub_config_file

      # Some arguments required by grub-bhyve
      attr_accessor :grub_run_partition
      attr_accessor :grub_run_dir
      
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
      # Addition storage
      attr_accessor :disks
      attr_accessor :cdroms

      def initialize
	@loader			= UNSET_VALUE
	@cpus			= UNSET_VALUE
	@memory			= UNSET_VALUE
	@pcis			= UNSET_VALUE
	@lpc			= UNSET_VALUE
	@hostbridge		= UNSET_VALUE
	@grub_config_file	= ''
	@grub_run_partition	= ''
	@grub_run_dir 		= ''
	@disks			= []
	@cdroms			= []
      end

      def storage(options={})
	if options[:device] == :cdrom
	  _handle_cdrom_storage(options)
	elsif options[:device] == :disk
	  _handle_disk_storage(options)
	end
      end

      def _handle_disk_storage(options={})
	cdrom = {
	  path: options[:path]
	}
	@cdroms << cdrom
      end

      def _handle_cdrom_storage(options={})
	options = {
	  path: nil,
	  name: nil,
	  size: "20G",
	  format: "raw",
	}.merge(options)

	disk = {
	  path: options[:path],
	  size: options[:size],
	}

	@disks << disk
      end

    end
  end
end
