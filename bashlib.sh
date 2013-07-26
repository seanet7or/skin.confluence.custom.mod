#!/bin/bash

set -o pipefail
2>/dev/null rm debug.log

DEBUG=false
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)
CYAN=$(tput setaf 6)


#prints the parameter, if debug mode is enabled
debug() {
	if $DEBUG ; then
		printf "\n$1" >>debug.log
		printf "%s\n%s%s" $CYAN "$1" $RESET >&2
	fi
}


# applies a perlregex to the given file(s)
# Valid parameters are one regex and the files
# parameters: 
#	--nocheck doesn't check if any changes were applied if given
perlregex() {(
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
		#exit 4
	fi
	#debug "Files are '$LIST'."
	debug "Regex is '$REGEX'."
	#apply regex
	IFS=$'\n' ; for FILE in $LIST ; do
		if [ -z "$FILE" ] ; then continue ; fi
		debug "Applying to '$FILE'."
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
	done
	if ! $CHANGED ; then
		printf "\n%sWARNING: No changes were made.%s" $RED $RESET
			printf "\n"
			printf "\nFile is: '$FILE'."
			printf "\nRegex is: '$REGEX'."
	fi
)}
