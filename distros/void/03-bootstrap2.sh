#!/bin/sh

. ./utils.sh

switch_dir

echo "Preparing rootfs for configuration..."

if [ ! -d rootfs ]; then
    echo "Rootfs dir doesn't exist, exitting..."
    exit 1
fi

echo "Copying qemu interpreter..."
cp "$MKROOTFS_QEMU" rootfs
if [ $? -ne 0 ]; then
    echo "Failed copying qemu, exitting..."
    exit 1
fi

echo "Registering binfmt and mounting pseudo-filesystems..."
register_binfmt
mount_pseudo

echo "5: Configuring packages for target..."
chroot rootfs /usr/bin/xbps-reconfigure -f -a
if [ $? -ne 0 ]; then
    echo "Failed configuring packages, exitting..."
    umount_pseudo
    unregister_binfmt
    exit 1
fi

umount_pseudo
unregister_binfmt
exit 0
