#!/bin/sh

. ./utils.sh

switch_dir

echo "Invoking rootfs shell..."

test_rootfs
register_binfmt
mount_pseudo
in_rootfs /bin/sh

echo "Done with rootfs shell."
