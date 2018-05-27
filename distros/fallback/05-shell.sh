#!/bin/sh

. ./utils.sh

switch_dir

stage_log "invoking rootfs shell..."

test_rootfs
register_binfmt
mount_pseudo
prepare_net
in_rootfs "$MKROOTFS_ENV_SHELL" -i

run_hook shell

stage_sublog "cleaning up..."
