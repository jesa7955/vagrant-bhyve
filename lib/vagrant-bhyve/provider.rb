require "vagrant"
require "log4r"

module VagrantPlugins
  module ProviderBhyve
    autoload :Driver, 'vagrant-bhyve/driver'

    class Provider < Vagrant.plugin('2', :provider)
      
      def initialize(machine)
	@logger = Log4r::Logger.new("vagrant::provider::bhyve")
	@machine = machine
      end

      def action(name)
	# Attrmpt to get the action method from the Action class if it 
	# exists, otherwise return nil to show that we don't support the
	# given action
	action_method = "action_#{name}"
	return Action.send(action_method) if Action.respond_to?(action_method)
	nil
      end

      def driver
	return @driver if @driver
	@driver = Driver.new(@machine)
      end

      # This should return a hash of information that explains how to SSH
      # into the machine. If the machine is not at a point where SSH is 
      # even possiable, then 'nil' should be returned
      #
      # The general structure of this returned hash should be the
      # following:
      #
      # 	{
      # 	 host: "1.2.3.4",
      # 	 port: "22",
      # 	 username: "vagrant",
      # 	 private_key_path: "/path/to/my/key"
      # 	}
      def ssh_info
	return nil if state.id != :running

	ip = driver.get_ipaddress(@machine)

	# We just return nil if were not able to identify the VM's IP and
	# let Vagrant core deal with it like docker provider does
	return nil if !ip

	ssh_info = {
	  host: ip,
	  port: @machine.config.ssh.guest_port
	}
#############################################################
#		TBD	add more ssh info		    #
#############################################################
	ssh_info
      end

      def state

      end


    end
  end
end
