#!/bin/sh

. ./utils.sh

stage_log "cleaning up for ${MKROOTFS_DISTRO}..."
rm -rf "${MKROOTFS_GENERATED}"

type mkrootfs_cleanup_hook > /dev/null 2>&1
if [ $? -eq 0 ]; then
    mkrootfs_cleanup_hook
fi

stage_sublog "done."
