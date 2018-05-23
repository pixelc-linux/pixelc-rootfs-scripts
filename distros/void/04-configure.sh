#!/bin/sh

. ./utils.sh

switch_dir

echo "Configuring rootfs..."

echo "Registering binfmt and mounting pseudo-filesystems..."
register_binfmt
mount_pseudo

echo "Setting default password..."
if [ ! -f "rootfs/etc/shadow" ]; then
    chroot rootfs /usr/bin/pwconv
    if [ $? -ne 0 ]; then
        echo "Creating shadow failed, exitting..."
        umount_pseudo
        unregister_binfmt
        exit 1
    fi
fi

echo "root:${MKROOTFS_ROOT_PASSWORD}" | chroot rootfs /usr/bin/chpasswd -c SHA512
if [ $? -ne 0 ]; then
    echo "Setting password failed, exitting..."
    umount_pseudo
    unregister_binfmt
    exit 1
fi

umount_pseudo
unregister_binfmt
exit 0
