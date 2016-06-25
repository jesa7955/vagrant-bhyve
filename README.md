# VagrantPlugin::ProviderBhyve

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/vagrant/bhyve`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vagrant-bhyve'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vagrant-bhyve

## Usage

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

3. Download [FreeBSD-10.3-RELEASE-amd64.raw.xz](http://ftp.freebsd.org/pub/FreeBSD/releases/VM-IMAGES/10.3-RELEASE/amd64/Latest/FreeBSD-10.3-RELEASE-amd64.raw.xz) and extract it to the same directory with Vagrantfile and metadata.json. Rename the img file into `disk.img`
4. Run `tar cvzf test.box *` to create a box.
5. `bundle exec vagrant box add test.box`

### Running the box

After a box is created, you can now start Bhyve VM with a standard Vagrantfile and `bundle exec vagrant up`.

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "test"
end
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jesa7955/vagrant-bhyve.


## License

BSD
