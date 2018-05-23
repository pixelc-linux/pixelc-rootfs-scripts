#!/bin/sh

. ./utils.sh

switch_dir

stage_log "configuring rootfs..."

test_rootfs
register_binfmt
mount_pseudo

stage_sublog "Setting default password..."
if [ ! -f "${MKROOTFS_ROOT_DIR}/etc/shadow" ]; then
    in_rootfs /usr/bin/pwconv || die_log "shadow creation failed"
fi

echo "root:${MKROOTFS_ROOT_PASSWORD}" | in_rootfs /usr/bin/chpasswd -c SHA512
test $? -eq 0 || die_log "setting password failed"

stage_sublog "cleaning up..."
