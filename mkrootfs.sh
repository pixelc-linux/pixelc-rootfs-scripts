#!/bin/sh

# include utils
. ./utils.sh

if [ "$(whoami)" != "root" ]; then
    echo "Must be run as root, exitting..."
    exit 1
fi

if [ ! -x "$(command -v sudo)" ]; then
    echo "Sudo not found, exitting..."
    exit 1
fi

export MKROOTFS_CURRENT_ARCH="$(get_arch)"
export MKROOTFS_TARGET_ARCH="aarch64"

export MKROOTFS_USER=""
export MKROOTFS_GROUP=""

export MKROOTFS_DISTRO=""

MKROOTFS_STAGE=""
MKROOTFS_SHELL=
MKROOTFS_QEMU="qemu-aarch64-static"

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
    echo ""
    echo "Group is used for ownership of the final tarball."
    echo "If you specify stage, only that stage will be run."
}

while getopts d:u:g:s:Sh OPT; do
    case $OPT in
        d) export MKROOTFS_DISTRO=$OPTARG ;;
        u) export MKROOTFS_USER=$OPTARG ;;
        g) export MKROOTFS_GROUP=$OPTARG ;;
        s) MKROOTFS_STAGE=$OPTARG ;;
        S) MKROOTFS_SHELL=1 ;;
        h) help; exit 0 ;;
        \?)
            echo "Unrecognized option: $OPTARG"
            help
            exit 1
        ;;
    esac
done

# sanitize beforehand

if [ "$MKROOTFS_USER" = "root" ]; then
    echo "Unprivileged user must not be root, exitting..."
    help
    exit 1
fi

id "$MKROOTFS_USER" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Unprivileged user does not exist, exitting..."
    help
    exit 1
fi

getent group "$MKROOTFS_GROUP" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Group does not exist, exitting..."
    help
    exit 1
fi

if [ ! -f "./distros/${MKROOTFS_DISTRO}.sh" ]; then
    echo "Distro '$MKROOTFS_DISTRO' not found, exitting..."
    help
    exit 1
fi

# prepare env

export MKROOTFS_GENERATED="./generated/${MKROOTFS_DISTRO}"

fetch_qemu() {
    echo "Interpreter '$MKROOTFS_QEMU' not found, downloading..."
    if [ ! -x "$(command -v wget)" ]; then
        echo "Wget not found, exitting..."
        exit 1
    fi
    if [ ! -x "$(command -v ar)" ]; then
        echo "The 'ar' utility was not found, exitting..."
        exit 1
    fi
    if [ ! -x "$(command -v tar)" ]; then
        echo "Tar not found, exitting..."
        exit 1
    fi
    TMPDIR="$(as_user mktemp -d qemu-XXXXXXXX)"
    if [ $? -ne 0 ]; then
        echo "Couldn't create a temporary directory, exitting..."
        exit 1
    fi
    cd "$TMPDIR"
    as_user wget "$QEMU_STATIC_DEB_URL"
    if [ $? -ne 0 ]; then
        echo "Couldn't fetch the qemu package, exitting..."
        cd ..
        as_user rm -rf "$TMPDIR"
        exit 1
    fi
    echo "Extracting qemu package..."
    as_user ar x "$QEMU_STATIC_DEB"
    if [ $? -ne 0 ]; then
        echo "Couldn't extract the deb package, exitting..."
        cd ..
        as_user rm -rf "$TMPDIR"
        exit 1
    fi
    as_user tar xf "data.tar.xz"
    if [ $? -ne 0 ]; then
        echo "Couldn't extract the deb data, exitting..."
        cd ..
        as_user rm -rf "$TMPDIR"
        exit 1
    fi
    echo "Copying qemu binary..."
    as_user cp "usr/bin/$MKROOTFS_QEMU" "../bin"
    if [ $? -ne 0 ]; then
        echo "Couldn't copy the qemu binary, exitting..."
        cd ..
        #as_user rm -rf "$TMPDIR"
        exit 1
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
        cp "$QEMU_PATH" "bin"
    fi
    as_user chmod 755 "bin/$QEMU_PATH"
fi

# export environment for the distro

export MKROOTFS_SCRIPT_DIR=""

. "./distros/${MKROOTFS_DISTRO}.sh"

if [ -z "$MKROOTFS_SCRIPT_DIR" ] || [ ! -d "distros/$MKROOTFS_SCRIPT_DIR" ]; then
    echo "Distro directory not set or not found, exitting..."
    exit 1
fi

# stage functions

check_stage() {
    STAGENAME="$(echo $1 | sed 's/..\-//')"
    PREVSTAGENAME="$(echo $2 | sed 's/..\-//')"
    if [ ! -f "${MKROOTFS_GENERATED}/.stage" ]; then
        echo "Stage '$STAGENAME' depends on '$PREVSTAGENAME' but" \
             "nothing was run, exitting..."
        exit 1
    fi
    CURPREVSTAGE="$(cat ${MKROOTFS_GENERATED}/.stage)"
    CURPREVSTAGENAME="$(echo $CURPREVSTAGE | sed 's/..\-//')"
    if [ "$CURPREVSTAGE" != "$2" ]; then
        echo "Stage '$STAGE' depends on '$PREVSTAGE' but previous stage" \
             "is '$CURPREVSTAGENAME', exitting..."
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
    echo "Running stage '${STAGE}' (${SCRIPT})..."
    if [ "$USER" = "root" ]; then
        "${SCRIPT}"
    else
        sudo -E -u "$USER" -g "$MKROOTFS_GROUP" "${SCRIPT}"
    fi
    EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
        echo "Stage '$(echo $STAGE | sed 's/..\-//')' failed, exitting..."
        exit $EXITCODE
    fi
    echo "Stage '${STAGE}' succeeded."
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
    run_stage "06-package"    "04-configure"  "$MKROOTFS_USER"
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
        run_stage "06-package" "04-configure" "$MKROOTFS_USER" ;;
    cleanup)
        run_stage "07-cleanup" "04-configure" "root" ;;
    *)
        echo "Unknown stage '$MKROOTFS_STAGE', exitting..."
        help
        exit 1
esac
