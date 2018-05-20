#!/bin/sh

# we're running as root; reduce danger
set -u

if [ "$(whoami)" != "root" ]; then
    echo "Must be run as root, exitting..."
    exit 1
fi

if [ ! -x "$(command -v sudo)" ]; then
    echo "Sudo not found, exitting..."
    exit 1
fi

export MKROOTFS_CURRENT_ARCH="$(uname -m)"
export MKROOTFS_TARGET_ARCH="aarch64"

export MKROOTFS_USER=""
export MKROOTFS_GROUP=""

MKROOTFS_DISTRO=""
MKROOTFS_STAGE=""

help() {
    echo "Usage: $0 [arguments]"
    echo "Available options:"
    echo "  -h print this message"
    echo "  -d DISTRO  the distro to generate"
    echo "  -u USER    the unprivileged user"
    echo "  -g GROUP   the group"
    echo "  -s STAGE   the stage to run"
    echo ""
    echo "Group is used for ownership of the final tarball."
    echo "If you specify stage, only that stage will be run."
}

while getopts d:u:g:s:h OPT; do
    case $OPT in
        d) MKROOTFS_DISTRO=$OPTARG ;;
        u) export MKROOTFS_USER=$OPTARG ;;
        g) export MKROOTFS_GROUP=$OPTARG ;;
        s) MKROOTFS_STAGE=$OPTARG ;;
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

id "$MKROOTFS_USER"
if [ $? -ne 0 ]; then
    echo "Unprivileged user does not exist, exitting..."
    help
    exit 1
fi

getent group "$MKROOTFS_GROUP"
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

mkdir -p "generated/${MKROOTFS_DISTRO}"

# export environment for the distro

export MKROOTFS_SCRIPT_DIR=""

. "./distros/${MKROOTFS_DISTRO}.sh"

if [ -z "$MKROOTFS_SCRIPT_DIR" ] || [ ! -d "$MKROOTFS_SCRIPT_DIR" ]; then
    echo "Distro directory not set or not found, exitting..."
    exit 1
fi

# stage functions

check_stage() {
    STAGE="$(echo $1 | sed 's/..\-//')"
    PREVSTAGE="$(echo $2 | sed 's/..\-//')"
    if [ ! -f "generated/${MKROOTFS_DISTRO}/.stage" ]; then
        echo "Stage '$STAGE' depends on '$PREVSTAGE' but" \
             "nothing was run, exitting..."
        exit 1
    fi
    CURPREVSTAGE="$(cat '.generated/${MKROOTFS_DISTRO}/.stage')"
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
    if [ "$USER" = "root" ]; then
        "${SCRIPT}"
    else
        sudo -E -u "$USER" -g "$MKROOTFS_GROUP" "${SCRIPT}"
    fi
    EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
        echo "Script '$script' failed, exitting..."
        exit $EXITCODE
    fi
    # only stages <= configure are ever "done"
    if [ "$(echo $STAGE | cut -d - -f 1)" -le "04" ]; then
        sudo -u "$MKROOTFS_USER" -g "$MKROOTFS_GROUP" \
            echo "$STAGE" > "generated/${MKROOTFS_DISTRO}/.stage"
    fi
}

# decide stages

if [ -z "$MKROOTFS_STAGE" ]; then
    rm -rf "generated/${MKROOTFS_DISTRO}/*"
    run_stage "01-download"   ""              "$MKROOTFS_USER"
    run_stage "02-bootstrap1" "01-download"   "root"
    run_stage "03-bootstrap2" "02-bootstrap1" "root"
    run_stage "04-configure"  "03-bootstrap2" "root"
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
