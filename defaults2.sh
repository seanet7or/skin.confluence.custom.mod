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

CONTROLS=$(grep -o '<control type="[a-z]*"' 720p/* | grep -o '"[a-z]*"' | tr -d '"' | sort -u -r | egrep -v 'list|group|panel')
#CONTROLS=$1

XBMCDEFS='
;visible;<visible>true</visible>
;colordiffuse;<colordiffuse>FFFFFFFF</colordiffuse>
;enable;<enable>true</true>
;pulseonselect;<pulseonselect>true</pulseonselect>
edit;aligny;<aligny>top</aligny>
fadelabel;resetonlabelchange;<resetonlabelchange>true</resetonlabelchange>
fadelabel;scrollspeed;<scrollspeed>60</scrollspeed>
label;align;<align>left</align>
label;aligny;<aligny>top</aligny>
label;scroll;<scroll>false</scroll>
label;scrollspeed;<scrollspeed>60</scrollspeed>
label;scrollsuffix;<scrollsuffix>|</scrollsuffix>
multiimage;loop;<loop>yes</loop>
radiobutton;align;<align>left</align>
radiobutton;aligny;<aligny>top</aligny>
scrollbar;orientation;<orientation>vertical</orientation>
scrollbar;showonepage;<showonepage>true</showonepage>
selectbutton;align;<align>left</align>
selectbutton;aligny;<aligny>top</aligny>
'

IFS=$'\n' ; for CONTROL in $CONTROLS ; do
	DEFAULT=$'\t'"<default type=\"$CONTROL\">"
	#echo "Control is '$CONTROL'."
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
	OPTTAGS=$(echo "$OPTTAGS" | egrep -v 'description|include')
	#echo "Tags to optimize are: '$OPTTAGS'."
	NUMCONTROL=$(grep -a "<control type=\"$CONTROL" 720p/* | wc -l)
	#echo "$NUMCONTROL controls at all."
	if [ $NUMCONTROL -lt 2 ] ; then
		#echo "Will not optimize."
		continue
	fi
	for TAG in $OPTTAGS ; do
		#echo
		#echo "Control: '$CONTROL', tag: '$TAG'."
		DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/* | grep "<$TAG[ >]" | sed 's|^\s*||')
		NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
		if [ -z "$DEFTAG" ] && [ $NUMMISSING -gt 0 ] ; then
			XBMCDEF=$(echo "$XBMCDEFS" | grep "^;$TAG;" | head -1 )
			if [ -z "$XBMCDEF" ] ; then
				XBMCDEF=$(echo "$XBMCDEFS" | grep "^$CONTROL;$TAG;" | head -1 )
			fi
			if ! [ -z "$XBMCDEF" ] ; then
				NEWDEFAULT=$(echo "$XBMCDEF" | cut -f3 -d';')
				echo "New default for '$CONTROL', '$TAG': '$NEWDEFAULT'."
			fi
		fi
	done
	
done

exit