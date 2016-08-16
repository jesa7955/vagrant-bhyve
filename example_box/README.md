# Vagrant Bhyve Example Box

Box format of bhyve provider is a plain directory consist of `Vagrantfile`, `metadata.json`, bhyve disk file, and an optional `uefi.fd`

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
:* ~~`grub_run_dir`:~~

Put everything we need in a directory and run the command below to package them as a box file.
```
$ tar cvzf test.box ./metadata.json ./Vagrantfile ./disk.img
```

This box works by using Vagrant's built-in Vagrantfile merging to setup
defaults for Bhyve. These defaults can easily be overwritten by higher-level
Vagrantfiles (such as project root Vagrantfiles).

## Box Metadata

Bhyve box should define at least two data fields in `metadata.json` file.

* provider - Provider name is bhyve.

## Converting Boxes

Instead of creating a box from scratch, you can use
[vagrant-mutate](https://github.com/sciurus/vagrant-mutate)
to take boxes created for other Vagrant providers and use them
with vagrant-bhyve
