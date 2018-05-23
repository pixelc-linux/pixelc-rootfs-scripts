#!/bin/sh

. ./utils.sh

if [ ! -f "${MKROOTFS_GENERATED}/${MKROOTFS_QEMU}" ]; then
    as_user cp "bin/$MKROOTFS_QEMU" "$MKROOTFS_GENERATED"
    if [ $? -ne 0 ]; then
        echo "Could not copy qemu interpreter, exitting..."
        exit 1
    fi
fi

switch_dir

XBPS_ARCHIVE="xbps-static-latest.$(uname -m)-musl.tar.xz"
XBPS_URL="http://repo.voidlinux.eu/static/${XBPS_ARCHIVE}"

echo "Fetching xbps..."

fetch_file "$XBPS_URL" "$XBPS_ARCHIVE"
if [ $? -ne 0 ]; then
    echo "Could not fetch xbps for $(uname -m), exitting..."
    exit 1
fi

as_user rm -rf xbps
if [ $? -ne 0 ]; then
    echo "Xbps directory cleanup failed, exitting..."
    rm -f "$XBPS_ARCHIVE"
    exit 1
fi

as_user mkdir xbps
if [ $? -ne 0 ]; then
    echo "Xbps directory creation failed, exitting..."
    rm -f "$XBPS_ARCHIVE"
    exit 1
fi

cd xbps
tar xf "../${XBPS_ARCHIVE}"
if [ $? -ne 0 ]; then
    echo "Unpacking xbps failed, exitting..."
    cd ..
    rm -rf xbps
    rm -f "$XBPS_ARCHIVE"
    exit 1
fi
cd ..

if [ ! -x "xbps/usr/bin/xbps-install.static" ]; then
    echo "Invalid xbps contents, exitting..."
    cd ..
    rm -rf xbps
    rm -f "$XBPS_ARCHIVE"
    exit 1
fi

exit 0
