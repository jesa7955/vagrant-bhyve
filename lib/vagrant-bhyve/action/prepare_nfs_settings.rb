require "log4r"
require "securerandom"
require "digest/md5"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class PrepareNFSSettings

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::prepare_nfs_settings")
	  @app = app
	end

	def call(env)
	  @machine	= env[:machine]
	  @driver	= @machine.provider.driver

	  if @machine.config.vm.synced_folders.any? { |_, opts| opts[:type] == :nfs }
	    tap_device	= @driver.get_attr('tap')
	    host_ip	= @driver.get_ip_address(nil, :host)
	    guest_ip 	= @driver.get_ip_address(tap_device, :guest)
	    env[:nfs_host_ip]	= host_ip
	    env[:nfs_machine_ip]	= guest_ip
	  end
	  @app.call(env)
	end

      end
    end
  end
end
