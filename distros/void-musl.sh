#!/bin/sh
# config template for Void Linux (musl)

# inherited from glibc config
. ./distros/void-glibc.sh

export MKROOTFS_VOID_ARCH="aarch64-musl"
