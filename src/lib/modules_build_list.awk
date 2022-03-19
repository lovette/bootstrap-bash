# Read a list of modules.txt files and output a list of modules with assigned sort priority.
#
# Example output:
# 000399  moduleA
# 000400  moduleB
# 000405  moduleC
# 000410  moduleD
#
# Note that `mawk` does not support `match()` with regex capture so you will have to
# replace it with `gawk` depending on your distribution.
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
	curorder=$2;

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

	if (!match(curorder, "^(first|last|before|after)"))
	{
		# If an order is not set explicitly, assign a default
		if (!match(curorder, "^[0-9]+$"))
		{
			curorder = defaultorder;
			defaultorder += 5
		}

		minorder = (curorder < minorder) ? curorder : minorder;
		maxorder = (curorder > maxorder) ? curorder : maxorder;
	}
	else
	{
		$1 = ""
		curorder = $0
		gsub(/^[ ]+/, "", curorder) # ltrim whitespace
		relnames[relcount++] = name;
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

	while (relcount > 0)
	{
		for (i in relnames)
		{
			name = relnames[i];
			curorder = moduleorder[name];

			# Assign before/after relative order a numeric order
			if (match(curorder, "(before|after) (.+)", parts))
			{
				if (parts[2] in moduleorder)
				{
					curorder = moduleorder[parts[2]];

					# If relative to another relative, resolve later
					if (!match(curorder, "^[0-9]+$"))
						continue;

					if (parts[1] == "before")
					{
						# Shift everything up
						for (j in moduleorder)
							if (match(moduleorder[j], "^[0-9]+$"))
								if (moduleorder[j] >= curorder)
									moduleorder[j]++;
						maxorder++;
					}
					else if (parts[1] == "after")
					{
						# Shift everything down
						for (j in moduleorder)
							if (match(moduleorder[j], "^[0-9]+$"))
								if (moduleorder[j] <= curorder)
									moduleorder[j]--;
						minorder--;
					}

					moduleorder[name] = curorder;
				}
				else
				{
					# Relative to unknown, put last
					maxorder++;
					moduleorder[name] = maxorder;
				}
			}
			else
			{
				# Unknown directive, put last
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
