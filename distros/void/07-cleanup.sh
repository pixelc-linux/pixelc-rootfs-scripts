#!/bin/sh

. ./utils.sh

echo "Cleaning up for ${MKROOTFS_DISTRO}..."
rm -rf "${MKROOTFS_GENERATED}"
