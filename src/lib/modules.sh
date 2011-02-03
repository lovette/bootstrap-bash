# Bootstrap library module - Modules
# This will be included by bootstrap-bash.sh only
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

# bootstrap_modules_set_state(module name, action)
# Creates module state file for an action
bootstrap_modules_set_state()
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
bootstrap_modules_check_state()
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
bootstrap_modules_clear_state()
{
	local module=$1
	local action=$2
	local BOOTSTRAP_DIR_MODULE_CACHE="${BOOTSTRAP_DIR_CACHE}/module-${module}"
	local statefile="${BOOTSTRAP_DIR_MODULE_CACHE}/action-${action}"

	[ -d "$BOOTSTRAP_DIR_MODULE_CACHE" ] && /bin/rm -f "$statefile"
}

# bootstrap_modules_reset_states(module name)
# Deletes state files for all actions for a module
bootstrap_modules_reset_states()
{
	local module=$1
	local BOOTSTRAP_DIR_MODULE_CACHE="${BOOTSTRAP_DIR_CACHE}/module-${module}"

	[ -d "$BOOTSTRAP_DIR_MODULE_CACHE" ] && find "${BOOTSTRAP_DIR_MODULE_CACHE}" -mindepth 1 -maxdepth 1 -print0 | xargs -r -0 /bin/rm -rf
}

# bootstrap_modules_reset_states_all()
# Deletes all state files for all modules
bootstrap_modules_reset_states_all()
{
	find "${BOOTSTRAP_DIR_CACHE}" -mindepth 1 -maxdepth 1 -print0 | xargs -r -0 /bin/rm -rf
}

# bootstrap_modules_is_installed(module name)
# Returns success if any actions have been taken for a module
bootstrap_modules_is_installed()
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
bootstrap_modules_get_version_info()
{
	local module=$1
	local verfilepath="${BOOTSTRAP_DIR_MODULES}/${module}/version.txt"

	module_version_desc="-"
	module_version_ver="-"

	if [ -f "$verfilepath" ] && [ -r "$verfilepath" ]; then
		while read curline; do
			[[ "$curline" =~ "^[D|d]escription: *(.+)$" ]] && module_version_desc="${BASH_REMATCH[1]}"
			[[ "$curline" =~ "^[V|v]ersion: *(.+)$" ]] && module_version_ver="${BASH_REMATCH[1]}"
		done < "$verfilepath"
	fi
}

# bootstrap_modules_build_list()
# Build list of modules based on the active role
# Return value is the global array BOOTSTRAP_MODULE_NAMES
bootstrap_modules_build_list()
{
	local file=""
	local modulefiles=( )
	local pathpart=""
	local pathparts=( )
	local rolepath=""

	BOOTSTRAP_MODULE_NAMES=( )

	modulefiles[${#modulefiles[@]}]="${BOOTSTRAP_DIR_ROLES}/modules.txt"

	# Split the role path into directory parts and reference
	# modules.txt for each directory in the path
	rolepath="$BOOTSTRAP_DIR_ROLES"
	IFS='/' read -ra pathparts <<< "${BOOTSTRAP_DIR_ROLE##$rolepath/}"
	for pathpart in "${pathparts[@]}"; do
		modulefiles[${#modulefiles[@]}]="${rolepath}/${pathpart}/modules.txt"
		rolepath="${rolepath}/${pathpart}"
	done

	# Build list of modules based on role
	for file in "${modulefiles[@]}"
	do
		if [ -f "$file" ]; then
			bootstrap_file_get_contents_list $file
			BOOTSTRAP_MODULE_NAMES=( ${BOOTSTRAP_MODULE_NAMES[@]} $get_file_contents_return )
		fi
	done
}

# bootstrap_modules_scan(array of module names)
bootstrap_modules_scan()
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
bootstrap_modules_script_exec()
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
	export BOOTSTRAP_DIR_LIB
	export BOOTSTRAP_DIR_ROLE
	export BOOTSTRAP_DIR_MODULE
	export BOOTSTRAP_DIR_MODULE_CACHE
	export BOOTSTRAP_DIR_TMP

	if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
		(cd $BOOTSTRAP_DIR_MODULE && bash ${bashargs} ${script})
		[ $? -ne 0 ] && bootstrap_die
	else
		echo "+ bash ${bashargs} ${script}";
		[ $BOOTSTRAP_GETOPT_PRINTSCRIPTS -eq 1 ] && bash -nv "${script}"
	fi
}

# bootstrap_modules_preinstall(array of module names)
bootstrap_modules_preinstall()
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
			echo "Preinstalling ${module} module..."

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
bootstrap_modules_config()
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
			echo "Configuring ${module} module..."
			bootstrap_modules_script_exec "$module" "$configscript"
			bootstrap_modules_set_state "$module" "config-sh"
		fi
	done
}

# bootstrap_modules_install(array of module names)
bootstrap_modules_install()
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
			echo "Installing ${module} module..."

			if ! bootstrap_modules_check_state "$module" "install-sh"; then
				bootstrap_modules_script_exec "$module" "$installscript"
				bootstrap_modules_set_state "$module" "install-sh"
			else
				echo " ! Module previously installed (use -f to force install)"
			fi
		fi

		if [ -f "$configscript" ]; then
			echo ""
			echo "Configuring ${module} module..."

			if ! bootstrap_modules_check_state "$module" "config-sh"; then
				bootstrap_modules_script_exec "$module" "$configscript"
				bootstrap_modules_set_state "$module" "config-sh"
			else
				echo " ! Module previously configured (use -u to refresh)"
			fi
		fi
	done
}
