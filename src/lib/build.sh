# Bootstrap library module - Build functions
# This will be included by necessary modules
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash
#
##! @file
##! @brief Convenience functions to manage build processes

##! @fn bootstrap_build_exec(string directory, string outfile, string errprefix, string command)
##! @brief Executes a command in a specified directory, saving output to a file
##! @param directory Working directory in which to execute command; directory must exist and be writable
##! @param outfile File path to capture command stdout and stderr
##! @param errprefix String prepended to output on command failure
##! @param command Command line to execute
##! @return Zero if successful, displays command output and calls `bootstrap_die` otherwise
function bootstrap_build_exec()
{
	local directory="$1"
	local outfile="$2"
	local errprefix="$3"
	local cmd="$4"

	echo " * executing '$cmd' in $directory"

	[ -d "$directory" ] || boostrap_die "$directory: directory does not exist"
	[ -w "$directory" ] || boostrap_die "$directory: directory is not writable"

	(cd $directory && $cmd &> $outfile)
	if [ $? -ne 0 ]; then
		cat $outfile | sed "s/^/ * $errprefix:  /"
		bootstrap_die
	fi
}

##! @fn bootstrap_build_make(string directory, string outfile, string makeargs)
##! @brief Executes `make` in a specified directory, saving output to a file
##! @param directory Working directory in which to execute command; directory must exist and be writable
##! @param outfile File path to capture command stdout and stderr
##! @param makeargs (optional) Command line arguments
##! @return Zero if successful, displays `make` output and calls `bootstrap_die` otherwise
function bootstrap_build_make()
{
	local directory="$1"
	local outfile="$2"
	local cmd="make"

	[ $# -ge 3 ] && cmd="$cmd $3"

	bootstrap_build_exec $directory $outfile "make" "$cmd"
}

##! @fn bootstrap_build_configure(string directory, string outfile, string cmdargs)
##! @brief Executes `configure` in a specified directory, saving output to a file
##! @param directory Working directory in which to execute command; directory must exist and be writable
##! @param outfile File path to capture command stdout and stderr
##! @param cmdargs (optional) Command line arguments
##! @return Zero if successful, displays `configure` output and calls `bootstrap_die` otherwise
function bootstrap_build_configure()
{
    local directory="$1"
    local outfile="$2"
	local cmd="./configure"

	[ $# -ge 3 ] && cmd="$cmd $3"

	bootstrap_build_exec $directory $outfile "configure" "$cmd"
}
