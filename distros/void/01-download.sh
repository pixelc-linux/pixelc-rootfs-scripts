#!/bin/sh

. ./utils.sh

switch_dir

XBPS_ARCHIVE="xbps-static-latest.$(uname -m)-musl.tar.xz"
XBPS_URL="http://repo.voidlinux.eu/static/${XBPS_ARCHIVE}"

stage_log "getting xbps..."

stage_sublog "fetching xbps..."

fetch_file "$XBPS_URL" "$XBPS_ARCHIVE" || \
    die_log "could not fetch xbps for $(uname -m)"

xbps_cleanup_archive() {
    rm -f "$XBPS_ARCHIVE"
}
CLEANUP_OLD=$(append_cleanup xbps_cleanup)

stage_sublog "extracting xbps..."

as_user rm -rf xbps || die_log "xbps directory cleanup failed"
as_user mkdir xbps  || die_log "xbps directory creation failed"

cd xbps
xbps_cleanup_dir() {
    cd ..
    rm -rf xbps
}
prepend_cleanup xbps_cleanup_dir

tar xf "../${XBPS_ARCHIVE}" || die_log "unpacking xbps failed"

test -x "xbps/usr/bin/xbps-install.static" || \
    die_log "invalid xbps contents"

stage_sublog "cleaning up..."

restore_cleanup "$CLEANUP_OLD"
cd ..
rm -f "$XBPS_ARCHIVE"

exit 0
