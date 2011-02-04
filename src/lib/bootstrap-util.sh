# Bootstrap library module - Common bootstrap functions
# This will be included by bootstrap-bash.sh only
# DO NOT INCLUDE THIS IN MODULE SCRIPTS
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

# bootstrap_die(message)
# Prints optional message and exits with an error code
bootstrap_die()
{
	local message="$1"

	[ -n "$message" ] && echo $message
	echo "Aborting bootstrap install!"
	exit 1
}

# bootstrap_echo_header(message)
# Prints section header message, with color if BOOTSTRAP_TTYHEADER is set
bootstrap_echo_header()
{
	local message="$1"

	if [ -z "$BOOTSTRAP_TTYHEADER" ]; then
		echo "$message"
	else
		echo -e "${BOOTSTRAP_TTYHEADER}${message}${BOOTSTRAP_TTYRESET}"
	fi
}
