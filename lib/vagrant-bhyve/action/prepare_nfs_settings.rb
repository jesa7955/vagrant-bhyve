require "log4r"
require "securerandom"
require "digest/md5"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class PrepareNFSSettings
	include Vagrant::Action::Builtin::MixinSyncedFolders

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::prepare_nfs_settings")
	  @app = app
	end

	def call(env)
	  @machine	= env[:machine]
	  @driver	= @machine.provider.driver
	  @app.call(env)

	  if using_nfs?
	    tap_device	= @driver.get_attr('tap')
	    #host_ip	= @driver.get_ip_address(nil, :host)
	    guest_ip 	= @driver.get_ip_address(tap_device, :guest)
	    host_ip	= read_host_ip(guest_ip)
	    env[:nfs_machine_ip]	= guest_ip
	    env[:nfs_host_ip]		= host_ip
	  end
	end

	def using_nfs?
	  !!synced_folders(@machine)[:nfs]
	end

	# Ruby way to get host ip
	def read_host_ip(ip)
	  UDPSocket.open do |s|
	    if(ip.kind_of?(Array))
	      s.connect(ip.last, 1)
	    else
	      s.connect(ip, 1)
	    end
	    s.addr.last
	  end
	end

      end
    end
  end
end
