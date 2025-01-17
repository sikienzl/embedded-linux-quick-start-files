#!/bin/bash

# Format an sd card

if [ $# -ne 1 ]; then
        echo "Usage: $0 [drive]"
        echo "       drive is 'sdb', 'mmcblk0'"
        exit 1
fi

export DRIVE=$1

# Check the drive exists in /sys/block
if [ ! -e /sys/block/${DRIVE}/size ]; then
	echo "Drive does not exist"
	exit 1
fi

# Check it is a flash drive (size < 32MiB)
NUM_SECTORS=`cat /sys/block/${DRIVE}/size`
if [ $NUM_SECTORS -eq 0 -o $NUM_SECTORS -gt 62000000 ]; then
	echo "Does not look like an SD card, bailing out"
	exit 1
fi

# Unmount any partitions that have been automounted
if [ $DRIVE == "mmcblk0" ]; then
    su -c 'umount /dev/${DRIVE}*'
    export BOOT_PART=/dev/${DRIVE}p1
    export ROOT_PART=/dev/${DRIVE}p2
else
    su -c 'umount /dev/${DRIVE}[1-9]'
    export BOOT_PART=/dev/${DRIVE}1
    export ROOT_PART=/dev/${DRIVE}2
fi

# Overwite existing partiton table with zeros
su -c 'dd if=/dev/zero of=/dev/${DRIVE} bs=1M count=10'
if [ $? -ne 0 ]; then echo "Error: dd"; exit 1; fi

# unit M not supported anymore:
# https://bugzilla.redhat.com/show_bug.cgi?id=1183236

# Create 2 primary partitons on the sd card
#  1: FAT32, 64 MiB, boot flag
#  2: Linux, 96 MiB
su -c 'sfdisk --unit M /dev/${DRIVE} << EOF
,64,0x0c,*
,96,L,
EOF
if [ $? -ne 0 ]; then echo "Error: sfdisk"; exit 1; fi'

# Format p1 with FAT32 and p2 with ext4
su -c 'mkfs.vfat -F 16 -n boot ${BOOT_PART}'
if [ $? -ne 0 ]; then echo "Error: mkfs.vfat"; exit 1; fi
su -c 'mkfs.ext4 -L rootfs ${ROOT_PART}'
if [ $? -ne 0 ]; then echo "Error: mkfs.ext4"; exit 1; fi

# Create ext4 system with block size 4096, stride and stripe 512 KiB
# (= 128 * 4096)

#### sudo mkfs.ext4 -b 4096 -E stride=128,stripe-width=128 /dev/${DRIVE}1

exit 0
