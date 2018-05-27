#!/bin/sh

. ./utils.sh

switch_dir

stage_log "packaging rootfs..."

test_rootfs
# just in case
umount_pseudo
unprepare_binfmt
unprepare_net

stage_sublog "Flushing caches and temporary directories..."

rm -rf "${MKROOTFS_ROOT_DIR}/var/cache"
rm -rf "${MKROOTFS_ROOT_DIR}/var/log"
rm -rf "${MKROOTFS_ROOT_DIR}/var/tmp"
rm -rf "${MKROOTFS_ROOT_DIR}/tmp"

mkdir -p "${MKROOTFS_ROOT_DIR}/var/cache"
mkdir -p "${MKROOTFS_ROOT_DIR}/var/log"
mkdir -p "${MKROOTFS_ROOT_DIR}/var/tmp"
mkdir -p "${MKROOTFS_ROOT_DIR}/tmp"

type mkrootfs_package_hook > /dev/null 2>&1
if [ $? -eq 0 ]; then
    mkrootfs_package_hook
fi

ROOTNAME="${MKROOTFS_DISTRO}-$(date '+%Y%m%d').tar.xz"

stage_sublog "creating archive ${ROOTNAME}..."

cd "${MKROOTFS_ROOT_DIR}" || die_log "could not enter root directory"

tar cpJf "../../${ROOTNAME}" . || die_log "could not create rootfs archive"
chown "${MKROOTFS_USER}:${MKROOTFS_GROUP}" "../../${ROOTNAME}"

stage_sublog "created archive: ${ROOTNAME}"
stage_sublog "cleaning up..."
