# Bootstrap library module - Common module functions
# This should be included by all module scripts
# DO NOT INCLUDE THIS IN BOOTSTRAP CORE SCRIPTS
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash
#
##! @file
##! @brief General module convenience functions
##! @note It is recommended (but not required) that all module scripts include
##!   this at the beginning of the script.
##! @note This script sets the shell option `nullglob` so glob patterns which
##!   match no files expand to a null string.

##########################################################################
# Functions

##! @fn bootstrap_die(string message)
##! @details The bootstrap process will stop execution after this function exits
##! @brief Prints error message and exits with error status 1
##! @param message (optional) Error message
function bootstrap_die()
{
	local message="$1"

	[ -n "$message" ] && echo " ! $message"
	echo " ! Aborting module install"
	exit 1
}

##! @fn bootstrap_list_active_modules()
##! @brief Outputs list of modules being installed or updated.
##! @note Modules are listed in the order they will be run.
function bootstrap_list_active_modules()
{
	[ -f "$BOOTSTRAP_DIR_CACHE/activemodulelist" ] && cat "$BOOTSTRAP_DIR_CACHE/activemodulelist"
}

##! @fn bootstrap_is_module_installed(string name)
##! @brief Check if any actions have been taken for a module.
##! @param name Module name
##! @return Returns success if any actions have been taken.
function bootstrap_is_module_installed()
{
	local module="$1"
	local filecount=0
	local checkmodulecachedir="${BOOTSTRAP_DIR_CACHE}/module-${module}"

	[ -d "$checkmodulecachedir" ] && filecount=$(find "${checkmodulecachedir}" -type f -name "action-*" | wc -l)

	[ $filecount -gt 0 ] && return 0
	return 1
}

##! @fn bootstrap_echo_header(string message)
##! @brief Prints section header message, with color if enabled
##! @param message Header message
function bootstrap_echo_header()
{
	local message="$1"

	if [ -z "$BOOTSTRAP_TTYHEADER" ]; then
		echo "$message"
	else
		echo -e "${BOOTSTRAP_TTYHEADER}${message}${BOOTSTRAP_TTYRESET}"
	fi
}

##########################################################################

# Expand glob patterns which match no files to a null string
shopt -s nullglob
