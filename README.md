# vagrant-bhyve

This is a Vagrant plugin which enable FreeBSD's hypervisor bhyve as its backend.

## Status

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
| Provision           | Working(Basically)
| Booting(UEFI)	      | Not working
| Port forwarding     | Not working
| File sharing        | Not implemented(Maybe uses NFS at first and waits for bhyve's VirtFS support)
| Suspend             | Not supported by bhyve yet
| Resume              | Not supported by bhyve yet

## Installation

## Usage

## Development

### Setup environment

    $ git clone https://github.com/jesa7955/vagrant-bhyve.git
    $ bundle install --path vendor/bundle

Note we will need package coreutils and dnsmasq. You can install them now or vagrant-bhyve will try to install them through pkg.

### Create a box

#### Creating a box from scratch

Box format is a plain directory consist of `Vagrantfile`, `metadata.json`, bhyve disk file, and an optional `uefi.fd`

```
../
|- Vagrantfile      This is where Xhyve is configured.
|- disk.img         The disk image
|- metadata.json    Box metadata
`- uefi.fd          UEFI firmware (only for guests who need uefi)
```

Available configurations for the provider are:

* `memory`: amount of memory, e.g. `512M`
* `cpus`: number of CPUs, e.g. `1`

Here is steps needed to create a test box.

1. Create a `Vagrantfile` with the following contents:

    ```ruby
    Vagrant.configure("2") do |config|
      config.vm.box = "test"

      config.vm.provider :bhyve do |vm|
        vm.memory = "512M"
        vm.cpus = "1"
      end
    end
    ```

2. Create `metadata.json` with the following contents in the same directory as Vagrantfile:

    ```json
    {
        "provider"    : "bhyve",
        "firmware"    : "bios",
        "loader"      : "bhyveload"
    }
    ```

3. Follow the instructions on [FreeBSD HandBook](https://www.freebsd.org/doc/handbook/virtualization-host-bhyve.html) to create FreeBSD VM image. Note to name the image to `disk.img` and remember to add a user named `vagrant` in the VM.
4. Run `tar cvzf test.box ./Vagrantfile ./metadata.json ./disk.img` to create a box.

#### Creating a box from an existing one


This part records on how to create a box with one for other provider. With this method, you can skip remain steps. We are also [working on](https://github.com/swills/vagrant-mutate) automating this job.

We use [FreeBSD-11.0-BETA1](https://atlas.hashicorp.com/freebsd/boxes/FreeBSD-11.0-BETA1) for VirtualBox here.

1. Make a directory where vagrant store box file for the new provider
```bash
$ mkdir ~/.vagrant.d/boxes/freebsd-VAGRANTSLASH-FreeBSD-11.0-BETA1/2016.07.08/bhyve
```
2. Create a metadata.json mentioned above and copy it to the new created directory
```bash
$ cp metadata.json ~/.vagrant.d/boxes/freebsd-VAGRANTSLASH-FreeBSD-11.0-BETA1/2016.07.08/bhyve
```
3. Create and copy a Vagrantfile metioned above
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
$ bundle exec vagrant init freebsd/FreeBSD-11.0-BETA1
$ bundle exec vagrant up --provider=bhyve
```


### Adding the box

    $ bundle exec vagrant box add test.box

### Running the box

After a box is created, you should create another Vagrantfile in the root directory of this project(path/to/vagrant-bhyve)

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "test"
end
```

then execute this command to start the box with bhyve

    $ bundle exec vagrant up --provider=bhyve

### SSH inito the box

After the box is booted(uped), you can ssh into by executing this command. Note that you will have to use password to authorize for now.

    $ bundle exec vagrant ssh

### Shutdown the box and cleanup

This command will shutdown the booted VM and clean up environment

    $ bundle exec vagrant halt

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jesa7955/vagrant-bhyve.


## License

MIT
