# Bootstrap library module - Common module functions
# This should be included by all module scripts
# DO NOT INCLUDE THIS IN BOOTSTRAP CORE SCRIPTS
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

# bootstrap_die(message)
# Prints optional message and exits with an error code
function bootstrap_die()
{
	local message="$1"

	[ -n "$message" ] && echo " ! $message"
	echo " ! Aborting module install"
	exit 1
}

# Expand glob patterns which match no files to a null string
shopt -s nullglob
