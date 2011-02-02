# Bootstrap library module - Users
# This will be included by bootstrap-bash.sh and necessary modules
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

# bootstrap_user_exists(name)
# Returns nonzero if user name exists
bootstrap_user_exists()
{
	/usr/bin/id "$1" &>/dev/null
}

# bootstrap_user_group_exists(name)
# Returns nonzero if the group name exists
bootstrap_user_group_exists()
{
	/usr/bin/id -g "$1" &>/dev/null
}

# bootstrap_user_group_add(uid, name)
# Add a user group
# Exits if the group cannot be added
bootstrap_user_group_add()
{
	local ADDGID=$1
	local GNAME=$2

	if ! bootstrap_user_group_exists $GNAME; then
		/usr/sbin/groupadd -g "$ADDGID" "$GNAME"
		[ $? -ne 0 ] && boostrap_die
	fi
}

# bootstrap_user_add_system(uid, name, comment, home)
# Add an account for a daemon which has no login rights
# Exits if the user cannot be added
bootstrap_user_add_system()
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

# bootstrap_user_add_login(uid, name, comment, password)
# Add an account for a person who has login rights
# Exits if the user cannot be added
# Requires Perl be installed so password can be encrypted
bootstrap_user_add_login()
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
