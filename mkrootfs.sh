#!/bin/sh

# some shells don't like just exporting
if [ -z "$MKROOTFS_NO_COLOR" ]; then
    export MKROOTFS_NO_COLOR=
else
    export MKROOTFS_NO_COLOR
fi

# redirected stdout, no color stuff
if [ ! -t 1 ]; then
    export MKROOTFS_NO_COLOR=1
fi

# include utils
. ./utils.sh
test "$(whoami)" = "root" || die_log "must be run as root"
test -x "$(command -v sudo)" || die_log "sudo not found"
test -x "$(command -v wget)" || die_log "wget not found"

export MKROOTFS_CURRENT_ARCH="$(get_arch)"
export MKROOTFS_TARGET_ARCH="aarch64"

export MKROOTFS_USER=""
export MKROOTFS_GROUP=""

export MKROOTFS_DISTRO=""

MKROOTFS_STAGE=""
MKROOTFS_SHELL=
export MKROOTFS_QEMU="qemu-aarch64-static"

QEMU_STATIC_DEB="qemu-user-static_2.12+dfsg-1+b1_${MKROOTFS_CURRENT_ARCH}.deb"
QEMU_STATIC_DEB_URL="http://ftp.debian.org/debian/pool/main/q/qemu/${QEMU_STATIC_DEB}"

help() {
    echo "Usage: $0 [arguments]"
    echo "Available options:"
    echo "  -h print this message"
    echo "  -d DISTRO  the distro to generate"
    echo "  -u USER    the unprivileged user"
    echo "  -g GROUP   the group"
    echo "  -s STAGE   the stage to run"
    echo "  -S         enter shell after configure stage"
    echo "  -C         do not use color output"
    echo ""
    echo "Group is used for ownership of the final tarball."
    echo "If you specify stage, only that stage will be run."
}

while getopts d:u:g:s:SCh OPT; do
    case $OPT in
        d) export MKROOTFS_DISTRO=$OPTARG ;;
        u) export MKROOTFS_USER=$OPTARG ;;
        g) export MKROOTFS_GROUP=$OPTARG ;;
        s) MKROOTFS_STAGE=$OPTARG ;;
        S) MKROOTFS_SHELL=1 ;;
        C) export MKROOTFS_NO_COLOR=1 ;;
        h) help; exit 0 ;;
        \?)
            echo "Unrecognized option: $OPTARG"
            help
            exit 1
        ;;
    esac
done

# sanitize beforehand

if [ "$MKROOTFS_USER" == "root" ]; then
    error_log "unprivileged user must not be root"
    help
    exit 1
fi

silent id "$MKROOTFS_USER"
if [ $? -ne 0 ]; then
    error_log "unprivileged user does not exist"
    help
    exit 1
fi

silent getent group "$MKROOTFS_GROUP"
if [ $? -ne 0 ]; then
    error_log "group does not exist"
    help
    exit 1
fi

if [ ! -f "./distros/${MKROOTFS_DISTRO}.sh" ]; then
    error_log "distro '$MKROOTFS_DISTRO' not found"
    help
    exit 1
fi

# prepare env

export MKROOTFS_GENERATED="./generated/${MKROOTFS_DISTRO}"

fetch_qemu() {
    echo "Interpreter '$MKROOTFS_QEMU' not found, downloading..."
    test -x "$(command -v ar)" || die_log "ar not found"
    test -x "$(command -v tar)" || die_log "tar not found"
    TMPDIR="$(as_user mktemp -d qemu-XXXXXXXX)"
    test $? -eq 0 || die_log "could not create a temporary direcotry"
    cd "$TMPDIR"
    as_user wget "$QEMU_STATIC_DEB_URL"
    if [ $? -ne 0 ]; then
        cd ..
        as_user rm -rf "$TMPDIR"
        die_log "could not fetch the qemu package"
    fi
    echo "Extracting qemu package..."
    as_user ar x "$QEMU_STATIC_DEB"
    if [ $? -ne 0 ]; then
        cd ..
        as_user rm -rf "$TMPDIR"
        die_log "could not extract the deb package"
    fi
    as_user tar xf "data.tar.xz"
    if [ $? -ne 0 ]; then
        cd ..
        as_user rm -rf "$TMPDIR"
        die_log "could not extract the deb data"
    fi
    echo "Copying qemu binary..."
    as_user cp "usr/bin/$MKROOTFS_QEMU" "../bin"
    if [ $? -ne 0 ]; then
        cd ..
        as_user rm -rf "$TMPDIR"
        die_log "could not copy the qemu binary"
    fi
    echo "Done copying."
    cd ..
    as_user rm -rf "$TMPDIR"
}

as_user mkdir -p "${MKROOTFS_GENERATED}"
as_user mkdir -p "bin"

if [ ! -f "bin/qemu-aarch64-static" ] && \
   [ "$MKROOTFS_TARGET_ARCH" != "$MKROOTFS_CURRENT_ARCH" ]
then
    QEMU_PATH="$(which $MKROOTFS_QEMU)"
    if [ $? -ne 0 ]; then
        fetch_qemu
    else
        as_user cp "$QEMU_PATH" "bin"
    fi
    as_user chmod 755 "bin/$MKROOTFS_QEMU" ||
        die_log "could not set qemu permissions"
fi

# export environment for the distro

export MKROOTFS_SCRIPT_DIR=""
export MKROOTFS_ROOT_PASSWORD="pixelc"
export MKROOTFS_ROOT_DIR="rootfs"
export MKROOTFS_ROOT_GID="0"
export MKROOTFS_ENV_BIN="/usr/bin/env"

export MKROOTFS_ENV_PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"
export MKROOTFS_ENV_TERM="$TERM"
export MKROOTFS_ENV_HOME="/root"
export MKROOTFS_ENV_SHELL="/bin/sh"

. "./distros/${MKROOTFS_DISTRO}.sh"

if [ -z "$MKROOTFS_SCRIPT_DIR" ] || [ ! -d "distros/$MKROOTFS_SCRIPT_DIR" ]; then
    die_log "distro directory not set or not found"
fi

# stage functions

check_stage() {
    STAGENAME="$(echo $1 | sed 's/..\-//')"
    PREVSTAGENAME="$(echo $2 | sed 's/..\-//')"
    if [ ! -f "${MKROOTFS_GENERATED}/.stage" ]; then
        error_log "stage '$STAGENAME' depends on '$PREVSTAGENAME' but" \
             "nothing was run"
        exit 1
    fi
    CURPREVSTAGE="$(cat ${MKROOTFS_GENERATED}/.stage)"
    CURPREVSTAGENAME="$(echo $CURPREVSTAGE | sed 's/..\-//')"
    if [ "$CURPREVSTAGE" != "$2" ]; then
        error_log "stage '$STAGE' depends on '$PREVSTAGE' but previous stage" \
             "is '$CURPREVSTAGENAME'"
        exit 1
    fi
}

run_stage() {
    STAGE="$1"
    PREVSTAGE="$2"
    USER="$3"
    SCRIPT="./distros/${MKROOTFS_SCRIPT_DIR}/${STAGE}.sh"
    if [ -n "$PREVSTAGE" ]; then
        check_stage "$STAGE" "$PREVSTAGE"
    fi
    if [ ! -f "$SCRIPT" ]; then
        SCRIPT="./distros/fallback/${STAGE}.sh"
    fi
    export MKROOTFS_STAGE="$STAGE"
    prestage_log "Running stage '${STAGE}' (${SCRIPT})..."
    if [ "$USER" = "root" ]; then
        "${SCRIPT}"
    else
        sudo -E -u "$USER" -g "$MKROOTFS_GROUP" "${SCRIPT}"
    fi
    if [ $? -ne 0 ]; then
        die_log "stage '$(echo $STAGE | sed 's/..\-//')' failed" $?
    fi
    poststage_log "Stage '${STAGE}' succeeded."
    # only stages <= configure are ever "done"
    if [ "$(echo $STAGE | cut -d - -f 1)" -le "04" ]; then
        echo "$STAGE" | \
            as_user dd of="${MKROOTFS_GENERATED}/.stage" status=none
    fi
}

# decide stages

if [ -z "$MKROOTFS_STAGE" ]; then
    rm -rf "${MKROOTFS_GENERATED}/*"
    run_stage "01-download"   ""              "$MKROOTFS_USER"
    run_stage "02-bootstrap1" "01-download"   "root"
    run_stage "03-bootstrap2" "02-bootstrap1" "root"
    run_stage "04-configure"  "03-bootstrap2" "root"
    if [ -n "$MKROOTFS_SHELL" ]; then
        run_stage "05-shell" "04-configure" "root"
    fi
    run_stage "06-package"    "04-configure"  "root"
    run_stage "07-cleanup"    "04-configure"  "root"
    exit 0
fi

case "$MKROOTFS_STAGE" in
    download)
        run_stage "01-download" "" "$MKROOTFS_USER";;
    bootstrap1)
        run_stage "02-bootstrap1" "01-download" "root" ;;
    bootstrap2)
        run_stage "03-bootstrap2" "02-bootstrap1" "root" ;;
    configure)
        run_stage "04-configure" "03-bootstrap2" "root" ;;
    shell)
        run_stage "05-shell" "04-configure" "root" ;;
    package)
        run_stage "06-package" "04-configure" "root" ;;
    cleanup)
        run_stage "07-cleanup" "04-configure" "root" ;;
    *)
        error_log "unknown stage '$MKROOTFS_STAGE'"
        help
        exit 1
esac
