#!/bin/sh

. ./utils.sh

switch_dir

stage_log "preparing initial rootfs..."

make_rootfs

stage_sublog "copying signing keys..."
cp -R xbps/var "$MKROOTFS_ROOT_DIR" || die_log "could not copy signing keys"

stage_sublog "downloading packages..."

cleanup_root() {
    rm -rf "$MKROOTFS_ROOT_DIR"
}
append_cleanup cleanup_root

# stage 1: download stuff, no need to configure
XBPS_TARGET_ARCH="${MKROOTFS_VOID_ARCH}" ./xbps/usr/bin/xbps-install \
    -S -y -R "${MKROOTFS_VOID_REPO_URL}" -r "$MKROOTFS_ROOT_DIR" base-voidstrap
test $? -eq 0 || die_log "initial bootstrap failed"

# glibc needs locale configured to work correctly
if [ -e "${MKROOTFS_ROOT_DIR}/etc/default/libc-locales" ]; then
    LOCALE=en_US.UTF-8
    sed -e "s/\#\(${LOCALE}.*\)/\1/g" \
        -i "${MKROOTFS_ROOT_DIR}/etc/default/libc-locales"
fi

# stage 2. configure base-files, this will fail as a whole but will set
# up the symlinks and other things necessary for the system to work at all
# note how it's run as host arch
stage_sublog "pre-configuring base (will partially fail)..."
./xbps/usr/bin/xbps-reconfigure -r "$MKROOTFS_ROOT_DIR" base-files

stage_sublog "cleaning up..."

# keep the root dir
remove_cleanup cleanup_root
