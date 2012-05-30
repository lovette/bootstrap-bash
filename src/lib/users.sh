# Bootstrap library module - Users
# This will be included by bootstrap-bash.sh and necessary modules
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash
#
##! @file
##! @brief Convenience functions to manage users and groups

##! @fn bootstrap_user_exists(string name)
##! @brief Check if user name exists.
##! @param name User name
##! @return Zero if user exists, non-zero otherwise
function bootstrap_user_exists()
{
	/usr/bin/id "$1" &>/dev/null
}

##! @fn bootstrap_user_group_exists(string name)
##! @brief Check if group name exists.
##! @param name Group name
##! @return Zero if group exists, non-zero otherwise
function bootstrap_user_group_exists()
{
	/usr/bin/id -g "$1" &>/dev/null
}

##! @fn bootstrap_user_group_add(int uid, string name)
##! @brief Add a user group.
##! @param uid Numerical group identifier
##! @param name Group name
##! @return Zero if group is added or already exists, calls `bootstrap_die` otherwise
function bootstrap_user_group_add()
{
	local ADDGID=$1
	local GNAME=$2

	if ! bootstrap_user_group_exists $GNAME; then
		/usr/sbin/groupadd -g "$ADDGID" "$GNAME"
		[ $? -ne 0 ] && boostrap_die
	fi
}

##! @fn bootstrap_user_add_system(int uid, string name, string comment, string home)
##! @brief Add a user account for a daemon which has no login rights.
##! @note Adds a user group with same uid and name if necessary.
##! @param uid Numerical user identifier
##! @param name User name
##! @param comment Short description of daemon
##! @param home User login directory, will not be created if it is missing.
##! @return Zero if user is added or already exists, calls `bootstrap_die` otherwise
function bootstrap_user_add_system()
{
	local ADDUID="$1"
	local UNAME="$2"
	local UCOMMENT="$3"
	local UHOME="$4"

	if ! bootstrap_user_exists $UNAME; then
		bootstrap_user_group_add $ADDUID $UNAME
		/usr/sbin/useradd -M -r -n -u $ADDUID -g $UNAME -c "$UCOMMENT" -d "$UHOME" -s /sbin/nologin $UNAME
		[ $? -ne 0 ] && boostrap_die
		echo " * created user ${UNAME} (no login)"
	fi
}

##! @fn bootstrap_user_add_login(int uid, string name, string comment, string password)
##! @brief Add a user account for a person who has login rights.
##! @note Adds a user group with same uid and name if necessary.
##! @attention Requires Perl be installed so password can be encrypted.
##! @param uid Numerical user identifier
##! @param name User name
##! @param comment User's full name
##! @param password Plain text password
##! @return Zero if user is added or already exists, calls `bootstrap_die` otherwise
function bootstrap_user_add_login()
{
	local ADDUID="$1"
	local UNAME="$2"
	local UCOMMENT="$3"
	local UPASSPLAIN="$4"
	local UPASSCRYPT=$(perl -e 'print crypt($ARGV[0], "password")' $UPASSPLAIN)

	if ! bootstrap_user_exists $UNAME; then
		bootstrap_user_group_add $ADDUID $UNAME
		/usr/sbin/useradd -u $ADDUID -g $UNAME -c "$UCOMMENT" -m -n -s /bin/bash -G users -p $UPASSCRYPT $UNAME
		[ $? -ne 0 ] && boostrap_die
		# Force password change on next login
		/usr/bin/chage -d 0 $UNAME
		echo " * created user ${UNAME} (login)"
	fi
}
