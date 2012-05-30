# Bootstrap library module - Files
# This will be included by bootstrap-bash.sh and necessary modules
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash
#
##! @file
##! @brief Convenience functions to manage files and directories

##! @fn bootstrap_file_chmod(string path, string|int perms)
##! @brief Set file access permissions
##! @param path File path
##! @param perms Permissions; `man chmod` for allowed formats
##! @note No-op if `perms` is 0
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_chmod()
{
	local filepath=$1
	local filemod=$2

	if [ $filemod -ne 0 ]; then
		/bin/chmod "$filemod" "$filepath"
		[ $? -ne 0 ] && bootstrap_die
	fi
}

##! @fn bootstrap_file_chown(string path, string owner)
##! @brief Change file ownership
##! @param path File path
##! @param owner New owner
##! @note No-op if `owner` is empty string
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_chown()
{
	local filepath=$1
	local fileowner=$2

	if [ -n "$fileowner" ]; then
		/bin/chown "$fileowner" "$filepath"
		[ $? -ne 0 ] && bootstrap_die
	fi
}

##! @fn bootstrap_mkdir(string path, string owner, string|int perms)
##! @brief Create directory with specified permissions and ownership
##! @param path New directory path; all path components will be created
##! @param owner (optional) Directory owner; set to empty string for default
##! @param perms File permissions; `man chmod` for allowed formats; set to 0 for default
##! @note No-op if directory already exists
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_mkdir()
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

##! @fn bootstrap_file_wget(string url, string path, string args)
##! @brief Download URL with `wget` and save to file
##! @param url URL to download
##! @param path File path to save as
##! @param args (optional) Additional `wget` command line arguments
##! @note Save path directory will be created if it does not exist
##! @note Save path will not be modified unless `wget` succeeds
##! @note Temporary file is downloaded to directory `BOOTSTRAP_DIR_TMP`
##! @note File name in URL is ignored
##! @note No-op if `path` exists
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_wget()
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

##! @fn bootstrap_file_untar(string path, string targetdir, string owner)
##! @brief Extract compressed "tarfile" archive into a directory.
##! @param path Archive file path
##! @param targetdir Directory in which to extract archive files
##! @param owner New directory and file ownership; set to empty string for default
##! @note The first path component of the paths in the archive will be stripped
##! @note No-op if `targetdir` already exists
##! @note Target directory will be created with permissions 755
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_untar()
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

##! @fn bootstrap_file_move(string srcpath, string destpath, string owner, string|int perms, int overwrite)
##! @brief Move or rename a file
##! @param srcpath Source file path
##! @param destpath Destination file path
##! @param owner New file ownership; set to empty string to preserve
##! @param perms New file permissions; `man chmod` for allowed formats; set to 0 to preserve
##! @param overwrite Overwrite mode: 0=never, 1=always
##! @note No-op if `srcpath` does not exist
##! @note No-op if `destpath` exists unless `overwrite` is non-zero
##! @note Set `BOOTSTRAP_ECHO_STRIPPATH` to a path to strip from status message
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_move()
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

##! @fn bootstrap_file_copy(string srcpath, string destpath, string owner, string|int perms, int overwrite)
##! @brief Copy a file
##! @param srcpath Source file path
##! @param destpath Destination file path
##! @param owner New file ownership; set to empty string to preserve
##! @param perms New file permissions; `man chmod` for allowed formats; set to 0 to preserve
##! @param overwrite Overwrite mode: 0=never, 1=always, 2=if file size has changed
##! @note No-op if `destpath` exists unless `overwrite` is non-zero
##! @note Timestamps are preserved
##! @note Set `BOOTSTRAP_ECHO_STRIPPATH` to a path to strip from status message
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_copy()
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

##! @fn bootstrap_file_copy_glob(string srcdir, string destdir, string glob, string owner, string|int perms, int overwrite, string removesuffix)
##! @brief Copy contents of one directory to another using `bootstrap_file_copy`.
##! @param srcdir Source directory path
##! @param destdir Destination directory path
##! @param glob File pattern (e.g * or *.txt)
##! @param owner New file ownership; set to empty string to preserve
##! @param perms New file permissions; `man chmod` for allowed formats; set to 0 to preserve
##! @param overwrite Overwrite mode: 0=never, 1=always, 2=if file size has changed
##! @param removesuffix File name suffix to remove in destination path
##! @note `srcdir` must exist and be readable
##! @note `destdir` must exist and be writable
##! @note Set `BOOTSTRAP_ECHO_STRIPPATH` to a path to strip from status message
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_copy_glob()
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

##! @fn bootstrap_file_link(string linkpath, string target, string|int perms)
##! @brief Create a soft link.
##! @param linkpath New link path
##! @param target Existing target path
##! @param perms New link permissions; `man chmod` for allowed formats; set to 0 to preserve
##! @note Directory containing `linkpath` must exist
##! @note `target` path must exist
##! @note Set `BOOTSTRAP_ECHO_STRIPPATH` to a path to strip from status message
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_link()
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

##! @fn bootstrap_file_create(string path, string owner, string|int perms)
##! @brief Create empty file using `touch`.
##! @param path New file path
##! @param owner New file ownership; set to empty string for default
##! @param perms New file permissions; `man chmod` for allowed formats; set to 0 for default
##! @note No-op if `path` exists
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_create()
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

##! @fn bootstrap_file_remove(string path)
##! @brief Remove file
##! @param path File path
##! @note No-op if `path` does not exist
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_file_remove()
{
	local filepath=$1

	if [ -f "$filepath" ]; then
		/bin/rm -f "$filepath"
		[ $? -ne 0 ] && bootstrap_die
		echo " * removed $filepath"
	fi
}

##! @fn bootstrap_file_get_contents_list(string path)
##! @brief Read file contents into a variable.
##! @param path File path
##! @note Returns file contents in global variable `$get_file_contents_return`
##! @note Lines beginning with "#" are considered comments and are excluded
##! @note No-op if `path` is empty string or does not exist
function bootstrap_file_get_contents_list()
{
	get_file_contents_return=""

	if [ -n "$1" ]; then
		if [ -f "$1" ]; then
			get_file_contents_return=$(grep -v "^#" "$1" | tr -s '[:space:]' ' ')
		fi
	fi
}

##! @fn bootstrap_dir_chmod(string path, string dirperms, string fileperms)
##! @brief Recursively set permissions of a directory its contents
##! @param path Directory path
##! @param dirperms New directory permissions; `man chmod` for allowed formats; set to 0 to preserve
##! @param fileperms New file permissions; `man chmod` for allowed formats; set to 0 to preserve
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_dir_chmod()
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

##! @fn bootstrap_dir_chown(string path, string owner)
##! @brief Recursively change ownership of a directory and its contents
##! @param path Directory path
##! @param owner New owner
##! @note No-op if `owner` is empty string
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_dir_chown()
{
	local dirpath=$1
	local dirowner=$2

	if [ -n "$dirowner" ]; then
		/bin/chown -R "$dirowner" "$dirpath"
		[ $? -ne 0 ] && bootstrap_die
	fi
}

##! @fn bootstrap_dir_copy(string srcpath, string destpath, string owner, string dirperms, string fileperms, int overwrite)
##! @brief Copy directory and contents.
##! @param srcpath Source directory path
##! @param destpath Destination directory path
##! @param owner New file ownership; set to empty string to preserve
##! @param dirperms New directory permissions; man chmod for allowed formats; set to 0 to preserve
##! @param fileperms New file permissions; man chmod for allowed formats; set to 0 to preserve
##! @param overwrite Overwrite mode: 0=never, 1=always, 2=rmdir before copy
##! @note No-op if `destpath` exists unless `overwrite` is non-zero
##! @note Timestamps are preserved
##! @note Set `BOOTSTRAP_ECHO_STRIPPATH` to a path to strip from status message
##! @warning Be careful when using `overwrite=2` as `destpath` is recursively removed before copy.
##! @return Zero if successful, calls `bootstrap_die` otherwise
function bootstrap_dir_copy()
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
