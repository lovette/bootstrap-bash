# Bootstrap library module - Build functions
# This will be included by necessary modules
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

# bootstrap_build_exec(directory, outfile, errprefix, command)
# Executes a command in a specified directory, saving output to outfile
# If command fails, output will be displayed and boostrap_die is called
bootstrap_build_exec()
{
	local directory="$1"
	local outfile="$2"
	local errprefix="$3"
	local cmd="$4"

	[ -d "$directory" ] || boostrap_die "$directory: directory does not exist"
	[ -w "$directory" ] || boostrap_die "$directory: directory is not writable"

	(cd $directory && $cmd &> $outfile)
	if [ $? -ne 0 ]; then
		cat $outfile | sed 's/^/ * $errprefix:  /'
		bootstrap_die
	fi
}

# bootstrap_build_make(directory, outfile, makeargs)
# Executes "make" in a specified directory, saving output to outfile
# If make fails, output will be displayed and boostrap_die is called
bootstrap_build_make()
{
	local directory="$1"
	local outfile="$2"
	local makeargs="$3"

	bootstrap_build_exec $directory $outfile "make" "make $makeargs"
}

# bootstrap_build_configure(directory, outfile, cmdargs)
# Executes "configure" in a specified directory, saving output to outfile
# If configure fails, output will be displayed and boostrap_die is called
bootstrap_build_configure()
{
    local directory="$1"
    local outfile="$2"
    local cmdargs="$3"

	bootstrap_build_exec $directory $outfile "make" "./configure $cmdargs"
}
