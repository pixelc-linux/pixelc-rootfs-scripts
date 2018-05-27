#!/bin/sh

. ./utils.sh

switch_dir

stage_log "preparing rootfs for configuration..."

test_rootfs
prepare_binfmt
register_binfmt
mount_pseudo

stage_sublog "Configuring packages for target..."
in_rootfs xbps-reconfigure -f -a || die_log "failed configuring packages"
