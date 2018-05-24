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

COLOR_BOLD_WHITE="\033[1;37m"
COLOR_BOLD_GREEN="\033[1;32m"
COLOR_BOLD_RED="\033[1;31m"
COLOR_RESET="\033[0m"

stage_log() {
    echo "${COLOR_BOLD_WHITE}${MKROOTFS_STAGE}:${COLOR_RESET} $@"
}

stage_sublog() {
    echo "${COLOR_BOLD_WHITE}-->${COLOR_RESET} $@"
}

error_log() {
    echo "${COLOR_BOLD_RED}ERROR:${COLOR_RESET} $@, exitting..."
}

die_log() {
    error_log "$1"
    if [ $# -gt 1 ]; then
        exit $2
    else
        exit 1
    fi
}

fetch_file() {
    as_user wget "$1" -O "$2"
}

fetch_file_root() {
    wget "$1" -O "$2"
}

switch_dir() {
    cd "$MKROOTFS_GENERATED" || die_log "could not switch directory"
}

MKROOTFS_CLEANUP_FUNCS=""
MKROOTFS_CLEANUP_ERROR_FUNCS=""
cleanup_cb_error() {
    for func in $(echo $MKROOTFS_CLEANUP_ERROR_FUNCS | tr ';' ' '); do
        eval "$func"
    done
    exit $?
}
cleanup_cb() {
    if [ $? -ne 0 ]; then
        cleanup_cb_error
    fi
    for func in $(echo $MKROOTFS_CLEANUP_FUNCS | tr ';' ' '); do
        eval "$func"
    done
    exit 0
}
trap cleanup_cb EXIT
trap cleanup_cb_error INT QUIT ABRT TERM

add_cleanup_success() {
    MKROOTFS_CLEANUP_FUNCS="${MKROOTFS_CLEANUP_FUNCS};$1"
}

add_cleanup() {
    MKROOTFS_CLEANUP_ERROR_FUNCS="${MKROOTFS_CLEANUP_ERROR_FUNCS};$1"
}

export MKROOTFS_BINFMT_NAME="mkrootfs-aarch64"
export MKROOTFS_BINFMT_MAGIC="\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7"
export MKROOTFS_BINFMT_MASK="\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff"

register_binfmt() {
    if [ "$MKROOTFS_TARGET_ARCH" != "$MKROOTFS_CURRENT_ARCH" ]; then
        stage_sublog "registering binary format..."
        test -d "/proc/sys/fs/binfmt_misc" || \
            die_log "no binfmt_misc support in your kernel"
        if [ ! -f "/proc/sys/fs/binfmt_misc/register" ]; then
            mount -t binfmt_misc none /proc/sys/fs/binfmt_misc || \
                die_log "could not mount binfmt_misc"
            append_cleanup unregister_binfmt
        fi
        if [ ! -f "/proc/sys/fs/binfmt_misc/${MKROOTFS_BINFMT_NAME}" ]; then
            echo ":${MKROOTFS_BINFMT_NAME}:M::${MKROOTFS_BINFMT_MAGIC}:${MKROOTFS_BINFMT_MASK}:/${MKROOTFS_QEMU}:" \
                > /proc/sys/fs/binfmt_misc/register
            if [ $? -ne 0 ]; then
                die_log "binfmt registration failed"
            fi
        fi
    fi
}

unregister_binfmt() {
    if [ "$MKROOTFS_TARGET_ARCH" != "$MKROOTFS_CURRENT_ARCH" ]; then
        if [ -f "/proc/sys/fs/binfmt_misc/${MKROOTFS_BINFMT_NAME}" ]; then
            echo -1 > "/proc/sys/fs/binfmt_misc/${MKROOTFS_BINFMT_NAME}"
        fi
    fi
}

prepare_binfmt() {
    if [ "$MKROOTFS_TARGET_ARCH" != "$MKROOTFS_CURRENT_ARCH" ]; then
        cp "../../bin/$MKROOTFS_QEMU" "$MKROOTFS_ROOT_DIR" || \
            die_log "could not copy qemu"
    fi
}

unprepare_binfmt() {
    if [ "$MKROOTFS_TARGET_ARCH" != "$MKROOTFS_CURRENT_ARCH" ]; then
        rm -f "${MKROOTFS_ROOT_DIR}/${MKROOTFS_QEMU}"
    fi
}

mount_pseudo() {
    stage_sublog "ounting pseudo-filesystems..."
    mkdir -p "${MKROOTFS_ROOT_DIR}/dev" "${MKROOTFS_ROOT_DIR}/proc" \
        "${MKROOTFS_ROOT_DIR}/sys"
    mount --bind /dev "${MKROOTFS_ROOT_DIR}/dev"
    mount --bind /sys "${MKROOTFS_ROOT_DIR}/sys"
    mount --bind /proc "${MKROOTFS_ROOT_DIR}/proc"
    append_cleanup umount_pseudo
}

umount_pseudo() {
    umount "$1/dev" > /dev/null 2>&1
    umount "$1/sys" > /dev/null 2>&1
    umount "$1/proc" > /dev/null 2>&1
}

test_rootfs() {
    test -d "$MKROOTFS_ROOT_DIR" || die_log "root directory does not exist"
}

make_rootfs() {
    test ! -d "$MKROOTFS_ROOT_DIR" || die_log "root directory already exists"
    mkdir "$MKROOTFS_ROOT_DIR" || die_log "could not create root directory"
    add_cleanup_error remove_rootfs
}

remove_rootfs() {
    rm -rf "$MKROOTFS_ROOT_DIR" > /dev/null 2>&1
}

in_rootfs() {
    chroot "$MKROOTFS_ROOT_DIR" "$MKROOTFS_ENV_BIN" -i \
        HOME="$MKROOTFS_ENV_HOME" TERM="$MKROOTFS_ENV_TERM" \
        PATH="$MKROOTFS_ENV_PATH" SHELL="$MKROOTFS_ENV_SHELL" \
        "$@"
}
