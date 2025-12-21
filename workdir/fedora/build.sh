#!/bin/bash
OUTPUT_FILE=$PWD/initrd.img

: ${MORE_INCLUDES=""}

if [ "$(grep ^ID= /etc/os-release  | cut -d= -f2)" = "fedora" ] ; then
	# The idea is to allow auto enrollment also from initramfs (if one wishes to do so, via initramfs hooks that run *before* the typical systemd-cryptgenerator et. al services)
	echo "Adding systemd-cryptenroll for Fedora" 
	MORE_INCLUDES="--include /usr/sbin/systemd-cryptenroll /usr/sbin/systemd-cryptenroll"
fi

dracut --force \
	--no-hostonly 	\
	--no-kernel 	\
	$MORE_INCLUDES 	\
	$OUTPUT_FILE
