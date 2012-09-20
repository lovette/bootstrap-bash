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

##########################################################################

# Expand glob patterns which match no files to a null string
shopt -s nullglob
