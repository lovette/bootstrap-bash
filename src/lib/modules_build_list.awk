# Read a list of modules.txt files and output a list of modules with assigned sort priority.
#
# Example output:
# 000399  moduleA
# 000400  moduleB
# 000405  moduleC
# 000410  moduleD
#
# Invoked as:
# awk -v include_tags=foo,bar -f /path/modules_build_list.awk /path/modules.txt /path/modules.txt ...

BEGIN {
	defaultorder=0;
	filenum=1;
	curfile="";
	modulecount=0;
	relcount=0;
	minorder=999999;
	maxorder=0;

	# Force declare empty array
	relnames[0]=0; delete relnames[0];

	# Turn tags argument into assoc array
	split(include_tags, tmp, ",");
	for (i in tmp)
		include_tags_hash[tmp[i]] = 1;
}

{
	# Each file gets a new range base
	if (curfile != FILENAME)
		defaultorder = filenum++ * 200;
	curfile=FILENAME;

	# Skip blank lines and comments
	if ($0 == "")
		next;
	if (substr($0, 1, 1) == "#")
		next;

	name=$1;

	if (NF == 1)
	{
		curorder=defaultorder;
		defaultorder += 5
		minorder = (curorder < minorder) ? curorder : minorder;
		maxorder = (curorder > maxorder) ? curorder : maxorder;
	}
	else
	{
		if (match($NF, "^\\([,A-Za-z0-9]+\\)$"))
		{
			tag_found = 0;

			# Module has tags, see if they match any provided
			split(substr($NF, 2, length($NF)-2), tmp, ",")
			for (i in tmp) {
				if (include_tags_hash[tmp[i]] == 1)
					tag_found++;
			}

			if (!tag_found)
				next;

			$NF = "";
		}

		curorder=$2

		if (match(curorder, "^(first|last)"))
		{
			relnames[relcount++] = name;
		}
		else if (match(curorder, "^(before|after)"))
		{
			relnames[relcount++] = name;
			relto[name] = $3;
		}
		else
		{
			if (!match(curorder, "^[0-9]+$"))
			{
				curorder = defaultorder;
				defaultorder += 5
			}

			minorder = (curorder < minorder) ? curorder : minorder;
			maxorder = (curorder > maxorder) ? curorder : maxorder;
		}
	}

	modulenames[modulecount++] = name;
	moduleorder[name] = curorder;
}

END {
	# Assign first/last relative order a numeric order
	for (i in relnames)
	{
		name = relnames[i];
		curorder = moduleorder[name];

		if (curorder == "first")
		{
			minorder--;
			moduleorder[name] = minorder;
			delete relnames[i];
			relcount--;
		}
		else if (curorder == "last")
		{
			maxorder++;
			moduleorder[name] = maxorder;
			delete relnames[i];
			relcount--;
		}
	}

	# Assign before/after relative to numeric order of another module
	while (relcount > 0)
	{
		for (i in relnames)
		{
			name = relnames[i];
			curorder = moduleorder[name];
			reltoname = relto[name];

			if (reltoname in moduleorder)
			{
				reltoorder = moduleorder[reltoname];

				# If relative to another relative, resolve later
				if (!match(reltoorder, "^[0-9]+$"))
					continue;

				if (curorder == "before")
				{
					# Shift everything up
					for (j in moduleorder)
						if (match(moduleorder[j], "^[0-9]+$"))
							if (moduleorder[j] >= reltoorder)
								moduleorder[j]++;
					maxorder++;
				}
				else if (curorder == "after")
				{
					# Shift everything down
					for (j in moduleorder)
						if (match(moduleorder[j], "^[0-9]+$"))
							if (moduleorder[j] <= reltoorder)
								moduleorder[j]--;
					minorder--;
				}

				moduleorder[name] = reltoorder;
			}
			else
			{
				# Relative to unknown, put last
				maxorder++;
				moduleorder[name] = maxorder;
			}

			delete relnames[i];
			relcount--;
		}

	}

	for (name in moduleorder)
		printf("%06d\t%s\n", moduleorder[name], name);
}
