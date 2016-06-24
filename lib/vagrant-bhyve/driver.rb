require "log4r"
require "fileutils"


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
	result = execute(true, "test $(uname -K) -lt 1000000")
	raise Errors::SystemVersionIsTooLow if result == 0

	# Check whether POPCNT is supported
	result = execute(false, "#{@sudo} grep -E '^[ ] +Features2' /var/run/dresult.boot | tail -n 1")
	raise Errors::MissingPopcnt unless result =~ /POPCNT/

	# Check whether EPT is supported for Intel
	result = execute(false, "#{@sudo} grep -E '^[ ]+VT-x' /var/run/dresult.boot | tail -n 1")
	raise Errors::MissingEpt unless result =~ /EPT/

	# Check VT-d 
	result = execute(false, "#{@sudo} acpidump -t | grep DMAR")
	raise Errors::MissingIommu if result.length == 0 
      end

      def load_module(module_name)
	result = execute(true, "#{@sudo} kldstat -qm #{module_name} >/dev/null 2>&1")
	if result != 0
	  result = execute(true, "#{@sudo} kldload #{module_name} >/dev/null 2>&1")
	  result != 0 && raise Errors::UnableToLoadModule
	end
      end

      def create_network_device(device_name, device_type, env = nil)
	return if device_name.length == 0

	# Check whether the switch has been created
	switch_iden = get_interface_name(device_name)
	return if switch_iden.length != 0

	# Create new bridge device
	interface_name = execute(false, "#{@sudo} ifconfig #{device_type} create")
	raise Errors::UnableToCreateBridge if interface_name.length == 0
	# Add new created bridge device's description
	execute(false, "#{@sudo} ifconfig #{interface_name} description #{device_name} up")

	# Configure tap device
	if device_name == 'tap' and env
	  mtu = execute(false, "ifconfig #{env[:switch]} | head -n1 | awk '{print $NF}'")
	  execute(false, "ifconfig #{interface_name} mtu #{mtu}") if mtu and mtu != '1500'
	  # Add tap device into switch member
	  execute(false, "ifconfig #{env[:switch]} addm #{interface_name}")
	end
	# Return the new created interface_name
	interface_name
      end

      # For now, only IPv4 is supported
      def enable_nat(switch_name, env)
	ui = env[:ui]
	directory = env[:machine].box.directory
	# Choose a subnet for this switch
	bridge_name = get_interface_name(switch_name)	
	index = bridge_name =~ /\d/
	raise Errors::NerworkInterfaceNotCreated unless index
	bridge_num = bridge_name[indxe..-1]
	sub_net = "172.16." + bridge_num

	# Config IP for the switch
	execute(false, "ifconfig #{bridge_name} #{sub_net}" + ".1/24")

	# Get default gateway
	gateway = execute(false, "netstat -4rn | grep default | awk '{print $4}")
	# Add gateway as a bridge member
	execute(false, "ifconfig #{bridge_name} addm #{gateway}")
	
	# Create a basic dnsmasq setting
	# Basic settings
	dnsmasq_conf = directory.join("dnsmasq.conf").to_s
	dnsmasq_file = File.open(dnsmasq_conf, "w")
	dnsmasq_file.puts <<-EOF
	#vagrant-bhyve dhcp
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
	pf_conf = directory.join("pf.conf").to_s
	pf_file = File.open(pf_conf, "w")
	pf.file.puts "#vagrant-bhyve nat"
	pf.file.puts "nat on #{gateway} from #{sub_net}.0/24 to any ->#{gateway}"
	# We have to use shell utility to add this part to /etc/pf.conf for now
	ui.warn "We are going change your /etc/pf.conf to enable nat for VMs"
	execute(false, "echo '# Include pf configure file to enable NAT for vagrant-bhyve' | #{@sudo} tee -a /etc/pf.conf")
	execute(false, "echo 'include #{pf_conf}'| #{@sudo} tee -a /etc/pf.conf")
	restart_service("pf")
	# Enable forwarding
	execute(false, "#{@sudo} sysctl net.inet.ip.forwarding=1 >/dev/null 2>&1")
      end

      def get_ip_address(interface_name)
	interface_info = execute(false, "ifconfig", interface_name) low = interface_info =~ /inet/
      	up = interface_info =~ /netmask/
	ip = interface_info[low..up].split[1]
      end

      def load(loader, machine)
	run_cmd = @sudo
	case loader
	when 'bhyveload'
	  run_cmd += ' bhyveload'
	  # Set autoboot, and memory and disk
	  run_cmd += " -m #{machine.config.memory}"
	  #########################################################
	  #		TBD: problem with disk name		  #
	  #########################################################
	  run_cmd += " -d #{machine.box.directory.join('disk.img').to_s}"
	  run_cmd += " -e autoboot_delay=0"
	when 'grub-bhyve'
	  command = execute(false, "which grub-bhyve")
	  raise Errors::GrubBhyveNotInstalled if command.length == 0
	  run_cmd += command
	  run_cmd += " -m #{machine.box.directory.join('device.map').to_s}")
	  run_cmd += " -M #{machine.config.memory}")
	  # Maybe there should be some grub config in Vagrantfile, for now
	  # we just use this hd0,1 as default root and don't use -d -g 
	  # argument
	  run_cmd += " -r hd0,1"
	else
	  raise Errors::UnrecognizedLoader
	end
	
	# Find an available nmdm device and add it as loader's -m argument
	nmdm_num = find_available_nmdm
	run_cmd += "-c /dev/nmdm#{nmdm_num}A"

	vm_name = machine.env[:vm_name]
	run_cmd += " #{vm_name}"
	execute(false, run_cmd)
      end

      def boot(machine)
	firmware	= machine.box.metadata[:firmware]
	loader		= machine.box.metadata[:loader]
	config		= machine.config

	run_cmd = @sudo
	# Prevent virtual CPU use 100% of host CPU
	run_cmd += " bhyve -H -P"

	# Configure for hostbridge & lpc device, Windows need slot 0 and 31
	# while others don't care, so we use slot 0 and 31
	case config.hostbridge
	when 'amd'
	  run_cmd += " -s 0,amd_hostbridge"
	when 'no'
	else
	  run_cmd += " -s 0,hostbridge"
	end
	run_cmd += " -s 31,lpc "

	# Generate ACPI tables for FreeBSD guest
	run_cmd += " -A" if loader == 'bhyveload'
	
	# For UEFI, we need to point a UEFI firmware which should be 
	# included in the box.
	run_cmd += " -l bootrom,#{machine.box.directory.join('uefi.fd').to_s}" if firmware == "uefi"
	
	# Enable graphics if the box is configed so

	# Allocate resources
	run_cmd += " -c #{config.cpu}"
	run_cmd += " -m #{config.memory}"

	# Disk 
	run_cmd += " -s 1, ahci-hd,#{config.box.directory.join("disk.img").to_s}"

	# Tap device
	run_cmd += " -s 2, virtio-net,#{machine.env[:tap]}"

	# Console
	nmdm_num = find_available_nmdm
	machine.env[:nmdm] = nmdm_num
	run_cmd += " -l com1,/dev/nmdm#{nmdm_num}A}"

	vm_name = machine.env[:vm_name]
	run_cmd += " #{vm_name}"

	execute(false, run_cmd)
      end

      def shutdown(env)
	ui = env[:ui]
	vm_name = env[:vm_name]
	if state == :not_running
	  ui.warn "You are trying to shutdown a VM which is not running"
	else
	  bhyve_pid = execute(false, "pgrep -fx 'bhyve: #{vm_name}'")
	  loader_pid = execute(false, "pgrep -fl 'grub-bhyve|bhyveload' | grep #{vm_name} | cut -d' ' -f1")
	  if bhyve_pid.length != 0
	    # We need to kill bhyve process twice and wait some time to make
	    # sure VM is shuted down.
	    execute(false, "#{@sudo} kill SIGTERM #{bhyve_pid}")
	    sleep 1
	    execute(false, "#{@sudo} kill SIGTERM #{bhyve_pid}")
	  else if loader_pid.length != 0
	    ui.warn "Guest is going to be exit in bootloader stage"
	    execute(false, "#{@sudo} kill #{loader_pid}")
	    execute(false, "#{@sudo} bhyvectl --destroy --vm=#{vm_name} >/dev/null 2>&1")
	  else
	    ui.warn "Unable to locate process id for #{vm_name}"
	  end
	end
      end

      def port_forward(forward_information, pf_conf, tap_device)
	pf_file = File.open(pf_conf, 'a')
	ip_address = get_ip_address(tap_device)
	tcp = "pass in on t10 proto tcp from any to any port #{forward_information[:host]} rdr-to #{ip_address} port #{forward_information[:guest]}"
	udp = "pass in on t10 proto udp from any to any port #{forward_information[:host]} rdr-to #{ip_address} port #{forward_information[:guest]}"
	pf_file.puts tcp
	pf_file.puts udp
	restart_service("pf")
      end

      def cleanup(env)
	switch = env[:switch]
	tap = env[:tap]
	directory = env[:machine].box.directory

	# Destory network interfaces
	execute(false, "#{@sudo} ifconfg #{switch} destroy") if switch.length != 0
	execute(false, "#{@sudo} ifconfg #{tap} destroy") if tap.length != 0

	# Delete configure files
	FileUtils.rm directory.join('dnsmasq.conf').to_s
	FileUtils.rm directory.join('pf.conf').to_s

	# Clean /etc/pf.conf
	execute(false, "sed -I'' '/# Include pf configure file to enable NAT for vagrant-bhyve/ {N;d;}' /etc/pf.conf")
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

      def running?(vm_name)
	execute(true, "test -e /dev/vmm/#{vm_name}") == 0
      end

      def execute(*cmd, **opts, &block)
	@executor.execute(*cmd, **opts, &block)
      end

      private

      # Get the interface name for a switch(like 'bridge0')
      def get_interface_name(device_name)
	desc = device_name + '\$'
	cmd = "ifconfig -a | grep -B 1 #{desc} | head -n1 | awk -F: '{print $1}'"
	result = execute(false, cmd)
      end

      def restart_service(service_name)
	status = execute(true, "service #{service_name} status >/dev/null 2>&1")
	if status == 0
	  cmd = "restart"
	else
	  cmd = "start"
	end
	status = execute(true, "service #{service_name} #{cmd} >/dev/null 2>&1")
	raise Errors::RestartServiceFailed if status != 0
      end

      def find_available_nmdm
	while true
	  result = execute(false, "ls -l /dev/ | grep 'nmdm#{nmdm_num}A'")
	  break if result.length == 0
	  nmdm_num += 1
	end
	nmdm_num
      end
	end

    end
  end
end
