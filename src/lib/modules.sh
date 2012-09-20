# Bootstrap library module - Modules
# This will be included by bootstrap-bash.sh only
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

BOOTSTRAP_MODULES_MODULELISTPATH="$BOOTSTRAP_DIR_CACHE/modulelist"

# bootstrap_modules_set_state(module name, action)
# Creates module state file for an action
function bootstrap_modules_set_state()
{
	local module=$1
	local action=$2
	local BOOTSTRAP_DIR_MODULE_CACHE="${BOOTSTRAP_DIR_CACHE}/module-${module}"
	local statefile="${BOOTSTRAP_DIR_MODULE_CACHE}/action-${action}"
	local verfilepath="${BOOTSTRAP_DIR_MODULES}/${module}/version.txt"

	[ ! -d "$BOOTSTRAP_DIR_MODULE_CACHE" ] && mkdir "$BOOTSTRAP_DIR_MODULE_CACHE"

	if [ -f "$verfilepath" ] && [ -r "$verfilepath" ]; then
		grep -i "^Version" "$verfilepath" > "$statefile"
	else
		touch "$statefile"
	fi
}

# bootstrap_modules_check_state(module name, action)
# Returns success if module state file exists for an action
function bootstrap_modules_check_state()
{
	local module=$1
	local action=$2
	local BOOTSTRAP_DIR_MODULE_CACHE="${BOOTSTRAP_DIR_CACHE}/module-${module}"
	local statefile="${BOOTSTRAP_DIR_MODULE_CACHE}/action-${action}"

	[ -f "$statefile" ] && return 0
	return 1
}

# bootstrap_modules_clear_state(module name, action)
# Deletes module state file for an action
function bootstrap_modules_clear_state()
{
	local module=$1
	local action=$2
	local BOOTSTRAP_DIR_MODULE_CACHE="${BOOTSTRAP_DIR_CACHE}/module-${module}"
	local statefile="${BOOTSTRAP_DIR_MODULE_CACHE}/action-${action}"

	[ -d "$BOOTSTRAP_DIR_MODULE_CACHE" ] && /bin/rm -f "$statefile"
}

# bootstrap_modules_reset_states(module name)
# Deletes state files for all actions for a module
function bootstrap_modules_reset_states()
{
	local module=$1
	local BOOTSTRAP_DIR_MODULE_CACHE="${BOOTSTRAP_DIR_CACHE}/module-${module}"

	[ -d "$BOOTSTRAP_DIR_MODULE_CACHE" ] && find "${BOOTSTRAP_DIR_MODULE_CACHE}" -mindepth 1 -maxdepth 1 -print0 | xargs -r -0 /bin/rm -rf
}

# bootstrap_modules_reset_states_all()
# Deletes all state files for all modules
function bootstrap_modules_reset_states_all()
{
	find "${BOOTSTRAP_DIR_CACHE}" -mindepth 1 -maxdepth 1 -print0 | xargs -r -0 /bin/rm -rf
}

# bootstrap_modules_is_installed(module name)
# Returns success if any actions have been taken for a module
function bootstrap_modules_is_installed()
{
	local module=$1
	local BOOTSTRAP_DIR_MODULE_CACHE="${BOOTSTRAP_DIR_CACHE}/module-${module}"
	local filecount=0

	[ -d "$BOOTSTRAP_DIR_MODULE_CACHE" ] && filecount=$(find "${BOOTSTRAP_DIR_MODULE_CACHE}" -type f -name "action-*" | wc -l)

	[ $filecount -gt 0 ] && return 0
	return 1
}

# bootstrap_modules_get_version_info(module name)
# Reads module version.txt information into variables
# - module_version_desc = description
# - module_version_ver  = version
# Value is set to "-" if version information is not available
function bootstrap_modules_get_version_info()
{
	local module=$1
	local verfilepath="${BOOTSTRAP_DIR_MODULES}/${module}/version.txt"
	local REGEX_DESC="^[D|d]escription: *(.+)$"
	local REGEX_VER="^[V|v]ersion: *(.+)$"

	module_version_desc="-"
	module_version_ver="-"

	if [ -f "$verfilepath" ] && [ -r "$verfilepath" ]; then
		while read curline; do
			[[ "$curline" =~ $REGEX_DESC ]] && module_version_desc="${BASH_REMATCH[1]}"
			[[ "$curline" =~ $REGEX_VER ]] && module_version_ver="${BASH_REMATCH[1]}"
		done < "$verfilepath"
	fi
}

# bootstrap_modules_build_list()
# Build list of modules based on the active role
# Return value is these global arrays:
#   BOOTSTRAP_ROLE_ALL_MODULES - all modules
#   BOOTSTRAP_ROLE_DEFAULT_MODULES - default modules
#   BOOTSTRAP_ROLE_OPTIONAL_MODULES - optional modules
function bootstrap_modules_build_list()
{
	local file=""
	local modulefiles=( )
	local pathpart=""
	local pathparts=( )
	local rolepath=""
	local REGEX_OPTIONAL_MODULE="\((.+)\)"
	local filepath=""
	local modules=""

	BOOTSTRAP_ROLE_ALL_MODULES=( )
	BOOTSTRAP_ROLE_DEFAULT_MODULES=( )
	BOOTSTRAP_ROLE_OPTIONAL_MODULES=( )

	filepath="${BOOTSTRAP_DIR_ROLES}/modules.txt"
	[ -f "$filepath" ] && modulefiles[${#modulefiles[@]}]="$filepath"

	# Split the role path into directory parts and reference
	# modules.txt for each directory in the path
	rolepath="$BOOTSTRAP_DIR_ROLES"
	IFS='/' read -ra pathparts <<< "${BOOTSTRAP_DIR_ROLE##$rolepath/}"
	for pathpart in "${pathparts[@]}"; do
		filepath="${rolepath}/${pathpart}/modules.txt"
		[ -f "$filepath" ] && modulefiles[${#modulefiles[@]}]="$filepath"
		rolepath="${rolepath}/${pathpart}"
	done

	# Sort modules by order
	(awk '
		BEGIN {
			order=0;
			filenum=1;
			curfile="";
		}

		{
			# Each file gets a new range base
			if (curfile != FILENAME)
				order = filenum++ * 200;
			curfile=FILENAME;

			# Skip blank lines and comments
			if ($1 == "")
				next;
			if (substr($1, 1, 1) == "#")
				next;

			# If an order is not set explicitly, assign a default
			if ($2 == "")
			{
				printf("%06d\t", order);
				order += 5
			}
			else
			{
				printf("%06d\t", $2);
			}

			print $1;
		}
	' "${modulefiles[@]}" | sort) > "$BOOTSTRAP_MODULES_MODULELISTPATH"

	modules=$(cut -f2 "$BOOTSTRAP_MODULES_MODULELISTPATH")

	# Build list of modules based on role
	for module in $modules; do
		if [[ $module =~ $REGEX_OPTIONAL_MODULE ]]; then
			# Modules in parenthesis are optional
			BOOTSTRAP_ROLE_ALL_MODULES=( ${BOOTSTRAP_ROLE_ALL_MODULES[@]} ${BASH_REMATCH[1]} )
			BOOTSTRAP_ROLE_OPTIONAL_MODULES=( ${BOOTSTRAP_ROLE_OPTIONAL_MODULES[@]} ${BASH_REMATCH[1]} )
		else
			BOOTSTRAP_ROLE_ALL_MODULES=( ${BOOTSTRAP_ROLE_ALL_MODULES[@]} $module )
			BOOTSTRAP_ROLE_DEFAULT_MODULES=( ${BOOTSTRAP_ROLE_DEFAULT_MODULES[@]} $module )
		fi
	done
}

# bootstrap_modules_scan(array of module names)
function bootstrap_modules_scan()
{
	local module=""
	local modules=( "$@" )
	local moduledir=""

	for module in "${modules[@]}";
	do
		moduledir="${BOOTSTRAP_DIR_MODULES}/${module}"
		if [ ! -d $moduledir ]; then
			bootstrap_die "$module: invalid module name (verify $moduledir exists)"
		fi
	done
}

# bootstrap_modules_script_exec(name, install.sh path)
function bootstrap_modules_script_exec()
{
	local BOOTSTRAP_MODULE_NAME=$1
	local script=$2
	local BOOTSTRAP_DIR_MODULE=$(dirname $script)
	local BOOTSTRAP_DIR_MODULE_CACHE="${BOOTSTRAP_DIR_CACHE}/module-${module}"
	local bashargs=""

	[ $BOOTSTRAP_GETOPT_BASH_DEBUG -eq 1 ] && bashargs="-x"

	[ ! -d "$BOOTSTRAP_DIR_MODULE_CACHE" ] && mkdir "$BOOTSTRAP_DIR_MODULE_CACHE"

	# Allow install scripts to reference these variables
	export BOOTSTRAP_MODULE_NAME
	export BOOTSTRAP_ROLE
	export BOOTSTRAP_BASEARCH
	export BOOTSTRAP_PROCARCH
	export BOOTSTRAP_INSTALL_FORCED
	export BOOTSTRAP_DIR_LIB
	export BOOTSTRAP_DIR_ROLE
	export BOOTSTRAP_DIR_MODULE
	export BOOTSTRAP_DIR_MODULE_CACHE
	export BOOTSTRAP_DIR_TMP
	export BOOTSTRAP_DIR_CACHE

	if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
		(cd $BOOTSTRAP_DIR_MODULE && bash ${bashargs} ${script})
		[ $? -ne 0 ] && bootstrap_die
	else
		echo "+ bash ${bashargs} ${script}";
		[ $BOOTSTRAP_GETOPT_PRINTSCRIPTS -eq 1 ] && bash -nv "${script}"
	fi
}

# bootstrap_modules_preinstall(array of module names)
function bootstrap_modules_preinstall()
{
	local module=""
	local modules=( "$@" )
	local moduledir=""
	local installscript=""

	for module in "${modules[@]}";
	do
		moduledir="${BOOTSTRAP_DIR_MODULES}/${module}"
		installscript="${moduledir}/preinstall.sh"

		if [ -f "$installscript" ]; then
			echo ""
			bootstrap_echo_header "Preinstalling ${module} module..."

			if ! bootstrap_modules_check_state "$module" "preinstall-sh"; then
				bootstrap_modules_script_exec "$module" "$installscript"
				bootstrap_modules_set_state "$module" "preinstall-sh"
			else
				echo " * Module previously preinstalled, skipping (use -f to override)"
			fi
		fi
	done
}

# bootstrap_modules_config(array of module names)
function bootstrap_modules_config()
{
	local module=""
	local modules=( "$@" )
	local moduledir=""
	local configscript=""

	for module in "${modules[@]}";
	do
		moduledir="${BOOTSTRAP_DIR_MODULES}/${module}"
		configscript="${moduledir}/config.sh"

		if [ -f "$configscript" ]; then
			echo ""
			bootstrap_echo_header "Configuring ${module} module..."
			bootstrap_modules_script_exec "$module" "$configscript"
			bootstrap_modules_set_state "$module" "config-sh"
		fi
	done
}

# bootstrap_modules_install(array of module names)
function bootstrap_modules_install()
{
	local module=""
	local modules=( "$@" )
	local moduledir=""
	local installscript=""
	local configscript=""

	for module in "${modules[@]}";
	do
		moduledir="${BOOTSTRAP_DIR_MODULES}/${module}"
		installscript="${moduledir}/install.sh"
		configscript="${moduledir}/config.sh"

		if [ -f "$installscript" ]; then
			echo ""
			bootstrap_echo_header "Installing ${module} module..."

			if ! bootstrap_modules_check_state "$module" "install-sh"; then
				# We don't know if:
				#  1) This is the first run of install.sh
				#  2) The module state directory was deleted
				#  3) Installation is being forced with -f option
				# In these cases, tell install script it can/should install from a clean slate:
				BOOTSTRAP_INSTALL_FORCED=1

				bootstrap_modules_script_exec "$module" "$installscript"
				bootstrap_modules_set_state "$module" "install-sh"

				BOOTSTRAP_INSTALL_FORCED=0
			else
				echo " ! Module previously installed (use -f to force install)"
			fi
		fi

		if [ -f "$configscript" ]; then
			echo ""
			bootstrap_echo_header "Configuring ${module} module..."

			if ! bootstrap_modules_check_state "$module" "config-sh"; then
				bootstrap_modules_script_exec "$module" "$configscript"
				bootstrap_modules_set_state "$module" "config-sh"
			else
				echo " ! Module previously configured (use -u to refresh)"
			fi
		fi
	done
}

# bootstrap_modules_getorder(name)
# Echos the installation order of the specified module.
# bootstrap_modules_build_list must be called first
function bootstrap_modules_getorder()
{
	local module="$1"

	[ -n "$module" ] || return 1
	[ -f "$BOOTSTRAP_MODULES_MODULELISTPATH" ] || return 1

	awk -v module="$module" '($2 == module) {print $1}' "$BOOTSTRAP_MODULES_MODULELISTPATH"
}
