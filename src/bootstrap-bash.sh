#!/usr/bin/env bash
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

CMDPATH=$(readlink -f "$0")
CMDNAME=$(basename "$CMDPATH")
CMDDIR=$(dirname "$CMDPATH")
CMDARGS=$@

BOOTSTRAP_VER="1.1.5-dev"
BOOTSTRAP_ROLE=""
BOOTSTRAP_DIR_ROOT="$CMDDIR"
BOOTSTRAP_DIR_LIB=$(readlink -f "${BOOTSTRAP_DIR_ROOT}/../share/bootstrap-bash/lib")
BOOTSTRAP_DIR_CACHE="/var/bootstrap-bash"
BOOTSTRAP_DIR_MODULES=""
BOOTSTRAP_DIR_ROLES=""
BOOTSTRAP_DIR_CONFIG=""
BOOTSTRAP_DIR_ROLE=""
BOOTSTRAP_DIR_TMP="/tmp/bootstrap-bash-$$.tmp"
BOOTSTRAP_BASEARCH=$(/bin/uname --hardware-platform)
BOOTSTRAP_PROCARCH=$(/bin/uname --processor)
BOOTSTRAP_MODULE_NAMES=( )
BOOTSTRAP_SELECTALLMODULES=0
BOOTSTRAP_INSTALL_FORCED=0
BOOTSTRAP_HOOK_INSTALLPACKAGES=( )
BOOTSTRAP_HOOK_BEFOREINSTALL=( )
BOOTSTRAP_HOOK_AFTERINSTALL=( )
BOOTSTRAP_GETOPT_CONFIG=""
BOOTSTRAP_GETOPT_DRYRUN=0
BOOTSTRAP_GETOPT_FORCE=0
BOOTSTRAP_GETOPT_PRINTMODULES=0
BOOTSTRAP_GETOPT_PRINTSCRIPTS=0
BOOTSTRAP_GETOPT_BASH_DEBUG=0
BOOTSTRAP_GETOPT_MODULE_NAMES=( )
BOOTSTRAP_GETOPT_PROMPT=1
BOOTSTRAP_GETOPT_PACKAGESONLY=0
BOOTSTRAP_GETOPT_CONFIGONLY=0
BOOTSTRAP_GETOPT_INCLUDEOPTIONALMODULES=0
BOOTSTRAP_GETOPT_TAGS=( )
BOOTSTRAP_PKG_YUM=1
BOOTSTRAP_PKG_RPM=1

# You can find a list of color values at
# https://wiki.archlinux.org/index.php/Color_Bash_Prompt
BOOTSTRAP_TTYHEADER="\e[1;37m"
BOOTSTRAP_TTYRESET="\e[0m"

##########################################################################
# Functions

# Print version and exit
function version()
{
	echo "bootstrap-bash $BOOTSTRAP_VER"
	echo
	echo "Copyright (C) 2011 Lance Lovette"
	echo "Licensed under the BSD License."
	echo "See the distribution file LICENSE.txt for the full license text."
	echo
	echo "Written by Lance Lovette <https://github.com/lovette>"

	exit 0
}

# Print usage and exit
function usage()
{
	echo "A simple server bootstrap and configuration framework based on BASH scripts."
	echo ""
	echo "Usage: bootstrap-bash [-h | --help | -V | --version]"
	echo "   or: bootstrap-bash [OPTION]... -c CONFIGPATH [ROLE]"
	echo ""
	echo "Run bootstrap process with CONFIGPATH configuration for ROLE (optional)."
	echo ""
	echo "Options:"
	echo "  -c PATH        Path to configuration file or directory"
	echo "  -d             Debug: show commands that would be executed (pseudo dry run)"
	echo "  -f             Force run module install scripts, even if they have run before"
	echo "  -h, --help     Show this help and exit"
	echo "  -l             List modules that would be installed; specify more than once to include details"
	echo "  -m MODULE      Install only this module (specify -m for each module); can be a glob pattern"
	echo "  -O             Include optional modules"
	echo "  -p             Package management only, skip install scripts"
	echo "  -s             Debug: output module install script commands, check syntax (implies -d)"
	echo "  -t TAG         Include modules with given tag (specify -t for each tag)"
	echo "  -V, --version  Print version and exit"
	echo "  -u             Update configurations only, skip package management and install scripts"
	echo "  -x             Debug: execute module install scripts with 'bash -x'"
	echo "  -y             Answer yes for all questions"
	echo
	echo "Report bugs to <https://github.com/lovette/bootstrap-bash/issues>"

	exit 0
}

# Confirm with the user the modules that will be installed or updated
function confirm()
{
	local TERMWIDTH=$(tput cols)
	local COLSPEC="%-20.20s %-15.15s %s\n"
	local INSTALLMODULES=( )
	local REINSTALLMODULES=( )
	local REFRESHMODULES=( )

	# Build lists of module states
	for module in "${BOOTSTRAP_MODULE_NAMES[@]}";
	do
		if ! bootstrap_modules_is_installed "$module"; then
			INSTALLMODULES+=("$module")
		elif [ $BOOTSTRAP_GETOPT_FORCE -eq 1 ]; then
			REINSTALLMODULES+=("$module")
		else
			REFRESHMODULES+=("$module")
		fi
	done

	echo
	eval printf '%.0s=' {1.."$TERMWIDTH"}
	printf "$COLSPEC" "Module" "Version" "Description"
	eval printf '%.0s=' {1.."$TERMWIDTH"}

	if [ "${#INSTALLMODULES[@]}" -gt 0 ]; then
		echo "Installing:"
		displaysorted=( $(printf '%s\n' "${INSTALLMODULES[@]}" | sort) )
		for module in "${displaysorted[@]}";
		do
			bootstrap_modules_get_version_info "$module"
			printf "$COLSPEC" " $module" "$module_version_ver" "$module_version_desc"
		done
		echo
	fi

	if [ "${#REINSTALLMODULES[@]}" -gt 0 ]; then
		echo "REinstalling:"
		displaysorted=( $(printf '%s\n' "${REINSTALLMODULES[@]}" | sort) )
		for module in "${displaysorted[@]}";
		do
			bootstrap_modules_get_version_info "$module"
			printf "$COLSPEC" " $module" "$module_version_ver" "$module_version_desc"
		done
		echo
	fi

	if [ "${#REFRESHMODULES[@]}" -gt 0 ]; then
		echo "Refreshing:"
		displaysorted=( $(printf '%s\n' "${REFRESHMODULES[@]}" | sort) )
		for module in "${displaysorted[@]}";
		do
			bootstrap_modules_get_version_info "$module"
			printf "$COLSPEC" " $module" "$module_version_ver" "$module_version_desc"
		done
		echo
	fi

	read -p "Is this ok [y/N]? " yn

	case "$yn" in
	[Yy]* ) ;;
	[Nn]* ) exit 1;;
	    * ) exit 1;;
	esac

	echo
}

# Set BOOTSTRAP_MODULE_NAMES to list of modules to install/config
function init_module_names()
{
	local selectedmodules=( )
	local validmodule=0
	local modulespec=""
	local rolemodule=""
	local module=""
	local activemodules=( )

	BOOTSTRAP_MODULE_NAMES=( )
	BOOTSTRAP_ROLE_ALL_MODULES=( )
	BOOTSTRAP_ROLE_DEFAULT_MODULES=( )
	BOOTSTRAP_ROLE_OPTIONAL_MODULES=( )

	if [ $BOOTSTRAP_SELECTALLMODULES -eq 1 ]; then
		# Select all defined modules
		BOOTSTRAP_ROLE_ALL_MODULES=( $(find "$BOOTSTRAP_DIR_MODULES" -maxdepth 1 -mindepth 1 -type d -printf "%f\n") )
		BOOTSTRAP_ROLE_DEFAULT_MODULES=( ${BOOTSTRAP_ROLE_ALL_MODULES[@]} )
	else
		# Enumerate all modules selected for the role
		bootstrap_modules_build_list
	fi

	# Activate all modules or only default modules?
	if [ $BOOTSTRAP_GETOPT_INCLUDEOPTIONALMODULES -eq 1 ]; then
		activemodules=( ${BOOTSTRAP_ROLE_ALL_MODULES[@]} )
	else
		activemodules=( ${BOOTSTRAP_ROLE_DEFAULT_MODULES[@]} )
	fi

	if [ "${#BOOTSTRAP_GETOPT_MODULE_NAMES[@]}" -gt 0 ]; then
		# Confirm specified modules are selected for this role while also expanding glob patterns
		for modulespec in "${BOOTSTRAP_GETOPT_MODULE_NAMES[@]}";
		do
			validmodule=0

			for rolemodule in "${activemodules[@]}";
			do
				if [[ $rolemodule == $modulespec ]]; then
					validmodule=1
					selectedmodules+=($rolemodule)
				fi
			done

			[ $validmodule -gt 0 ] || bootstrap_die "$modulespec: not found in list of role modules"
		done

		# Install modules in consistent order
		for rolemodule in "${activemodules[@]}";
		do
			for module in "${selectedmodules[@]}";
			do
				if [ "$rolemodule" == "$module" ]; then
					BOOTSTRAP_MODULE_NAMES+=($module)
				fi
			done
		done
	else
		# Install all modules selected for this role
		BOOTSTRAP_MODULE_NAMES=( ${activemodules[@]} )
	fi

	# Remove duplicate modules
	BOOTSTRAP_MODULE_NAMES=( $( printf "%s\n" "${BOOTSTRAP_MODULE_NAMES[@]}" | awk '!x[$0]++' ) )
}

function onexit()
{
	[ -d "$BOOTSTRAP_DIR_TMP" ] && /bin/rm -rf "$BOOTSTRAP_DIR_TMP"
}

##########################################################################
# Main

# Check for usage longopts
case "$1" in
	"--help"    ) usage;;
	"--version" ) version;;
esac

# Expand glob patterns which match no files to a null string
shopt -s nullglob

# Search for library scripts (helpful for non-default installs)
# Default installs to /usr/share/bootstrap-bash/lib
for p in "$BOOTSTRAP_DIR_LIB" "${BOOTSTRAP_DIR_ROOT}/lib" "${BOOTSTRAP_DIR_ROOT}/../lib" "${BOOTSTRAP_DIR_ROOT}/../share/lib";
do
	if [[ -d "${p}" && -f "${p}/modules.sh" ]]; then
		BOOTSTRAP_DIR_LIB=$(readlink -f "${p}")
	fi
done

[ -d "$BOOTSTRAP_DIR_LIB" ] || { echo "Cannot find 'lib' directory containing modules.sh"; exit 1; }

source ${BOOTSTRAP_DIR_LIB}/bootstrap-util.sh
source ${BOOTSTRAP_DIR_LIB}/modules.sh
source ${BOOTSTRAP_DIR_LIB}/file.sh
source ${BOOTSTRAP_DIR_LIB}/yum.sh
source ${BOOTSTRAP_DIR_LIB}/rpm.sh

# Parse command line options
while getopts "c:dfhlm:Opst:Vuxy" opt
do
	case $opt in
	c  ) BOOTSTRAP_GETOPT_CONFIG=$OPTARG;;
	d  ) BOOTSTRAP_GETOPT_DRYRUN=1;;
	f  ) BOOTSTRAP_GETOPT_FORCE=1;;
	h  ) usage;;
	l  ) let BOOTSTRAP_GETOPT_PRINTMODULES++;;
	m  ) BOOTSTRAP_GETOPT_MODULE_NAMES+=($OPTARG);;
	O  ) BOOTSTRAP_GETOPT_INCLUDEOPTIONALMODULES=1;;
	p  ) BOOTSTRAP_GETOPT_PACKAGESONLY=1; BOOTSTRAP_GETOPT_FORCE=0;;
	s  ) BOOTSTRAP_GETOPT_DRYRUN=1; BOOTSTRAP_GETOPT_PRINTSCRIPTS=1;;
	t  ) BOOTSTRAP_GETOPT_TAGS+=($OPTARG);;
	u  ) BOOTSTRAP_GETOPT_CONFIGONLY=1; BOOTSTRAP_GETOPT_FORCE=0;;
	x  ) BOOTSTRAP_GETOPT_BASH_DEBUG=1;;
	y  ) BOOTSTRAP_GETOPT_PROMPT=0;;
	V  ) version;;
	\? ) echo "Try '$CMDNAME --help' for more information."; exit 1;;
	esac
done

# Final command line option is the role
shift $(($OPTIND - 1))
[ $# -ge 1 ] && BOOTSTRAP_ROLE="$1"

# BOOTSTRAP_INCLUDE_TAGS can be set as an environment variable.
# Tags can be separated by spaces or commas so do not quote the array expansion.
# Pass tags to modules as comma-delimited list.
[ -n "$BOOTSTRAP_INCLUDE_TAGS" ] && BOOTSTRAP_GETOPT_TAGS+=( $BOOTSTRAP_INCLUDE_TAGS )
BOOTSTRAP_INCLUDE_TAGS=$(IFS=, ; echo "${BOOTSTRAP_GETOPT_TAGS[*]}")

[[ $(id -u) -eq 0 ]] || { echo "$CMDNAME: You must be root user to run this script."; exit 1; }

# Path to a configuration file or directory option is required
if [ -z "${BOOTSTRAP_GETOPT_CONFIG}" ]; then
	echo "$CMDNAME: missing option -- a configuration path must be specified"
	echo "Try '$CMDNAME --help' for more information."
	exit 1
fi

# Convert config to full path
BOOTSTRAP_GETOPT_CONFIG=$(readlink -f "$BOOTSTRAP_GETOPT_CONFIG")

if [ -d "${BOOTSTRAP_GETOPT_CONFIG}" ]; then
	BOOTSTRAP_DIR_CONFIG="$BOOTSTRAP_GETOPT_CONFIG"
	BOOTSTRAP_GETOPT_CONFIG=""

	# Search for configuration file
	for p in "${BOOTSTRAP_DIR_CONFIG}/bootstrap.conf" "${BOOTSTRAP_DIR_CONFIG}/etc/bootstrap.conf";
	do
		[ -f "${p}" ] && BOOTSTRAP_GETOPT_CONFIG=$(readlink -f "${p}")
	done
elif [ -f "${BOOTSTRAP_GETOPT_CONFIG}" ]; then
	BOOTSTRAP_DIR_CONFIG=$(dirname "$BOOTSTRAP_GETOPT_CONFIG" )
else
	bootstrap_die "${BOOTSTRAP_GETOPT_CONFIG}: Configuration path is not a file or directory"
fi

# Import configuration file
if [ -n "${BOOTSTRAP_GETOPT_CONFIG}" ]; then
	[ -r "${BOOTSTRAP_GETOPT_CONFIG}" ] || bootstrap_die "${BOOTSTRAP_GETOPT_CONFIG}: Configuration file not readable"
	source $BOOTSTRAP_GETOPT_CONFIG
fi

if [ -z "$BOOTSTRAP_DIR_MODULES" ]; then
	# Search for modules directory
	for p in "${BOOTSTRAP_DIR_CONFIG}/modules" "${BOOTSTRAP_DIR_CONFIG}/../modules";
	do
		[ -d "${p}" ] && BOOTSTRAP_DIR_MODULES=$(readlink -f "${p}")
	done

	[ -n "$BOOTSTRAP_DIR_MODULES" ] || bootstrap_die "The 'modules' directory cannot be determined; you should set config var BOOTSTRAP_DIR_MODULES"
else
	BOOTSTRAP_DIR_MODULES=$(readlink -f "$BOOTSTRAP_DIR_MODULES")
	[ -d "$BOOTSTRAP_DIR_MODULES" ] || bootstrap_die "The directory specified by BOOTSTRAP_DIR_MODULES does not exist ($BOOTSTRAP_DIR_MODULES)"
fi

if [ -z "$BOOTSTRAP_DIR_ROLES" ]; then
	# Search for roles directory
	for p in "${BOOTSTRAP_DIR_CONFIG}/roles" "${BOOTSTRAP_DIR_CONFIG}/../roles";
	do
		[ -d "${p}" ] && BOOTSTRAP_DIR_ROLES=$(readlink -f "${p}")
	done
else
	BOOTSTRAP_DIR_ROLES=$(readlink -f "$BOOTSTRAP_DIR_ROLES")
	[ -d "$BOOTSTRAP_DIR_ROLES" ] || bootstrap_die "The directory specified by BOOTSTRAP_DIR_ROLES does not exist ($BOOTSTRAP_DIR_ROLES)"
fi

if [ -n "$BOOTSTRAP_ROLE" ]; then
	BOOTSTRAP_DIR_ROLE="${BOOTSTRAP_DIR_ROLES}/${BOOTSTRAP_ROLE}"
	[ -n "$BOOTSTRAP_DIR_ROLES" ] || bootstrap_die "ROLE argument is specified but no 'roles' are defined"
	[ -d "$BOOTSTRAP_DIR_ROLE" ] || bootstrap_die "${BOOTSTRAP_ROLE}: Not a valid role"
	[ -f "${BOOTSTRAP_DIR_MODULES}/modules.txt" ] && bootstrap_die "${BOOTSTRAP_DIR_MODULES} should not contain modules.txt when roles are defined"
elif [ -n "$BOOTSTRAP_DIR_ROLES" ]; then
	bootstrap_die "${BOOTSTRAP_DIR_ROLES}: ROLE argument must be specified when 'roles' are defined"
else
	BOOTSTRAP_DIR_ROLES="$BOOTSTRAP_DIR_MODULES"
	BOOTSTRAP_DIR_ROLE="$BOOTSTRAP_DIR_ROLES"
	[ -f "${BOOTSTRAP_DIR_MODULES}/modules.txt" ] || BOOTSTRAP_SELECTALLMODULES=1
fi

# Create cache directory
if [ ! -d "$BOOTSTRAP_DIR_CACHE" ]; then
	mkdir -p $BOOTSTRAP_DIR_CACHE
	(
	echo "This is the cache and state directory for bootstrap-bash."
	echo "You can reference this directory in module scripts as \$BOOTSTRAP_DIR_CACHE."
	echo "Modifying the contents of this directory will cause modules to be reinstalled."
	) >> "$BOOTSTRAP_DIR_CACHE/README"
fi

[ -d "$BOOTSTRAP_DIR_CACHE" ] || bootstrap_die "$BOOTSTRAP_DIR_CACHE: cache directory does not exist"

# Set RPM cache based on BOOTSTRAP_DIR_CACHE if not set explicitly
[ -n "$BOOTSTRAP_DIR_CACHE_RPM" ] || BOOTSTRAP_DIR_CACHE_RPM="$BOOTSTRAP_DIR_CACHE/rpms"

BOOTSTRAP_MODULES_MODULELISTPATH="$BOOTSTRAP_DIR_CACHE/modulelist"

# Disable yum and rpm package management if system does not support
if (("$BOOTSTRAP_PKG_YUM")); then
	command -v yum &> /dev/null || BOOTSTRAP_PKG_YUM=0
fi
if (("$BOOTSTRAP_PKG_RPM")); then
	command -v rpm &> /dev/null || BOOTSTRAP_PKG_RPM=0
fi

init_module_names

[ "${#BOOTSTRAP_MODULE_NAMES[@]}" -gt 0 ] || bootstrap_die "No modules selected"

bootstrap_modules_scan "${BOOTSTRAP_MODULE_NAMES[@]}"

if [ $BOOTSTRAP_GETOPT_PRINTMODULES -gt 0 ]; then
	for module in "${BOOTSTRAP_MODULE_NAMES[@]}";
	do
		if [ $BOOTSTRAP_GETOPT_PRINTMODULES -gt 1  ]; then
			echo $(bootstrap_modules_getorder "$module") "$module"
		else
			echo "$module"
		fi
	done

	exit 0
fi

echo "Executing bootstrap process for ${BOOTSTRAP_ROLE:-default} role..."
echo "Platform is $BOOTSTRAP_BASEARCH ($BOOTSTRAP_PROCARCH)"
[ -n "$BOOTSTRAP_INCLUDE_TAGS" ] && echo "With tags: $BOOTSTRAP_INCLUDE_TAGS"

if [ $BOOTSTRAP_GETOPT_CONFIGONLY -eq 1 ] && [ $BOOTSTRAP_GETOPT_PACKAGESONLY -eq 1 ]; then
	bootstrap_die "Command line options -p and -u cannot be combined"
elif [ $BOOTSTRAP_GETOPT_CONFIGONLY -eq 1 ]; then
	echo "Configuration management only, skipping package management and install scripts"
elif [ $BOOTSTRAP_GETOPT_PACKAGESONLY -eq 1 ]; then
	echo "Package management only, skipping install scripts"
fi

[ $BOOTSTRAP_GETOPT_DRYRUN -eq 1 ] && echo "Debug mode: showing commands that would be executed (pseudo dry run)"

# Confirm with the user if necessary
[ $BOOTSTRAP_GETOPT_PROMPT -eq 1 ] && confirm

if [ "${#BOOTSTRAP_GETOPT_MODULE_NAMES[@]}" -eq 0 ]; then
	echo "Installing ${#BOOTSTRAP_MODULE_NAMES[@]} modules..."
else
	echo "Only installing modules:" "${BOOTSTRAP_MODULE_NAMES[@]}..."
fi

# Reset module states if install is forced
if [ $BOOTSTRAP_GETOPT_FORCE -eq 1 ]; then
	if [ "${#BOOTSTRAP_GETOPT_MODULE_NAMES[@]}" -gt 0 ]; then
		for module in "${BOOTSTRAP_MODULE_NAMES[@]}";
		do
			bootstrap_modules_reset_states "$module"
		done
	else
		bootstrap_modules_reset_states_all
	fi
fi

#
# Install process...
#

mkdir -p "$BOOTSTRAP_DIR_TMP" || bootstrap_die

# Remove temp dir on exit
trap "onexit" EXIT

# Cache list of active modules
echo "${BOOTSTRAP_MODULE_NAMES[@]}" > "$BOOTSTRAP_DIR_CACHE/activemodulelist"

if [ $BOOTSTRAP_GETOPT_CONFIGONLY -ne 1 ]; then
	[ $BOOTSTRAP_GETOPT_PACKAGESONLY -ne 1 ] && bootstrap_modules_preinstall "${BOOTSTRAP_MODULE_NAMES[@]}"

	if (("$BOOTSTRAP_PKG_YUM")); then
		bootstrap_yum_repos_add "${BOOTSTRAP_MODULE_NAMES[@]}"
		bootstrap_yum_packages_install "${BOOTSTRAP_MODULE_NAMES[@]}"
		bootstrap_yum_packages_remove "${BOOTSTRAP_MODULE_NAMES[@]}"
	fi

	if (("$BOOTSTRAP_PKG_RPM")); then
		bootstrap_rpm_packages_install "${BOOTSTRAP_MODULE_NAMES[@]}"
	fi

	bootstrap_modules_exec_hook "install packages" "installpackages-hook.sh" "${BOOTSTRAP_HOOK_INSTALLPACKAGES[@]}"

	[ $BOOTSTRAP_GETOPT_PACKAGESONLY -ne 1 ] && bootstrap_modules_install "${BOOTSTRAP_MODULE_NAMES[@]}"
else
	bootstrap_modules_config "${BOOTSTRAP_MODULE_NAMES[@]}"
fi

echo ""
echo "Bootstrap complete!"
