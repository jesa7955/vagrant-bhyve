require "log4r"

module VagrantPlugins
  module ProviderBhyve
    class Driver

      # This executor is responsible for actually executing commands, including 
      # bhyve, dnsmasq and other shell utils used to get VM's state
      attr_accessor :executor
      
      def initialize(machine)
	@logger = Log4r::Logger.new("vagrant_bhyve::driver")
	@machine = machine
	@executor = Executor::Exec.new

	# if vagrant is excecuted by root (or with sudo) then the variable
	# will be empty string, otherwise it will be 'sudo' to make sure we
	# can run bhyve, bhyveload and pf with sudo privilege
	if Process.uid == 0
	 @sudo = ''
	@sudo = 'sudo'
	end
      end

      def load_module(module_name)
	result = execute(true, @sudo, "kldstat", "-qm", module_name, ">/dev/null", "2>&1")
	if result != 0
	  result = execute(true, @sudo, "kldload", module_name, ">/dev/null", "2>&1")
	  result != 0 && raise Errors::UnableToLoadModule
	end
      end

      def create_switch(switch_name)
	return if switch_name.length == 0

	# Check whether the switch has been created
	desc = switch_name + '\$'
	cmd = %w(ifconfig -a | grep -B 1).push(desc).push("|")
	cmd += %w(head -n 1 | awk -F: '{print $1}')
	result = execute(false, cmd)
	return if result.length != 0

	# Create new bridge device
	bridge_name = execute(false, @sudo, "ifconfig", "bridge", "create")
	raise Errors::UnableToCreateBridge if bridge_name.length == 0
	# Add new created bridge device's description
	execute(false, @sudo, "ifconfig", bridge_name, "description", switch_name, "up")
      end

      def loader(loader)
      end

      def bhyve
      end

      def state
	# Prepare for other bhyve state which may be added in. For now, only
	# running and not_running.
	case
	when running?
	  :running
	else
	:not_running
	end
      end

      def running?
	execute(true, "test", "-e", "/dev/vmm/#{@machine.name}") == 0
      end

      def execute(*cmd, **opts, &block)
	@executor.execute(*cmd, **opts, &block)
      end

    end
  end
end
