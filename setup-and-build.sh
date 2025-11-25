#!/bin/bash

# Pretty much what is mentioned in the .md file and the Dockerfile documentation (but without running bash)

docker build -t fedora -f Dockerfile.fedora .
if docker run --name fedora --rm -it -w /host -v $PWD/workdir/fedora:/host fedora:latest ./build.sh ; then
	sudo chown $USER:$USER workdir/fedora/initrd.img  # yes, I know I can make user mapping in Docker, say thank you I bother to give you the examples!
	echo -e "\x1b[32mYour built initramfs is available under workdir/fedora/initrd.img\x1b[0m"
else
	echo -e "\x1b[31mFailed to build your initramfs image\x1b[0m"
fi


