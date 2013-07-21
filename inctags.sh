
CONTROLS=$(grep -o '<control type="[a-z]*"' 720p/* | grep -o '"[a-z]*"' | tr -d '"' | sort -u -r | egrep -v 'list|group|panel|epggrid|karvisualisation')

printf "\nScanning for tags to optimize: "
OPTTAGS=""
for CONTROL in $CONTROLS ; do
	TAGS=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep -o "<[a-z]*[ >]" | grep -v "<control" | tr -d '<> ' | sort -u )
	INCLUDES=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep "<include>" | sed 's|<[/]*include>||g' | sed 's|^\s*||' | sort -u )
	INCLUDETAGS=""
	for INCLUDE in $INCLUDES ; do
		INCLUDETAGS="$INCLUDETAGS"$'\n'$(grep -a -z -Po "<include name=\"$INCLUDE\".*\n(\s*<[a-z].*\n)*\s*</include>" 720p/* | grep -o "<[a-z]*[ >]" | grep -v "<include" | tr -d '<>' | sort -u)
	done
	INCLUDETAGS=$(echo "$INCLUDETAGS" | sort -u)
	printf "\n'$CONTROL' control:"
	printf "\n'$INCLUDETAGS'"
	for TAG in $TAGS ; do
		if ! [[ *$INCLUDETAGS* = *$TAG* ]] ; then
			OPTTAGS="$OPTTAGS"$'\n'"$CONTROL;$TAG"
		fi
	done
done
OPTTAGS=$(echo "$OPTTAGS" | egrep -v 'description|include|onup|ondown|onleft|onright|onclick')
printf "%sDONE!%s" $GREEN $RESET

