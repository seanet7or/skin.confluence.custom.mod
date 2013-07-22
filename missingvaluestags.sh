DEBUG=false

printf "\nTags with missing values:\n\n"
CONTROLS=$(grep -o '<control type="[a-z]*"' 720p/* | grep -o '"[a-z]*"' | tr -d '"' | sort -u -r | egrep -v 'list|group|panel')

IFS=$'\n' ; for CONTROL in $CONTROLS ; do
	#echo "Control is '$CONTROL'."
	TAGS=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep -o "<[a-z]*[ >]" | grep -v "<control" | tr -d '<> ' | sort -u )
	TAGS=$(echo "$TAGS" | egrep -v 'onclick|ondown|onup|onleft|onright|onback')
	#printf "\nAll tags for control '$CONTROL' are: '$TAGS'"
	INCLUDES=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep "<include>" | sed 's|<[/]*include>||g' | sed 's|^\s*||' | sort -u )
	#printf "\nIncludes are: '$INCLUDES'."
	for INCLUDE in $INCLUDES ; do
		INCLUDETAGS="$INCLUDETAGS"$'\n'$(grep -a -z -Po "<include name=\"$INCLUDE\".*\n(\s*<[a-z].*\n)*\s*</include>" 720p/* | grep -o "<[a-z]*[ >]" | grep -v "<include" | tr -d '<>' | sort -u)		
	done
	INCLUDETAGS=$(echo "$INCLUDETAGS" | sort -u)
	#printf "\nIncludetags are: '$INCLUDETAGS'."
	OPTTAGS=""
	for TAG in $TAGS ; do
		if ! [[ *$INCLUDETAGS* = *$TAG* ]] ; then
			if [ -z "$OPTTAGS" ] ; then
				OPTTAGS="$TAG"
			else
				OPTTAGS="$OPTTAGS"$'\n'"$TAG"
			fi
		fi
	done
	OPTTAGS=$(echo "$OPTTAGS" | egrep -v 'description|include')
	#echo "Tags to optimize are: '$OPTTAGS'."
	for TAG in $OPTTAGS ; do
		#echo
		#echo "Control: '$CONTROL', tag: '$TAG'."
		DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/* | grep "<$TAG[ >]" | sed 's|^\s*||')
		NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
		if [ -z "$DEFTAG" ] && [ $NUMMISSING -gt 0 ] ; then
			echo "'$CONTROL', '$TAG'."
		fi
	done
	
done

exit