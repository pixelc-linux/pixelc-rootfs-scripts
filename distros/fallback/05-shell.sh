#!/bin/sh

. ./utils.sh

switch_dir

echo "Invoking rootfs shell..."

test_rootfs
register_binfmt
mount_pseudo
in_rootfs /bin/sh

type mkrootfs_shell_hook > /dev/null 2>&1
if [ $? -eq 0 ]; then
    mkrootfs_shell_hook
fi

echo "Done with rootfs shell."
