#!/bin/bash
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

BOOTSTRAP_VER="1.0.10"
BOOTSTRAP_ROLE=""
BOOTSTRAP_DIR_ROOT="$CMDDIR"
BOOTSTRAP_DIR_LIB="/usr/share/bootstrap-bash/lib"
BOOTSTRAP_DIR_CACHE="/var/bootstrap-bash"
BOOTSTRAP_DIR_CACHE_RPM="$BOOTSTRAP_DIR_CACHE/rpms"
BOOTSTRAP_DIR_ROLE=""
BOOTSTRAP_DIR_TMP="/tmp/bootstrap-bash-$$.tmp"
BOOTSTRAP_BASEARCH=$(/bin/uname --hardware-platform)
BOOTSTRAP_PROCARCH=$(/bin/uname --processor)
BOOTSTRAP_MODULE_NAMES=( )
BOOTSTRAP_INSTALL_FORCED=0
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

# You can find a list of color values at
# https://wiki.archlinux.org/index.php/Color_Bash_Prompt
BOOTSTRAP_TTYHEADER="\e[1;37m"
BOOTSTRAP_TTYRESET="\e[0m"

# Runtime configuration file must define these
BOOTSTRAP_DIR_MODULES=""
BOOTSTRAP_DIR_ROLES=""

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
	echo "   or: bootstrap-bash [OPTION]... -c CONFIGFILE ROLE"
	echo ""
	echo "Run bootstrap process for ROLE with CONFIGFILE configuration."
	echo ""
	echo "Options:"
	echo "  -c FILE        Configuration file to use"
	echo "  -d             Debug: show commands that would be executed (pseudo dry run)"
	echo "  -f             Force run module install scripts, even if they have run before"
	echo "  -h, --help     Show this help and exit"
	echo "  -l             List modules that would be installed; specify more than once to include details"
	echo "  -m MODULE      Install only this module (specify -m for each module); can be a glob pattern"
	echo "  -O             Include optional modules"
	echo "  -p             Package management only, skip install scripts"
	echo "  -s             Debug: output module install script commands, check syntax (implies -d)"
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
			INSTALLMODULES=( "${INSTALLMODULES[@]}" "$module" )
		elif [ $BOOTSTRAP_GETOPT_FORCE -eq 1 ]; then
			REINSTALLMODULES=( "${REINSTALLMODULES[@]}" "$module" )
		else
			REFRESHMODULES=( "${REFRESHMODULES[@]}" "$module" )
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

	# Enumerate all modules selected for the role
	bootstrap_modules_build_list

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
					selectedmodules=( "${selectedmodules[@]}" $rolemodule )
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
					BOOTSTRAP_MODULE_NAMES=( "${BOOTSTRAP_MODULE_NAMES[@]}" $module )
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

# If run from the src directory, use local lib directory
[ -f "${BOOTSTRAP_DIR_ROOT}/lib/modules.sh" ] && BOOTSTRAP_DIR_LIB="${BOOTSTRAP_DIR_ROOT}/lib"

[ -d "$BOOTSTRAP_DIR_LIB" ] || { echo "$BOOTSTRAP_DIR_LIB: directory does not exist"; exit 1; }

source ${BOOTSTRAP_DIR_LIB}/bootstrap-util.sh
source ${BOOTSTRAP_DIR_LIB}/modules.sh
source ${BOOTSTRAP_DIR_LIB}/file.sh
source ${BOOTSTRAP_DIR_LIB}/yum.sh
source ${BOOTSTRAP_DIR_LIB}/rpm.sh

# Parse command line options
while getopts "c:dfhlm:OpsVuxy" opt
do
	case $opt in
	c  ) BOOTSTRAP_GETOPT_CONFIG=$OPTARG;;
	d  ) BOOTSTRAP_GETOPT_DRYRUN=1;;
	f  ) BOOTSTRAP_GETOPT_FORCE=1;;
	h  ) usage;;
	l  ) let BOOTSTRAP_GETOPT_PRINTMODULES++;;
	m  ) BOOTSTRAP_GETOPT_MODULE_NAMES[${#BOOTSTRAP_GETOPT_MODULE_NAMES[@]}]=$OPTARG;;
	O  ) BOOTSTRAP_GETOPT_INCLUDEOPTIONALMODULES=1;;
	p  ) BOOTSTRAP_GETOPT_PACKAGESONLY=1; BOOTSTRAP_GETOPT_FORCE=0;;
	s  ) BOOTSTRAP_GETOPT_DRYRUN=1; BOOTSTRAP_GETOPT_PRINTSCRIPTS=1;;
	u  ) BOOTSTRAP_GETOPT_CONFIGONLY=1; BOOTSTRAP_GETOPT_FORCE=0;;
	x  ) BOOTSTRAP_GETOPT_BASH_DEBUG=1;;
	y  ) BOOTSTRAP_GETOPT_PROMPT=0;;
	V  ) version;;
	\? ) echo "Try '$CMDNAME --help' for more information."; exit 1;;
	esac
done

# Final command line option is the role
shift $(($OPTIND - 1))
BOOTSTRAP_ROLE="$1"

[[ $(id -u) -eq 0 ]] || { echo "$CMDNAME: You must be root user to run this script."; exit 1; }

# Configuration file option is required
if [ -z "${BOOTSTRAP_GETOPT_CONFIG}" ]; then
	echo "$CMDNAME: missing option -- a configuration file must be specified"
	echo "Try '$CMDNAME --help' for more information."
	exit 1
fi

# Role option is required
if [ -z "${BOOTSTRAP_ROLE}" ]; then
	echo "$CMDNAME: missing option -- a role must be specified"
	echo "Try '$CMDNAME --help' for more information."
	exit 1
fi

# Convert config to full path
[ -n "$BOOTSTRAP_GETOPT_CONFIG" ] && BOOTSTRAP_GETOPT_CONFIG=$(readlink -f "$BOOTSTRAP_GETOPT_CONFIG")

# Verify configuration file exists
[ -f "${BOOTSTRAP_GETOPT_CONFIG}" ] || bootstrap_die "${BOOTSTRAP_GETOPT_CONFIG}: Configuration file not found"
[ -r "${BOOTSTRAP_GETOPT_CONFIG}" ] || bootstrap_die "${BOOTSTRAP_GETOPT_CONFIG}: Configuration file not readable"

# Import configuration file
source $BOOTSTRAP_GETOPT_CONFIG

# Validate required configuration variables
for confvar in "BOOTSTRAP_DIR_MODULES" "BOOTSTRAP_DIR_ROLES";
do
	eval confdir=\$$confvar
	[ -n "$confdir" ] || bootstrap_die "The configuration variable ${confvar} must be defined"
done

# Convert configuration paths to full path
BOOTSTRAP_DIR_MODULES=$(readlink -f "$BOOTSTRAP_DIR_MODULES")
BOOTSTRAP_DIR_ROLES=$(readlink -f "$BOOTSTRAP_DIR_ROLES")

BOOTSTRAP_DIR_ROLE="${BOOTSTRAP_DIR_ROLES}/${BOOTSTRAP_ROLE}"

# Confirm paths exist
[ -d "$BOOTSTRAP_DIR_MODULES" ] || bootstrap_die "The directory specified by BOOTSTRAP_DIR_MODULES does not exist ($BOOTSTRAP_DIR_MODULES)"
[ -d "$BOOTSTRAP_DIR_ROLES" ] || bootstrap_die "The directory specified by BOOTSTRAP_DIR_ROLES does not exist ($BOOTSTRAP_DIR_ROLES)"
[ -d "$BOOTSTRAP_DIR_ROLE" ] || bootstrap_die "${BOOTSTRAP_ROLE}: Not a valid role"

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

echo "Executing bootstrap process for $BOOTSTRAP_ROLE role..."
echo "Platform is $BOOTSTRAP_BASEARCH ($BOOTSTRAP_PROCARCH)"

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

	bootstrap_yum_repos_add "${BOOTSTRAP_MODULE_NAMES[@]}"
	bootstrap_yum_packages_install "${BOOTSTRAP_MODULE_NAMES[@]}"
	bootstrap_yum_packages_remove "${BOOTSTRAP_MODULE_NAMES[@]}"

	bootstrap_rpm_packages_install "${BOOTSTRAP_MODULE_NAMES[@]}"

	[ $BOOTSTRAP_GETOPT_PACKAGESONLY -ne 1 ] && bootstrap_modules_install "${BOOTSTRAP_MODULE_NAMES[@]}"
else
	bootstrap_modules_config "${BOOTSTRAP_MODULE_NAMES[@]}"
fi

echo ""
echo "Bootstrap complete!"
