DEBUG=false

#prints the parameter, if debug mode is enabled
debug() {
	if $DEBUG ; then
		printf "\n$1" >>debug.log
		printf "%s\n%s%s" $CYAN "$1" $RESET >&2
	fi
}

# applies a perlregex to the given file(s)
# Valid parameters are one regex and the files; if no files are given,
# the regex will be applied to all files in the 720p subfolder
# parameters: 
#	--nocheck doesn't check if any changes were applied if given
perlregex() {
	debug "perlregex() entered."
	#parse parameters
	local LIST=''
	local REGEX=''
	local CHANGED=false
	
	for I in "$@" ; do
		I=$(echo "$I" | sed 's|^\s*||' | sed 's|\s*$||')
		debug "Parameter: '$I'."
		if [ -z "$I" ] ; then continue ; fi
		if [ "$I" == "--nocheck" ] ; then
			CHANGED=true
			continue
		fi
		if [ -f "$I" ] ; then
			debug "'Adding '$I' to the files."
			LIST+="$I"$'\n'
			continue
		else
			debug "'$I' is a regex."
			REGEX="$I"
			continue
		fi
	done
	#check parameters
	if [ -z "$REGEX" ] ; then
		printf "\nperlregex(): Missing regex parameter."
		exit 3
	fi
	if [ -z "$LIST" ] ; then
		#LIST=$(find 720p -type f)
		printf "\nperlregex(): Called with empty file list."
		printf "\n"
		printf "\nRegex is: '$REGEX'."
		exit 4
	fi
	#debug "Files are '$LIST'."
	debug "Regex is '$REGEX'."
	#apply regex
	local OLDIFS=$IFS ; IFS=$'\n' ; for FILE in $LIST ; do
		debug "Applying to '$FILE'."
		if [ -z "$FILE" ] ; then continue ; fi
		cat "$FILE" | tr '\n' '#' | ssed -R "$REGEX" | tr '#' '\n' >"$FILE.tmp"
		if [ $? -gt 0 ]; then
			printf "\nperlregex(): ERROR applying the regex."
			printf "\n"
			printf "\nFile is: '$FILE'."
			printf "\nRegex is: '$REGEX'."
			exit 3
		fi
		if ! $CHANGED ; then
			if ! >/dev/null diff -q "$FILE.tmp" "$FILE" ; then
				#printf "\n Changed '$FILE'."
				CHANGED=true
			fi
		fi
		mv -f "$FILE.tmp" "$FILE"
	done ; IFS=$OLDIFS
	if ! $CHANGED ; then
		printf "\n%sWARNING: No changes were made.%s" $RED $RESET
			printf "\n"
			printf "\nFile is: '$FILE'."
			printf "\nRegex is: '$REGEX'."
	fi
}

CONTROLS=$(grep -o '<control type="[a-z]*"' 720p/* | grep -o '"[a-z]*"' | tr -d '"' | sort -u | egrep -v 'list|group|panel')
echo "$CONTROLS"
exit

IFS=$'\n' ; for CONTROL in $CONTROLS ; do
	DEFAULT=$'\t'"<default type=\"$CONTROL\">"
	echo "Control is '$CONTROL'."
	TAGS=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep -o "<[a-z]*[ >]" | grep -v "<control" | tr -d '<> ' | sort -u )
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
	OPTTAGS=$(echo "$OPTTAGS" | egrep -v 'description|onleft|onright|onup|ondown|include')
	echo "Tags to optimize are: '$OPTTAGS'."
	NUMCONTROL=$(grep -a "<control type=\"$CONTROL" 720p/* | wc -l)
	echo "$NUMCONTROL controls at all."
	if [ $NUMCONTROL -lt 2 ] ; then
		echo "Will not optimize."
		continue
	fi
	for TAG in $OPTTAGS ; do
		#echo
		echo "Control: '$CONTROL', tag: '$TAG'."
		DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/* | grep "<$TAG[ >]" | sed 's|^\s*||')
		NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
		echo "$NUMMISSING controls with missing tag."
		if [ $NUMMISSING -gt 0 ] ; then
			if ! [ -z "$DEFTAG" ] ; then
				echo "Default tag is '$DEFTAG'."
				R="s|(<control type=\"$CONTROL\"[^#]*#)(\s*)"
				R+="((\s*(?!<$TAG[ >])<[a-z][^#]*#)*"
				R+="\s*</control>\s*#)"
				R+="|\1\2$DEFTAG#\2\3|g"
				XMLS=$(2>/dev/null grep "<control type=\"$CONTROL\"" -l 720p/*)
				perlregex $XMLS "$R"
				NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
				if [ $NUMMISSING -gt 0 ] ; then
					echo "There should be no more controls with missing tag, but we found some!"
					exit
				fi
			fi
		fi
		MOST=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep "<$TAG" | sed 's|^\s*||' | sort --batch-size=1021 | uniq -c | sort -n -r | head -1 | sed 's|^\s*||')
		NUMMOST=$(echo "$MOST" | cut -f1 -d' ')
		MOST=$(echo "$MOST" | sed 's|^[0-9]*\s*||')
		if [ $NUMMISSING == 0 ] ; then
			#echo "Most frequent is '$MOST'."
			DEFTAG=$(echo "$DEFTAG" | sed 's/|/\\|/g')
			MOST=$(echo "$MOST" | sed 's/|/\\|/g')
			DEFAULT="$DEFAULT"$'\n'$'\t'$'\t'"$MOST"
			if ! [ -z "$DEFTAG" ] ; then
				if ! [ "$DEFTAG" == "$MOST" ] ; then
					R="s|(<default type=\"$CONTROL\"[^#]*#"		#1
					R+="(\s*<[a-z][^#]*#)*?"					#2
					R+="\s*)$DEFTAG(#"							#3
					R+="(\s*<[a-z][^#]*#)*?"					#4
					R+="\s*</default>#)"
					R+="|\1$MOST\3|g"
					perlregex 720p/defaults.xml "$R"
				fi
			else
				if grep -q "default type=\"$CONTROL\"" 720p/defaults.xml ; then
					R="s|(<default type=\"$CONTROL\"[^#]*#)(\s*)"		#1#2
					R+="|\1\2$MOST#\2|g"				
					perlregex 720p/defaults.xml "$R"
				else
					R='s|(<includes>#)(\s*)|\1\2<default type="'$CONTROL'">#\2\2'$MOST'#\2<\/default>#\2|g'
					perlregex 720p/defaults.xml "$R"					
				fi
			fi
		fi
	done
	DEFAULT="$DEFAULT"$'\n'$'\t'"</default>"
	echo
	echo "Recommended defaults: "
	echo "$DEFAULT"
	
	DEF="$CONTROL"
	printf "\nRemoving default tags for control type '$DEF': "
	if [ -z "$DEF" ] ; then 
		printf "\nERROR: Found empty type."
		exit 3
	fi
	DEFSTART=$(grep -n '<default type="'"$DEF"'">' 720p/defaults.xml | cut -f1 -d:)
	debug "DEFSTART is '$DEFSTART'."
	if [ ! -z "$DEFSTART" ] ; then
		DEFSTOP=$(tail -n+"$DEFSTART" 720p/defaults.xml | grep -n '</default>' | head -n 1 | cut -f1 -d:)
		STRUCT=$(tail -n+"$DEFSTART" 720p/defaults.xml | head -n "$DEFSTOP" | grep -v '<[/]*default' )
		for L in $STRUCT ; do
			if [ ! -z "$L" ] ; then
				L=$(echo "$L" | sed 's|^\s*<|<|')
				R='s|'
				R+='(<control type="'"$DEF"'"[^#]*#(\s*<[a-z][^#]*#)*)\s*'"$L"'#'
				R+='|\1|g'
				XMLS2=""
				XMLS=$(2>/dev/null grep "$L" -l 720p/*)
				for X in $XMLS ; do
					if grep -q '<control type="'"$DEF"'"' "$X" ; then
						XMLS2="$XMLS2"$'\n'"$X"
					fi
				done
				if [ ! -z "$XMLS2" ] ; then
					perlregex "$R" --nocheck $XMLS2
				fi
			fi
		done
	else
		printf "\nNo default structure for type '$DEF' found."
		continue	
	fi
	printf "%sDONE!%s" $GREEN $RESET
done

exit

IFS=$'\n' ; for T in $TAGS ; do
	if $(echo "$T" | cut -f3 -d';' | grep -q 'done' ) ; then
		continue
	fi
	CONTROL=$(echo "$T" | cut -f1 -d';')
	TAG=$(echo "$T" | cut -f2 -d';')
	DEFSTART=$(grep -a -n '<default type="'"$CONTROL"'">' 720p/defaults.xml | cut -f1 -d:)
	if [ ! -z "$DEFSTART" ] ; then
		DEFSTOP=$(tail -n+"$DEFSTART" 720p/defaults.xml | grep -n '</default>' | head -n 1 | cut -f1 -d:)
		DEFTAG=$(tail -n+"$DEFSTART" 720p/defaults.xml | head -n "$DEFSTOP" | grep -v '<[/]*default' | \
			grep "<$TAG[ >]" | sed 's|^\s*||' )
	else
		DEFTAG=""
	fi
	
	#if ! [ -z "$DEFTAG" ] ; then
	#	continue
	#fi
	printf "\nControl is '$CONTROL', tag is '$TAG'."
	#printf "\nThere is no default tag."
	
	2>/dev/null rm tags.tmp
	EMPTY=0
	COUNT=0
	INCS=0
	for F in 720p/* ; do
		IFS=$'\n' ; for CONTROLSTART in $(grep -n '<control type="'"$CONTROL"'"' "$F" | cut -f1 -d:)
		do
			let COUNT=COUNT+1
			CONTROLSTOP=$(tail -n+"$CONTROLSTART" "$F" | grep -n '</control>' | head -n 1 | cut -f1 -d:)
			STRUCT=$(tail -n+"$CONTROLSTART" "$F" | head -n "$CONTROLSTOP" )
			STAG=$(echo "$STRUCT" | grep "<$TAG[ >]" | sed 's|^\s*||' )
			if echo "$STRUCT" | grep "<include>" ; then
				let INCS=INCS+1
			else
				if [ -z "$STAG" ] ; then
					let EMPTY=EMPTY+1
				else
					echo "$STAG" >>tags.tmp
				fi
			fi
		done
	done
	printf "\n$COUNT '$CONTROL' controls."
	#printf "\n%d controls with <include> tags." $INCS
	printf "\n%d controls with missing tags.\n" $EMPTY
	#printf "\nMost frequent tag:\n"
	2>/dev/null more tags.tmp | sort --batch-size=1021 | uniq -c | sed 's|^\s*||' | sort -r -n | head -n 5
done