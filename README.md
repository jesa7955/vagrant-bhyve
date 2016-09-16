# vagrant-bhyve

This is a Vagrant plugin which enable FreeBSD's hypervisor bhyve as its backend.

- [Status](#status)
  - [Functions](#functions)
  - [Boxes](#boxes)
- [Test](#test)
  - [Setup environment](#setup-environment)
  - [Create a box](#create-a-box)
  - [Add the box](#add-the-box)
  - [Run the box](#run-the-box)
  - [SSH into the box](#ssh-into-the-box)
  - [Shutdown the box and cleanup](#shutdown-the-box-and-cleanup)
- [Known Issues](#known-issues)
- [Installation](#installation)

## Status

### Functions

| Function            | Status
| :----------         | :-----
| Box format          | Defined
| Check bhyve support | Working
| Cloning	      | Working(needs gcp package to copy image)
| Booting(BIOS)	      | Working
| Network             | Working(needs pf and dnsmasq to provider NAT and DHCP)
| SSH/SSH run         | Working(SSH run may needs bash)
| Graceful shutdown   | Working
| ACPI shutdown       | Working
| Destroying          | Working
| Provision           | Working
| File sharing        | Working(NFS and vagrant-sshfs, maybe switch to VirtFS in the future)
| Booting(UEFI)	      | Not working
| Port forwarding     | Not working
| Suspend             | Not supported by bhyve yet
| Resume              | Not supported by bhyve yet

### Boxes

Collecting status of boxes from [Atlas](https://atlas.hashicorp.com/boxes/search) other than those provided by [FreeBSD](https://atlas.hashicorp.com/freebsd)

| Function										| Status
| :---------------------------------------------------------------------------------	| :------
| [ubuntu/trusty64](https://atlas.hashicorp.com/ubuntu/boxes/trusty64)			| Working
| [laravel/homestead](https://atlas.hashicorp.com/laravel/boxes/homestead)		| Untested
| [hashicorp/precise64](https://atlas.hashicorp.com/hashicorp/boxes/precise64)		| Untested 	
| [hashicorp/precise32](https://atlas.hashicorp.com/hashicorp/boxes/precise32)		| Untested 	
| [centos/7](https://atlas.hashicorp.com/centos/boxes/7)				| Working 	
| [puphpet/ubuntu1404-x64](https://atlas.hashicorp.com/puphpet/boxes/ubuntu1404-x64)	| Untested 	
| [ubuntu/trusty32](https://atlas.hashicorp.com/ubuntu/boxes/trusty32)			| Untested 	
| [puphpet/debian75-x64](https://atlas.hashicorp.com/puphpet/boxes/debian75-x64)	| Untested 	
| [debian/jessie64](https://atlas.hashicorp.com/debian/boxes/jessie64)			| Working 	
| [scotch/box](https://atlas.hashicorp.com/scotch/boxes/box)				| Untested 	
| [centos/6](https://atlas.hashicorp.com/centos/boxes/6)				| Working 	

## Test

### Setup environment

    $ git clone https://github.com/jesa7955/vagrant-bhyve.git
    $ cd vagrant-bhyve
    $ bundle install --path vendor/bundle --binstubs

Note we will need package coreutils and dnsmasq(and of course we will need grub-bhyve to boot Linux box), vagrant-bhyve will try to install them with pkg.

### Create a box

Thanks to [Steve Wills](https://github.com/swills)'s work, now you can convert a VirtualBox box to a bhyve one with [vagrant-mutate](https://github.com/sciurus/vagrant-mutate).

### Run the box

After a box is created, you should create another Vagrantfile.

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "boxname"
end
```

then execute this command to start the box with bhyve

    $ /path/to/vagrant-bhyve/bin/vagrant up --provider=bhyve

### SSH into the box

After the box is booted(uped), you can ssh into by executing this command. Note that you will have to use password to authorize for now.

    $ /path/to/vagrant-bhyve/bin/vagrant ssh

### Shutdown the box and cleanup

This command will shutdown the booted VM and clean up environment

    $ /path/to/vagrant-bhyve/bin/vagrant halt

### Destroy the box

    $ /path/to/vagrant-bhyve/vagrant destroy

## Known Issues

### FreeBSD can't be shutdown gracefully

This issue seems like a bug of Vagrant core. It even appears when I test
with virtualbox provider. The are two know solutions:
* Add `config.vm.guest = :freebsd` to Vagrantfile
* Add `config.ssh.shell = "sh"` to Vagrantfile

### Synced folder is not working correctlly

I met this issue when I try to use vagrant-bhyve to boot `centos/7` box.
Vagrant uses NFS as default synced folder type. When it fails on your
machine and box, you can:
* Add `config.vm.synced_folder ".", "/vagrant", type: "rsync"` to your
  Vagrantfile to ensure that rsync type is used. Vagrant core will raise an
  error to inform you when there is not rsync find in PATH
* Run `vagrant plugin install vagrant-sshfs` to enable vagrant-sshfs



## Installation

Now this gem has been published on [rubygems.org](https://rubygems.org/gems/vagrant-bhyve). You can install it through `vagrant plugin install vagrant-bhyve`
to install it in a normal Vagrant environment

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jesa7955/vagrant-bhyve.


## License

MIT
