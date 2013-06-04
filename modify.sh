#!/bin/bash
#set -e
set -o pipefail
DEBUG=false

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)
CYAN=$(tput setaf 6)


#prints the parameter, if debug mode is enabled
debug() {
	if $DEBUG ; then
		printf "\n$1"
	fi
}


# applies a perlregex to the given file(s)
# Valid parameters are one regex and the files; if no files are given,
# the regex will be applied to all files in the 720p subfolder
perlregex() {
	debug "perlregex() entered."
	#parse parameters
	local LIST=''
	local REGEX=''
	for I in "$@" ; do
		debug "Parameter: '$I'."
		if [ -z "$I" ] ; then continue ; fi
		if [ -f "$I" ] ; then
			debug "'Adding '$I' to the files."
			LIST+="$I"$'\n'
		else
			debug "'$I' is a regex."
			REGEX="$I"
		fi
	done
	#check parameters
	if [ -z "$REGEX" ] ; then
		printf "\nperlregex(): Missing regex parameter."
		exit 3
	fi
	if [ -z "$LIST" ] ; then
		LIST=$(find 720p -type f)
	fi
	debug "Files are '$LIST'."
	debug "Regex is '$REGEX'."
	#apply regex
	local OLDIFS=$IFS ; IFS=$'\n' ; for FILE in $LIST ; do
		#printf "\n$FILE" ; continue
		if [ -z "$FILE" ] ; then continue ; fi
		cat "$FILE" | tr '\n' '#' | ssed -R "$REGEX" | tr '#' '\n' >"$FILE.tmp"
		if [ $? -gt 0 ]; then
			printf "\nperlregex(): ERROR applying the regex."
			printf "\n"
			printf "\nFile is: '$FILE'."
			printf "\nRegex is: '$REGEX'."
			exit 3
		fi
		mv -f "$FILE.tmp" "$FILE"
	done ; IFS=$OLDIFS
}


# removes <$STRUCTURE$TAGS> .... </$STRUCTURE> structure from a xml file
# the controle structure to remove is identified by the characteristic line
# $1 type of structure (control, include, etc...)
# $2 structure tags ( type="" id="", etc...)
# $3 characteristic line
# $4 .xml file ; if empty, all occurrencies are searched
remove_structure() {
	local TYPE=$1
	local TAGS=$2
	local LINE="$3"
	LINE=$(echo $LINE | sed 's|^<|\\s\*<|g')
	LINE=$(echo $LINE | sed 's|>$|>#|g')
	local REGEX='s|\s*<'"$TYPE""$TAGS"'>#'
	local FILE="$4"
	REGEX+='(\s*<[a-z][^#]*#\|)*?' # matching lines beginning with any opening tag
	REGEX+="$LINE"
	REGEX+='(\s*<[a-z][^#]*#\|)*?' # matching lines beginning with any opening tag
	REGEX+='\s*</'"$TYPE"'>#'
	REGEX+='||g'
	perlregex "$REGEX" "$FILE"	
}


# removes <control type="?"> .... </control> structure from a xml file
# this function removes only controls without an id!
# the controle structure to remove is identified by the characteristic line
# $1 type of controle (image, button, etc...)
# $2 characteristic line
# $3 .xml file ; if empty, all occurrencies are searched
remove_control() {
	local TYPE=$1
	local LINE="$2"
	local FILE="$3"
	remove_structure "control" " type=\"$TYPE\"" "$LINE" "$FILE"
}



# removes <control type="?"> .... </control> structure from a xml file
# this function removes also controls with an id!
# the controle structure to remove is identified by the characteristic line
# $1 type of controle (image, button, etc...)
# $2 characteristic line
# $3 .xml file ; if empty, all occurrencies are searched
remove_controlid() {
	local TYPE=$1
	local LINE="$2"
	local FILE="$3"
	remove_structure "control" " type=\"$TYPE\"[^>]*" "$LINE" "$FILE"
}


# Checks if an image file is linked from within the xmls ; if not, the image is deleted
# If the image is still mentioned in the gui files, this function will exit and show an error message.
# $1 image file with full path
check_and_remove() {
	local FILE=$1
	if [ ! -f "$FILE" ] ; then
		#printf "\n'$FILE' doesn't exist."
		return 0
	fi
	
	local FILENAME=$(basename "$FILE")
	if ! grep -I -q "[^a-z]$FILENAME" 720p/* ; then
		
		local BASE=$(echo "$FILENAME" | sed 's|\.[a-zA-Z]*||g')

		if ! grep -I -q "[^a-z]$BASE[^a-zA-Z0-9 _]" 720p/* ; then
			rm "$FILE" # 2>/dev/null
		else
			printf "\n'$BASE' ('$FILE') was found in the .xmls: "
			grep "$BASE" 720p/*
			exit 3
		fi
	else
		printf "\n'$FILENAME' ('$FILE') was found in the .xmls: "
		grep "$FILENAME" 720p/*
		exit 3
	fi
}


read_origmaster() {
	local URL='https://github.com/Mudislander/skin.confluence.custom.mod/archive/master.zip'
	local ZIP='Mudislander-master.zip'
	printf "\nDownloading from GitHub."
	#wget -O- --no-check-certificate --progress=bar "$URL" >"$ZIP"
	curl -L --progress-bar "$URL" >"$ZIP"
	mkdir -p Mudislander-master
	printf "\nExtracting the archive."
	unzip -o -q "$ZIP" -d Mudislander-master
	printf "\nCopying the files to the right place."
	rm -rf media
	rm -rf backgrounds
	rm -rf colors
	rm -rf language
	rm -rf themes
	rm -rf extras
	cp -rf Mudislander-master/skin.confluence.custom.mod-master/* .
	cp -rf lightmod/* .
	printf "\nCopied all files."
}


if [ "$1" == "read" ] || [ "$1" == "readexit" ] ; then
	printf "\n############# BUILDING BASE FILES #############################################"
	printf "\nReading original repository."
	read_origmaster
	printf "\nCompleted creating the base files."
	if [ "$1" == "readexit" ] ; then
		exit
	fi
fi


#remove temporary files (if script was canceled before)
rm 720p/*.tmp 2>/dev/null

printf "\n############# APPLYING GENERIC/SKIN-WIDE MODIFICATIONS ########################"

printf "\nCorrecting wrong translation: "
if grep -q -zo -P 'msgctxt "#31153"\nmsgid "Home Menu"\nmsgstr "Gesehen Status Overlay benutzen"' \
	language/German/strings.po 
then
	sed "s|Gesehen Status Overlay benutzen|Hauptmenü|" -i language/German/strings.po
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving media files: "
if [ -f media/defaultDVDFull.png ] ; then
	check_and_remove media/icon-weather.png
	check_and_remove media/icon-video.png
	check_and_remove media/icon_volume.png
	check_and_remove media/poster_diffuse.png
	check_and_remove media/OSDFullScreenFO.png
	check_and_remove media/OSDFullScreenNF.png
	check_and_remove media/defaultDVDFull.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging texture for items without focus: "
if grep -q '>button-nofocus.png' 720p/* | head -n 1 ; then
	R='s|(<(item\|focused\|ruler\|channel)layout [^#]*#'
	# matching lines beginning with any opening tag and </control>:
	R+='(\s*<[a-z][^#]*#\|\s*</control>#)*?'
	R+='\s*<texture) border="[0-9]*">button-nofocus.png</texture>'
	R+='|\1>black-back.png</texture>|g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging default texture for controls without focus: "
if grep -q '>button-nofocus.png' 720p/* | head -n 1 ; then
	R='s|(<default type="[^#]*#'
	R+='(\s*<[a-z][^#]*#)*?' # matching lines beginning with any opening tag
	R+='\s*<texturenofocus) border="[0-9]*">button-nofocus.png</texturenofocus>'
	R+='|\1>black-back.png</texturenofocus>|g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging default texture for control presets without focus: "
if grep -q '>button-nofocus.png' 720p/* | head -n 1 ; then
	R='s|(<include name="Button[^#]*#'
	R+='(\s*<[a-z][^#]*#)*?' # matching lines beginning with any opening tag
	R+='\s*<texturenofocus) border="[0-9]*">button-nofocus.png</texturenofocus>'
	R+='|\1>black-back.png</texturenofocus>|g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging texture for controls without focus: "
if grep -q '>button-nofocus.png' 720p/* | head -n 1 ; then
	R='s|(<control type="[^#]*#'
	R+='(\s*(<[a-z]\|<!--)[^#]*#)*?' # matching lines beginning with any opening tag and comments
	R+='\s*<texturenofocus) border="[0-9]*">button-nofocus.png</texturenofocus>'
	R+='|\1>black-back.png</texturenofocus>|g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging alttexture for controls without focus: "
if grep -q '>button-nofocus.png' 720p/* | head -n 1 ; then
	R='s|(<control type="[^#]*#'
	R+='(\s*<[a-z][^#]*#)*?' # matching lines beginning with any opening tag
	R+='\s*<alttexturenofocus) border="[0-9]*">button-nofocus.png</alttexturenofocus>'
	R+='|\1>black-back.png</alttexturenofocus>|g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving button-nofocus.png bordertextures: "
if grep -q '>button-nofocus.png' 720p/* | head -n 1 ; then
	R='s|(\s*<bordertexture border="[0-9]*"[^>]*>button-nofocus.png</bordertexture>#\|'
	R+='\s*<bordersize>[0-9]*</bordersize>#){2}'
	R+='||g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving button-nofocus.png where used as border background: "
if grep -q '>button-nofocus.png' 720p/* | head -n 1 ; then
	R='s|\s*<control type="image">#'
	R+='(\s*<[a-z][^#]*#)*?' # matching lines beginning with any opening tag
	R+='\s*<height>[23456789][0-9][0-9]</height>#' # 200 or more pixels high
	R+='\s*<texture border="[0-9]">button-nofocus.png</texture>#'
	R+='\s*</control>#'
	R+='||g'
	perlregex "$R"
	check_and_remove media/button-nofocus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving reflections: "
if grep -q 'diffuse_mirror[23].png' 720p/* | head -n 1 ; then
	remove_control 'image' '<texture[^>]*diffuse="diffuse_mirror[23].png"[^>]*>[^<]*</texture>'
	check_and_remove media/diffuse_mirror2.png
	check_and_remove media/diffuse_mirror3.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging dialog background: "
if grep -I -q "DialogBack.png" 720p/* ; then
	R='s|(\s*)<texture border="[0-9]*">DialogBack.png</texture>'
	R+='|\1<texture>white100_light.png</texture>#\1<colordiffuse>DF101314</colordiffuse>|g'
	perlregex "$R"
	check_and_remove media/DialogBack.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
		
printf "\nRemoving mouse close buttons: "
if grep -I -q '>DialogCloseButton.png' 720p/* ; then
	remove_controlid 'button' '<texturenofocus>DialogCloseButton.png</texturenofocus>'
	check_and_remove media/DialogCloseButton.png
	check_and_remove media/DialogCloseButton-focus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
	
printf "\nReplacing content panel background: "
if grep -I -q 'ContentPanel.png' 720p/* ; then	
	perlregex 's|<texture[^>]*>ContentPanel.png|<texture>black-back.png|g'
	check_and_remove media/ContentPanel.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi	
	
printf "\nReplacing default background: "
if grep -I -q 'SKINDEFAULT.jpg' 720p/* ; then
	perlregex 's|<value>special://skin/backgrounds/SKINDEFAULT.jpg</value>|<value>special://skin/extras/lightmod/default.jpg</value>|g'
	perlregex 's|.INFO.Skin.CurrentTheme,special://skin/backgrounds/,.jpg.|special://skin/extras/lightmod/default.jpg|g'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi	
	
printf "\nRemoving hidden panel arrow: "	
if grep -I -q HasSub.png 720p/* ; then
	perlregex 's|<texturefocus>HasSub.png</texturefocus>|<texturefocus>-</texturefocus>|g'
	perlregex 's|<texturenofocus>HasSub.png</texturenofocus>|<texturenofocus>-</texturenofocus>|g'
	check_and_remove media/HasSub.png	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi	

printf "\nRemoving xbmc logo: "
if grep -I -q xbmc-logo.png 720p/* ; then
	#remove logo from all screens
	remove_control 'image' '<texture>xbmc-logo.png</texture>'
	#remove logo fallback from music visualisation
	perlregex 's| fallback="xbmc-logo.png"||g'
	check_and_remove media/xbmc-logo.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi	
	
printf "\nReplacing scroll bars: "
if grep ScrollBarH.png 720p/* >/dev/null ; then
	perlregex 's|ScrollBarH_bar.png|ScrollBarH_bar_light.png|g'
	perlregex 's|ScrollBarV_bar.png|ScrollBarV_bar_light.png|g'
	perlregex 's|ScrollBarH.png|ScrollBarH_light.png|g'
	perlregex 's|ScrollBarV.png|ScrollBarV_light.png|g'
	check_and_remove 'media/ScrollBarH_bar.png'
	check_and_remove 'media/ScrollBarV_bar.png'
	check_and_remove 'media/ScrollBarH.png'
	check_and_remove 'media/ScrollBarV.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
	
printf "\nRemoving GlassOverlay.png: "
if grep -I -q 'GlassOverlay.png' 720p/* ; then
	remove_control 'image' '<texture>GlassOverlay.png</texture>'
	check_and_remove media/GlassOverlay.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving separators: "
if grep -q separator.png 720p/* | head -n 1 ; then
	remove_control 'image' '<texture>separator(\|2).png</texture>'
	#not all controls can be removed, some have an id and are used for navigation
	perlregex 's|separator2.png|-|g'
	check_and_remove media/separator.png
	check_and_remove media/separator2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
	
printf "\nRemoving menu items separator 'MenuItemNF.png': "
if grep -I -q 'MenuItemNF.png' 720p/* ; then
	#remove all image controls using it as texture
	remove_control 'image' '<texture[^>]*>MenuItemNF.png</texture>'
	#replace when used as texture for controls without focus
	R='s|(<control type="[^#]*#'
	R+='(\s*(<[a-z]\|<!--)[^#]*#)*?' # matching lines beginning with any opening tag and comments
	R+='\s*<texturenofocus)(\| border="[0-9,]*")>MenuItemNF.png</texturenofocus>'
	R+='|\1>black-back.png</texturenofocus>|g'
	perlregex "$R"
	check_and_remove 'media/MenuItemNF.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving content panel mirrors: "
if grep -I -q 'ContentPanelMirror' 720p/* ; then
	remove_control 'image' '<texture[^>]*>ContentPanelMirror.png</texture>'
	check_and_remove 'media/ContentPanelMirror.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving floor image: "
if grep -I -q '>floor.png' 720p/* ; then
	remove_control 'image' '<texture[^>]*>floor.png</texture>'
	check_and_remove 'media/floor.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving HomeNowPlayingBack.png: "
if grep -I -q '<texture flipy="true">HomeNowPlayingBack.png' 720p/* ; then
	remove_control 'image' '<texture[^>]*>HomeNowPlayingBack.png</texture>'
	#remove behind time label on video osd, but not behind seek bar
	remove_controlid 'image' '<texture flipy="true">HomeNowPlayingBack.png</texture>'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving thumb shadows: "
if grep -q '>ThumbShadow.png' 720p/* | head -n 1 ; then
	R='s|(\s*<bordertexture[^>]*>ThumbShadow.png</bordertexture>#\|'
	R+='\s*<bordersize>[0-9]*</bordersize>#){2}'
	R+='||g'
	perlregex "$R"
	R='s|\s*<bordertexture border="8">ThumbShadow.png</bordertexture>#'
	R+='(\s*<visible>!Skin.HasSetting.HideEpisodeThumb. . StringCompare.ListItem.Label,...</visible>#)'
	R+='\s*<bordersize>8</bordersize>#'
	R+='|\1|g'
	perlregex "$R"
	check_and_remove 'media/ThumbShadow.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving thumb background: "
if grep -I -q 'ThumbBG.png' 720p/* ; then
	remove_control 'image' '<texture border="2">ThumbBG.png</texture>'
	check_and_remove 'media/ThumbBG.png'	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving thumb border: "
if grep -I -q 'ThumbBorder.png' 720p/* ; then
	R='s|(\s*<bordertexture[^>]*>ThumbBorder.png</bordertexture>#\|'
	R+='\s*<bordersize>[0-9]*</bordersize>#){2}'
	R+='||g'
	perlregex "$R"
	R='s|\s*<bordersize>8</bordersize>#'
	R+='(\s*<texture background="true">.VAR.PosterThumb.</texture>#)'
	R+='\s*<bordertexture border="8">ThumbBorder.png</bordertexture>#'
	R+='|\1|g'
	perlregex "$R"
	check_and_remove media/ThumbBorder.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving page count info: "
if grep -I -q 'CommonPageCount' 720p/* ; then		
	#includes
	perlregex 's|\s*<include[^>]*>CommonPageCount</include>\s*#||g'
	#CommonPageCount definition
	R='s|\s*<include name="CommonPageCount">\s*#'
	R+='(\s*(<[a-z][^#]*\|</control>)#)*?'
	R+='\s*</include>\s*#||'
	perlregex "$R"
	if grep -I -q 'CommonPageCount' 720p/* ; then
		printf "\nError: CommonPageCount could not be removed totally."
		exit 3
	fi
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging time display: "
if grep -I -q '<description>date label</description>' 720p/* ; then
	#remove date label - in 720p\includes.xml and 720p\VideoFullScreen.xml
	remove_controlid 'label' '<description>date label</description>'
	#move time label up
	R='s|(<control type="label"[^>]*>\s*#'
	R+='\s*<description>time label</description>\s*#'
	R+='\s*<posx>15r</posx>\s*#'
	R+='\s*<posy)>20<|\1>5<|'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nEnabling German movie ratings: "
if ! grep -I -q 'fsk-18' '720p/IncludesVariables.xml' ; then
	#uncommenting the "Germany" option from the settings window
	R='s|<!--(item>\s*#'
	R+='\s*<label>.LOCALIZE.31702.</label>\s*#'
	R+='\s*<onclick>noop</onclick>\s*#'
	R+='\s*<icon>.</icon>\s*#'
	R+='\s*<thumb>.</thumb>\s*#'
	R+='\s*</item>\s*#'
	R+='\s*)<item>'
	R+='|<\1<!--item>|'
	perlregex "$R" 720p/SkinSettings.xml
	#choose right flag depending on the FSK
	R='s|(#\s*)(<variable name="rating">).*?#|\1\2'
	R+='\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,18)">de/fsk-18</value>'
	R+='\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,16)">de/fsk-16</value>'
	R+='\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,12)">de/fsk-12</value>'
	R+='\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,6)">de/fsk-6</value>'
	R+='\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,0)">de/fsk-0</value>'
	R+='\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,o)">de/fsk-0</value>'
	R+='\n\n|' 
	perlregex '720p/IncludesVariables.xml' "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving references to 'media/separator_vertical.png': "
if grep -I -q "separator_vertical.png" 720p/* ; then
	remove_control 'image' '<texture>separator_vertical.png</texture>'
	check_and_remove media/separator_vertical.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\n############# APPLYING HOME SCREEN MODIFICATIONS ##############################"

printf "\nReplacing submenus item texture (for items that are not focused): "
if grep -I -q 'HomeSubNF.png' 720p/* ; then
	perlregex 's|HomeSubNF.png|HomeSubNF_light.png|g'
	check_and_remove media/HomeSubNF.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nModifying weather info: "
if grep -I -q '<description>Location label</description>' '720p/Home.xml' ; then
	#remove weather location
	remove_control 'label' '<description>Location label</description>' 720p/Home.xml
	#center temp label
	R='s|(<posx>65</posx>\s*#'
	R+='\s*<posy)>20</posy>'
	R+='|\1>15</posy>|'
	perlregex 720p/Home.xml "$R"
	#remove weather condition
	remove_control 'label' '<description>Conditions Label</description>' 720p/Home.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving Main menu side fade effect: "
if grep -q SideFade.png 720p/* | head -n 1 ; then
	remove_control 'image' '<texture[^>]*>SideFade.png</texture>'
	check_and_remove media/SideFade.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving Main menu items separator: "
if grep -I -q 'HomeSeperator' '720p/Home.xml' ; then
	remove_control 'image' '<texture>HomeSeperator.png</texture>'
	check_and_remove 'media/HomeSeperator.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving main menu overlay: "
if grep -I -q 'HomeOverlay1.png' '720p/Home.xml' ; then
	remove_control 'image' '<texture>HomeOverlay1.png</texture>'
	check_and_remove 'media/HomeOverlay1.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging addons on the home screen: "
if grep -q '<posx>91</posx>' 720p/includes.xml | head -n 1 ; then
	#remove label for addons that are not focused on the home view
	remove_control 'label' '<posx>91</posx>' 720p/includes.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging widgets on the home screen: "
if grep -I -q 'RecentAddedBack.png' 720p/* ; then
	#removing widgets background
	remove_control 'image' '<texture[^>]*>RecentAddedBack.png</texture>'
	#widget group title label
	remove_control 'label' '<description>Title label</description>' '720p/IncludesHomeWidget.xml'
	#label for widgets without focus
	remove_control 'label' '<textcolor>white</textcolor>' '720p/IncludesHomeWidget.xml'
	remove_control 'label' '<textcolor>grey2</textcolor>' '720p/IncludesHomeWidget.xml'
	check_and_remove 'media/RecentAddedBack.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving home floor: "
if grep -I -q "homefloor.png" 720p/* ; then
	remove_control 'image' '<texture>homefloor.png</texture>' 720p/Home.xml
	check_and_remove media/homefloor.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\n############# APPLYING MODIFICATIONS TO PICTURE LIBRARY #######################"

printf "\nChanging picture views to use thumbnails for preview: "
if grep -I -q '<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>' 720p/ViewsPictures.xml
then
	perlregex 720p/ViewsPictures.xml 's|<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>|<texture background="true">\$INFO\[ListItem.Icon\]</texture>|g'
	perlregex 720p/MyPics.xml 's|<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>|<texture background="true">\$INFO\[ListItem.Icon\]</texture>|g'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
	
# change picturethumbview
printf "\nChanging picture preview/thumb view: "
if grep -I -q '<description>Date time txt</description>' 720p/ViewsPictures.xml ; then
	#resize left selection panel (to 1 column, 6 rows and fixedlist)
	R='s|(\s*<control type)="panel" id="514">\s*#'
	R+='(\s*<posx>60</posx>\s*#)'
	R+='(\s*)<posy>75</posy>\s*#'
	R+='(\s*)<width>432</width>\s*#'
	R+='(\s*)<height>576</height>\s*#'
	R+='|\1="fixedlist" id="514">#'
	R+='\2\3\<posy>-72</posy>#'
	R+='\4<width>144</width>#'
	R+='\5<height>864</height>#'
	R+='\5<focusposition>1</focusposition>#|'
	perlregex 720p/ViewsPictures.xml "$R"
	#resize background of the left panel accordingly
	R='s|(\s*<visible>Control.IsVisible.514.</visible>\s*#'
	R+='\s*<control type="image">\s*#'
	R+='\s*<posx>50</posx>\s*#'
	R+='\s*)<posy>60</posy>(\s*#'
	R+='\s*)<width>490</width>(\s*#'
	R+='\s*)<height>600</height>'
	R+='|\1<posy>-15</posy>\2<width>202</width>\3<height>750</height>|'
	perlregex 720p/IncludesBackgroundBuilding.xml "$R"
	#move the scrollbar of the selection panel left
	R='s|(\s*<control type="scrollbar" id="60">\s*#)'
	R+='(\s*)<posx>500</posx>|\1\2<posx>212</posx>|'
	perlregex 720p/ViewsPictures.xml "$R"
	#resize and move the picture preview on the right
	perlregex 720p/ViewsPictures.xml 's|<posx>570</posx>|<posx>282</posx>|'
	perlregex 720p/ViewsPictures.xml 's|<width>640</width>|<width>928</width>|g'
	perlregex 720p/ViewsPictures.xml 's|<height>470</height>|<height>570</height>|g'
	#and the background of the preview on the right side accordingly
	R='s|<width>680</width>\s*#'
	R+='(\s*)<height>600</height>|<width>968</width>#\1<height>640</height>|'
	perlregex 720p/IncludesBackgroundBuilding.xml "$R"
	perlregex 720p/IncludesBackgroundBuilding.xml 's|<posx>550</posx>|<posx>262</posx>|'
	#remove date+res labels for the preview panel
	remove_control 'label' '<description>Date time txt</description>' 720p/ViewsPictures.xml
	remove_control 'label' '<description>Resolution txt</description>' 720p/ViewsPictures.xml
	#add border texture directly to the picture that is focused in the left selection panel
	R='s|(<control type="image">\s*#'
	R+='\s*)<posx>10</posx>(\s*#'
	R+='\s*)<posy>10</posy>(\s*#'
	R+='\s*)<width>124</width>(\s*#'
	R+='\s*)<height>124</height>(\s*#'
	R+='\s*<aspectratio>keep</aspectratio>\s*#)'
	R+='(\s*)(<texture background="true">.INFO.ListItem.Icon.</texture>\s*#'
	R+='\s*</control>\s*#'
	R+='\s*</focusedlayout>\s*#)'
	R+='|\1<posx>8</posx>\2<posy>8</posy>\3<width>128</width>\4<height>128</height>\5'
	R+='\6<bordersize>2</bordersize>#'
	R+='\6<bordertexture border="2">folder-focus.png</bordertexture>#'
	R+='\6\7|'
	perlregex 720p/IncludesBackgroundBuilding.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nRemoving location header: "
if grep -I -q '<description>Section header image</description>' 720p/MyPics.xml 
then
	#section icon
	remove_control 'image' '<description>Section header image</description>' 720p/MyPics.xml
	#remove location labels
	remove_control 'label' '<include>WindowTitleCommons</include>' 720p/MyPics.xml
	#remove location grouplist
	R='s|\s*<control type="grouplist">\s*#'
	R+='\s*<posx>65</posx>\s*#'
	R+='\s*<posy>5</posy>\s*#'
	R+='(\s*<(height\|width\|orientation\|align\|itemgap\|aspectratio\|texture\|visible\|label)>[^>]*>\s*?#)*'
	R+='\s*</control>\s*#||'
	perlregex 720p/MyPics.xml "$R"
	check_and_remove media/icon_pictures.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\n############# APPLYING MODIFICATIONS TO VIDEO LIBRARY #########################"

printf "\nRemoving location info: "
if grep -I -q '<description>Section header image</description>' 720p/MyVideoNav.xml
then
	#remove sections icon
	remove_control 'image' '<description>Section header image</description>' 720p/MyVideoNav.xml
	#remove location labels
	remove_control 'label' '<include>WindowTitleCommons</include>' 720p/MyVideoNav.xml
	#remove location grouplist
	R='s|\s*<control type="grouplist">\s*#'
	R+='\s*<posx>65</posx>\s*#'
	R+='\s*<posy>5</posy>\s*#'
	R+='(\s*<(height\|width\|orientation\|align\|itemgap\|aspectratio\|texture\|visible\|label)>[^>]*>\s*?#)*'
	R+='\s*</control>\s*#||'
	perlregex 720p/MyVideoNav.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

#printf "\n############# APPLYING MODIFICATIONS TO VIDEO OSD #############################"

printf "\n############# APPLYING MODIFICATIONS TO SPECIAL DIALOGS #######################"

printf "\nChanging shutdown menu: "
if grep -I -q "DialogContextTop.png" 720p/* ; then
	remove_controlid 'image' '<description>background [a-z]* image</description>' 720p/DialogButtonMenu.xml
	perlregex '720p/DialogButtonMenu.xml' 's|texturenofocus border="25,5,25,5">ShutdownButtonNoFocus.png|texturenofocus>black-back.png|g'
	perlregex '720p/DialogButtonMenu.xml' 's|ShutdownButtonFocus.png|button-focus.png|g'
	check_and_remove media/ShutdownButtonFocus.png
	check_and_remove media/ShutdownButtonNoFocus.png
	check_and_remove media/DialogContextBottom.png
	check_and_remove media/DialogContextMiddle.png
	check_and_remove media/DialogContextTop.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "\nChanging context menu: "
if grep -I -q '<itemgap>2</itemgap>' 720p/DialogContextMenu.xml ; then
	#remove itemgap
	perlregex '720p/DialogContextMenu.xml' 's|<itemgap>2</itemgap>|<itemgap>0</itemgap>|g'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

#removed up and down arrows
if grep -I -q '<texturefocus>arrow-big-down.png</texturefocus>' 720p/* ; then
	printf "\nRemoving up and down arrows from several dialogs: "
	remove_control 'button' '<texturefocus>arrow-big-up.png</texturefocus>'
	remove_control 'button' '<texturefocus>arrow-big-down.png</texturefocus>'
	check_and_remove media/arrow-big-up.png
	check_and_remove media/arrow-big-down.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi

printf "%s\nAll modifications are completed.%s" $GREEN $RESET

exit


	#changing texturenofocus for buttons (instead default one)
	perlregex '720p/DialogContextMenu.xml' 's|(\s*)<description>button template</description>|\1<description>button template</description>#\1<texturenofocus>black-back.png</texturenofocus>|g'
	perlregex '720p/DialogContextMenu.xml' 's|(\s*)<description>Watch it Later</description>|\1<description>Watch it Later</description>#\1<texturenofocus>black-back.png</texturenofocus>|g'		
