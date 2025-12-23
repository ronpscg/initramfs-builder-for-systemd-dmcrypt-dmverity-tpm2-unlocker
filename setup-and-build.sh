#!/bin/bash

# Pretty much what is mentioned in the .md file and the Dockerfile documentation (but without running bash)

: ${IN_DOCKER=false}
: ${IN_YOCTO=false}
: ${DOCKER_IMAGE="fedora-yocto-initramfs-builder:latest"}
: ${DOCKER_NAME="fedora-initramfs-dracut-builder"}

LOCAL_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))


check_docker() {
	if [ -f /.dockerenv ] ; then
		echo "In Docker"
		IN_DOCKER=true
		return 0
	fi
	return 1
}

check_yocto() {
	: # won't test now
	if [ ! -z "$BBPATH" ] ; then 
		echo "In Bitbake/Yocto"
		IN_BITBAKE=true
		return 0
	fi
	return 1
}


setup_in_docker() {
	set -euo pipefail
	sudo cp -a targetfiles/* /
}

build_in_docker() {
	echo "[+] Building natively." # We will ignore completely the host and target dependencies, so be careful when porting to other devices, or to your own device!

	# Keeping the target identical for the calling script to not be modified. Might change in the future / might change build.sh as well, which does some 
	# other things / installs some more things. Here we'll keep it minimal, and only require the host (i.e. the Ubuntu docker, at the time of this writing) to have systemd
	# and tpm2-tools, which are supposed to be setup by the docker that calls this script (again, if called inside a docker...)
	OUTPUT_FILE=$LOCAL_DIR/workdir/fedora/initrd.img
	# On Debian systemd-cryptsetup and systemd-cryptenroll are installed by our config. We do not need cryptsetup itself or verity setup, as there are ways
	# to verify that (see examples in one of the commits related to the GRUB config, on the main project that uses this ramdisk builder)
	MORE_INSTALLS="--install $(which systemd-cryptenroll)"
	MORE_INCLUDES=""
	MORE_ADDS="--add tpm-auto-enrollment"
	sudo dracut --force --no-hostonly --no-kernel $MORE_INSTALLS $MORE_INCLUDES $MORE_ADDS $OUTPUT_FILE && sudo chmod a+rw $OUTPUT_FILE
}

setup_native_use_docker() {
	docker build --build-arg CACHEBUST=$(date +%s) -t ${DOCKER_IMAGE} -f Dockerfile.fedora .
}

build_native_use_docker() {
	DOCKER_RUN_CMD="docker run --rm -i -w /host -v $PWD/workdir/fedora:/host ${DOCKER_IMAGE}"
	if $DOCKER_RUN_CMD bash -c "./build.sh && chmod a+rw /host/initrd.img" ; then
		echo -e "\e[32mYour built initramfs is available under workdir/fedora/initrd.img\e[0m"
	else
		echo -e "\e[31mFailed to build your initramfs image\e[0m"
	fi
}

setup() {
	if [ "$IN_DOCKER" = "false" ] ; then
		setup_native_use_docker
	else
		setup_in_docker
	fi
}

build() {
	if [ "$IN_DOCKER" = "false" ] ; then
		build_native_use_docker
	else
		build_in_docker
	fi
}


main() {
	cd $LOCAL_DIR
	echo "$0 called with $@"
	check_docker
	check_yocto

	$1 || { echo -e "\e[41m$0 failed to build\e[0m" ; exit 1 ; }
}

main $@
