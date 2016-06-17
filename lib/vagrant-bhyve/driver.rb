require "log4r"
require "sudo"

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

      def check_bhyve_support
	# Check whether FreeBSD version is lower than 10
	result = execute(true, %w(test ${VERSION_BSD} -lt 1000000))
	raise Errors::SystemVersionIsTooLow if result == 0

	# Check whether POPCNT is supported
	result = execute(false, [@sudo] + %w(grep -E '^[ ] +Features2' /var/run/dresult.boot | tail -n 1))
	raise Errors::MissingPopcnt unless result =~ /POPCNT/

	# Check whether EPT is supported for Intel
	result = execute(false, [@sudo] + %w(grep -E '^[ ]+VT-x' /var/run/dresult.boot | tail -n 1))
	raise Errors::MissingEpt unless result =~ /EPT/

	# Check VT-d 
	result = execute(false, [@sudo] + %w(acpidump -t | grep DMAR))
	raise Errors::MissingIommu if result.length == 0 
      end

      def load_module(module_name)
	result = execute(true, @sudo, "kldstat", "-qm", module_name, ">/dev/null", "2>&1")
	if result != 0
	  result = execute(true, @sudo, "kldload", module_name, ">/dev/null", "2>&1")
	  result != 0 && raise Errors::UnableToLoadModule
	end
      end

      def create_network_device(device_name, device_type)
	return if device_name.length == 0

	# Check whether the switch has been created
	switch_iden = get_interface_name(device_name)
	return if switch_iden.length != 0

	# Create new bridge device
	interface_name = execute(false, @sudo, "ifconfig", device_type, "create")
	raise Errors::UnableToCreateBridge if interface_name.length == 0
	# Add new created bridge device's description
	execute(false, @sudo, "ifconfig", interface_name, "description", device_name, "up")

	# Return the new created interface_name
	interface_name
      end

      # For now, only IPv4 is supported
      def enable_nat(switch_name, directory, ui)
	# Choose a subnet for this switch
	bridge_name = get_interface_name(switch_name)	
	index = bridge_name =~ /\d/
	raise Errors::SwitchNotCreated unless index
	bridge_num = bridge_name[indxe..-1]
	sub_net = "172.16." + bridge_num

	# Config IP for the switch
	execute(false, "ifconfig", bridge_name, sub_net + ".1/24"

	# Get default gateway
	gateway = execute(false, %w(netstat -4rn | grep default | awk '{print $4}'))
	
	# Create a basic dnsmasq setting
	# Basic settings
	dnsmasq_conf = directory.join("dnsmasq.conf")
	dnsmasq_file = File.open(dnsmasq_conf, "w")
	dnsmasq_file.puts <<-EOF
	#vm-bhyve dhcp
	port=0
	domain-needed
	no-resolv
	except-interface=lo0
	bind-interfaces
	local-service
	dhcp-authoritative
	EOF
	# DHCP part
	dnsmasq_file.puts "interface=#{bridge_name}"
	dnsmasq_file.puts "dhcp-range=#{sub_net + ".10," + subnet + ".254"}"
	dnsmasq_file.close
	
	# Change pf's configuration
	pf_conf = directory.join("pf.conf")
	pf_file = File.open(pf_conf, "w")
	pf.file.puts "nat on #{gateway} from #{sub_net}.0/24 to any ->#{gateway}"
	# We have to use shell utility to add this part to /etc/pf.conf for now
	execute(false, %w(echo 'include).push(pf_conf + "'").push("|").push(@sudo) + %w(tee -a /etc/pf.conf))
	restart_service("pf")
	# Enable forwarding
	execute(false, [@sudo] + %w(sysctl net.inet.ip.forwarding=1 >/dev/null 2>&1))
      end

      def load(loader, machine)
	run_cmd = [@sudo]
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
	machine.env[:nmdm] = nmdm_num

	vm_name = machine.box.name.gsub('/', '_')
	run_cmd.push(vm_name)
	execute(false, run_cmd)
      end

      def bhyve(machine)
	firmware	= machine.box.metadata[:firmware]
	loader		= machine.box.metadata[:loader]
	config		= machine.config

	run_cmd = [@sudo]
	# Prevent virtual CPU use 100% of host CPU
	run_cmd += %w(bhyve -H -P)

	# Generate ACPI tables for FreeBSD guest
	run_cmd.push("-A") if loader == 'bhyveload'
	
	# For UEFI, we need to point a UEFI firmware which should be 
	# included in the box.
	if firmware == "uefi"
	run_cmd += %w(-l bootrom,)
	run_cmd.push(machine.box.directory.join('uefi.fd'))
	end
	
	# Enable graphics if the box is configed so

	# Allocate resources
	run_cmd.push("-c").push(config.cpu)
	run_cmd.push("-m").push(config.memory)

	# Disk 
	run_cmd += %w(-s 0, ahci-hd,)
	run_cmd.push(config.box.directory.join("disk.img"))

	# Tap device
	run_cmd += %w(-s 1, virtio-net,)
	run_cmd.push(machine.env[:tap])

	# Console
	run_cmd += %w(-l com1,)
	run_cmd.push("/dev/nmdm#{machine.env[:nmdm]}A"

	vm_name = machine.box.name.gsub('/', '_')
	run_cmd.push(vm_name)

	execute(false, run_cmd)
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

      private

      # Get the interface name for a switch(like 'bridge0')
      def get_interface_name(device_name)
	desc = device_name + '\$'
	cmd = %w(ifconfig -a | grep -B 1).push(desc).push("|")
	cmd += %w(head -n 1 | awk -F: '{print $1}')
	result = execute(false, cmd)
      end

      def restart_service(service_name)
	status = execute(true, ["service"].push(service_name) + %w(status >/dev/null 2>&1))
	if status == 0
	  cmd = "restart"
	else
	  cmd = "start"
	end
	status = execute(true, ["service"].push(service_name).push(cmd) + %w(>/dev/null 2>&1))
	raise Errors::RestartServiceFailed if status != 0
      end

    end
  end
end
