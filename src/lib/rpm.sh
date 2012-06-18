# Bootstrap library module - Rpm
# This will be included by bootstrap-bash.sh only
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

# bootstrap_rpm_packages_install(array of module names)
function bootstrap_rpm_packages_install()
{
	local modules=( "$@" )
	local module=""
	local packagefilepath=""
	local installedmodules=( )
	local skipped=0
	local rpms=( )
	local rpmpath=""
	local rpmname=""
	local localpath=""
	local installrpms=( )
	local installrpmsnodeps=( )
	local dlrpms=( )
	local forced=0
	local optionnodeps=0
	local NODEPSREGEX="^(.+)[[:space:]]+nodeps"
	local REMOTEPATHREGEX="^(http|ftp)://"

	[ $BOOTSTRAP_GETOPT_PACKAGESONLY -eq 1 ] && forced=1

	# Search modules for RPMs to install
	for module in "${modules[@]}";
	do
		moduledir="${BOOTSTRAP_DIR_MODULES}/${module}"
		packagefilepath="${moduledir}/rpm-packages.txt"


		if [ -f "$packagefilepath" ]; then
			old_IFS=$IFS
			IFS=$'\n' # process package list line by line

			rpms=( $(grep -v -E "(^[:space:]*#|^[:space:]*$)" "$packagefilepath") )

			if [ "${#rpms[@]}" -gt 0 ]; then
				if [ $forced -eq 1 ] || ! bootstrap_modules_check_state "$module" "rpm-install"; then
					for rpmpath in "${rpms[@]}";
					do
						# Determine if nodeps option is set
						optionnodeps=0
						if [[ "$rpmpath" =~ $NODEPSREGEX ]]; then
							rpmpath=${BASH_REMATCH[1]}
							optionnodeps=1
						fi

						# rpmpath can be a URL or full/relative local file path
						if [[ "$rpmpath" =~ $REMOTEPATHREGEX ]]; then
							rpmname=$(basename "$rpmpath")
							localpath="$BOOTSTRAP_DIR_CACHE_RPM/$rpmname"
							[ ! -f "$localpath" ] && dlrpms=( "${dlrpms[@]}" $rpmpath )
						elif [[ $rpmpath != /* ]]; then
							localpath="${moduledir}/${rpmpath}"
						else
							localpath="$rpmpath"
						fi

						if [ $optionnodeps -eq 1 ]; then
							installrpmsnodeps=( "${installrpmsnodeps[@]}" $localpath )
						else
							installrpms=( "${installrpms[@]}" $localpath )
						fi
					done
					installedmodules=( "${installedmodules[@]}" $module )
				else
					let skipped++
				fi
			fi

			IFS=$old_IFS
		fi
	done

	# Download RPMs
	if [ ${#dlrpms[@]} -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Downloading RPM packages..."
		echo " * saving RPMs in $BOOTSTRAP_DIR_CACHE_RPM/"

		bootstrap_mkdir $BOOTSTRAP_DIR_CACHE_RPM 755

		for rpmpath in "${dlrpms[@]}";
		do
			rpmname=$(basename "$rpmpath")
			localpath="$BOOTSTRAP_DIR_CACHE_RPM/$rpmname"

			if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
				bootstrap_file_wget "$rpmpath" "$localpath"
			else
				echo "+ bootstrap_file_wget $rpmpath $localpath"
			fi
		done
	fi

	# Install RPMs that are not checking dependencies first
	# in case the next set of RPMs depend on them.
	if [ ${#installrpmsnodeps[@]} -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Installing RPM packages without checking dependencies..."

		if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
			echo "${installrpmsnodeps[@]}" | xargs /bin/rpm -Uv --nodeps
			[ ${PIPESTATUS[0]} -gt ${#installrpmsnodeps[@]} ] && bootstrap_die
		else
			echo "+ /bin/rpm -Uv --nodeps" "${installrpmsnodeps[@]}"
		fi
	fi

	# Install RPMs normally
	if [ ${#installrpms[@]} -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Installing RPM packages..."

		if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
			echo "${installrpms[@]}" | xargs /bin/rpm -Uv
			[ ${PIPESTATUS[0]} -gt ${#installrpms[@]} ] && bootstrap_die
		else
			echo "+ /bin/rpm -Uv" "${installrpms[@]}"
		fi
	fi

	if [ ${#installrpms[@]} -eq 0 ]  && [ ${#installrpmsnodeps[@]} -eq 0 ] && [ $skipped -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Installing RPM packages..."
		echo " * RPMs previously installed, skipping (use -f or -p to override)"
	fi

	# Keep track of the modules we installed for
	for module in "${installedmodules[@]}";
	do
		bootstrap_modules_set_state "$module" "rpm-install"
	done
}
