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

# choose right flag for german mpaa ratings
if ! grep -q 'fsk-18' '720p/IncludesVariables.xml' ; then
	perlregex '720p/IncludesVariables.xml' \
	's|(\000\s*)(<variable name="rating">).*?\000|\1\2'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,18)">de/fsk-18</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,16)">de/fsk-16</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,12)">de/fsk-12</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,6)">de/fsk-6</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,0)">de/fsk-0</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,o)">de/fsk-0</value>'\
	'\n\n|' 
fi

#cat 720p/IncludesVariables.xml | tr '\n' '\0' | ssed -R "$R" | tr '\0' '\n' >720p/IncludesVariables.xml2	