# vagrant-bhyve

This is a Vagrant plugin which enable FreeBSD's hypervisor bhyve as its backend.

## Installation

## Usage(Test)

## Development

### Setup environment

    $ git clone https://github.com/jesa7955/vagrant-bhyve.git
    $ bundle install --path vendor/bundle

Note we will need package coreutils and dnsmasq. You can install them now or vagrant-bhyve will try to install them through pkg.

### Creating a box

Box format is a plain directory consist of `Vagrantfile`, `metadata.json`, bhyve disk file, maybe `uefi.fd` file is optional.

```
../
|- Vagrantfile      This is where Xhyve is configured.
|- disk.img         The disk image
|- metadata.json    Box metadata
|- device.map	    Device map file (only for guests who need grub2-bhyve)
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
4. Run `tar cvzf test.box ./Vagrantfil ./meta.json ./disk.img` to create a box.

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
