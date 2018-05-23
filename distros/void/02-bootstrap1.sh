#!/bin/sh

. ./utils.sh

switch_dir

echo "Preparing initial rootfs..."

if [ -d rootfs ]; then
    echo "Rootfs dir already exists, exitting..."
    exit 1
fi

mkdir rootfs

echo "Copying signing keys..."
cp -R xbps/var rootfs

echo "Downloading packages..."

# stage 1: download stuff, no need to configure
XBPS_TARGET_ARCH="${MKROOTFS_VOID_ARCH}" ./xbps/usr/bin/xbps-install \
    -S -y -R "${MKROOTFS_VOID_REPO_URL}" -r rootfs base-voidstrap
if [ $? -ne 0 ]; then
    echo "Initial bootstrap failed, exitting..."
    rm -rf rootfs
    exit 1
fi

# glibc needs locale configured to work correctly
if [ -e "rootfs/etc/default/libc-locales" ]; then
    LOCALE=en_US.UTF-8
    sed -e "s/\#\(${LOCALE}.*\)/\1/g" -i "rootfs/etc/default/libc-locales"
fi

# stage 2. configure base-files, this will fail as a whole but will set
# up the symlinks and other things necessary for the system to work at all
# note how it's run as host arch
echo "Pre-configuring base (will partially fail)..."
./xbps/usr/bin/xbps-reconfigure -r rootfs base-files
