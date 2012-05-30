#!/bin/sh
#
# Shell script function declarations do not have arguments, so we filter
# the script through `awk` and declare function arguments using the preceeding
# @fn document command.

awk '
BEGIN {
fnargs = ""
}

# for each line
{

if (match($0, /##!(.+)/, lineparts))
{
	# Capture function arguments
	if (match(lineparts[1], /@fn [^(]+(.+)/, funcparts))
	{
		fnargs = funcparts[1]
	}

	# Transform doc comments into doxygen format
	print "//!" lineparts[1]
}
else if (fnargs != "" && match($0, /(function[^(]+)/, lineparts))
{
	# Replace function arguments with those given by the preceding @fn
	print lineparts[1] fnargs
	fnargs = ""
}
else
{
	print $0
}

}' $1
