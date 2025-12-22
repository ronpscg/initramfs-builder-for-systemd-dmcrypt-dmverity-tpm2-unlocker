#!/bin/bash
OUTPUT_FILE=$PWD/initrd.img

: ${MORE_INCLUDES=""}
: ${MORE_INSTALLS=""}
: ${MORE_ADDS=""}

distro_id="$(grep ^ID= /etc/os-release  | cut -d= -f2)"
echo "Adding systemd-cryptenroll for $distro_id built initramfs" 

MORE_ADDS+=" --add tpm-auto-enrollment"

dracut  --force \
	--no-hostonly 	\
	--no-kernel 	\
	$MORE_INSTALLS 	\
	$MORE_INCLUDES 	\
	$MORE_ADDS \
	$OUTPUT_FILE

exit $rc

