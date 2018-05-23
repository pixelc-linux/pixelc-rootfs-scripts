#!/bin/sh

. ./utils.sh

switch_dir

echo "Preparing rootfs for configuration..."

test_rootfs
prepare_binfmt
register_binfmt
mount_pseudo

echo "5: Configuring packages for target..."
in_rootfs /usr/bin/xbps-reconfigure -f -a || \
    die_log "failed configuring packages"
