#!/bin/sh

. ./utils.sh

PREVPATH="$(pwd)"
switch_dir

# just in case
umount_pseudo
unprepare_binfmt
unprepare_net

cd "$PREVPATH"

stage_log "cleaning up for ${MKROOTFS_DISTRO}..."
rm -rf "${MKROOTFS_GENERATED}"

run_hook cleanup

stage_sublog "done."
