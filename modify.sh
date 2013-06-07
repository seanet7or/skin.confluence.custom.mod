#!/bin/bash
#set -e
SCRIPTFILE=$0
set -o pipefail
2>/dev/null rm debug.log
DEBUG=false
TILL=0

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
	#debug "Files are '$LIST'."
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
		printf "\nREGEX: '$REGEX'."
	fi
}


# removes <$STRUCTURE$TAGS> .... </$STRUCTURE> structure from a xml file
# the controle structure to remove is identified by the characteristic line
# $1 type of structure (control, include, etc...)
# $2 structure tags ( type="" id="", etc...)
# $3 characteristic line
# $4 files where to search
remove_structure() {
	TYPE=$1
	TAGS=$2
	LINE="$3"
	FILES=$4
	debug "remove_structure() entered."
	debug "Parameters are: TYPE='$TYPE'."
	debug "TAGS='$TAGS'."
	debug "LINE='$LINE'."
	debug "FILES='$FILES'."
	if [ -z "$FILES" ] ; then
		FILES=$( local STRUCT='<'"$TYPE""$TAGS"'>'
			debug "Structure is '$STRUCT'."
			for F in $( egrep -l -q "$LINE" 720p/* ) ; do
			debug "'$F' contains '$LINE'."
			if grep -q -l '<'"$TYPE""$TAGS"'>' $F ; then
				debug "'$F' contains also '$STRUCT'."
				echo \"$F\"
			fi
		done )
	fi
	LINE=$(echo $LINE | sed 's|^<|\\s\*<|g')
	LINE=$(echo $LINE | sed 's|>$|>#|g')
	local REGEX='s|\s*<'"$TYPE""$TAGS"'>#'
	REGEX+='(\s*<[a-z][^#]*#\|)*?' # matching lines beginning with any opening tag
	REGEX+="$LINE"
	REGEX+='(\s*<[a-z][^#]*#\|)*?' # matching lines beginning with any opening tag
	REGEX+='\s*</'"$TYPE"'>#'
	REGEX+='||g'
	debug "Calling 'perlregex $FILES'."
	perlregex "$REGEX" "$FILES"
}


# removes <control type="?"> .... </control> structure from a xml file
# this function removes only controls without an id!
# the controle structure to remove is identified by the characteristic line
# $1 type of controle (image, button, etc...)
# $2 characteristic line
# $3 files where to search
remove_control() {
	local TYPE=$1
	local LINE="$2"
	local FILES=$3
	remove_structure "control" " type=\"$TYPE\"" "$LINE" $FILES
}



# removes <control type="?"> .... </control> structure from a xml file
# this function removes also controls with an id!
# the controle structure to remove is identified by the characteristic line
# $1 type of controle (image, button, etc...)
# $2 characteristic line
# $3 files where to search
remove_controlid() {
	local TYPE=$1
	local LINE="$2"
	local FILES=$3
	remove_structure "control" " type=\"$TYPE\"[^>]*" "$LINE" $FILES
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
	printf "Extracting the archive."
	unzip -o -q "$ZIP" -d Mudislander-master
	printf "\nCopying the files to the right place."
	rm -rf media
	rm -rf backgrounds
	rm -rf colors
	rm -rf language
	rm -rf extras
	rm -rf themes 2>/dev/null
	rm -rf Mudislander-master/skin.confluence.custom.mod-master/themes
	cp -rf Mudislander-master/skin.confluence.custom.mod-master/* .
	cp -rf lightmod/* .
	printf "\nCopied all files."
}


step() {
	let MAXSTEPS=54   
	STEP=$((STEP+1))
	if [ $STEP -gt $MAXSTEPS ] ; then
		sed -i 's|let MAXSTEPS=[0-9]*|let MAXSTEPS='$MAXSTEPS'|' "$SCRIPTFILE"
	fi
	printf " [$STEP/%d] " $MAXSTEPS
	if [ $TILL -gt 0 ] ; then
		if [ $STEP -eq $TILL ] ; then
			printf "\n Step $STEP reached, exiting."
			exit 0
		fi
	fi
}


####################################### CODE STARTS HERE! ####################################
debug "Parsing parameters."
for I in "$@" ; do
	debug "Read parameter '$I'."
	if [ "$I" == "--debug" ] ; then
		DEBUG=true
		continue
	fi
	if echo "$I" | egrep 'steps=[0-9]*' ; then
		TILL=$(echo "$I" | cut -f2 -d'=')
		printf "\n Running till step %d." $TILL
	fi
done

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

BUTTON_NF='button-nf_light.png'
BUTTON_FO='button-focus_light.png'
DIALOG_BG='dialog-back_light.png'
DIALOG_BG_COLOR='DF101314'
CONTENT_BG='content-back_light.png'
BACKGROUND_DEF='special://skin/backgrounds/default_light.jpg'
SCROLLBAR_HOR_BAR='ScrollBarH_bar_light.png'
SCROLLBAR_VER_BAR='ScrollBarV_bar_light.png'
SCROLLBAR_HOR='ScrollBarH_light.png'
SCROLLBAR_VER='ScrollBarV_light.png'
SCROLLBAR_HOR_BAR_FO='ScrollBarH_bar_focus_light.png'
SCROLLBAR_VER_BAR_FO='ScrollBarV_bar_focus_light.png'
printf "\nBUTTON_NF: '%s'" $BUTTON_NF
printf "\nBUTTON_FO: '%s'" $BUTTON_FO''
printf "\nDIALOG_BG: '%s'" $DIALOG_BG
printf "\nDIALOG_BG_COLOR: '%s'" $DIALOG_BG_COLOR
printf "\nCONTENT_BG: '%s'" $CONTENT_BG
printf "\nBACKGROUND_DEF: '%s'" $BACKGROUND_DEF
printf "\nSCROLLBAR_HOR_BAR: '%s'" $SCROLLBAR_HOR_BAR
printf "\nSCROLLBAR_VER_BAR: '%s'" $SCROLLBAR_HOR_BAR
printf "\nSCROLLBAR_HOR: '%s'" $SCROLLBAR_HOR
printf "\nSCROLLBAR_VER: '%s'" $SCROLLBAR_VER
printf "\nSCROLLBAR_HOR_BAR_FO: '%s'" $SCROLLBAR_HOR_BAR_FO
printf "\nSCROLLBAR_VER_BAR_FO: '%s'" $SCROLLBAR_HOR_BAR_FO


STEP=0
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
step

printf "\nRemoving media files: "
if [ -f media/defaultDVDFull.png ] ; then
	check_and_remove media/icon_volume.png
	check_and_remove media/poster_diffuse.png
	check_and_remove media/OSDFullScreenFO.png
	check_and_remove media/OSDFullScreenNF.png
	check_and_remove media/defaultDVDFull.png
	check_and_remove backgrounds/Fire.jpg
	check_and_remove backgrounds/Kryptonite.jpg
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging texture for items without focus: "
if [ -f media/button-nofocus.png ] ; then
	XMLS=$(2>/dev/null grep 'button-nofocus.png</texture>' -l 720p/*)
	R='s|(<(item\|focused\|ruler\|channel)layout [^#]*#'
	# matching lines beginning with any opening tag and </control>:
	R+='(\s*<[a-z][^#]*#\|\s*</control>#)*?'				
	R+='\s*<texture) border="[0-9]*">button-nofocus.png</texture>'
	R+='|\1>'$BUTTON_NF'</texture>|g'
	perlregex "$R" $XMLS
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging default texture for controls without focus: "
if [ -f media/button-nofocus.png ] ; then
	R='s|(<default type="[^#]*#'
	R+='(\s*<[a-z][^#]*#)*?' # matching lines beginning with any opening tag
	R+='\s*<texturenofocus) border="[0-9]*">button-nofocus.png</texturenofocus>'
	R+='|\1>'$BUTTON_NF'</texturenofocus>|g'
	perlregex "$R" 720p/defaults.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging default texture for control presets without focus: "
if [ -f media/button-nofocus.png ] ; then
	R='s|(<include name="Button[^#]*#'
	R+='(\s*<[a-z][^#]*#)*?' # matching lines beginning with any opening tag
	R+='\s*<texturenofocus) border="[0-9]*">button-nofocus.png</texturenofocus>'
	R+='|\1>'$BUTTON_NF'</texturenofocus>|g'
	perlregex "$R" 720p/includes.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #5

printf "\nChanging texture for controls without focus: "
if [ -f media/button-nofocus.png ] ; then
	XMLS=$(2>/dev/null grep 'button-nofocus.png</texturenofocus>' -l 720p/*)
	R='s|(<control type="[^#]*#'
	R+='(\s*(<[a-z]\|<!--)[^#]*#)*?' # matching lines beginning with any opening tag and comments
	R+='\s*<texturenofocus) border="[0-9]*">button-nofocus.png</texturenofocus>'
	R+='|\1>'$BUTTON_NF'</texturenofocus>|g'
	perlregex "$R" $XMLS
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #6

printf "\nChanging alttexture for controls without focus: "
if [ -f media/button-nofocus.png ] ; then
	XMLS=$(2>/dev/null grep 'button-nofocus.png</alttexturenofocus>' -l 720p/*)
	R='s|(<control type="[^#]*#'
	R+='(\s*<[a-z][^#]*#)*?' # matching lines beginning with any opening tag
	R+='\s*<alttexturenofocus) border="[0-9]*">button-nofocus.png</alttexturenofocus>'
	R+='|\1>'$BUTTON_NF'</alttexturenofocus>|g'
	perlregex "$R" $XMLS
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #7

printf "\nRemoving button-nofocus.png bordertextures: "
if [ -f media/button-nofocus.png ] ; then
	XMLS=$(2>/dev/null grep 'button-nofocus.png</bordertexture>' -l 720p/*)
	R='s|(\s*<bordertexture border="[0-9]*"[^>]*>button-nofocus.png</bordertexture>#\|'
	R+='\s*<bordersize>[0-9]*</bordersize>#){2}'
	R+='||g'
	perlregex "$R" $XMLS
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #8

printf "\nRemoving button-nofocus.png where used as border background: "
if [ -f media/button-nofocus.png ] ; then
	XMLS=$(2>/dev/null grep 'button-nofocus.png</texture>' -l 720p/*)
	R='s|\s*<control type="image">#'
	R+='(\s*<[a-z][^#]*#)*?' # matching lines beginning with any opening tag
	R+='\s*<height>[23456789][0-9][0-9]</height>#' # 200 or more pixels high
	R+='\s*<texture border="[0-9]">button-nofocus.png</texture>#'
	R+='\s*</control>#'
	R+='||g'
	perlregex "$R" $XMLS
	check_and_remove media/button-nofocus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #9

printf "\nRemoving reflections: "
if [ -f media/diffuse_mirror3.png ] ; then
	remove_control 'image' '<texture[^>]*diffuse="diffuse_mirror[23].png"[^>]*>[^<]*</texture>'
	check_and_remove media/diffuse_mirror2.png
	check_and_remove media/diffuse_mirror3.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #10

printf "\nChanging dialog background: "
if [ -f media/DialogBack2.png ] ; then
	R='s|(\s*)<texture border="[0-9]*">DialogBack.png</texture>'
	R+='|\1<texture>'$DIALOG_BG'</texture>#\1<colordiffuse>'$DIALOG_BG_COLOR'</colordiffuse>|g'
	perlregex "$R"
	R='s|(\s*)<texture border="[0-9]*">DialogBack2.png</texture>'
	R+='|\1<texture>'$DIALOG_BG'</texture>#\1<colordiffuse>'$DIALOG_BG_COLOR'</colordiffuse>|g'
	perlregex "$R"
	check_and_remove media/DialogBack.png
	check_and_remove media/DialogBack2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #11
	
printf "\nChanging info message dialog background: "
if [ -f media/InfoMessagePanel.png ] ; then
	R='s|(\s*)<texture[^>]*>InfoMessagePanel.png</texture>'
	R+='|\1<texture>'$DIALOG_BG'</texture>#\1<colordiffuse>'$DIALOG_BG_COLOR'</colordiffuse>|g'
	perlregex "$R"
	check_and_remove media/InfoMessagePanel.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #11

printf "\nChanging dialog background overlay: "
if [ -f media/OverlayDialogBackground.png ] ; then
	R='s|<texturebg border="20">OverlayDialogBackground.png</texturebg>'
	R+='|<texturebg>'$BUTTON_NF'</texturebg>|g'
	perlregex "$R"
	R='s|(\s*)<texture border="[0-9]*">OverlayDialogBackground.png</texture>'
	R+='|\1<texture>'$DIALOG_BG'</texture>#\1<colordiffuse>'$DIALOG_BG_COLOR'</colordiffuse>|g'
	perlregex "$R"
	check_and_remove media/OverlayDialogBackground.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #12
	
printf "\nRemoving mouse close buttons: "
if [ -f  media/DialogCloseButton-focus.png ] ; then
	remove_controlid 'button' '<texturenofocus>DialogCloseButton.png</texturenofocus>'
	check_and_remove media/DialogCloseButton.png
	check_and_remove media/DialogCloseButton-focus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #13
	
printf "\nReplacing content panel background: "
if [ -f media/ContentPanel.png ] ; then	
	R='s|(\s*)<texture[^>]*>ContentPanel.png</texture>'
	R+='|\1<texture>'$CONTENT_BG'</texture>|g'
	perlregex "$R"
	check_and_remove media/ContentPanel.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #14
	
printf "\nReplacing some backgrounds: "
if [ -f backgrounds/media-overlay.jpg ] ; then
	perlregex 's|<value>special://skin/backgrounds/SKINDEFAULT.jpg</value>|<value>'$BACKGROUND_DEF'</value>|g'
	perlregex 's|.INFO.Skin.CurrentTheme,special://skin/backgrounds/,.jpg.|'$BACKGROUND_DEF'|g'
	perlregex 's|<texture>special://skin/backgrounds/media-overlay.jpg</texture>|<texture>'$BACKGROUND_DEF'</texture>|g'
	check_and_remove backgrounds/SKINDEFAULT.jpg
	check_and_remove backgrounds/media-overlay.jpg
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #15
	
printf "\nRemoving hidden panel arrow: "	
if [ -f media/HasSub.png ] ; then
	perlregex 720p/includes.xml 's|HasSub.png|-|g'
	check_and_remove media/HasSub.png	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #16

printf "\nRemoving xbmc logo: "
if grep -I -q xbmc-logo.png 720p/* ; then
	#remove logo from all screens
	remove_control 'image' '<texture>xbmc-logo.png</texture>'
	#remove logo fallback from music visualisation
	XMLS=$(2>/dev/null grep 'fallback="xbmc-logo.png"' -l 720p/*)
	perlregex 's| fallback="xbmc-logo.png"||g' $XMLS
	check_and_remove media/xbmc-logo.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #17
	
printf "\nReplacing scroll bars: "
if grep -q ScrollBarNib.png 720p/ViewsPictures.xml ; then
	XMLS=$(2>/dev/null grep 'ScrollBar' -l 720p/*)
	perlregex $XMLS 's|<texturesliderbar border="[0-9,]*">ScrollBarH_bar.png|<texturesliderbar>'$SCROLLBAR_HOR_BAR'|g'
	perlregex $XMLS 's|<texturesliderbar border="[0-9,]*">ScrollBarV_bar.png|<texturesliderbar>'$SCROLLBAR_VER_BAR'|g'
	perlregex $XMLS 's|<texturesliderbackground border="[0-9,]*">ScrollBarH.png|<texturesliderbackground>'$SCROLLBAR_HOR'|g'
	perlregex $XMLS 's|<texturesliderbackground border="[0-9,]*">ScrollBarV.png|<texturesliderbackground>'$SCROLLBAR_VER'|g'
	perlregex $XMLS 's|<texturesliderbarfocus border="[0-9,]*">ScrollBarH_bar_focus.png|<texturesliderbarfocus>'$SCROLLBAR_HOR_BAR_FO'|g'
	perlregex $XMLS 's|<texturesliderbarfocus border="[0-9,]*">ScrollBarV_bar_focus.png|<texturesliderbarfocus>'$SCROLLBAR_VER_BAR_FO'|g'
	perlregex $XMLS 's|\s*<textureslidernib>ScrollBarNib.png</textureslidernib>#||g'
	perlregex $XMLS 's|\s*<textureslidernibfocus>ScrollBarNib.png</textureslidernibfocus>#||g'	
	check_and_remove 'media/ScrollBarH_bar.png'
	check_and_remove 'media/ScrollBarV_bar.png'
	check_and_remove 'media/ScrollBarH.png'
	check_and_remove 'media/ScrollBarV.png'
	check_and_remove 'media/ScrollBarH_bar_focus.png'
	check_and_remove 'media/ScrollBarV_bar_focus.png'
	check_and_remove 'media/ScrollBarNib.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #18
	
printf "\nRemoving GlassOverlay.png: "
if grep -I -q 'GlassOverlay.png' 720p/* ; then
	remove_control 'image' '<texture>GlassOverlay.png</texture>'
	check_and_remove media/GlassOverlay.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #19

printf "\nRemoving separators: "
if [ -f media/separator2.png ] ; then
	remove_control 'image' '<texture>separator.png</texture>'
	remove_control 'image' '<texture>separator2.png</texture>'
	#not all controls can be removed, some have an id and are used for navigation
	XMLS=$(2>/dev/null grep 'separator2.png' -l 720p/*)
	perlregex $XMLS 's|separator2.png|-|g'
	check_and_remove media/separator.png
	check_and_remove media/separator2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #20

printf "\nRemoving menu items separator 'MenuItemNF.png': "
if [ -f media/MenuItemNF.png ] ; then
	#remove all image controls using it as texture
	remove_control 'image' '<texture[^>]*>MenuItemNF.png</texture>'
	#remove when used as texture for controls without focus
	R='s|(<control type="[^#]*#'
	R+='(\s*(<[a-z]\|<!--)[^#]*#)*?' # matching lines beginning with any opening tag and comments
	R+='\s*<texturenofocus)(\| border="[0-9,]*")>MenuItemNF.png</texturenofocus>'
	R+='|\1>-</texturenofocus>|g'
	perlregex "$R"
	check_and_remove media/MenuItemNF.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #21

printf "\nRemoving content panel mirrors: "
if [ -f media/ContentPanelMirror.png ] ; then
	remove_control 'image' '<texture[^>]*>ContentPanelMirror.png</texture>'
	check_and_remove 'media/ContentPanelMirror.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #22

printf "\nRemoving floor image: "
if [ -f media/floor.png ] ; then
	remove_control 'image' '<texture[^>]*>floor.png</texture>'
	check_and_remove 'media/floor.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #23

printf "\nRemoving HomeNowPlayingBack.png: "
if grep -q 'HomeNowPlayingBack.png' 720p/ViewsVideoLibrary.xml ; then
	remove_control 'image' '<texture[^>]*>HomeNowPlayingBack.png</texture>'
	#remove behind time label on video osd, but not behind seek bar
	remove_controlid 'image' '<texture flipy="true">HomeNowPlayingBack.png</texture>'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #24

printf "\nRemoving thumb shadows: "
if [ -f media/ThumbShadow.png ] ; then
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
step #25

printf "\nRemoving thumb background: "
if [ -f media/ThumbBG.png ] ; then
	remove_control 'image' '<texture border="2">ThumbBG.png</texture>'
	check_and_remove 'media/ThumbBG.png'	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #26

printf "\nRemoving thumb border: "
if [ -f media/ThumbBorder.png ] ; then
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
step #27

printf "\nRemoving page count info: "
if grep -q 'CommonPageCount' 720p/includes.xml ; then		
	#includes
	XMLS=$(2>/dev/null grep 'CommonPageCount' -l 720p/*)
	perlregex $XMLS 's|\s*<include[^>]*>CommonPageCount</include>\s*#||g'
	#CommonPageCount definition
	R='s|\s*<include name="CommonPageCount">\s*#'
	R+='(\s*(<[a-z][^#]*\|</control>)#)*?'
	R+='\s*</include>\s*#||'
	perlregex "$R" 720p/includes.xml
	if grep -I -q 'CommonPageCount' 720p/* ; then
		printf "\nError: CommonPageCount could not be removed totally."
		exit 3
	fi
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #28

printf "\nChanging time display: "
if grep -q '<description>date label</description>' 720p/includes.xml ; then
	#remove date label - in 720p\includes.xml and 720p\VideoFullScreen.xml
	remove_controlid 'label' '<description>date label</description>'
	#move time label up
	XMLS=$(2>/dev/null grep '<description>time label</description>' -l 720p/*)
	R='s|(<control type="label"[^>]*>\s*#'
	R+='\s*<description>time label</description>\s*#'
	R+='\s*<posx>15r</posx>\s*#'
	R+='\s*<posy)>20<|\1>5<|'
	perlregex $XMLS "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #29

printf "\nEnabling German movie ratings: "
if ! grep -q 'fsk-18' '720p/IncludesVariables.xml' ; then
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
step #30

printf "\nRemoving references to 'media/separator_vertical.png': "
if [ -f media/separator_vertical.png ] ; then
	remove_control 'image' '<texture>separator_vertical.png</texture>'
	check_and_remove media/separator_vertical.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #31

printf "\nReplacing focused texture for controls with default $BUTTON_NF texturenofocus: "
if [ $(grep 'button-focus2.png' 720p/DialogAddonSettings.xml | wc -l) -gt 1 ] ; then
	# Looking for all controls having $BUTTON_NF texturenofocus
	DEFS=$(grep '<default type="' 720p/defaults.xml | sed 's|^\s*[^"]*"||g' | cut -f1 -d'"')
	OLDIFS=$IFS ; 
	CONTROLS+="$(SEP=''
		IFS=$'\n'; for DEF in $DEFS ; do
		DEFSTART=$(grep -n '<default type="'"$DEF"'">' 720p/defaults.xml | cut -f1 -d:)
		DEFSTOP=$(tail -n+"$DEFSTART" 720p/defaults.xml | grep -n '</default>' | head -n 1 | cut -f1 -d:)
		STRUCT=$(tail -n+"$DEFSTART" 720p/defaults.xml | head -n "$DEFSTOP")
		if echo "$STRUCT" | grep -q "$BUTTON_NF</texturenofocus>" ; then
			printf "$SEP$DEF"
			SEP="\|"
		fi
	done)"
	#printf "\n\n'$CONTROLS'"
	R='s|(<control type="('"$CONTROLS"')"[^#]*#'
	#opening tags, but not texturenofocus
	R+='(\s*(?!<texturenofocus)<[a-z][^#]*#)*?' 		
	#texturefocus with tex not matching the default one
	R+='\s*)<texturefocus[^>]*>(?!button-focus.png)(?!HomeSubFO.png)(?!floor_buttonFO.png)(?!ShutdownButton)[^<]*(<[^#]*#'
	R+='(\s*(?!<texturenofocus)<[a-z][^#]*#)*?'
	R+='\s*</control>)|\1<texturefocus border="2">'$BUTTON_FO'\4|g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #32

printf "\nReplacing focused texture for all controls with custom '$BUTTON_NF' texturenofocus: "
if grep -q 'button-focus2.png' 720p/DialogAddonSettings.xml ; then
	R='s|(<texturenofocus[^>]*>'$BUTTON_NF'</texturenofocus>#' # $BUTTON_NF texturenofocus
	R+='(\s*(?!<texturenofocus>)(?!<control)(?!<image)(?!<texturefocus>)<[a-z][^#]*#)*?' # match opening tags (0+)
	# match bad texturefocus combination for $BUTTON_NF texturenofocus
	R+='\s*)<texturefocus[^>]*>(?!button-focus.png)(?!HomeSubFO.png)(?!floor_buttonFO.png)(?!ShutdownButton)[^<]*<[^#]*#'
	R+='|\1<texturefocus border="2">'$BUTTON_FO'</texturefocus>#|g'
	perlregex "$R"
	# match bad texturefocus combination for $BUTTON_NF texturenofocus
	R='s|<texturefocus[^>]*>(?!button-focus.png)(?!HomeSubFO.png)(?!floor_buttonFO.png)(?!ShutdownButton)[^<]*<[^#]*#'
	R+='((\s*(?!<texturenofocus>)(?!<control)(?!<image)(?!<texturefocus>)<[a-z][^#]*#)*?' # match opening tags (0+)
	R+='\s*<texturenofocus[^>]*>'$BUTTON_NF'</texturenofocus>#)' # $BUTTON_NF texturenofocus
	R+='|<texturefocus border="2">'$BUTTON_FO'</texturefocus>#\1|g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #33

printf "\nReplacing focused texture for all items with custom '$BUTTON_NF' texturenofocus: "
if grep -q 'button-focus2.png' 720p/DialogAlbumInfo.xml ; then
	R='s|(<focusedlayout[^#]*#'
	R+='(\s*<[a-z][^#]*#)*?' # match opening tags (0+)
	R+='\s*<texture[^>]*>'$BUTTON_NF'</texture>#'
	R+='(\s*(<[a-z][^#]*\|</control>)#)*?' # match opening or </control> tags (0+)
	# match bad texture combination for black-back texture
	R+='\s*)<texture[^>]*>(?!button-focus.png)(?!HomeSubFO.png)(?!floor_buttonFO.png)(?!ShutdownButton)[^>]*>'
	R+='|\1<texture border="2">'$BUTTON_FO'</texture>|g'
	perlregex "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #34

printf "\nRemoving up and down arrows from several dialogs: "
if [ -f media/arrow-big-up.png ] ; then
	remove_control 'button' '<texturefocus>arrow-big-up.png</texturefocus>'
	remove_control 'button' '<texturefocus>arrow-big-down.png</texturefocus>'
	check_and_remove media/arrow-big-up.png
	check_and_remove media/arrow-big-down.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #35

printf "\nRemoving section header images: "
if [ -f media/icon_addons.png ] ; then
	#section icon
	remove_control 'image' '<description>Section header image</description>'
	check_and_remove media/icon_addons.png
	check_and_remove media/icon_system.png
	check_and_remove media/icon_music.png
	check_and_remove media/icon_video.png
	check_and_remove media/icon_weather.png
	check_and_remove media/icon_pictures.png	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\n############# APPLYING HOME SCREEN MODIFICATIONS ##############################"

printf "\nReplacing submenus item texture (for items that are not focused): "
if [ -f media/HomeSubNF.png ] ; then
	XMLS=$(2>/dev/null grep 'HomeSubNF.png' -l 720p/*)
	perlregex $XMLS 's|HomeSubNF.png|HomeSubNF_light.png|g'
	check_and_remove media/HomeSubNF.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #36

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
step #37

printf "\nRemoving main menu side fade effect: "
if [ -f media/SideFade.png ] ; then
	remove_control 'image' '<texture[^>]*>SideFade.png</texture>'
	check_and_remove media/SideFade.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #38

printf "\nRemoving main menu items separator: "
if grep -I -q 'HomeSeperator' '720p/Home.xml' ; then
	remove_control 'image' '<texture>HomeSeperator.png</texture>' 720p/Home.xml
	check_and_remove 'media/HomeSeperator.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #39

printf "\nRemoving main menu overlay: "
if grep -I -q 'HomeOverlay1.png' '720p/Home.xml' ; then
	remove_control 'image' '<texture>HomeOverlay1.png</texture>'
	check_and_remove 'media/HomeOverlay1.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #40

printf "\nRemoving labels for addons on the main menu: "
if grep -q '<posx>91</posx>' 720p/includes.xml | head -n 1 ; then
	remove_control 'label' '<posx>91</posx>' 720p/includes.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #41

printf "\nChanging widgets on the home screen: "
if [ -f media/RecentAddedBack.png ] ; then
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
step #42

printf "\nRemoving home floor: "
if [ -f media/homefloor.png ] ; then
	remove_control 'image' '<texture>homefloor.png</texture>' 720p/Home.xml
	check_and_remove media/homefloor.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #43

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
step #44

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
	perlregex 720p/ViewsPictures.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #45

printf "\nRemoving location header: "
if grep -I -q '<description>Section header image</description>' 720p/MyPics.xml 
then
	#remove location labels
	remove_control 'label' '<include>WindowTitleCommons</include>' 720p/MyPics.xml
	#remove location grouplist
	R='s|\s*<control type="grouplist">\s*#'
	R+='\s*<posx>65</posx>\s*#'
	R+='\s*<posy>5</posy>\s*#'
	R+='(\s*<[a-z][^>]*>[^>]*>\s*?#)*'
	R+='\s*</control>\s*#||'
	perlregex 720p/MyPics.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #46
exit

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
	R+='(\s*<[a-z][^>]*>[^>]*>\s*?#)*'
	R+='\s*</control>\s*#||'
	perlregex 720p/MyVideoNav.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #47

#printf "\n############# APPLYING MODIFICATIONS TO VIDEO OSD #############################"

printf "\n############# APPLYING MODIFICATIONS TO SMALL DIALOGS #########################"

printf "\nChanging busy dialog: "
if [ -f media/busy.png ] ; then
	remove_control 'image' '<texture>busy.png</texture>' 720p/DialogBusy.xml
	perlregex 's|(<description>Busy label</description>#\s*<posx)>60|\1>40|' 720p/DialogBusy.xml
	check_and_remove media/busy.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #48

printf "\nChanging shutdown menu: "
if [ -f media/DialogContextTop.png ] ; then
	remove_controlid 'image' '<description>background top image</description>' 720p/DialogButtonMenu.xml
	remove_controlid 'image' '<description>background bottom image</description>' 720p/DialogButtonMenu.xml
	perlregex '720p/DialogButtonMenu.xml' 's|texturenofocus border="25,5,25,5">ShutdownButtonNoFocus.png|texturenofocus>'$BUTTON_NF'|g'
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
step #49

printf "\nChanging context menu: "
if grep -I -q '<itemgap>2</itemgap>' 720p/DialogContextMenu.xml ; then
	#remove itemgap
	perlregex '720p/DialogContextMenu.xml' 's|<itemgap>2</itemgap>|<itemgap>0</itemgap>|g'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step #50

printf "\n############# CLEANING UP #####################################################"

TEXLIST='button-focus2.png;2
folder-focus.png;2
button-focus.png;2
black-back2.png;0
KeyboardKey.png;4
KeyboardKeyNF.png;1'
OLDIFS=$IFS ; IFS=$'\n'
for T in $TEXLIST ; do
	TEXTURE=$(echo "$T" | cut -f1 -d';')
	BORDER=$(echo "$T" |cut -f2 -d';')
	printf "\nSetting correct borders for $TEXTURE: "
	if [ $BORDER -ne 0 ] ; then
		if grep "$TEXTURE" 720p/* | grep -v -q 'border="'$BORDER'"' ; then
			XMLS=$(2>/dev/null grep "$TEXTURE" -l 720p/*)
			R='s|border="[0-9,]*">'$TEXTURE'</|border="'$BORDER'">'$TEXTURE'</|g'
			perlregex $XMLS "$R" --nocheck
			R='s|([a-z])>'$TEXTURE'</|\1 border="'$BORDER'">'$TEXTURE'</|g'
			perlregex $XMLS "$R" --nocheck
			printf "%sDONE!%s" $GREEN $RESET
		else
			printf "%sSKIPPED.%s" $CYAN $RESET
		fi
	else
		if grep "$TEXTURE" 720p/* | grep -q 'border="' ; then
			XMLS=$(2>/dev/null grep "$TEXTURE" -l 720p/*)
			R='s| border="[0-9,]*">'$TEXTURE'</|>'$TEXTURE'</|g'
			perlregex $XMLS "$R"
			printf "%sDONE!%s" $GREEN $RESET
		else
			printf "%sSKIPPED.%s" $CYAN $RESET
		fi
	fi
done ; IFS=$OLDIFS
step #51

printf "\nScanning defaults.xml for default values: "
DEFS=$(grep '<default type="' 720p/defaults.xml | sed 's|^\s*[^"]*"||g' | cut -f1 -d'"')
printf "%sDONE!%s" $GREEN $RESET

OLDIFS=$IFS ; IFS=$'\n'
for DEF in $DEFS ; do
	printf "\nRemoving default tags for control type '$DEF': "
	if [ -z "$DEF" ] ; then 
		printf "\nERROR: Found empty type."
		exit 3
	fi
	DEFSTART=$(grep -n '<default type="'"$DEF"'">' 720p/defaults.xml | cut -f1 -d:)
	debug "DEFSTART is '$DEFSTART'."
	if [ ! -z "$DEFSTART" ] ; then
		DEFSTOP=$(tail -n+"$DEFSTART" 720p/defaults.xml | grep -n '</default>' | head -n 1 | cut -f1 -d:)
		STRUCT=$(tail -n+"$DEFSTART" 720p/defaults.xml | head -n "$DEFSTOP" | grep -v '<[/]*default' | \
			egrep -v '<posx|<posy|<width|<height')
		for L in $STRUCT ; do
			if [ ! -z "$L" ] ; then
				L=$(echo "$L" | sed 's|^\s*<|<|')
				R='s|'
				R+='(<control type="'"$DEF"'"[^#]*#(\s*<[a-z][^#]*#)*)\s*'"$L"'#'
				R+='|\1|g'
				XMLS=$(2>/dev/null grep '<control type="'"$DEF"'"' -l 720p/*)
				if [ ! -z "$XMLS" ] ; then
					perlregex "$R" --nocheck $XMLS
				fi
			fi
		done
	else
		printf "\nERROR: Unable to find start default structure for type '$DEF'."
		exit 3		
	fi
	printf "%sDONE!%s" $GREEN $RESET
done
IFS=$OLDIFS
step #52

printf "%s\nAll modifications are completed.\n%s" $GREEN $RESET

exit
