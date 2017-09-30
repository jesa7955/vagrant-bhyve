require "log4r"
require "fileutils"
require "digest/md5"
require "io/console"
require "ruby_expect"


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
	password = ''
	check_and_install('gcp', 'coreutils', ui)
	check_and_install('fdisk-linux', 'linuxfdisk', ui)
	execute(false, "gcp --sparse=always #{box_dir.join('disk.img').to_s} #{instance_dir.to_s}")
	if box_dir.join('uefi.fd').exist?
	  FileUtils.copy(box_dir.join('uefi.fd'), instance_dir) 
	  store_attr('firmware', 'uefi')
	else
	  store_attr('firmware', 'bios')
	  boot_partition = execute(false, "cd #{instance_dir.to_s} && fdisk-linux -lu disk.img | grep 'disk.img' | grep -E '\\*' | awk '{print $1}'")
	  if boot_partition == ''
	    store_attr('bootloader', 'bhyveload')
	  else
	    if execute(true, "sudo -n grub-bhyve --help") != 0
	      ui.warn "We need to use your password to commmunicate with grub-bhyve, please make sure the password you input is correct."
	      password = ui.ask("Password:", echo: false)
	    end
	    store_attr('bootloader', 'grub-bhyve')
	    # We need vmm module to be loaded to use grub-bhyve
	    load_module('vmm')
	    # Check whether grub-bhyve is installed
	    check_and_install('grub-bhyve', 'grub2-bhyve', ui)
	    instance_dir.join('device.map').open('w') do |f|
	      f.puts "(hd0) #{instance_dir.join('disk.img').to_s}"
	    end
	    partition_index	= boot_partition =~ /\d/
	    partition_id	= boot_partition[partition_index..-1]
	    grub_run_partition	= "msdos#{partition_id}"
	    files		= grub_bhyve_execute("ls (hd0,#{grub_run_partition})/", password, :match)
	    if files =~ /grub2\//
	      grub_run_dir	= "/grub2"
	      store_attr('grub_run_partition', grub_run_partition)
	      store_attr('grub_run_dir', grub_run_dir)
	    elsif files =~ /grub\//
	      files		= grub_bhyve_execute("ls (hd0,#{grub_run_partition})/grub/", password, :match)
	      if files =~ /grub\.conf/
		grub_conf 		= grub_bhyve_execute("cat (hd0,#{grub_run_partition})/grub/grub.conf", password, :before)
		info_index		= grub_conf =~ /title/
		boot_info		= grub_conf[info_index..-1]
		kernel_info_index	= boot_info =~ /kernel/
		initrd_info_index	= boot_info =~ /initrd/
		kernel_info		= boot_info[kernel_info_index..initrd_info_index - 1].gsub("\r\e[1B", "").gsub("kernel ", "linux (hd0,#{grub_run_partition})")
		initrd_info 		= boot_info[initrd_info_index..-1].gsub("\r\e[1B", "").gsub("initrd ", "initrd (hd0,#{grub_run_partition})")
		instance_dir.join('grub.cfg').open('w') do |f|
		  f.puts kernel_info
		  f.puts initrd_info
		  f.puts  "boot"
		end
	      elsif files =~ /grub\.cfg/
		store_attr('grub_run_partition', grub_run_partition)
	      end
	    else
	      if files =~ /boot\//
		files = grub_bhyve_execute("ls (hd0,#{grub_run_partition})/boot/", password, :match)
		if files =~ /grub2/
		  grub_run_dir	= "/boot/grub2"
		  store_attr('grub_run_partition', grub_run_partition)
		  store_attr('grub_run_dir', grub_run_dir)
		elsif files =~ /grub/
		  files		= grub_bhyve_execute("ls (hd0,#{grub_run_partition})/boot/grub/", password, :match)
		  if files =~ /grub\.conf/
		    grub_conf 		= grub_bhyve_execute("cat (hd0,#{grub_run_partition})/boot/grub/grub.conf", password, :before)
		    info_index		= grub_conf =~ /title/
		    boot_info		= grub_conf[info_index..-1]
		    kernel_info_index	= boot_info =~ /kernel/
		    initrd_info_index	= boot_info =~ /initrd/
		    kernel_info		= boot_info[kernel_info_index..initrd_info_index - 1].gsub("\r\e[1B", "").gsub("kernel ","linux (hd0,#{grub_run_partition})/boot")
		    initrd_info 	= boot_info[initrd_info_index..-1].gsub("\r\e[1B", "").gsub("initrd ", "initrd (hd0,#{grub_run_partition})/boot")
		    instance_dir.join('grub.cfg').open('w') do |f|
		      f.puts kernel_info
		      f.puts initrd_info
		      f.puts  "boot"
		    end
		  elsif files =~ /grub\.cfg/
		    store_attr('grub_run_partition', grub_run_partition)
		  end
		end
	      end
	    end
	  end
	end
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

      def check_or_create_default_pfconf(ui)
        if execute(true, "test -s /etc/pf.conf") != 0
	  ui.warn I18n.t("vagrant_bhyve.action.vm.boot.create_default_pfconf")

          # probably this could be done in a nicer way with open and puts...
          execute(false, "echo \"nat-anchor \\\"vagrant/*\\\"\" | #{@sudo} tee -a /etc/pf.conf")
          execute(false, "echo \"rdr-anchor \\\"vagrant/*\\\"\" | #{@sudo} tee -a /etc/pf.conf")
          execute(false, "echo \"anchor \\\"vagrant/*\\\"\" | #{@sudo} tee -a /etc/pf.conf")
	  restart_service('pf')
        else
          if execute(true, 'pfctl -sn | grep -q "nat-anchor .vagrant/"') != 0
	    ui.warn I18n.t("vagrant_bhyve.errors.nat_anchor_not_found")
          end
          if execute(true, 'pfctl -sn | grep -q "nat-anchor .vagrant/"') != 0
	    ui.warn I18n.t("vagrant_bhyve.errors.rdr_anchor_not_found")
          end
          if execute(true, 'pfctl -sr | grep -q "anchor .vagrant/"') != 0
	    ui.error I18n.t("vagrant_bhyve.errors.anchor_not_found")
          end
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
	  pf_conf.open('w') do |f|
	    f.puts "set skip on #{interface_name}" 
	  end
          check_or_create_default_pfconf(ui)
	  execute(false, "#{@sudo} pfctl -a 'vagrant/#{id}' -f #{pf_conf.to_s}")
	  #if !pf_enabled?
	  #  execute(false, "#{@sudo} pfctl -e")
	  #end
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
	#execute(false, "#{@sudo} ifconfig #{bridge_name} addm #{gateway}")

	# Enable forwarding
	execute(false, "#{@sudo} sysctl net.inet.ip.forwarding=1 >/dev/null 2>&1")
	execute(false, "#{@sudo} sysctl net.inet6.ip6.forwarding=1 >/dev/null 2>&1")

        check_or_create_default_pfconf(ui)
	# set up bridge pf anchor
        pf_bridge_conf = "/usr/local/etc/pf.#{bridge_name}.conf"
	File.open(pf_bridge_conf, "w") do |pf_file|
	  pf_file.puts "nat on #{gateway} from {#{sub_net}.0/24} to any -> (#{gateway})"
	  pf_file.puts "pass quick on #{bridge_name}"
	end

	# Use pfctl to enable pf rules
	execute(false, "#{@sudo} pfctl -a 'vagrant/#{bridge_name}' -f /usr/local/etc/pf.#{bridge_name}.conf")

	# Create a basic dnsmasq setting
	# Basic settings
	check_and_install('dnsmasq', 'dnsmasq', ui)
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

      def get_ip_address(interface_name, type=:guest)
	bridge_name = get_attr('bridge')
	if type == :guest
	  return nil if execute(true, "test -e /var/run/dnsmasq.#{bridge_name}.pid") != 0
	  mac         = get_attr('mac')
	  leases_file = Pathname.new("/var/run/dnsmasq.#{bridge_name}.leases")
	  leases_info = leases_file.open('r'){|f| f.readlines}.select{|line| line.match(mac)}
	  raise Errors::NotFoundLeasesInfo if leases_info == []
	  # IP address for a device is on third coloum
	  ip = leases_info[0].split[2]
	elsif type == :host
	  return nil if execute(true, "ifconfig #{bridge_name}")
	  ip = execute(false, "ifconfig #{bridge_name} | grep -i inet").split[1]
	end
      end

      def ip_ready?
	bridge_name = get_attr('bridge')
	mac         = get_attr('mac')
	leases_file = Pathname.new("/var/run/dnsmasq.#{bridge_name}.leases")
	return (leases_file.open('r'){|f| f.readlines}.select{|line| line.match(mac)} != [])
      end

      def ssh_ready?(ssh_info)
	if ssh_info
	  return execute(true, "nc -z #{ssh_info[:host]} #{ssh_info[:port]}") == 0
	end
	return false
      end

      def load(machine, ui)
	loader_cmd	= @sudo
	directory	= @data_dir
	config		= machine.provider_config
	loader		= get_attr('bootloader')
	case loader
	when 'bhyveload'
	  loader_cmd += ' bhyveload'
	  # Set autoboot, and memory and disk
	  loader_cmd += " -m #{config.memory}"
	  loader_cmd += " -d #{directory.join('disk.img').to_s}"
	  loader_cmd += " -e autoboot_delay=0"
	when 'grub-bhyve'
	  loader_cmd += " grub-bhyve"
	  loader_cmd += " -m #{directory.join('device.map').to_s}"
	  loader_cmd += " -M #{config.memory}"
	  # Maybe there should be some grub config in Vagrantfile, for now
	  # we just use this hd0,1 as default root and don't use -d -g 
	  # argument
	  grub_cfg		= directory.join('grub.cfg')
	  grub_run_partition	= get_attr('grub_run_partition')
	  grub_run_dir		= get_attr('grub_run_dir')
	  if grub_cfg.exist?
	    loader_cmd += " -r host -d #{directory.to_s}"
	  else
	    if grub_run_partition
	      loader_cmd += " -r hd0,#{grub_run_partition}"
	    else
	      loader_cmd += " -r hd0,1"
	    end

	    if grub_run_dir
	      loader_cmd += " -d #{grub_run_dir}"
	    end
	    # Find an available nmdm device and add it as loader's -m argument
	    nmdm_num = find_available_nmdm
	    loader_cmd += " -c /dev/nmdm#{nmdm_num}A"
	  end
	end

	vm_name = get_attr('vm_name')
	loader_cmd += " #{vm_name}"
	execute(false, loader_cmd)
      end

      def boot(machine, ui)
	firmware	= get_attr('firmware')
	loader		= get_attr('bootloader')
	directory	= @data_dir
	config		= machine.provider_config

	# Run in bhyve in background
	bhyve_cmd = "sudo -b"
	# Prevent virtual CPU use 100% of host CPU
	bhyve_cmd += " bhyve -HP"

	# Configure for hostbridge & lpc device, Windows need slot 0 and 31
	# while others don't care, so we use slot 0 and 31
	case config.hostbridge
	when 'amd'
	  bhyve_cmd += " -s 0,amd_hostbridge"
	when 'no'
	else
	  bhyve_cmd += " -s 0,hostbridge"
	end
	bhyve_cmd += " -s 31,lpc"

	# Generate ACPI tables for FreeBSD guest
	bhyve_cmd += " -A" if loader == 'bhyveload'

	# For UEFI, we need to point a UEFI firmware which should be 
	# included in the box.
	bhyve_cmd += " -l bootrom,#{directory.join('uefi.fd').to_s}" if firmware == "uefi"

	# TODO Enable graphics if the box is configed so

	uuid = get_attr('id')
	bhyve_cmd += " -U #{uuid}"

	# Allocate resources
	bhyve_cmd += " -c #{config.cpus}"
	bhyve_cmd += " -m #{config.memory}"

	# Disk(if any)
	bhyve_cmd += " -s 1:0,ahci-hd,#{directory.join("disk.img").to_s}"
	disk_id = 1
	config.disks.each do |disk|
	  if disk[:format] == "raw"
	    if disk[:path]
	      path = disk[:path]
	    else
	      path = directory.join(disk[:name].to_s).to_s + ".img"
	    end
	    execute(false, "truncate -s #{disk[:size]} #{path}")
	    bhyve_cmd += " -s 1:#{disk_id.to_s},ahci-hd,#{path.to_s}"
	  end
	  disk_id += 1
	end

	# CDROM(if any)
	cdrom_id = 0
	config.cdroms.each do |cdrom|
	  path = File.realpath(cdrom[:path])
	  bhyve_cmd += " -s 2:#{cdrom_id.to_s},ahci-cd,#{path.to_s}"
	  cdrom_id += 1
	end
	

	# Tap device
	tap_device  = get_attr('tap')
	mac_address = get_attr('mac')
	bhyve_cmd += " -s 3:0,virtio-net,#{tap_device},mac=#{mac_address}"

	# Console
	nmdm_num = find_available_nmdm
	@data_dir.join('nmdm_num').open('w') { |nmdm_file| nmdm_file.write nmdm_num }
	bhyve_cmd += " -l com1,/dev/nmdm#{nmdm_num}A"

	vm_name = get_attr('vm_name')
	bhyve_cmd += " #{vm_name} >/dev/null 2>&1"

	execute(false, bhyve_cmd)
	while state(vm_name) != :running
	  sleep 0.5
	end
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

      def forward_port(forward_information, tap_device, ui)
	id		= get_attr('id')
	ip_address	= get_ip_address(tap_device)
	pf_conf 	= @data_dir.join('pf.conf')
	rule 		= "rdr on #{forward_information[:adapter]} proto {udp, tcp} from any to any port #{forward_information[:host_port]} -> #{ip_address} port #{forward_information[:guest_port]}"

        # FIXME: does this work for multiple port forwards, or should we rather set up a list with them and template that out to the pf.conf file?
	pf_conf.open('a') do |pf_file|
	  pf_file.puts rule
	end

        check_or_create_default_pfconf(ui)
	execute(false, "#{@sudo} pfctl -a 'vagrant/#{id}' -f #{pf_conf.to_s}")
      end

      def cleanup
	bridge		= get_attr('bridge')
	tap		= get_attr('tap')
	vm_name		= get_attr('vm_name')
	id		= get_attr('id')
	mac		= get_attr('mac')
	directory	= @data_dir

	return unless bridge && tap
	# Destroy vmm device
	execute(false, "#{@sudo} bhyvectl --destroy --vm=#{vm_name} >/dev/null 2>&1") if state(vm_name) == :uncleaned

	# Clean instance-specific pf rules
	execute(false, "#{@sudo} pfctl -a 'vagrant/#{id}' -F all")

	# Destory tap interfaces
	execute(false, "#{@sudo} ifconfig #{tap} destroy") if execute(true, "ifconfig #{tap}") == 0
	execute(false, "#{@sudo} sed -i '' '/#{mac}/d' /var/run/dnsmasq.#{bridge}.leases") if execute(true, "grep \"#{mac}\" /var/run/dnsmasq.#{bridge}.leases") == 0

	# Delete configure files
	#FileUtils.rm directory.join('dnsmasq.conf').to_s if directory.join('dnsmasq.conf').exist?
	#FileUtils.rm directory.join('pf.conf').to_s if directory.join('pf.conf').exist?

	# Clean nat configurations if there is no VMS is using the bridge
	member_num = 3
	bridge_exist = execute(true, "ifconfig #{bridge}")
	member_num = execute(false, "ifconfig #{bridge} | grep -c 'member' || true") if bridge_exist == 0

	if bridge_exist != 0 || member_num.to_i < 2
	  execute(false, "#{@sudo} pfctl -a 'vagrant/#{bridge}' -F all")

	  #if directory.join('pf_disabled').exist?
	  #  FileUtils.rm directory.join('pf_disabled')
	  #  execute(false, "#{@sudo} pfctl -d")
	  #end
	  execute(false, "#{@sudo} ifconfig #{bridge} destroy") if bridge_exist == 0
	  pf_bridge_conf = "/usr/local/etc/pf.#{bridge}.conf"
	  execute(false, "#{@sudo} rm #{pf_bridge_conf}") if execute(true, "test -e #{pf_bridge_conf}") == 0
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
	status = execute(true, "#{@sudo} pfctl -s all | grep -i disabled")
	if status == 0
	  cmd = "onerestart"
	else
	  cmd = "onestart"
	end
	status = execute(true, "#{@sudo} service #{service_name} #{cmd} >/dev/null 2>&1")
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

      def check_and_install(command, package, ui)
	command_exist = execute(true, "which #{command}")
	if command_exist != 0
	  ui.warn "We need #{command} in #{package} package, installing with pkg..."
	  pkg_install(package)
	end
      end

      def grub_bhyve_execute(command, password, member)
	vm_name	= get_attr('vm_name')
	exp = RubyExpect::Expect.spawn("sudo grub-bhyve -m #{@data_dir.join('device.map').to_s} -M 128M #{vm_name}")
	if password == ''
	  exp.procedure do
	    each do
	      expect /grub> / do
		send command
	      end
	      expect /.*(grub> )$/ do
		send 'exit'
	      end
	    end
	  end
	else 
	  exp.procedure do
	    each do
	      expect /Password:/ do
		send password
	      end
	      expect /grub> / do
		send command
	      end
	      expect /.*(grub> )$/ do
		send 'exit'
	      end
	    end
	  end
	end
	execute(false, "#{@sudo} bhyvectl --destroy --vm=#{vm_name}")
	case member
	when :match
	  return exp.match.to_s
	when :before
	  return exp.before.to_s
	when :last_match
	  return exp.last_match.to_s
	end
      end

    end
  end
end
