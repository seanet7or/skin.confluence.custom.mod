printf "\nScanning for variable definitions: "
VARDEFS=$(grep "<variable name=\"[^\"]*" 720p/* | grep -o "\"[^\"]*\"" | sort -u | tr -d '"')
printf "%sDONE!%s" $GREEN $RESET

printf "\nScanning for unused variables: "
OLDIFS=$IFS ; IFS=$'\n'
for DEF in $VARDEFS ; do
	if ! grep -q "[^\"]$DEF[^\"]" 720p/* ; then
		printf "\n%sWARNING: Variable '$DEF' is unused.%s" $RED $RESET
	fi
done
IFS=$OLDIFS
printf "%sDONE!%s" $GREEN $RESET
