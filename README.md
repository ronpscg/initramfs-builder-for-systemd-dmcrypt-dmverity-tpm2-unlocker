# Dracut based Initramfs builder that supports systemd-cryptsetup and systemd-veritysetup from the get-go
The idea of this repository is to assist in the creation of initramfs that will automatically unlock and set the verification when using **systemd-cryptsetup** and **systemd-veritysetup**  (*LUKS2*/*dmcrypt*, *verity*/*dmverity*).
*TPM2* automatic unlocking is supported with **systemd-cryptenroll**

**NOTE:** `systemd-cryptenroll` can be also added to the initramfs. I have done that for an `update-initramfs` based (*Debian* flavor, not `dracut`) initramfs, but making the *Debian* flavor work is **significantly** more complex, and everyone uses `dracut` anyhow, so this is what this repo shows.

**NOTE:** **clevis** can be used as well, perhaps I will show it in another repo. It is more complex to set up TPM2 with clevis. On the other hand, it does enable features that systemd-cryptenroll does not.

Last tested with the following hosts:
- *Fedora Core 42* Docker (what is built here with the `Dockerfile.fedora` 
- *Ubuntu 24.04/24.10/25.04/25.10* running inside Docker (running native code, see [`setup-and-build.sh`](setup-and-build.sh) )
- Both of the above, inside a Yocto Project (Scarthgap) build


## Building and running

You can simply run `./setup-and-build.sh`

### Building and running the image


To build the docker image (replace with your own image tag etc.):
```
docker build -t fedora -f Dockerfile.fedora .
```
To run the image:
```
docker run --name fedora --rm -it -w /host -v $PWD/workdir/fedora:/host fedora:latest  bash
```

**Note:** `dnf` will install some dependencies that are absolutely unecessary (like some drivers/firmware) and it is possible to modify
the install command so that the setup will be faster. It is not very critical, so it is left aside for now.

## Building the ramdisk
To build the ramdisk, inside the Docker container, and under the */host/* directory so that it is available to your host do:
```
./build.sh
```

Then, you can copy from your host the result (it will be under host/initrd.img) to wherever you want to use it, and/or open/repackage it/whatever: 
```
cp workdir/fedora/initrd.img <wherever-you-want-it-to-be-copied>
```

### Warnings to ignore:
If you see warnings and "errors" such as the following, don't worry:
```
dracut[W]: Running in hostonly mode in a container!
dracut[E]: No '/dev/log' or 'logger' included for syslog logging
realpath: /lib/modules/6.14.0-33-generic: No such file or directory
dracut[E]: /usr/lib/cryptsetup doesn't exist
```

### Misc. adding more modules etc.
You can see what's available with  `dracut --list-modules`
I am pretty sure there is no need to install *verity*, but if you don't find it in the generated initramfs (e.g. `lsinitrd` on the result of */host/build.sh*), you can also install that module, or others.

### Misc. testing automatic (passwordless/password or key file provided via kernel cmdline) unlocking during first boot
**Building the initramfs**. On this project:
```
./setup-and-build.sh setup && ./setup-and-build.sh build
```

**Testing interesting things** assuming you use the [bigger project](https://github.com/ronpscg/secure-and-measured-boot-qemu-x86_64-uefi-ovmf-grub-kernel-initramfs-luks2-verity-no-shim-no-mok):
This can be done either inside or outside the building Docker container (everything builds and runs well with or without that Docker anyway).

Then, two methods for testing:
- The full one:
  ```
  ( cd ~/secboot-ovmf-x86_64/ && rm -f ~/pscg/secureboot-qemu-x86_64-efi-grub/artifacts/*.img && ./scripts/external-projects/setup-or-build.sh initramfs copy_artifacts && ./scripts/external-projects/setup-or-build.sh rootfs add_more_customizations && /setup/build.sh -p -q )
  ```
  Note the removal of images - it is done to avoid (quite justified) prompts 
- The quick one (super useful for testing changes in the initramfs super fast):
  ```
  ~/secboot-ovmf-x86_64/scripts/external-projects/setup-or-build.sh initramfs copy_artifacts &&  ~/secboot-ovmf-x86_64/scripts/main/make-images-boot-materials.sh && ~/secboot-ovmf-x86_64/scripts/qemu/test-tmp.sh -nographic
  ```

If you use the quick one and want to cleanup the current enrollment before you pack the disk, or retry the quick one, do:
```
for i in ~/pscg/secureboot-qemu-x86_64-efi-grub/artifacts/rootfs.enc.img* ; do systemd-cryptenroll --wipe-slot=tpm2 $i ; done
```
