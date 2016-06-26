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

	tap_device = driver.get_attr('tap')
	ip = driver.get_ip_address(tap_device) unless tap_device == ''

	# We just return nil if were not able to identify the VM's IP and
	# let Vagrant core deal with it like docker provider does
	return nil if !ip

	ssh_info = {
	  host: ip,
	  port: @machine.config.ssh.guest_port
	}
	ssh_info
      end

      # This is called early, before a machine is instantiated, to check
      # if this provider is usable. This should return true or false.
      #
      # If raise_error is true, then instead of returning false, this
      # should raise an error with a helpful message about why this
      # provider cannot be used.
      #
      # @param [Boolean] raise_error If true, raise exception if not usable.
      # @return [Boolean]
      def self.usable?(raise_error=false)
	# Return true by default for backwards compat since this was
	# introduced long after providers were being written.
	true
      end

      # This is called early, before a machine is instantiated, to check
      # if this provider is installed. This should return true or false.
      #
      # If the provider is not installed and Vagrant determines it is
      # able to install this provider, then it will do so. Installation
      # is done by calling Environment.install_provider.
      #
      # If Environment.can_install_provider? returns false, then an error
      # will be shown to the user.
      def self.installed?
	# By default return true for backwards compat so all providers
	# continue to work.
	true
      end

      # This should return an action callable for the given name.
      #
      # @param [Symbol] name Name of the action.
      # @return [Object] A callable action sequence object, whether it
      #   is a proc, object, etc.
      def action(name)
	# Attrmpt to get the action method from the Action class if it 
	# exists, otherwise return nil to show that we don't support the
	# given action
	action_method = "action_#{name}"
	return Action.send(action_method) if Action.respond_to?(action_method)
	nil
      end

      # This method is called if the underying machine ID changes. Providers
      # can use this method to load in new data for the actual backing
      # machine or to realize that the machine is now gone (the ID can
      # become `nil`). No parameters are given, since the underlying machine
      # is simply the machine instance given to this object. And no
      # return value is necessary.
      def machine_id_changed
      end

      # This should return the state of the machine within this provider.
      # The state must be an instance of {MachineState}. Please read the
      # documentation of that class for more information.
      #
      # @return [MachineState]
      def state
        state_id = nil
        state_id = :not_created if !@machine.id
	
	# Use the box's name as vm_name and store it
	vm_name  = @machine.box.name.gsub('/', '_')
	driver.store_attr('vm_name', vm_name)
        # Query the driver for the current state of the machine
        state_id = driver.state(vm_name) if @machine.id && !state_id
        state_id = :unknown if !state_id

        # Get the short and long description
        short = state_id.to_s.gsub("_", " ")
        long  = I18n.t("vagrant_bhyve.states.#{state_id}")

        # If we're not created, then specify the special ID flag
        if state_id == :not_created
          state_id = Vagrant::MachineState::NOT_CREATED_ID
        end

        # Return the MachineState object
        Vagrant::MachineState.new(state_id, short, long)
      end

    end
  end
end
