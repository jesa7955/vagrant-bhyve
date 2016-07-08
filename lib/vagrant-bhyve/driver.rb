require "log4r"
require "fileutils"
require "digest/md5"


module VagrantPlugins
  module ProviderBhyve
    class Driver

      # This executor is responsible for actually executing commands, including 
      # bhyve, dnsmasq and other shell utils used to get VM's state
      attr_accessor :executor

      def initialize(machine)
	@logger = Log4r::Logger.new("vagrant_bhyve::driver")
	@machine = machine
	@data_dir = @machine.data_dir
	@executor = Executor::Exec.new
	
	# if vagrant is excecuted by root (or with sudo) then the variable
	# will be empty string, otherwise it will be 'sudo' to make sure we
	# can run bhyve, bhyveload and pf with sudo privilege
	if Process.uid == 0
	  @sudo = ''
	else
	  @sudo = 'sudo'
	end
      end

      def import(machine, ui)
	box_dir		= machine.box.directory
	instance_dir	= @data_dir
	store_attr('id', machine.id)
	cp		= execute(true, "which gcp")
	if cp != 0
	  ui.warn "We need gcp in coreutils package to copy image file, installing from pkg."
	  pkg_install('coreutils')
	end
	execute(false, "gcp --sparse=always #{box_dir.join('disk.img').to_s} #{instance_dir.to_s}")
	FileUtils.copy(box_dir.join('uefi.fd'), instance_dir) if box_dir.join('uefi.fd').exist?
	FileUtils.copy(box_dir.join('device.map'), instance_dir) if box_dir.join('device.map').exist?
      end

      def destroy
	FileUtils.rm_rf(Dir.glob(@data_dir.join('*').to_s))
      end

      def check_bhyve_support
	# Check whether FreeBSD version is lower than 10
	result = execute(true, "test $(uname -K) -lt 1000000")
	raise Errors::SystemVersionIsTooLow if result == 0

	# Check whether POPCNT is supported
	result = execute(false, "#{@sudo} grep -E '^[ ] +Features2' /var/run/dmesg.boot | tail -n 1")
	raise Errors::MissingPopcnt unless result =~ /POPCNT/

	# Check whether EPT is supported for Intel
	result = execute(false, "#{@sudo} grep -E '^[ ]+VT-x' /var/run/dmesg.boot | tail -n 1")
	raise Errors::MissingEpt unless result =~ /EPT/

	# Check VT-d 
	#result = execute(false, "#{@sudo} acpidump -t | grep DMAR")
	#raise Errors::MissingIommu if result.length == 0 
      end

      def load_module(module_name)
	result = execute(true, "#{@sudo} kldstat -qm #{module_name} >/dev/null 2>&1")
	if result != 0
	  result = execute(true, "#{@sudo} kldload #{module_name} >/dev/null 2>&1")
	  raise Errors::UnableToLoadModule if result != 0
	end
      end

      def create_network_device(device_name, device_type)
	return if device_name.length == 0

	# Check whether the bridge has been created
	interface_name = get_interface_name(device_name)
	interface_name = execute(false, "#{@sudo} ifconfig #{device_type} create") if interface_name.length == 0
	raise Errors::UnableToCreateInterface if interface_name.length == 0
	# Add new created device's description
	execute(false, "#{@sudo} ifconfig #{interface_name} description #{device_name} up")

	# Store the new created network device's name
	store_attr(device_type, interface_name)

	# Configure tap device
	if device_type == 'tap'
	  # Add the tap device as bridge's member
	  bridge = get_attr('bridge')
	  # Make sure the tap deivce has the same mtu value
	  # with the bridge
	  mtu = execute(false, "ifconfig #{bridge} | head -n1 | awk '{print $NF}'")
	  execute(false, "#{@sudo} ifconfig #{interface_name} mtu #{mtu}") if mtu.length != 0 and mtu != '1500'
	  execute(false, "#{@sudo} ifconfig #{bridge} addm #{interface_name}")
	  # Setup VM-specific pf rules
	  id		= get_attr('id')
	  pf_conf	= @data_dir.join('pf.conf')
	  pf_conf.open('w') { |f| f.puts "set skip on #{interface_name}" }
         if pf_enabled?
           execute(false, "#{@sudo} pfctl -d")
         end
	  execute(false, "#{@sudo} pfctl -a '/vagrant_#{id}' -ef #{pf_conf.to_s}") 
	end
      end

      # For now, only IPv4 is supported
      def enable_nat(bridge, ui)
	bridge_name 	= get_interface_name(bridge)
	return if execute(true, "ifconfig #{bridge_name} | grep inet") == 0

	directory	= @data_dir
	# Choose a subnet for this bridge
	index = bridge_name =~ /\d/
	bridge_num = bridge_name[index..-1]
	sub_net = "172.16." + bridge_num

	# Config IP for the bridge
	execute(false, "#{@sudo} ifconfig #{bridge_name} #{sub_net}.1/24")

	# Get default gateway
	gateway = execute(false, "netstat -4rn | grep default | awk '{print $4}'")
	store_attr('gateway', gateway)
	# Add gateway as a bridge member
	execute(false, "#{@sudo} ifconfig #{bridge_name} addm #{gateway}")
	
	# Enable forwarding
	execute(false, "#{@sudo} sysctl net.inet.ip.forwarding=1 >/dev/null 2>&1")
	execute(false, "#{@sudo} sysctl net.inet6.ip6.forwarding=1 >/dev/null 2>&1")
	
	# Change pf's configuration
	pf_conf = directory.join("pf.conf")
	pf_conf.open("w") do |pf_file|
	  pf_file.puts "#vagrant-bhyve nat"
	  pf_file.puts "set skip on #{bridge_name}"
	  pf_file.puts "nat on #{gateway} from {#{sub_net}.0/24} to any -> (#{gateway})"
	end
	# Use pfctl to enable pf rules
	execute(false, "#{@sudo} cp #{pf_conf.to_s} /usr/local/etc/pf.#{bridge_name}.conf")
       if pf_enabled?
         execute(false, "#{@sudo} pfctl -d")
       end
	execute(false, "#{@sudo} pfctl -a '/vagrant_#{bridge_name}' -ef /usr/local/etc/pf.#{bridge_name}.conf")

	# Create a basic dnsmasq setting
	# Basic settings
	dnsmasq = execute(true, 'which dnsmasq')
	if dnsmasq != 0
	  ui.warn "dnsmasq is not installed on your system, installing using pkg."
	  pkg_install('dnsmasq')
	end
	dnsmasq_conf = directory.join("dnsmasq.conf")
	dnsmasq_conf.open("w") do |dnsmasq_file|
	  dnsmasq_file.puts <<-EOF
	  domain-needed
	  except-interface=lo0
	  bind-interfaces
	  local-service
	  dhcp-authoritative
	  EOF
	  # DHCP part
	  dnsmasq_file.puts "interface=#{bridge_name}"
	  dnsmasq_file.puts "dhcp-range=#{sub_net + ".10," + sub_net + ".254"}"
	  dnsmasq_file.puts "dhcp-option=option:dns-server,#{sub_net + ".1"}"
	end
	execute(false, "#{@sudo} cp #{dnsmasq_conf.to_s} /usr/local/etc/dnsmasq.#{bridge_name}.conf")
	dnsmasq_cmd = "dnsmasq -C /usr/local/etc/dnsmasq.#{bridge_name}.conf -l /var/run/dnsmasq.#{bridge_name}.leases -x /var/run/dnsmasq.#{bridge_name}.pid"
	execute(false, "#{@sudo} #{dnsmasq_cmd}")

      end

      def get_ip_address(interface_name)
	bridge_name = get_attr('bridge')
	return nil if execute(true, "test -e /var/run/dnsmasq.#{bridge_name}.pid") != 0
	mac         = get_attr('mac')
	leases_file = Pathname.new("/var/run/dnsmasq.#{bridge_name}.leases")
	leases_info = leases_file.open('r'){|f| f.readlines}.select{|line| line.match(mac)}
	raise Errors::NotFoundLeasesInfo if leases_info == []
	# IP address for a device is on third coloum
	ip = leases_info[0].split[2]
      end

      def ip_ready?
        bridge_name = get_attr('bridge')
        mac         = get_attr('mac')
        leases_file = Pathname.new("/var/run/dnsmasq.#{bridge_name}.leases")
        return (leases_file.open('r'){|f| f.readlines}.select{|line| line.match(mac)} != [])
      end

      def ssh_ready?(ssh_info)
        return execute(true, "nc -z #{ssh_info[:host]} #{ssh_info[:port]}") == 0 if ssh_info[:host]
        return false
      end

      def load(loader, machine, ui)
	run_cmd		= @sudo
	directory	= @data_dir
	config		= machine.provider_config
	case loader
	when 'bhyveload'
	  run_cmd += ' bhyveload'
	  # Set autoboot, and memory and disk
	  run_cmd += " -m #{config.memory}"
	  #run_cmd += " -d #{machine.box.directory.join('disk.img').to_s}"
	  run_cmd += " -d #{directory.join('disk.img').to_s}"
	  run_cmd += " -e autoboot_delay=0"
	when 'grub-bhyve'
	  grub-bhyve = execute(true, "which grub-bhyve")
	  if grub-bhyve != 0
	    ui.warn "grub-bhyve is not found on your system, installing with pkg"
	    pkg_install('grub2-bhyve')
	  end
	  run_cmd += "grub-bhyve"
	  run_cmd += " -m #{directory.join('device.map').to_s}"
	  run_cmd += " -M #{config.memory}"
	  # Maybe there should be some grub config in Vagrantfile, for now
	  # we just use this hd0,1 as default root and don't use -d -g 
	  # argument
	  run_cmd += " -r hd0,1"
	end

	# Find an available nmdm device and add it as loader's -m argument
	nmdm_num = find_available_nmdm
	run_cmd += " -c /dev/nmdm#{nmdm_num}A"

	vm_name = get_attr('vm_name')
	run_cmd += " #{vm_name}"
	execute(false, run_cmd)
      end

      def boot(machine, ui)
	firmware	= machine.box.metadata['firmware']
	loader		= machine.box.metadata['loader']
	directory	= @data_dir
	config		= machine.provider_config

	# Run in bhyve in background
	run_cmd = "sudo -b"
	# Prevent virtual CPU use 100% of host CPU
	run_cmd += " bhyve -HP"

	# Configure for hostbridge & lpc device, Windows need slot 0 and 31
	# while others don't care, so we use slot 0 and 31
	case config.hostbridge
	when 'amd'
	  run_cmd += " -s 0,amd_hostbridge"
	when 'no'
	else
	  run_cmd += " -s 0,hostbridge"
	end
	run_cmd += " -s 31,lpc"

	# Generate ACPI tables for FreeBSD guest
	run_cmd += " -A" if loader == 'bhyveload'

	# For UEFI, we need to point a UEFI firmware which should be 
	# included in the box.
	run_cmd += " -l bootrom,#{directory.join('uefi.fd').to_s}" if firmware == "uefi"

	# TODO Enable graphics if the box is configed so
	
	uuid = get_attr('id')
	run_cmd += " -U #{uuid}"

	# Allocate resources
	run_cmd += " -c #{config.cpus}"
	run_cmd += " -m #{config.memory}"

	# Disk 
	#run_cmd += " -s 1,ahci-hd,#{machine.box.directory.join("disk.img").to_s}"
	run_cmd += " -s 1,ahci-hd,#{directory.join("disk.img").to_s}"

	# Tap device
	tap_device  = get_attr('tap')
	mac_address = get_attr('mac')
	run_cmd += " -s 2,virtio-net,#{tap_device},mac=#{mac_address}"

	# Console
	nmdm_num = find_available_nmdm
	@data_dir.join('nmdm_num').open('w') { |nmdm_file| nmdm_file.write nmdm_num }
	run_cmd += " -l com1,/dev/nmdm#{nmdm_num}A"

	vm_name = get_attr('vm_name')
	run_cmd += " #{vm_name} >/dev/null 2>&1"

	execute(false, run_cmd)
      end

      def shutdown(ui)
	vm_name = get_attr('vm_name')
	if state(vm_name) == :not_running
	  ui.warn "You are trying to shutdown a VM which is not running"
	else
	  bhyve_pid = execute(false, "pgrep -fx 'bhyve: #{vm_name}'")
	  loader_pid = execute(false, "pgrep -fl 'grub-bhyve|bhyveload' | grep #{vm_name} | cut -d' ' -f1")
	  if bhyve_pid.length != 0
	    # We need to kill bhyve process twice and wait some time to make
	    # sure VM is shuted down.
	    while bhyve_pid.length != 0
	      begin
		execute(false, "#{@sudo} kill -s TERM #{bhyve_pid}")
                sleep 1
		bhyve_pid = execute(false, "pgrep -fx 'bhyve: #{vm_name}'")
	      rescue Errors::ExecuteError
		break
	      end
	    end
	  elsif loader_pid.length != 0
	    ui.warn "Guest is going to be exit in bootloader stage"
	    execute(false, "#{@sudo} kill #{loader_pid}")
	  else
	    ui.warn "Unable to locate process id for #{vm_name}"
	  end
	end
      end

      def forward_port(forward_information, tap_device)
	id		= get_attr('id')
	ip_address	= get_ip_address(tap_device)
	pf_conf 	= @data_dir.join('pf.conf')
	rule 		= "rdr on #{forward_information[:adapter]} proto {udp, tcp} from any to any port #{forward_information[:host_port]} -> #{ip_address} port #{forward_information[:guest_port]}"
	
	pf_conf.open('a') do |pf_file|
	  pf_file.puts rule
	end
	# Update pf rules
       if pf_enabled?
         execute(false, "#{@sudo} pfctl -d")
       end
	execute(false, "#{@sudo} pfctl -a '/vagrant_#{id}' -ef #{pf_conf.to_s}")
	#execute(false, "#{@sudo} pfctl -a vagrant_#{id} -F all")

      end

      def cleanup
	bridge		= get_attr('bridge')
	tap		= get_attr('tap')
	vm_name		= get_attr('vm_name')
	id		= get_attr('id')
	directory	= @data_dir
    
	# Destroy vmm device
  	execute(false, "#{@sudo} bhyvectl --destroy --vm=#{vm_name} >/dev/null 2>&1") if state(vm_name) == :uncleaned

	# Clean instance-specific pf rules
	execute(false, "#{@sudo} pfctl -a '/vagrant_#{id}' -F all")
	# Destory tap interfaces
	execute(false, "#{@sudo} ifconfig #{tap} destroy") if execute(true, "ifconfig #{tap}") == 0
	
	# Delete configure files
	#FileUtils.rm directory.join('dnsmasq.conf').to_s if directory.join('dnsmasq.conf').exist?
	#FileUtils.rm directory.join('pf.conf').to_s if directory.join('pf.conf').exist?

	# Clean nat configurations if there is no VMS is using the bridge
       member_num = 3
	member_num = execute(false, "ifconfig #{bridge} | grep -c 'member' || true") if execute(true, "ifconfig #{bridge}") == 0
	if member_num.to_i < 2
	  execute(false, "#{@sudo} pfctl -a '/vagrant_#{bridge}' -F all")
          if directory.join('pf_disabled').exist?
            FileUtils.rm directory.join('pf_disabled')
            execute(false, "#{@sudo} pfctl -d")
          end
          execute(false, "#{@sudo} ifconfig #{bridge} destroy")
          pf_conf = "/usr/local/etc/pf.#{bridge}.conf"
          execute(false, "#{@sudo} rm #{pf_conf}") if execute(true, "test -e #{pf_conf}") == 0
          if execute(true, "test -e /var/run/dnsmasq.#{bridge}.pid") == 0
            dnsmasq_cmd = "dnsmasq -C /usr/local/etc/dnsmasq.#{bridge}.conf -l /var/run/dnsmasq.#{bridge}.leases -x /var/run/dnsmasq.#{bridge}.pid"
            dnsmasq_conf    = "/var/run/dnsmasq.#{bridge}.leases"
            dnsmasq_leases  = "/var/run/dnsmasq.#{bridge}.pid"
            dnsmasq_pid     = "/usr/local/etc/dnsmasq.#{bridge}.conf"
            execute(false, "#{@sudo} kill -9 $(pgrep -fx \"#{dnsmasq_cmd}\")")
            execute(false, "#{@sudo} rm #{dnsmasq_leases}") if execute(true, "test -e #{dnsmasq_leases}") == 0
            execute(false, "#{@sudo} rm #{dnsmasq_pid}") if execute(true, "test -e #{dnsmasq_pid}") == 0
            execute(false, "#{@sudo} rm #{dnsmasq_conf}") if execute(true, "test -e #{dnsmasq_conf}") == 0
          end
        end
      end

      def state(vm_name)
	vmm_exist = execute(true, "test -e /dev/vmm/#{vm_name}") == 0
	if vmm_exist
	  if execute(true, "pgrep -fx \"bhyve: #{vm_name}\"") == 0
            :running
	  else
	    :uncleaned
	  end
	else
          :stopped
	end
      end

      def execute(*cmd, **opts, &block)
	@executor.execute(*cmd, **opts, &block)
      end

      def get_mac_address(vm_name)
	# Generate a mac address for this tap device from its vm_name
	# IEEE Standards OUI for bhyve
	mac = "58:9c:fc:0"
	mac += Digest::MD5.hexdigest(vm_name).scan(/../).select.with_index{ |_, i| i.even? }[0..2].join(':')[1..-1]
      end

      # Get the interface name for a bridge(like 'bridge0')
      def get_interface_name(device_name)
	desc = device_name + '\$'
	cmd = "ifconfig -a | grep -B 1 #{desc} | head -n1 | awk -F: '{print $1}'"
	result = execute(false, cmd)
      end

      def restart_service(service_name)
	status = execute(true, "service #{service_name} status >/dev/null 2>&1")
	if status == 0
	  cmd = "onerestart"
	else
	  cmd = "onestart"
	end
	status = execute(true, "service #{service_name} #{cmd} >/dev/null 2>&1")
	raise Errors::RestartServiceFailed if status != 0
      end

      def pf_enabled?
        status = execute(true, "#{@sudo} pfctl -s all | grep -i disabled")
        if status == 0
          store_attr('pf_disabled', 'yes')
          false
        else
          true
        end
      end

      def find_available_nmdm
	nmdm_num = 0
	while true
	  result = execute(true, "ls -l /dev/ | grep 'nmdm#{nmdm_num}A'")
	  break if result != 0
	  nmdm_num += 1
	end
	nmdm_num
      end
      
      def get_attr(attr)
	name_file = @data_dir.join(attr)
	if File.exist?(name_file)
	  name_file.open('r') { |f| f.readline }
	else
	  nil
	end
      end

      def pkg_install(package)
	  execute(false, "#{@sudo} ASSUME_ALWAYS_YES=yes pkg install #{package}")
      end

      def store_attr(name, value)
	@data_dir.join(name).open('w') { |f| f.write value }
      end

    end
  end
end
