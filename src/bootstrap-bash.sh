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

BOOTSTRAP_VER="1.0.0"
BOOTSTRAP_ROLE=""
BOOTSTRAP_DIR_ROOT="$CMDDIR"
BOOTSTRAP_DIR_LIB="/usr/share/bootstrap-bash/lib"
BOOTSTRAP_DIR_CACHE="/var/bootstrap-bash"
BOOTSTRAP_DIR_CACHE_RPM="$BOOTSTRAP_DIR_CACHE/rpms"
BOOTSTRAP_DIR_ROLE=""
BOOTSTRAP_DIR_TMP="/tmp/bootstrap-bash-$$.tmp"
BOOTSTRAP_BASEARCH=$(/bin/uname -i)
BOOTSTRAP_MODULE_NAMES=( )
BOOTSTRAP_GETOPT_CONFIG=""
BOOTSTRAP_GETOPT_DRYRUN=0
BOOTSTRAP_GETOPT_FORCE=0
BOOTSTRAP_GETOPT_PRINTMODULES=0
BOOTSTRAP_GETOPT_PRINTSCRIPTS=0
BOOTSTRAP_GETOPT_BASH_DEBUG=0
BOOTSTRAP_GETOPT_MODULE_NAMES=( )
BOOTSTRAP_GETOPT_PROMPT=1
BOOTSTRAP_GETOPT_PACKAGESONLY=0

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
	echo "  -l             List modules that would be installed"
	echo "  -m MODULE      Install only this module (specify -m for each module)"
	echo "  -p             Package management only, no pre/install scripts are run"
	echo "  -s             Debug: output module install script commands, check syntax (implies -d)"
	echo "  -V, --version  Print version and exit"
	echo "  -x             Debug: execute module install scripts with 'bash -x'"
	echo "  -y             Answer yes for all questions"
	echo
	echo "Report bugs to <https://github.com/lovette/bootstrap-bash/issues>"

	exit 0
}

# Confirm with the user the modules that will be installed or updated
function confirm()
{
	TERMWIDTH=$(tput cols)
	COLSPEC="%-20.20s %-15.15s %s\n"
	INSTALLMODULES=( )
	REINSTALLMODULES=( )
	REFRESHMODULES=( )

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
		for module in "${INSTALLMODULES[@]}";
		do
			bootstrap_modules_get_version_info "$module"
			printf "$COLSPEC" " $module" "$module_version_ver" "$module_version_desc"
		done
		echo
	fi

	if [ "${#REINSTALLMODULES[@]}" -gt 0 ]; then
		echo "REinstalling:"
		for module in "${REINSTALLMODULES[@]}";
		do
			bootstrap_modules_get_version_info "$module"
			printf "$COLSPEC" " $module" "$module_version_ver" "$module_version_desc"
		done
		echo
	fi

	if [ "${#REFRESHMODULES[@]}" -gt 0 ]; then
		echo "Refreshing:"
		for module in "${REFRESHMODULES[@]}";
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
while getopts "c:dfhlm:psVxy" opt
do
	case $opt in
	c  ) BOOTSTRAP_GETOPT_CONFIG=$OPTARG;;
	d  ) BOOTSTRAP_GETOPT_DRYRUN=1;;
	f  ) BOOTSTRAP_GETOPT_FORCE=1;;
	h  ) usage;;
	l  ) BOOTSTRAP_GETOPT_PRINTMODULES=1;;
	m  ) BOOTSTRAP_GETOPT_MODULE_NAMES[${#BOOTSTRAP_GETOPT_MODULE_NAMES[@]}]=$OPTARG;;
	p  ) BOOTSTRAP_GETOPT_PACKAGESONLY=1; BOOTSTRAP_GETOPT_FORCE=0;;
	s  ) BOOTSTRAP_GETOPT_DRYRUN=1; BOOTSTRAP_GETOPT_PRINTSCRIPTS=1;;
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

# Build list of modules based on role if none were explicitly set
if [ "${#BOOTSTRAP_GETOPT_MODULE_NAMES[@]}" -eq 0 ]; then
	bootstrap_modules_build_list
else
	BOOTSTRAP_MODULE_NAMES=( "${BOOTSTRAP_GETOPT_MODULE_NAMES[@]}" )
fi

bootstrap_modules_scan "${BOOTSTRAP_MODULE_NAMES[@]}"

if [ $BOOTSTRAP_GETOPT_PRINTMODULES -eq 1 ]; then
	echo ${BOOTSTRAP_MODULE_NAMES[@]}
	exit 0
fi

# Create cache directory
[ -d "$BOOTSTRAP_DIR_CACHE" ] || mkdir -p $BOOTSTRAP_DIR_CACHE
[ -d "$BOOTSTRAP_DIR_CACHE" ] || bootstrap_die "$BOOTSTRAP_DIR_CACHE: cache directory does not exist"

echo "Executing bootstrap process for $BOOTSTRAP_ROLE role..."

[ $BOOTSTRAP_GETOPT_PACKAGESONLY -eq 1 ] && echo "Package management only, no install scripts will be run"

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

[ $BOOTSTRAP_GETOPT_PACKAGESONLY -ne 1 ] && bootstrap_modules_preinstall "${BOOTSTRAP_MODULE_NAMES[@]}"

bootstrap_rpm_packages_install "${BOOTSTRAP_MODULE_NAMES[@]}"
bootstrap_yum_packages_remove "${BOOTSTRAP_MODULE_NAMES[@]}"
bootstrap_yum_repos_add "${BOOTSTRAP_MODULE_NAMES[@]}"
bootstrap_yum_packages_install "${BOOTSTRAP_MODULE_NAMES[@]}"

[ $BOOTSTRAP_GETOPT_PACKAGESONLY -ne 1 ] && bootstrap_modules_install "${BOOTSTRAP_MODULE_NAMES[@]}"

/bin/rm -rf "$BOOTSTRAP_DIR_TMP" || bootstrap_die

echo ""
echo "Bootstrap complete!"
