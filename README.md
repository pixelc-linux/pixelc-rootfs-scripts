# Pixel C rootfs generation scripts

The goal of this repository is to provide a script infra that will take care
of generating root filesystem tarballs for arbitrary distros, suitable for
distribution or usage.

It requires root to run, as certain tasks cannot be done without it (such as
making sure the permissions are correct). But in order to not use root more
than necessary, the scripts will switch to an unprivileged user where possible.
