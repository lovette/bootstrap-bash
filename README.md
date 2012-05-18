# bootstrap-bash

A simple server bootstrap and configuration framework based on BASH scripts.


Requirements
---

* [BASH 3.0 or later](http://www.gnu.org/software/bash/)


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

### Configuration File

The configuration file specified by `-c` must be a BASH script that at minimum
defines the following two constants:

	BOOTSTRAP_DIR_MODULES="/path/to/modules directory"
	BOOTSTRAP_DIR_ROLES="/path/to/roles directory"

The script can also define (and export) any other constants that the module
installation scripts need to reference.

### Directory Structure

Each module available must be a subdirectory below a root modules directory.

	modules/
	|- <module name>/
	   |-- version.txt      - Module information (optional)
	   |-- preinstall.sh    - BASH script to execute before modules are installed (optional)
	   |-- install.sh       - BASH script to execute to install module (optional)
	   |-- config.sh        - BASH script to execute to configure module (optional)
	   |-- yum-packages.txt - Yum packages to install or remove (optional)
	   |-- rpm-packages.txt - RPM packages to install or remove (optional)

Each role available must be a subdirectory below a root roles directory.

	roles/
	|- modules.txt          - Modules to install for ALL roles (optional)
	|- <role>/
	   |-- modules.txt      - Modules to install for role <role>

Role directories can have subdirectories. For example, you could define "server" roles below
"development" and "public" roles. The modules.txt file in each parent directory
above the leaf role will be applied.

### version.txt

Each module can have a text file that describes the module.

	Description: Module description
	Version: 1.0


Package Management
---

### YUM

#### yum-packages.txt

This file lists all packages that should be installed or removed with `yum`.

Each line should contain the name of a package to install or remove.
Blank lines and comment lines beginning with "#" will be ignored.
Packages that should be removed must be prefixed with "-" (e.g. "-package").
All other lines in the file will be considered a package name and installed.
Packages that need to be installed from a specific repository can be prefixed
with the repo name as: repo/package.

Yum repositories that packages are installed from can be added to yum.repos.d
automatically using the "yum-repo-add:" tag. This will install an RPM to update
the repolist or copy a local file to yum.repos.d.

Add RPMs via a URL or local file with this syntax:

	yum-repo-add:<URL or path>.rpm

Add local files with this syntax:
(If the path is relative, it will be prepended with the module directory.)

	yum-repo-add:<path>.repo

If you need a custom repository that does not follow these conventions, 
you can modify yum.repos.d in a preinstall script. You can reference
the hardware architecture (e.g. i386, x86_64) with the tag {BOOTSTRAP_BASEARCH}
or the processor architecture (e.g. i686, x86_64) with {BOOTSTRAP_PROCARCH}.

### RPM

#### rpm-packages.txt

This file lists all packages that should be installed with `rpm` directly.

Each line should contain the URL (HTTP or FTP) or local file path to a .rpm file.
(If the path is relative, it will be prepended with the module directory.)

Non-local RPMs will be downloaded with `wget` and saved to the directory
specified by BOOTSTRAP_DIR_CACHE_RPM. The default directory is BOOTSTRAP_DIR_CACHE/rpms.

Blank lines and comment lines beginning with "#" will be ignored.

### Other package management tools

The framework is not dependent on Yum and can easily be expanded to support
other package management tools.


Module Installation
---

### preinstall.sh, install.sh, config.sh

The module install scripts are BASH scripts that execute commands and functions
to install the software related to the module.

The following global variables are available to the script:

* `BOOTSTRAP_MODULE_NAME` - The name of the module being installed
* `BOOTSTRAP_ROLE` - The active role being installed
* `BOOTSTRAP_BASEARCH` - The server hardware (base) architecture (e.g. i386, x86_64)
* `BOOTSTRAP_PROCARCH` - The server processor architecture (e.g. i686, x86_64)
* `BOOTSTRAP_DIR_LIB` - The directory with bootstrap library scripts
* `BOOTSTRAP_DIR_ROLE` - The active roles directory
* `BOOTSTRAP_DIR_MODULE` - The directory containing the active module install script
* `BOOTSTRAP_DIR_MODULE_CACHE` - The directory where module installation state is saved
* `BOOTSTRAP_DIR_TMP` - The directory where temporary files can be saved


How it works
---
1. Modules are enumerated based on role, unless specified on the command line
2. Module preinstall scripts are executed (preinstall.sh)
3. Yum repositories are updated (yum-packages.txt)
4. Yum packages are installed (yum-packages.txt)
5. Yum packages are removed (yum-packages.txt)
6. RPM packages are installed (rpm-packages.txt)
7. Module install scripts are executed (install.sh then config.sh)

Packages are removed after they are added so dependencies on removed packages
can be fulfilled by new packages (as when replacing syslogd with rsyslogd).
Packages without dependency management (ie. individual RPMs) are installed last
so dependencies can be managed through a package manager.
