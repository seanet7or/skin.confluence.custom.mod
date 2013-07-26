printf "\nScanning for include definitions: "
INCDEFS=$(grep "<include name=\"[^\"]*" 720p/* | grep -o "\"[^\"]*\"" | sort -u | tr -d '"')
printf "%sDONE!%s" $GREEN $RESET

printf "\nScanning for unused includes: "
OLDIFS=$IFS ; IFS=$'\n'
for DEF in $INCDEFS ; do
	if ! grep -q ">$DEF</include>" 720p/* ; then
		printf "\n%sWARNING: Include '$DEF' is unused.\n%s" $RED $RESET
	fi
done
IFS=$OLDIFS
printf "%sDONE!%s" $GREEN $RESET
