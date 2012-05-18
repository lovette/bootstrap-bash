# Bootstrap library module - Yum
# This will be included by bootstrap-bash.sh only
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/bootstrap-bash

# bootstrap_yum_repos_add(array of module names)
function bootstrap_yum_repos_add()
{
	local modules=( "$@" )
	local rpms=( )
	local copyfiles=( )
	local module=""
	local packagefilepath=""
	local installedmodules=( )
	local skipped=0
	local rpmrepos=""
	local txtrepos=""
	local reponame=""
	local repopath=""
	local forced=0

	[ $BOOTSTRAP_GETOPT_PACKAGESONLY -eq 1 ] && forced=1

	# Search modules for Yum repositories to add
	for module in "${modules[@]}";
	do
		moduledir="${BOOTSTRAP_DIR_MODULES}/${module}"
		packagefilepath="${moduledir}/yum-packages.txt"

		if [ -f "$packagefilepath" ]; then
			rpmrepos=$(grep -E "^yum-repo-add:(.+)\.rpm$" "$packagefilepath" | sed -r -e "s/^yum-repo-add:(.+)/\1/" -e "s/{BOOTSTRAP_BASEARCH}/${BOOTSTRAP_BASEARCH}/" -e "s/{BOOTSTRAP_PROCARCH}/${BOOTSTRAP_PROCARCH}/" | tr -s '[:space:]' ' ')
			txtrepos=$(grep -E "^yum-repo-add:(.+)\.repo$" "$packagefilepath" | sed -r -e "s/^yum-repo-add:(.+)/\1/" -e "s/{BOOTSTRAP_BASEARCH}/${BOOTSTRAP_BASEARCH}/" -e "s/{BOOTSTRAP_PROCARCH}/${BOOTSTRAP_PROCARCH}/" | tr -s '[:space:]' ' ')

			if [ -n "$rpmrepos" ] || [ -n "$txtrepos" ]; then
				if [ $forced -eq 1 ] || ! bootstrap_modules_check_state "$module" "yum-repo-add"; then
					[ -n "$rpmrepos" ] && rpms=( "${rpms[@]}" $rpmrepos )
					if [ -n "$txtrepos" ]; then
						txtrepos=( "$txtrepos" )
						for reponame in "${txtrepos[@]}";
						do
							# Prepend module path to given path if it is relative
							[[ $reponame != /* ]] && reponame="${moduledir}/${reponame}"
							copyfiles=( "${copyfiles[@]}" $reponame )
						done
					fi
					installedmodules=( "${installedmodules[@]}" $module )
				else
					let skipped++
				fi
			fi
		fi
	done

	if [ ${#rpms[@]} -gt 0 ] || [ ${#copyfiles[@]} -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Adding Yum repositories..."

		# Install rpms all at once
		if [ ${#rpms[@]} -gt 0 ]; then
			if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
				/bin/rpm -Uv ${rpms[@]} 2>&1 | sed 's/^/ * rpm: /'
				[ ${PIPESTATUS[0]} -gt ${#rpms[@]} ] && bootstrap_die
			else
				echo "+ /bin/rpm -Uv" "${rpms[@]}"
			fi
		fi

		# Copy text files to yum.repos.d
		for repopath in "${copyfiles[@]}";
		do
			reponame=$(basename "$repopath")
			if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
				BOOTSTRAP_ECHO_STRIPPATH=$BOOTSTRAP_DIR_MODULES
				bootstrap_file_copy $repopath "/etc/yum.repos.d/${reponame}" "root:root" 644 1
				sed -i -e "s/{BOOTSTRAP_BASEARCH}/${BOOTSTRAP_BASEARCH}/" -e "s/{BOOTSTRAP_PROCARCH}/${BOOTSTRAP_PROCARCH}/" "/etc/yum.repos.d/${reponame}"
				BOOTSTRAP_ECHO_STRIPPATH=""
			else
				echo "+ bootstrap_file_copy ${repopath} to /etc/yum.repos.d/${reponame}"
			fi
		done
	elif [ $skipped -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Adding Yum repositories..."
		echo " * Repositories previously added, skipping (use -f or -p to override)"
	fi

	# Keep track of the modules we installed for
	for module in "${installedmodules[@]}";
	do
		bootstrap_modules_set_state "$module" "yum-repo-add"
	done
}

# bootstrap_yum_packages_remove(array of module names)
function bootstrap_yum_packages_remove()
{
	local modules=( "$@" )
	local packages=( )
	local module=""
	local packagefilepath=""
	local installedmodules=( )
	local skipped=0
	local removepackages=""
	local forced=0

	[ $BOOTSTRAP_GETOPT_PACKAGESONLY -eq 1 ] && forced=1

	# Search modules for Yum packages to remove
	for module in "${modules[@]}";
	do
		moduledir="${BOOTSTRAP_DIR_MODULES}/${module}"
		packagefilepath="${moduledir}/yum-packages.txt"

		if [ -f "$packagefilepath" ]; then
			removepackages=$(grep "^-" "$packagefilepath" | sed -r "s/^-(.+)/\1/" | tr -s '[:space:]' ' ')
			if [ -n "$removepackages" ]; then
				if [ $forced -eq 1 ] || ! bootstrap_modules_check_state "$module" "yum-remove"; then
					packages=( "${packages[@]}" $removepackages )
					installedmodules=( "${installedmodules[@]}" $module )
				else
					let skipped++
				fi
			fi
		fi
	done

	# Remove packages
	if [ ${#packages[@]} -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Removing Yum packages..."

		if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
			/usr/bin/yum -q remove ${packages[@]}
			[ ${PIPESTATUS[0]} -ne 0 ] && bootstrap_die
		else
			echo "+ /usr/bin/yum -q remove" "${packages[@]}"
		fi
	elif [ $skipped -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Removing Yum packages..."
		echo " * Packages previously removed, skipping (use -f or -p to override)"
	fi

	# Keep track of the modules we installed for
	for module in "${installedmodules[@]}";
	do
		bootstrap_modules_set_state "$module" "yum-remove"
	done
}

# bootstrap_yum_packages_install(array of module names)
function bootstrap_yum_packages_install()
{
	local modules=( "$@" )
	local packages=( )
	local module=""
	local packagefilepath=""
	local installedmodules=( )
	local skipped=0
	local addpackages=""
	local packagename=""
	local reponame=""
	local repos=( )
	local packagelistcache="$BOOTSTRAP_DIR_CACHE/yum-packages-install"
	local forced=0

	[ $BOOTSTRAP_GETOPT_PACKAGESONLY -eq 1 ] && forced=1

	/bin/rm -f "$packagelistcache"
	touch "$packagelistcache"

	# Search modules for Yum packages to install
	for module in "${modules[@]}";
	do
		moduledir="${BOOTSTRAP_DIR_MODULES}/${module}"
		packagefilepath="${moduledir}/yum-packages.txt"

		if [ -f "$packagefilepath" ]; then
			addpackages=$(grep -v -E "^(#|-|yum-repo-add:)" "$packagefilepath" | tr -s '[:space:]' ' ')
			if [ -n "$addpackages" ]; then
				if [ $forced -eq 1 ] || ! bootstrap_modules_check_state "$module" "yum-install"; then
					for packagename in $addpackages;
					do
						if [[ "$packagename" =~ ^(.+)/(.+)$ ]]; then
							echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}" >> $packagelistcache
						else
							echo "- $packagename" >> $packagelistcache
						fi
					done
					installedmodules=( "${installedmodules[@]}" $module )
				else
					let skipped++
				fi
			fi
		fi
	done

	repos=$(awk '{ print $1 };' "$packagelistcache" | sort | uniq | tr -s '[:space:]' ' ')

	# Install packages, grouped by repo
	if [ -n "$repos" ]; then
		echo ""
		bootstrap_echo_header "Installing Yum packages..."

		for reponame in $repos;
		do
			if [ "$reponame" == "-" ]; then
				echo " * from default repositories:"
				yumargs=""
			else
				echo " * from $reponame repository only:"
				yumargs="--disablerepo=* --enablerepo=$reponame"
			fi

			packages=$(grep "^$reponame " $packagelistcache | awk '{ print $2 };' | sort | uniq | tr -s '[:space:]' ' ')

			if [ $BOOTSTRAP_GETOPT_DRYRUN -eq 0 ]; then
				/usr/bin/yum -q install $yumargs ${packages[@]}
				[ ${PIPESTATUS[0]} -ne 0 ] && bootstrap_die
			else
				echo "+ /usr/bin/yum -q install $yumargs" "${packages[@]}"
			fi
		done
	elif [ $skipped -gt 0 ]; then
		echo ""
		bootstrap_echo_header "Installing Yum packages..."
		echo " * Packages previously installed, skipping (use -f or -p to override)"
	fi

	/bin/rm -f "$packagelistcache"

	# Keep track of the modules we installed for
	for module in "${installedmodules[@]}";
	do
		bootstrap_modules_set_state "$module" "yum-install"
	done
}
