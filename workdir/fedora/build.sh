#!/bin/bash
OUTPUT_FILE=$PWD/initrd.img

dracut --force \
       --hostonly \
       --no-kernel \
       --include "/usr/lib/cryptsetup" "/usr/lib/cryptsetup" \
       $OUTPUT_FILE
