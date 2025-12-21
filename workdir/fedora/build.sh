#!/bin/bash
OUTPUT_FILE=$PWD/initrd.img

: ${MORE_INCLUDES=""}
: ${MORE_INSTALLS=""}

if [ "$(grep ^ID= /etc/os-release  | cut -d= -f2)" = "fedora" ] ; then
	# The idea is to allow auto enrollment also from initramfs (if one wishes to do so, via initramfs hooks that run *before* the typical systemd-cryptgenerator et. al services)
	echo "Adding systemd-cryptenroll for Fedora" 
	MORE_INSTALLS="--install $(which systemd-cryptenroll)"
	MORE_INSTALLS+=" --install $(which cryptsetup)"
	MORE_INSTALLS+=" --install $(which mktemp)"

	MORE_INCLUDES="$MORE_INCLUDES --include $PWD/dracut-hooks/tpm-auto-enrollment.sh /usr/lib/dracut/hooks/initqueue/001-tpm-auto-enrollment.sh "

fi

dracut --force \
	--no-hostonly 	\
	--no-kernel 	\
	$MORE_INSTALLS 	\
	$MORE_INCLUDES 	\
	$OUTPUT_FILE
