printf "\nScanning for variable definitions: "
VARDEFS=$(grep '<variable ' 720p/* | cut -d':' -f2 | grep -o 'name="[^"]*"' \
	| ssed 's|^name="||' | ssed 's|"$||')
printf "DONE!"

printf "\nScanning for unused variables: "
OLDIFS=$IFS ; IFS=$'\n'
for DEF in $VARDEFS ; do
	#printf "$DEF... "
	
	USES=$(grep "$DEF" 720p/* | grep -v "name=\"$DEF\"" | head -n 1)
	if [ -z "$USES" ] ; then
		printf "\n%sWARNING: Include '$DEF' is unused.\n%s" $RED $RESET
	fi
done
IFS=$OLDIFS
printf "DONE!"
