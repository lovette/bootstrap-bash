# Bootstrap library module - Files
# This will be included by bootstrap-bash.sh and necessary modules
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

# bootstrap_file_chmod(path, perms)
# Set permissions of path to perms
# No-op if perms is 0
bootstrap_file_chmod()
{
	local filepath=$1
	local filemod=$2

	if [ $filemod -ne 0 ]; then
		/bin/chmod "$filemod" "$filepath"
		[ $? -ne 0 ] && bootstrap_die
	fi
}

# bootstrap_file_chown(path, owner)
# Change ownership of path to owner
# No-op if owner is empty string
bootstrap_file_chown()
{
	local filepath=$1
	local fileowner=$2

	if [ -n "$fileowner" ]; then
		/bin/chown "$fileowner" "$filepath"
		[ $? -ne 0 ] && bootstrap_die
	fi
}

# bootstrap_mkdir(path, perms)
# bootstrap_mkdir(path, owner, perms)
# Create directory with permissions set to perms
# No-op if directory exists
bootstrap_mkdir()
{
	local dirpath=$1
	local dirmod=
	local dirowner=

	if [ $# -ge 3 ]; then
		dirowner=$2
		dirmod=$3
	else
		dirmod=$2
	fi

	if [ ! -d "$dirpath" ]; then
		/bin/mkdir -p $dirpath
		[ $? -ne 0 ] && bootstrap_die
		bootstrap_dir_chmod $dirpath $dirmod $dirmod
		bootstrap_dir_chown "$dirpath" "$dirowner"
		echo " * mkdir ${dirpath}/"
	fi
}

# bootstrap_wget(url, path[, args])
# Download url and save as path
# Local save directory will be created if it does not exist
# No-op if path exists
bootstrap_file_wget()
{
	local geturl=$1
	local localfile=$2
	local localdir=$(dirname "$localfile")
	local localbase=$(basename "$localfile")
	local localtmp="$BOOTSTRAP_DIR_TMP/wget-$localbase"
	local wgetout="${localtmp}.stdout"
	local wgetargs=

	[ $# -ge 3 ] && wgetargs="$3"
	wgetargs="$wgetargs -O $localtmp"

	if [ ! -f "$localfile" ]; then
		bootstrap_mkdir "$localdir" 755
		echo " * downloading $geturl"
		echo " *          as $localfile"
		/usr/bin/wget $wgetargs "$geturl" > "$wgetout" 2>&1
		[ $? -ne 0 ] && sed "s/^/ ! wget:  /" "$wgetout" && bootstrap_die
		/bin/mv "$localtmp" "$localfile"
	fi
}

# bootstrap_untar(path, targetdir, owner)
# Untars path into targetdir and sets ownership to owner
# The first component of the paths in the tarfile will be stripped
# No-op if targetdir already exists
bootstrap_file_untar()
{
	local tarfile=$1
	local targetdir=$2
	local fileowner=$3

	if [ ! -d "$targetdir" ]; then
		bootstrap_mkdir "$targetdir" 755
		echo " * extracting `basename $tarfile` to $targetdir/"
		/bin/tar xfz "$tarfile" --strip-components 1 -C "$targetdir"
		[ $? -ne 0 ] && bootstrap_die
		bootstrap_dir_chown "$targetdir" "$fileowner"
	fi
}

# bootstrap_file_move(srcpath, destpath, owner, perms, overwrite)
# Moves srcpath to destpath
# Sets ownership to owner and permissions to perms
# No-op if srcpath does not exist
# No-op if destpath exists unless overwrite is non-zero
bootstrap_file_move()
{
	local srcpath=$1
	local destpath=$2
	local fileowner=$3
	local filemod=$4
	local overwrite=$5
	local srcdir=$(dirname "$srcpath")
	local destdir=$(dirname "$destpath")

	if [ -f "$srcpath" ]; then
		if [ $overwrite -ne 0 ] || [ ! -f $destpath ]; then
			/bin/mv -f $srcpath $destpath
			[ $? -ne 0 ] && bootstrap_die

			bootstrap_file_chown "$destpath" "$fileowner"
			bootstrap_file_chmod "$destpath" $filemod

			[ -n "$BOOTSTRAP_ECHO_STRIPPATH" ] && srcpath="${srcpath/#$BOOTSTRAP_ECHO_STRIPPATH/...}"
			[ -n "$BOOTSTRAP_DIR_MODULE" ] && srcpath="${srcpath/#$BOOTSTRAP_DIR_MODULE/[module] }"
			[ -n "$BOOTSTRAP_DIR_ROLE" ] && srcpath="${srcpath/#$BOOTSTRAP_DIR_ROLE/[role] }"

			if [ "$srcdir" = "$destdir" ]; then
				echo " * renamed ${srcpath} to "$(basename $destpath)
			else
				echo " * moved ${srcpath} to ${destpath}"
			fi
		fi
	fi
}

# bootstrap_file_copy(srcpath, destpath, owner, perms, overwrite)
# Copies srcpath as destpath
# Sets ownership to owner and permissions to perms
# Overwrite: 0=never, 1=always, 2=if src is newer
# No-op if destpath exists unless overwrite is non-zero
bootstrap_file_copy()
{
	local srcpath=$1
	local destpath=$2
	local fileowner=$3
	local filemod=$4
	local overwrite=$5
	local docopy=0
	local skipreason=""

	[ -f "$srcpath" ] || bootstrap_die "cannot copy file: $srcpath does not exist"

	case "$overwrite" in
		"0")
			[ ! -f "$destpath" ] && docopy=1
			skipreason="exists" ;;
		"1")
			docopy=1 ;;
		"2")
			[ $srcpath -nt $destpath ] && docopy=1
			[ $docopy -eq 0 ] && [ $(stat -c%s "$srcpath") -ne $(stat -c%s "$srcpath") ] && docopy=1
			skipreason="up to date" ;;
		 * )
			bootstrap_die "bootstrap_file_copy: bad arg"
	esac

	if [ $docopy -eq 1 ]; then
		/bin/cp --remove-destination --preserve=timestamps "$srcpath" "$destpath"
		[ $? -ne 0 ] && bootstrap_die

		bootstrap_file_chown "$destpath" "$fileowner"
		bootstrap_file_chmod "$destpath" $filemod

		[ -n "$BOOTSTRAP_ECHO_STRIPPATH" ] && srcpath="${srcpath/#$BOOTSTRAP_ECHO_STRIPPATH/...}"
		[ -n "$BOOTSTRAP_DIR_MODULE" ] && srcpath="${srcpath/#$BOOTSTRAP_DIR_MODULE/[module] }"
		[ -n "$BOOTSTRAP_DIR_ROLE" ] && srcpath="${srcpath/#$BOOTSTRAP_DIR_ROLE/[role] }"

		echo " * copied ${srcpath} to $destpath"
	else
		echo " * $destpath not copied ($skipreason)"
	fi
}

# bootstrap_file_copy_glob(srcdir, destdir, glob, owner, perms, overwrite, removesuffix)
# Copies srcdir/glob as destdir/file
# See bootstrap_file_copy for description of owner, perms, overwrite
bootstrap_file_copy_glob()
{
	local srcdir=$1
	local destdir=$2
	local glob=$3
	local owner=$4
	local perms=$5
	local overwrite=$6
	local removesuffix=$7
	local path=
	local name=

	# Remove trailing slashes
	srcdir=${srcdir%%/}
	destdir=${destdir%%/}

	[ -d "$srcdir" ] || bootstrap_die "cannot copy files: $srcdir: No such directory"
	[ -d "$destdir" ] || bootstrap_die "cannot copy files: $destdir: No such directory"
	[ -r "$srcdir" ] || bootstrap_die "cannot copy files: $srcdir: Read permission denied"
	[ -w "$destdir" ] || bootstrap_die "cannot copy files: $destdir: Write permission denied"

	for path in $srcdir/$glob
	do
		name=$(basename "$path" "$removesuffix")
		bootstrap_file_copy "$path" "${destdir}/${name}" "$owner" $perms $overwrite
	done
}

# bootstrap_file_link(path, target, perms)
# Create path as a soft link to target with perms permissions
# Will fail if path directory does not exist
bootstrap_file_link()
{
	local linkpath=$1
	local target=$2
	local linkmod=$3
	local linkdir=$(dirname $linkpath)
	local linkname=$(basename $linkpath)

	[ -e "$target" ] || bootstrap_die "cannot link to target: $target does not exist"

	(cd "$linkdir" && /bin/ln -sf "$target" "$linkname")
	[ $? -ne 0 ] && bootstrap_die
	bootstrap_file_chmod $linkpath $linkmod
	[ -n "$BOOTSTRAP_ECHO_STRIPPATH" ] && linkpath="${linkpath/#$BOOTSTRAP_ECHO_STRIPPATH/...}"
	[ -n "$BOOTSTRAP_DIR_MODULE" ] && linkpath="${linkpath/#$BOOTSTRAP_DIR_MODULE/[module] }"
	[ -n "$BOOTSTRAP_DIR_ROLE" ] && linkpath="${linkpath/#$BOOTSTRAP_DIR_ROLE/[role] }"
	echo " * linked ${linkpath} to $target"
}

# bootstrap_file_create(path, owner, perms)
# Create empty file path
# Sets ownership to owner and permissions to perms
# No-op if path exists
bootstrap_file_create()
{
	local filepath=$1
	local fileowner=$2
	local filemod=$3

	if [ ! -f "$filepath" ]; then
		/bin/touch "$filepath"
		[ $? -ne 0 ] && bootstrap_die
		bootstrap_file_chown "$filepath" "$fileowner"
		bootstrap_file_chmod "$filepath" $filemod
		echo " * touch'd $filepath"
	fi
}

# bootstrap_file_remove(path)
# Remove file path
# No-op if path does not exist
bootstrap_file_remove()
{
	local filepath=$1

	if [ -f "$filepath" ]; then
		/bin/rm -f "$filepath"
		[ $? -ne 0 ] && bootstrap_die
		echo " * removed $filepath"
	fi
}

# bootstrap_file_get_contents_list(path)
# Returns file contents in $get_file_contents_return global variable
# Comments are excluded
# No-op if path is empty string or does not exist
bootstrap_file_get_contents_list()
{
	get_file_contents_return=""

	if [ -n "$1" ]; then
		if [ -f "$1" ]; then
			get_file_contents_return=$(grep -v "^#" "$1" | tr -s '[:space:]' ' ')
		fi
	fi
}

# bootstrap_dir_chmod(path, dirperms, fileperms)
# Set permissions of directory and subdirectories to dirperms and files to fileperms
# No-op if perms is 0
bootstrap_dir_chmod()
{
	local dirpath=$1
	local dirmod=$2
	local filemod=$3

	if [ $dirmod -ne 0 ]; then
		find "$dirpath" -type d -print0 | xargs -r -0 /bin/chmod $dirmod
		[ $? -ne 0 ] && bootstrap_die
	fi

	if [ $filemod -ne 0 ]; then
		find "$dirpath" -type f -print0 | xargs -r -0 /bin/chmod $filemod
		[ $? -ne 0 ] && bootstrap_die
	fi
}

# bootstrap_dir_chown(path, owner)
# Change ownership of directory and contents to owner
# No-op if owner is empty string
bootstrap_dir_chown()
{
	local dirpath=$1
	local dirowner=$2

	if [ -n "$dirowner" ]; then
		/bin/chown -R "$dirowner" "$dirpath"
		[ $? -ne 0 ] && bootstrap_die
	fi
}

# bootstrap_dir_copy(srcpath, destpath, owner, dirperms, fileperms, overwrite)
# Copies srcpath directory as destpath
# Sets ownership to owner, directory permissions to dirperms and file permissions to fileperms
# Overwrite: 0=never, 1=copy, 2=rmdir before copy
# No-op if destpath exists unless overwrite is non-zero
bootstrap_dir_copy()
{
	local srcpath=$1
	local destpath=$2
	local fileowner=$3
	local dirperms=$4
	local fileperms=$5
	local overwrite=$6
	local docopy=0
	local skipreason=""

	[ -d "$srcpath" ] || bootstrap_die "cannot copy: $srcpath not a directory"

	if [ -e "$destpath" ] && [ ! -d "$destpath" ]; then
		bootstrap_die "cannot copy $srcpath: $destpath exists but is not a directory"
	fi

	# This function can really screw you, but we can at least prevent "rm -rf /"
	[ "$destpath" == "/" ] && bootstrap_die "bootstrap_dir_copy: destpath cannot be /"

	case "$overwrite" in
		"0")
			[ ! -d "$destpath" ] && docopy=1
			skipreason="exists" ;;
		"1")
			docopy=1 ;;
		"2")
			[ -d "$destpath" ] && /bin/rm -rf "$destpath"
			docopy=1 ;;
		 * )
			bootstrap_die "bootstrap_dir_copy: bad arg"
	esac

	if [ $docopy -eq 1 ]; then
		/bin/cp -r --preserve=timestamps "$srcpath" "$destpath"
		[ $? -ne 0 ] && bootstrap_die
		
		bootstrap_dir_chown "$destpath" "$fileowner"
		bootstrap_dir_chmod "$destpath" $dirperms $fileperms

		[ -n "$BOOTSTRAP_ECHO_STRIPPATH" ] && srcpath="${srcpath/#$BOOTSTRAP_ECHO_STRIPPATH/...}"
		[ -n "$BOOTSTRAP_DIR_MODULE" ] && srcpath="${srcpath/#$BOOTSTRAP_DIR_MODULE/[module] }"
		[ -n "$BOOTSTRAP_DIR_ROLE" ] && srcpath="${srcpath/#$BOOTSTRAP_DIR_ROLE/[role] }"

		echo " * copied ${srcpath}/ to $destpath/"
	else
		echo " * $destpath/ not copied ($skipreason)"
	fi
}
