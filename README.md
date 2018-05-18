# Pixel C rootfs generation scripts

The goal of this repository is to provide a script infra that will take care
of generating root filesystem tarballs for arbitrary distros, suitable for
distribution or usage.

It requires root to run, as certain tasks cannot be done without it (such as
making sure the permissions are correct). But in order to not use root more
than necessary, the scripts will switch to an unprivileged user where possible.

## Process

A rootfs generation process consists of the following stages:

1) **Download** - run as **user**, optional; downloads data necessary to
   build the rootfs, such as an upstream rootfs tarball
2) **Initial bootstrap** - run as **root**, either bootstraps the system
   from scratch or extracts some data downloaded in the prior step
3) **Secondary bootstrap** - run as **root**, configures the system
   bootstrapped in stage 2; may make use of user-mode `qemu` when not run
   on the target architecture
4) **Configuration** - run as **root**, does any kind of post-installation
   on the generated rootfs, such as creating users and setting up networks
5) **Shell** - run as **root** and only executed **upon request**, you
   can also gain a shell environment inside the configured rootfs for manual
   tinkering
6) **Packaging** - run as **user**, takes care of generating the rootfs
   archive
7) **Cleanup** - run as **root**, removes the unpackaged rootfs and any
   downloaded files; this must be run as root because the rootfs files are
   owned by root and cannot be otherwise directly manipulated

The stages need to be run in that order. The scripts take care of making
sure the dependencies are satisfied. If any stage fails, you can continue
where it left off after figuring out the problem by running the script
again. You can also explicitly request a stage if you wish to run the
process manually.
