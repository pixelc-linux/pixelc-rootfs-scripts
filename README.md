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
6) **Packaging** - run as **root**, takes care of generating the rootfs
   archive; the reason it has to run as root is to perform cleanup in the
   rootfs as well as be able to package files that are only root-readable
   into the final archive
7) **Cleanup** - run as **root**, removes the unpackaged rootfs and any
   downloaded files; this must be run as root because the rootfs files are
   owned by root and cannot be otherwise directly manipulated

The stages need to be run in that order. The scripts take care of making
sure the dependencies are satisfied. If any stage fails, you can continue
where it left off after figuring out the problem by running the script
again. You can also explicitly request a stage if you wish to run the
process manually.

## Running

You generally need to specify 3 parameters, the distro being one and the user
and group being the other. Any other parameters are optional and can be found
by passing `-h`.

```
./mkrootfs.sh -d void-musl -u youruser -g yourgroup
```

The script needs to be run as root. If you don't run it as root, it will not
do anything. The script does its own checks.

You can invoke each stage on its own by passing `-s`. This is useful if some
stage fails and you've fixed the problem. To for example do the packaging
stage. simply run

```
./mkrootfs.sh -d mydistro -u youruser -g yourgroup -s package
```

The script automatically makes sure the dependencies are met, so it will
not let you run an incorrect stage.

You can also run the entire process with a custom shell run just before
packaging by passing `-S`. This is useful if you want to do some specific
customization in your rootfs before packaging it. Don't forget to clean up
things the scripts wouldn't.

## Creating a distro template and scripts

When writing distribution support for the rootfs generator, two things are
needed. One is a set of scripts for the distro; the other is its template
file.

### Distro scripts

The `distros` directory contains a sub-directory for each distro script set.
One script set may be shared between multiple distro templates; for exmaple,
Void Linux has `glibc` and `musl` variants and each needs its own template
but they can share the scripts.

The scripts set can contain the following scripts:

- `01-download.sh`
- `02-bootstrap1.sh`
- `03-bootstrap2.sh`
- `04-configure.sh`
- `05-shell.sh`
- `06-package.sh`
- `07-cleanup.sh`

Only `bootstrap1`, `bootstrap2` and `configure` are mandatory; these need to
be written separately for each distribution. The others can be supplied from
the `fallback` directory. This directory provides fallback scripts for when
they're not written; the mandatory ones have fallbacks that exit with failure,
the optional ones have reasonable default behavior, with the exception of the
`download` stage, which simply does nothing by default.

### Distro template

Each distribution needs its template file, in `distros`, named `my-distro.sh`.
That is then invoked when generating for `my-distro`. It's an ordinary shell
script; it shall export environment variables that the distro scripts need or
that the generator needs.

The following variables are mandatory:

- `MKROOTFS_SCRIPT_DIR` - the directory with the distro scripts, e.g. `void`

The following variables are optional:

- `MKROOTFS_ROOT_PASSWORD` - the root password for the generated rootfs, by
  default `pixelc`
- `MKROOTFS_ROOT_DIR` - the directory in `generated/my-distro` where the
  unpacked rootfs resides before packaging, by default `rootfs`, you should
  not have any reason to change this
- `MKROOTFS_ROOT_GID` - the group name or group ID (the latter is portable
  as it does not depend on what is available in the running system) of the
  rootfs files; by default this is `0`. This will be the correct value for
  most distros but you can change it if necessary. The root directory made
  by `make_rootfs` will be owned by this group, so any files inside should
  inherit that correctly, but if they do not, it's up to the distro scripts
  to make sure they do.
- `MKROOTFS_ENV_BIN` - the path to the `env` binary in the resulting rootfs,
  needed for environment setting and command invocation; by default this is
  `/usr/bin/env` which will match vast majority of distros but may not always
  be correct
- `MKROOTFS_ENV_PATH` - the value of the `PATH` environment variable in the
  rootfs, `/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin` by
  default
- `MKROOTFS_ENV_TERM` - the value of the `TERM` environment variable in the
  rootfs, by default your own environment's value of `TERM`
- `MKROOTFS_ENV_HOME` - the value of the `HOME` environment variable in the
  rootfs, by default `/root`
- `MKROOTFS_ENV_SHELL` - the value of the `SHELL` environment variable in
  the rootfs and the shell that will get invoked, `/bin/sh` by default,
  must be a Bourne shell

It may additionally contain any distro-dependent environment variables.

### Utility library

There is the `utils.sh` script meant to be included in distro scripts like
this:

```
. ./utils.sh
```

It will provide functions to simplify writing of distro scripts. The following
functions are provided.

#### as_user [...]

Runs a command, but as an unprivileged user rather than as root.

#### switch_dir

Switches into the `generated/my-distro` directory. Should be called after
including `utils.sh`.

#### get_arch

Similar to `uname -m`, but always returns `amd64` for `x86_64` platforms.

#### stage_log [...]

Logs into standard output in format `NN-stage: ...`, with `NN` being the
stage number and `stage` being the stage name, like `01-download`. The
arguments are concatenated and separated with space.

#### stage_sublog [...]

Logs into standard output in format `--> ...`, similarly to above.

#### error_log [...]

Logs into standard output in format `ERROR: ..., exitting...

#### die_log message [error_code]

Calls `error_log` with `message` and exits with either `1` or `error_code`.

#### fetch_file url output

Fetches a file from `url` into `output` as an unprivileged user.

#### fetch_file_root url output

Like above, but as root.

#### add_cleanup func

Given a function name, this function will be called upon error.
Meant to clean up any resources not meant to persist into the next stage.

#### add_cleanup_success func

Same as above, but to be called on success.

#### register_binfmt

If run on a non-`aarch64` architecture, this will register the `qemu` user mode
interpreter so that `chroot` can happen. On success, it will also make sure
that `unregister_binfmt` is called on cleanup.

#### unregister_binfmt

If a handler was registered, this will unregister it. Typically no need to
call this manually as it will be called upon cleanup.

#### prepare_binfmt

This should be called before entering `chroot` for the first time, but never
after. It will copy the `qemu` interpreter into the `rootfs` directory so
that the `binfmt` handler has something to execute. Does nothing when run
on `aarch64`.

#### unprepare_binfmt

Should be called as a part of cleanups before packaging the `rootfs` archive.
It will remove the `qemu` interpreter from the directory.

#### mount_pseudo

Mounts pseudo-filesystems `/proc`, `/dev`, `/sys` into the `rootfs`. Also
registers cleanup handler to un-mount them upon exit/error. This is usually
necessary for full function of the `rootfs`.

#### umount_pseudo

Unmounts the pseudo-filesystems when mounted by above. Automatically called
upon cleanup when the above is called. It is also good to call as a part of
the packaging process, just to make sure, in case a `shell` stage didn't
automatically unmount it.

#### prepare_net

Makes sure the rootfs contains a `resolv.conf` for network access inside the
chroot. Automatically cleans up using `unprepare_net` at the end, so you do
not need to call it manually.

#### unprepare_net

Cleans up `resolv.conf` left by `prepare_net`; typically called automatically
but it's good to make sure in packaging stage anyway.

#### test_rootfs

Use this to test whether a `rootfs` directory exists. It will error if it
does not.

#### make_rootfs

Use this to create the `rootfs` directory and error if it already exists,
if it cannot be created or if the permissions cannot be set. It also defines
a cleanup handler using `add_cleanup` that will remove the `rootfs` if the
stage fails. The resulting root directory will be owned by `MKROOTFS_ROOT_GID`
and that alone should be enough for most distro scripts to result in proper
permissions all across the rootfs.

#### in_rootfs command [...]

This will run `command` in the rootfs, passing it any additional arguments.
The `command` will be run with only the `HOME`, `TERM`, `PATH` and `SHELL`
environment varibles set, the values of them depend on the template file.

### Writing distro scripts

Every distro script should begin with the following lines:

```
#!/bin/sh

. ./utils.sh
switch_dir
```

This will include the utility library and switch to the directory in which
everything is being generated, which is important for proper function of
all of the utility library.

You can also extend default scripts easily by using hooks. That means you can
create a scripts that will define a hook function and include the fallback
script; the fallback script will execute the hook at the specified point.
Example:

```
#!/bin/sh

necessary_hook() {
    # do stuff
}
. ./distros/fallback/NN-whatever.sh
```

#### 01-download.sh

In this script you will want to fetch everything that is necessary for the
bootstrap process; it doesn't mean it should fetch the root filesystem itself,
more like any tools needed for it etc. for example a static binary of the
package manager you'll be bootstrapping with. It can also do nothing, as
is default.

No hook functionality is provided, because it does nothing.

#### 02-bootstrap1.sh

Here you will want to use whatever from the previous stage (or from scratch)
to fetch an initial version of the root filesystem that may not be configured,
but will be at least `chroot`able. It will look roughly like this:

```
#!/bin/sh

. ./utils.sh
switch_dir

# make the rootfs directory
make_rootfs

##############################
# fetch rootfs contents here #
##############################

################################
# do initial preparations here #
################################

##########################################################
# maybe some pre-configuration necessary to enter chroot #
##########################################################

# success, so do not remove root
remove_cleanup cleanup_root
```

No hook functionality is provided, because it must be specified per-distro.

#### 03-bootstrap2.sh

This will `prepare_binfmt`, `register_binfmt`, `mount_pseudo` and then
use `in_rootfs` to do initial configuration on the root filesystem. This
will result in the root filesystem being technically ready and functional
as if it was generated by the upstream distro, but without any adjustments
necessary for the Pixel C and maybe missing some custom packages etc. Example:

```
#!/bin/sh

. ./utils.sh
switch_dir

# preparations
test_rootfs
prepare_binfmt
register_binfmt
mount_pseudo

################################
# perform stuff in chroot here #
################################
# e.g. in_rootfs my-cool-package-manager reconfigure -a -f
```

This part tends to be rather simple.

No hook functionality is provided, because it must be specified per-distro.

#### 04-configure.sh

This will do stuff like setting root password, pre-configuring hardware such
as Bluetooth, enabling services to make sure a graphical environment starts
and so on.

```
#!/bin/sh

. ./utils.sh
switch_dir

# preparations, note how there is no prepare_binfmt
test_rootfs
register_binfmt
mount_pseudo
prepare_net

################################
# perform stuff in chroot here #
################################
```

No hook functionality is provided, because it must be specified per-distro.

#### 05-shell.sh

You shouldn't need to override this, as there is a functional default version
already provided out of box in the `fallback` directory. IF you happen to need
to change something, copy it into your distro and modify.

You can do that using a hook. The `mkrootfs_shell_hook` function is invoked
after the `chroot` exits, if it exists.

#### 06-package.sh

There is a default version in `fallback`. Chances are you will want to actually
override this to do e.g. custom cleanups.

The default version does roughly this:

1) `test_rootfs`, `umount_pseudo`, `unprepare_binfmt`, `unprepare_net`
2) flush `/var/cache`, `/var/log`, `/var/tmp` and `/tmp`
3) compress into `my-distro-YYYYMMDD.tar.xz`, preserving permissions
4) change ownership of the resulting archive to the unprivileged user/group

If you can think of any additional cleanups, go ahead and change it. You can
use a hook for that; the `mkrootfs_package_hook` is invoked after doing the
default cleanups and before making the archive.

#### 07-cleanup.sh

This is also provided by default. It removes all of `genrated/my-distro` by
default. It also executes `mkrootfs_cleanup_hook` after the removal.
