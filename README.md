# bootstrap-bash

A simple server kickstart and software configuration tool.


Overview
---
There are a lot of ways to kickstart a server and manage software configurations.
The most basic (and probably most future-proof) is to rely only on shell scripts
and package managers. This tool makes the task of configuring servers and software as easy
as creating directories that contain shell scripts and files listing packages
to install or remove.

If you're looking for more power or automation, have a look at these tools:

* [Chef](http://www.opscode.com/chef/)
* [Puppet](http://puppetlabs.com/)
* [Ansible](http://ansible.github.com/)


### Basic Example

Here are the commands you might execute in a shell to build PHP CLI SAPI:

	cd /tmp
	wget http://us.php.net/distributions/php-5.3.6.tar.gz
	tar xvfz php-5.3.6.tar.gz
	cd php-5.3.6
	./configure
	make
	make install

Or, if you want better error handling, progress output and an audit trail,
you can take this one step further and use some built-in convenience functions:

	bootstrap_file_wget  http://us.php.net/distributions/php-5.3.6.tar.gz /tmp/php-5.3.6.tar.gz
	bootstrap_file_untar /tmp/php-5.3.6.tar.gz /tmp/php-5.3.6 root:root
	bootstrap_build_exec /tmp/php-5.3.6 configure.out make ./configure
	bootstrap_build_make /tmp/php-5.3.6 make.out
	bootstrap_build_make /tmp/php-5.3.6 make-install.out install

Save either set of commands to a file named `install.sh` in a directory
called `php-cli` and you now have a "module" to build the PHP CLI SAPI.
Repeat this process to create a module for each server component or software package
you want to manage and bootstrap-bash will take care of running specific
modules based on the selected server "role".

Requirements
---

* [BASH 3.0 or later](http://www.gnu.org/software/bash/) or compatible shell


Installation
---
Download the archive and extract into a folder. Then, to install the package:

	make install

This installs scripts to `/usr/sbin` and man pages to `/usr/share/man`.
You can also stage the installation with:

	make DESTDIR=/stage/path install

You can undo the install with:

	make uninstall


Usage
---

	bootstrap-bash [OPTION]... -c CONFIGFILE ROLE

Run the command with `--help` argument or see bootstrap-bash(8) for available OPTIONS.


Getting Started
---
Getting started is easy.

1. Create a configuration file
2. Create a directory containing one or more modules
3. Create a directory containing one or more roles


Configuration File
---
The configuration file is a shell script that at minimum defines the following two variables:

	BOOTSTRAP_DIR_MODULES="/path/to/modules directory"
	BOOTSTRAP_DIR_ROLES="/path/to/roles directory"

These default variables may be overridden if necessary:

	BOOTSTRAP_DIR_LIB="/usr/share/bootstrap-bash/lib"
	BOOTSTRAP_DIR_CACHE="/var/bootstrap-bash"
	BOOTSTRAP_DIR_CACHE_RPM="$BOOTSTRAP_DIR_CACHE/rpms"
	BOOTSTRAP_DIR_TMP="/tmp/bootstrap-bash-$$.tmp"

The script can also define (and export) any other global variables that the module
installation scripts need to reference.


Modules
---
Each available module must be a subdirectory below a root modules directory.
Each module directory contains one or more files that control the installation,
configuration and package management for the module.

	modules/
	|- <module name>/

### Files
Each module directory contains one or more shell scripts or text files that
define the module operations.

#### version.txt

Text file that provides metadata to describe the module.

	Description: Module description
	Version: 1.0

#### preinstall.sh

Shell script to execute before modules are installed. This script is executed
before package management and other module scripts.
This script is not executed if bootstrap-bash is run in update configurations mode.

#### install.sh

Shell script with commands and functions to install the software related
to the module. This script is executed after `preinstall.sh` and package management
and before `config.sh`. This script is not executed if bootstrap-bash is run in
update configurations mode.

#### config.sh

Shell script to execute to configure module. This script is executed
after `install.sh`. Only this script is executed if bootstrap-bash is run in
update configurations mode.

#### yum-packages.txt

Text file listing Yum packages to install or remove. See Package Management for details.

#### rpm-packages.txt

Text file listing RPM packages to install or remove. See Package Management for details.

### Variables

The following global variables are available to `preinstall.sh`, `install.sh`
and `config.sh` scripts:

* `BOOTSTRAP_MODULE_NAME` - The name of the module being installed
* `BOOTSTRAP_ROLE` - The active role being installed
* `BOOTSTRAP_BASEARCH` - The server hardware (base) architecture (e.g. i386, x86_64)
* `BOOTSTRAP_PROCARCH` - The server processor architecture (e.g. i686, x86_64)
* `BOOTSTRAP_INSTALL_FORCED` - The install is being run for the first time or with the `-f` option
* `BOOTSTRAP_DIR_LIB` - The directory with bootstrap library scripts
* `BOOTSTRAP_DIR_ROLE` - The active roles directory
* `BOOTSTRAP_DIR_MODULE` - The directory containing the active module install script
* `BOOTSTRAP_DIR_MODULE_CACHE` - The directory where module installation state is saved
* `BOOTSTRAP_DIR_TMP` - The directory where temporary files can be saved

### Exit Status

Module scripts must exit with a zero status if successful. A non-zero exit status
causes bootstrap-bash to stop execution. The default exit status of a script is that of
the last command executed, so an explicit call to `exit` is typically not required.
You can use the convenience function `bootstrap_die` to exit with an error message.


Roles
---
Each available role must be a subdirectory below a root roles directory.

	roles/
	|- <role>/
	   |-- <subrole>/

Each role directory can have subdirectories that define a "subrole".
For example, you could define the top-level roles "development" and "public".
Beneath each of those roles you could have a subrole for each specific type of
server, such as "web" and "database".

### Files
Each role directory contains a text file that defines the role modules.

#### modules.txt

Text file listing names of modules that will be applied for the role.
Blank lines and comment lines beginning with "#" will be ignored.
Optional modules can be specified by wrapping with parenthesis.
The `modules.txt` file in each directory above a subrole will be applied when
a role is selected. This allows for common modules to be defined in common role directories.


Package Management
---
Modules can contain text files defining package management operations.

Packages are removed after they are added so dependencies on removed packages
can be fulfilled by new packages (as when replacing syslogd with rsyslogd).
Packages without dependency management (ie. individual RPMs) are installed last
so dependencies can be managed through a package manager.

### YUM

`yum-packages.txt` lists all packages that should be installed or removed with `yum`.

#### Packages

Each line should contain the name of a package to install or remove.
Blank lines and comment lines beginning with "#" will be ignored.
Packages that should be removed must be prefixed with "-" (e.g. "-package").
All other lines in the file will be considered a package name and installed.
Packages that need to be installed from a specific repository can be prefixed
with the repo name as: repo/package.

#### Repositories

Yum repositories that packages are installed from can be added to `/etc/yum.repos.d`
automatically using the "yum-repo-add:" tag. This tag can either install an RPM to update
the repolist or copy a local file to yum.repos.d.

Add RPMs via a URL or local file with this syntax:

	yum-repo-add:<URL or path>.rpm

Add local files with this syntax:
(If the path is relative, it will be prepended with the module directory.)

	yum-repo-add:<path>.repo

If you need a custom repository that does not follow these conventions,
you can modify yum.repos.d with `preinstall.sh`.

`yum-repo-add` statements and repo configuration text files can reference
the hardware architecture (e.g. i386, x86_64) with the tag {BOOTSTRAP_BASEARCH}
or the processor architecture (e.g. i686, x86_64) with {BOOTSTRAP_PROCARCH}.

### RPM

`rpm-packages.txt` lists all packages that should be installed with `rpm` directly.

Each line should contain the URL (HTTP or FTP) or local file path to a .rpm file.
(If the path is relative, it will be prepended with the module directory.)
Blank lines and comment lines beginning with "#" will be ignored.

Non-local RPMs will be downloaded with `wget` and saved to the directory
specified by BOOTSTRAP_DIR_CACHE_RPM.

### Other package management tools

The framework is not dependent on Yum and can easily be expanded to support
other package management tools.


Order of operations
---
1. Modules are enumerated based on role, unless specified on the command line
2. Module preinstall scripts are executed (preinstall.sh)
3. Yum repositories are updated (yum-packages.txt)
4. Yum packages are installed (yum-packages.txt)
5. Yum packages are removed (yum-packages.txt)
6. RPM packages are installed (rpm-packages.txt)
7. Module install scripts are executed (install.sh)
8. Module configuration scripts are executed (config.sh)
