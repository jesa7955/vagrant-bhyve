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

      def load(loader, machine)
	run_cmd = []
	case loader
	when 'bhyveload'
	  run_cmd.push('bhyveload')
	  # Set autoboot, and memory and disk
	  run_cmd.push("-m").push("#{machine.config.memory}")
	  #########################################################
	  #		TBD: problem with disk name		  #
	  #########################################################
	  run_cmd.push("-d").push("#{machine.box.directory.join('disk.img').to_s}")
	  run_cmd += %w(-e autoboot_delay=0)
	when 'grub-bhyve'
	  command = execute(false, %w(which grub-bhyve))
	  raise Errors::GrubBhyveNotInstalled if command.length == 0
	  run_cmd.push(command)
	  run_cmd.push("-m").push("#{machine.box.directory.join('device.map').to_s}")
	  run_cmd.push("-M").push("#{machine.config.memory}")
	  # Maybe there should be some grub config in Vagrantfile, for now
	  # we just use this hd0,1 as default root and don't use -d -g 
	  # argument
	  run_cmd += %w(-r hd0,1)
	else
	  raise Errors::UnrecognizedLoader
	end
	
	# Find an available nmdm device and add it as loader's -m argument
	nmdm_num = 1
	while true
	  result = execute(false, %w(ls -l /dev/ | grep).push("nmdm#{nmdm_num}A"))
	  break if result.length == 0
	  nmdm_num += 1
	end
	run_cmd.push("-c").push("/dev/nmdm#{nmdm_num}A")

	vm_name = machine.box.name.gsub('/', '_')
	run_cmd.push(vm_name)
	execute(false, run_cmd)
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
