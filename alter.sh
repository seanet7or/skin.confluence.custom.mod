#!/bin/bash

# $1 file
# $2 regex
perlregex() {
	local FILE=$1
	local REGEX=$2
	cp "$FILE" "$FILE.tmp"
	cat "$FILE.tmp" | tr '\n' '\0' | ssed -R "$REGEX" | tr '\0' '\n' >"$FILE"
	rm "$FILE.tmp"
}

# enable germany mpaa setting 
perlregex '720p/SkinSettings.xml' 's|<!--(item[^>]*id="3".*31702.*?)/item-->|<\1/item>|'
