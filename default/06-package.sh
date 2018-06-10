#!/bin/sh

. ./utils.sh

switch_dir

stage_log "packaging rootfs..."

test_rootfs
# just in case
umount_pseudo
unprepare_binfmt
unprepare_net

stage_sublog "flushing caches and temporary directories..."

rm -rf "${MKROOTFS_ROOT_DIR}/var/cache"
rm -rf "${MKROOTFS_ROOT_DIR}/var/log"
rm -rf "${MKROOTFS_ROOT_DIR}/var/tmp"
rm -rf "${MKROOTFS_ROOT_DIR}/tmp"

mkdir -p "${MKROOTFS_ROOT_DIR}/var/cache"
mkdir -p "${MKROOTFS_ROOT_DIR}/var/log"
mkdir -p "${MKROOTFS_ROOT_DIR}/var/tmp"
mkdir -p "${MKROOTFS_ROOT_DIR}/tmp"

run_hook package

archive_rootfs
