# vagrant-bhyve

This is a Vagrant plugin which enable FreeBSD's hypervisor bhyve as its backend.

- [Status](#status)
  - [Functions](#functions)
  - [Boxes](#boxes)
- [Test](#test)
  - [Setup environment](#setup-environment)
  - [Create a box](#create-a-box)
    - [Create a box from scratch](#create-a-box-from-scratch)
    - [Create a box from an existing one(FreeBSD)](#create-a-freebsd-box-from-an-existing-one)
    - [Create a box from an existing one(Linux)](#create-a-linux-box-from-an-existing-one)
  - [Add the box](#add-the-box)
  - [Run the box](#run-the-box)
  - [SSH into the box](#ssh-into-the-box)
  - [Shutdown the box and cleanup](#shutdown-the-box-and-cleanup)

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

| Function										| Status	| Vagrantfile
| :---------------------------------------------------------------------------------	| :------	| :--
| [ubuntu/trusty64](https://atlas.hashicorp.com/ubuntu/boxes/trusty64)			| Working	| [debian/ubuntu](https://github.com/jesa7955/vagrant-bhyve/blob/master/Vagrantfiles/Vagrantfile_Debian_Ubuntu)
| [laravel/homestead](https://atlas.hashicorp.com/laravel/boxes/homestead)		| Untested	| []()
| [hashicorp/precise64](https://atlas.hashicorp.com/hashicorp/boxes/precise64)		| Untested 	| []()
| [hashicorp/precise32](https://atlas.hashicorp.com/hashicorp/boxes/precise32)		| Untested 	| []()
| [centos/7](https://atlas.hashicorp.com/centos/boxes/7)				| Working 	| [centos-7](https://github.com/jesa7955/vagrant-bhyve/blob/master/Vagrantfiles/Vagrantfile_CentOS-7)
| [puphpet/ubuntu1404-x64](https://atlas.hashicorp.com/puphpet/boxes/ubuntu1404-x64)	| Untested 	| []()
| [ubuntu/trusty32](https://atlas.hashicorp.com/ubuntu/boxes/trusty32)			| Untested 	| []()
| [puphpet/debian75-x64](https://atlas.hashicorp.com/puphpet/boxes/debian75-x64)	| Untested 	| []()
| [debian/jessie64](https://atlas.hashicorp.com/debian/boxes/jessie64)			| Working 	| [debian/ubuntu](https://github.com/jesa7955/vagrant-bhyve/blob/master/Vagrantfiles/Vagrantfile_Debian_Ubuntu)
| [scotch/box](https://atlas.hashicorp.com/scotch/boxes/box)				| Untested 	| []()
| [centos/6](https://atlas.hashicorp.com/centos/boxes/6)				| Working 	| [centos-6](https://github.com/jesa7955/vagrant-bhyve/blob/master/Vagrantfiles/Vagrantfile_CentOS-6)

## Test

### Setup environment

    $ git clone https://github.com/jesa7955/vagrant-bhyve.git
    $ cd vagrant-bhyve
    $ bundle install --path vendor/bundle --binstubs

Note we will need package coreutils and dnsmasq(and of course we will need grub-bhyve to boot Linux box), vagrant-bhyve will try to install them with pkg.

### Create a box

Want solution for automating this part? Find process on [vagrant-mutate](https://github.com/swills/vagrant-mutate/tree/bhyve).

#### Create a box from scratch

Box format is a plain directory consist of `Vagrantfile`, `metadata.json`, bhyve disk file, and an optional `uefi.fd`

```
|
|- Vagrantfile      This is where Bhyve is configured.
|- disk.img         The disk image including basic OS.
|- metadata.json    Box metadata.
`- uefi.fd          UEFI firmware (only for guests who use uefi as firmware).
```

Available configurations for the provider are:

* `memory`: Amount of memory, e.g. `512M`
* `cpus`: Number of CPUs, e.g. `1`
* `disks`: An array of disks which users want to attach to the guest other than the box shipped one. Each disk is described by a hash which has three members.
	* **path/name**: path is used to specify a image file outside .vagrant direcotory while name is used to specify an image file name which will be created inside .vagrant directory for the box. Only one of these two arguments is needed to describe an additional disk file.
	* **size**: specify the image file's virutal size.
	* **format**: specify the format of disk image file. Bhyve only support raw images now but maybe we can extend vagrant-bhyve when bhyve supports more.
* `cdroms`: Like `disks`, this is an array contains all ISO files which users want to attach to bhyve. Now, each cdrom is described by a hash contains only the path to a ISO file.
* ~~`grub_config_file`:~~
* ~~`grub_run_partition`:~~
* ~~`grub_run_dir`:~~

Here is steps needed to create a test box.

1. Create a `Vagrantfile` with the following contents:

    ```ruby
    Vagrant.configure("2") do |config|
      config.vm.provider :bhyve do |vm|
        vm.memory = "512M"
        vm.cpus = "1"
      end
    end
    ```

2. Create `metadata.json` with the following contents in the same directory as Vagrantfile:

    ```json
    {
        "provider"    : "bhyve"
    }
    ```

3. Follow the instructions on [FreeBSD HandBook](https://www.freebsd.org/doc/handbook/virtualization-host-bhyve.html) to create FreeBSD VM image. Note to name the image to `disk.img` and remember to add a user named `vagrant` in the VM.
4. Run `tar -Scvzf test.box ./Vagrantfile ./metadata.json ./disk.img` to create a box.

#### Create a FreeBSD box from an existing one


This part records on how to create a FreeBSD box with one for other provider. With this method, you can skip remaining steps. We are also [working on](https://github.com/swills/vagrant-mutate) automating this job.

We use [FreeBSD-11.0-BETA1](https://atlas.hashicorp.com/freebsd/boxes/FreeBSD-11.0-BETA1) for VirtualBox here. You should make sure the box has been downloaded.(With vagrant init and vagrant up --provider=virtualbox)

1. Make a directory where vagrant store box file for the new provider
```bash
$ mkdir ~/.vagrant.d/boxes/freebsd-VAGRANTSLASH-FreeBSD-11.0-BETA1/2016.07.08/bhyve
```
2. Create a metadata.json mentioned above
```json
    {
        "provider"    : "bhyve"
    }
```
And copy it to the new created directory
```bash
$ cp metadata.json ~/.vagrant.d/boxes/freebsd-VAGRANTSLASH-FreeBSD-11.0-BETA1/2016.07.08/bhyve
```
3. Create a Vagrantfile metioned above

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :bhyve do |vm|
    vm.memory = "512M"
    vm.cpus = "1"
  end
end
```
And copy it
```bash
$ cp Vagrantfile ~/.vagrant.d/boxes/freebsd-VAGRANTSLASH-FreeBSD-11.0-BETA1/2016.07.08/bhyve
```
4. Convert VirtualBox virtual disk file to a raw image file we need
```bash
$ cd ~/.vagrant.d/boxes/freebsd-VAGRANTSLASH-FreeBSD-11.0-BETA1/2016.07.08/
$ qemu-img convert -p -S 16k -O raw virtualbox/vagrant.vmdk bhyve/disk.img
```

Done! Now you can use commands below to boot a box with vagrant-bhyve.
```bash
$ /path/to/vagrant-bhyve/bin/vagrant init freebsd/FreeBSD-11.0-BETA1
$ /path/to/vagrant-bhyve/bin/vagrant up
$ /path/to/vagrant-bhyve/bin/vagrant ssh
```

#### Create a Linux box from an existing one

Most steps to create a Linux box with an exising one from Atlas are the same as those to create a FreeBSD box. But metadata.json and Vagrantfile have big differences. Here takes [ubuntu/trusty64](https://atlas.hashicorp.com/ubuntu/boxes/trusty64) as an example.

metadata.json we will need looks like this
```json
{
    "provider"    : "bhyve"
}

```
Vagrantfile looks like this. You can also download it from [here](https://raw.githubusercontent.com/jesa7955/vagrant-bhyve/master/Vagrantfiles/Vagrantfile_Debian_Ubuntu) and rename it to Vagrantfile
```ruby
Vagrant.configure("2") do |config|
    config.vm.provider :bhyve do |vm|
#     vm.grub_run_partition = "msdos1"
      vm.memory = "512M"
      vm.cpus = "1"
    end
end

```

### Add the box

    $ /path/to/vagrant-bhyve/bin/vagrant box add --name=test test.box

### Run the box

After a box is created, you should create another Vagrantfile in the root directory of this project(path/to/vagrant-bhyve)

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "test"
end
```

then execute this command to start the box with bhyve

    $ /path/to/vagrant-bhyve/bin/vagrant up

### SSH into the box

After the box is booted(uped), you can ssh into by executing this command. Note that you will have to use password to authorize for now.

    $ /path/to/vagrant-bhyve/bin/vagrant ssh

### Shutdown the box and cleanup

This command will shutdown the booted VM and clean up environment

    $ /path/to/vagrant-bhyve/bin/vagrant halt

## Installation

## Usage

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jesa7955/vagrant-bhyve.


## License

MIT
