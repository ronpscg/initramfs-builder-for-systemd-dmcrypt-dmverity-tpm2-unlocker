# Dracut based Initramfs builder that supports systemd-cryptsetup and systemd-veritysetup from the get-go
Last tested with *Fedora Core 42*.

The idea of this repository is to assist in the creation of initramfs that will automatically unlock and set the verification when using **systemd-cryptsetup** and **systemd-veritysetup**  (*LUKS2*/*dmcrypt*, *verity*/*dmverity*).
*TPM2* automatic unlocking is supported with **systemd-cryptenroll**

**NOTE:** `systemd-cryptenroll` can be also added to the initramfs. I have done that for an `update-initramfs` based (*Debian* flavor, not `dracut`) initramfs, but making the *Debian* flavor work is **significantly** more complex, and everyone uses `dracut` anyhow, so this is what this repo shows.

**NOTE:** **clevis** can be used as well, perhaps I will show it in another repo. It is more complex to set up TPM2 with clevis. On the other hand, it does enable features that systemd-cryptenroll does not.


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

