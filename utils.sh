#!/bin/sh
# script utilities

# safety
set -u

as_user() {
    sudo -E -u "$MKROOTFS_USER" -g "$MKROOTFS_GROUP" "$@"
}

# makes fetching packages and stuff easier
get_arch() {
    ARCH="$(uname -m)"
    case $ARCH in
        x86_64) echo "amd64" ;;
        *) echo "$ARCH" ;;
    esac
}

fetch_file() {
    as_user wget "$1" -O "$2"
}

fetch_file_root() {
    wget "$1" -O "$2"
}

switch_dir() {
    cd "$MKROOTFS_GENERATED"
    if [ $? -ne 0 ]; then
        echo "Could not switch directory, exitting..."
        exit 1
    fi
}

export MKROOTFS_BINFMT_NAME="mkrootfs-aarch64"
export MKROOTFS_BINFMT_MAGIC="\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7"
export MKROOTFS_BINFMT_MASK="\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff"

register_binfmt() {
    if [ ! -d "/proc/sys/fs/binfmt_misc" ]; then
        echo "No binfmt_misc support in your kernel, exitting..."
        exit 1
    fi
    if [ ! -f "/proc/sys/fs/binfmt_misc/register" ]; then
        mount -t binfmt_misc none /proc/sys/fs/binfmt_misc
        if [ $? -ne 0 ]; then
            echo "Could not mount binfmt_misc, exitting..."
            exit 1
        fi
    fi
    if [ ! -f "/proc/sys/fs/binfmt_misc/${MKROOTFS_BINFMT_NAME}" ]; then
        echo ":${MKROOTFS_BINFMT_NAME}:M::${MKROOTFS_BINFMT_MAGIC}:${MKROOTFS_BINFMT_MASK}:/${MKROOTFS_QEMU}:" \
            > /proc/sys/fs/binfmt_misc/register
        if [ $? -ne 0 ]; then
            echo "Binfmt registration failed, exitting..."
            exit 1
        fi
    fi
}

unregister_binfmt() {
    if [ -f "/proc/sys/fs/binfmt_misc/${MKROOTFS_BINFMT_NAME}" ]; then
        echo -1 > "/proc/sys/fs/binfmt_misc/${MKROOTFS_BINFMT_NAME}"
    fi
}

mount_pseudo() {
    mkdir -p "$1/dev" "$1/proc" "$1/sys"
    mount --bind /dev "$1/dev"
    mount --bind /sys "$1/sys"
    mount --bind /proc "$1/proc"
}

umount_pseudo() {
    umount "$1/dev"
    umount "$1/sys"
    umount "$1/proc"
}
