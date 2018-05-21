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
