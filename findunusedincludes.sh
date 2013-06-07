printf "\nScanning for include definitions: "
INCDEFS=$(grep '<include[^s]' 720p/* | grep -v '</include>' | grep -v 'file' \
	| cut -f2 -d':' | sed 's|^\s*<include name="||' | sed 's|">$||')
printf "%sDONE!%s" $GREEN $RESET

printf "\nScanning for unused includes: "
OLDIFS=$IFS ; IFS=$'\n'
for DEF in $INCDEFS ; do
	#printf "$DEF... "
	USES=$(grep '<include' 720p/* | grep -v name | grep "$DEF" | head -n 1)
	if [ -z "$USES" ] ; then
		printf "\n%sWARNING: Include '$DEF' is unused.\n%s" $RED $RESET
	fi
done
IFS=$OLDIFS
printf "%sDONE!%s" $GREEN $RESET
