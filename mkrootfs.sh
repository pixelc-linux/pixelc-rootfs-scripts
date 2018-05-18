#!/bin/sh

if [ "$(whoami)" != "root" ]; then
    echo "Must be run as root, exitting..."
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

# export environment for the distro

. "./distros/${MKROOTFS_DISTRO}.sh"
