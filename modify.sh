#!/bin/bash
#set -e
SCRIPTFILE=$0
set -o pipefail
2>/dev/null rm debug.log
TILL=0
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
		printf "\nERROR: remove_structure called without files."
		printf "\nParameters are: TYPE='$TYPE'."
		printf "\nTAGS='$TAGS'."
		printf "\nLINE='$LINE'."
		printf "\nFILES='$FILES'."
		exit 4
#		FILES=$( local STRUCT='<'"$TYPE""$TAGS"'>'
#			debug "Structure is '$STRUCT'."
#			for F in $( egrep -l -q "$LINE" 720p/* ) ; do
#			debug "'$F' contains '$LINE'."
#			if grep -q -l '<'"$TYPE""$TAGS"'>' $F ; then
#				debug "'$F' contains also '$STRUCT'."
#				echo \"$F\"
#			fi
#		done )
	fi
	LINE=$(echo $LINE | sed 's|^<|\\s\*<|g')
	LINE=$(echo $LINE | sed 's|>$|>\\s\*#|g')
	local REGEX='s|\s*<'"$TYPE""$TAGS"'>\s*#'
	REGEX+='(\s*<[a-z][^#]*#\|)*?' # matching lines beginning with any opening tag
	REGEX+="$LINE"
	REGEX+='(\s*<[a-z][^#]*#\|)*?' # matching lines beginning with any opening tag
	REGEX+='\s*</'"$TYPE"'>\s*#'
	REGEX+='||g'
	debug "Calling 'perlregex $FILES'."
	perlregex "$REGEX" $FILES
	#again for uncommented structures
	#local REGEX='s|\s*<!--'"$TYPE""$TAGS"'>\s*#'
	#REGEX+='(\s*<[a-z][^#]*#\|)*?' # matching lines beginning with any opening tag
	#REGEX+="$LINE"
	#REGEX+='(\s*<[a-z][^#]*#\|)*?' # matching lines beginning with any opening tag
	#REGEX+='\s*</'"$TYPE"'-->\s*#'
	#REGEX+='||g'
	#debug "Calling 'perlregex $FILES'."
	#perlregex "$REGEX" "$FILES"
}


# removes <include name="?"> .... </include> structure from a xml file
# $1 name of include
# $2 files where to search
remove_include() {
	local NAME=$1
	local FILES=$2
	local REGEX='s|\s*<include name="'$NAME'">#'
	REGEX+='(\s*<[/a-z][^#]*#\|)*?'
	REGEX+='\s*</include>#'
	REGEX+='||g'
	perlregex "$REGEX" "$FILES"
	if grep -I -q "$NAME" 720p/* ; then
		printf "\n'Removed include $NAME' was found in the .xmls: \n"
		grep "$NAME" 720p/*
	fi
}



# removes <variable name="?"> .... </variable> structure from a xml file
# $1 name of variable
# $2 files where to search
remove_variable() {
	local NAME=$1
	local FILES=$2
	local REGEX='s|\s*<variable name="'$NAME'">#'
	REGEX+='(\s*<[/a-z][^#]*#\|)*?'
	REGEX+='\s*</variable>#'
	REGEX+='||g'
	perlregex "$REGEX" "$FILES"
	if grep -I -q "$NAME" 720p/* ; then
		printf "\n'Removed variable $NAME' was found in the .xmls: \n"
		grep "$NAME" 720p/*
	fi
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
	local FILES="$3"
	remove_structure "control" " type=\"$TYPE\"" "$LINE" "$FILES"
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
	local FILES="$3"
	remove_structure "control" " type=\"$TYPE\"[^>]*" "$LINE" "$FILES"
}


# Checks if an image file is linked from within the xmls ; if not, the image is deleted
# If the image is still mentioned in the gui files, this function will exit and show an error message.
# $1 image file with full path
check_and_remove() {
	local FILE=$1
	if [ ! -f "$FILE" ] ; then
		debug "check_and_remove: '$FILE' doesn't exist."
		return 0
	fi
	
	local FILENAME=$(basename "$FILE")
	if ! grep -I -q "[^a-z_]$FILENAME" 720p/* ; then
		
		local BASE=$(echo "$FILENAME" | sed 's|\.[a-zA-Z]*||g')

		if ! grep -I -q "[^a-z_\.\(]$BASE[^a-zA-Z0-9 _\.=/]" 720p/* ; then
			rm "$FILE" # 2>/dev/null
		else
			printf "\n'$BASE' ('$FILE') was found in the .xmls (deleting anyway): \n"
			grep "[^a-z_\.\(]$BASE[^a-zA-Z0-9 _\.=/]" 720p/*
			#exit 3
			rm "$FILE" # 2>/dev/null
		fi
	else
		printf "\n'$FILENAME' ('$FILE') was found in the .xmls: \n"
		grep "$FILENAME" 720p/*
		#exit 3
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
	if [ -z "$MAXSTEPS" ] ; then
		let MAXSTEPS=$(grep '^step$' modify.sh | wc -l)
	fi
	STEP=$((STEP+1))
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
	if echo "$I" | >/dev/null egrep 'debug' ; then
		printf "\nUsing debug mode!"
		DEBUG=true
		continue
	fi
	if echo "$I" | >/dev/null egrep 'steps=[0-9]*' ; then
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

BUTTON_NF='buttons/nf_light.png'
BUTTON_FO='buttons/fo_light.png'
DIALOG_BG='dialogs/dialog-back_light.png'
#DIALOG_BG_COLOR='DF1C1C1C'
CONTENT_BG='dialogs/content-back_light.png'
BACKGROUND_DEF='special://skin/backgrounds/default_light.jpg'
SCROLLBAR_HOR_BAR='scrollbar/ScrollBarH_bar_light.png'
SCROLLBAR_VER_BAR='scrollbar/ScrollBarV_bar_light.png'
SCROLLBAR_HOR='scrollbar/ScrollBarH_light.png'
SCROLLBAR_VER='scrollbar/ScrollBarV_light.png'
SCROLLBAR_HOR_BAR_FO='scrollbar/ScrollBarH_bar_focus_light.png'
SCROLLBAR_VER_BAR_FO='scrollbar/ScrollBarV_bar_focus_light.png'
MEDIA_BLADE='dialogs/bladesub_light.png'
HOME_BLADE='dialogs/bladesub_light.png'
OVERLAY_BG='dialogs/overlay-background.png'
KEYBOARD_EDITAREA='KeyboardEditArea_light.png'
PROGRESS_MIDLIGHT='progressbar/OSDProgressMidLight_light.png'
PROGRESS_MID='progressbar/OSDProgressMid_light.png'
PROGRESS_BACK='progressbar/OSDProgressBack_light.png'
#SEEKSLIDER='seekslider_light.png'
SPINDOWN_NF='buttons/spin-down-nf_light.png'
SPINDOWN_FO='buttons/spin-down-fo_light.png'
SPINLEFT_FO='buttons/spin-left-fo_light.png'
SPINLEFT_NF='buttons/spin-left-nf_light.png'
CALIBRATE_TOPLEFT='buttons/calibrate/topleft_light.png'
CALIBRATE_PIXELRATIO='buttons/calibrate/pixelratio_light.png'
CALIBRATE_SUBTITLES='buttons/calibrate/subtitles_light.png'
HOME_MAIN_FO='home/main-fo_light.png'
HOME_SUB_NF='home/sub-nf_light.png'
HOME_SUB_FO='home/sub-fo_light.png'
RADIOBUTTON_FO='controls/radiobutton-fo_light.png'
RADIOBUTTON_NF='controls/radiobutton-nf_light.png'
FOLDER_NF='controls/folder-nf_light.png'
SLIDER_BG='controls/slider/bg_light.png'
SLIDER_NIB_NF='controls/slider/nib-nf_light.png'
SLIDER_NIB_FO='controls/slider/nib-fo_light.png'

STEP=0
printf "\n############# APPLYING GENERIC/SKIN-WIDE MODIFICATIONS ########################"

printf "\nReplacing '#'s in original xmls: "
if grep -q '#' 720p/SkinSettings.xml ; then 
	sed 's/#/No\./g' -i 720p/SkinSettings.xml 
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving all tags which are commented out: "
if grep -q '<\!--' 720p/* ; then
	XMLS=$(2>/dev/null grep '<\!--' -l 720p/*)
	R='s|\s*<\!--(?!-->).*?-->[^#]*#||g'
	perlregex $XMLS "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

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
if [ -f media/OverlayWatching.png ] || [ -f media/poster_diffuse.png ] ; then
	check_and_remove media/icon_volume.png
	check_and_remove media/poster_diffuse.png
	check_and_remove media/OSDFullScreenFO.png
	check_and_remove media/OSDFullScreenNF.png
	check_and_remove media/defaultDVDFull.png
	check_and_remove backgrounds/Fire.jpg
	check_and_remove backgrounds/Kryptonite.jpg
	check_and_remove media/OverlayWatching.png
	check_and_remove media/Invisable.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing radiobutton textures: "
if [ -f media/radiobutton-focus.png ] ; then
	XMLS=$(2>/dev/null grep '>radiobutton-focus.png<' -l 720p/*)
	R='s|>radiobutton-focus.png<|>'$RADIOBUTTON_FO'<|g'
	perlregex "$R" $XMLS
	XMLS=$(2>/dev/null grep '>radiobutton-nofocus.png<' -l 720p/*)
	R='s|>radiobutton-nofocus.png<|>'$RADIOBUTTON_NF'<|g'
	perlregex "$R" $XMLS
	check_and_remove media/radiobutton-focus.png
	check_and_remove media/radiobutton-nofocus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing texture for items without focus: "
if [ -f media/button-nofocus.png ] ; then
	XMLS=$(2>/dev/null grep '>button-nofocus.png<' -l 720p/*)
	R='s|>button-nofocus.png<|>'$BUTTON_NF'<|g'
	perlregex "$R" $XMLS
	check_and_remove media/button-nofocus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving reflections: "
if [ -f media/diffuse_mirror3.png ] ; then
	XMLS=$(2>/dev/null grep 'diffuse_mirror[23].png' -l 720p/*)
	remove_control 'image' '<texture[^>]*diffuse="diffuse_mirror[23].png"[^>]*>[^<]*</texture>' "$XMLS"
	check_and_remove media/diffuse_mirror2.png
	check_and_remove media/diffuse_mirror3.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging dialog background: "
if [ -f media/DialogBack2.png ] ; then
	XMLS=$(2>/dev/null grep '>DialogBack.png<' -l 720p/*)
	R='s|>DialogBack.png<|>'$DIALOG_BG'<|g'
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep 'DialogBack2.png</texture>' -l 720p/*)
	R='s|>DialogBack2.png<|>'$DIALOG_BG'<|g'
	perlregex $XMLS "$R"
	check_and_remove media/DialogBack.png
	check_and_remove media/DialogBack2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step
	
printf "\nChanging info message dialog background: "
if [ -f media/InfoMessagePanel.png ] ; then
	XMLS=$(2>/dev/null grep '>InfoMessagePanel.png<' -l 720p/*)
	R='s|>InfoMessagePanel.png<|>'$DIALOG_BG'<|g'
	perlregex $XMLS "$R"
	check_and_remove media/InfoMessagePanel.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging dialog background overlay: "
if [ -f media/OverlayDialogBackground.png ] ; then
	XMLS=$(2>/dev/null grep '>OverlayDialogBackground.png<' -l 720p/*)
	R='s|>OverlayDialogBackground.png<|>'$DIALOG_BG'<|g'
	perlregex $XMLS "$R"
	check_and_remove media/OverlayDialogBackground.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step
	
printf "\nRemoving mouse close buttons: "
if [ -f  media/DialogCloseButton-focus.png ] ; then
	XMLS=$(2>/dev/null grep '>DialogCloseButton.png<' -l 720p/*)
	remove_controlid 'button' '<texturenofocus>DialogCloseButton.png</texturenofocus>' "$XMLS"
	check_and_remove media/DialogCloseButton.png
	check_and_remove media/DialogCloseButton-focus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving studio logos: "
if grep -q 'listitem.Studio,studios' 720p/ViewsLogoVertical.xml ; then
	XMLS=$(2>/dev/null grep '>.INFO.listitem.Studio,studios.,.png.<' -l 720p/*)
	remove_control 'image' '<texture>.INFO.listitem.Studio,studios.,.png.</texture>' "$XMLS"
	remove_include 'MediaStudioFlagging' 720p/includes.xml
	rm -rf media/studios
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step
	
printf "\nReplacing content panel background: "
if [ -f media/ContentPanel.png ] ; then	
	XMLS=$(2>/dev/null grep '>ContentPanel.png<' -l 720p/*)
	R='s|>ContentPanel.png<|>'$CONTENT_BG'<|g'
	perlregex $XMLS "$R"
	check_and_remove media/ContentPanel.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step
	
printf "\nReplacing some backgrounds: "
if [ -f backgrounds/media-overlay.jpg ] || [ -f media/media-overlay.jpg ]  ; then
	XMLS=$(2>/dev/null grep 'SKINDEFAULT.jpg' -l 720p/*)
	perlregex $XMLS 's|special://skin/backgrounds/SKINDEFAULT.jpg|'$BACKGROUND_DEF'|g'
	XMLS=$(2>/dev/null grep 'INFO.Skin.CurrentTheme' -l 720p/*)
	perlregex $XMLS 's|.INFO.Skin.CurrentTheme,special://skin/backgrounds/,.jpg.|'$BACKGROUND_DEF'|g'
	XMLS=$(2>/dev/null grep '>media-overlay.jpg<' -l 720p/*)
	perlregex $XMLS 's|>media-overlay.jpg<|>'$BACKGROUND_DEF'<|g'
	check_and_remove backgrounds/SKINDEFAULT.jpg
	check_and_remove backgrounds/media-overlay.jpg
	check_and_remove media/media-overlay.jpg
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step
	
printf "\nRemoving hidden panel arrow: "	
if [ -f media/HasSub.png ] ; then
	perlregex 720p/includes.xml 's|HasSub.png|-|g'
	check_and_remove media/HasSub.png	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving xbmc logo: "
if grep -I -q xbmc-logo.png 720p/* ; then
	#remove logo from all screens
	XMLS=$(2>/dev/null grep '>xbmc-logo.png<' -l 720p/*)
	remove_control 'image' '<texture>xbmc-logo.png</texture>' "$XMLS"
	#remove logo fallback from music visualisation
	XMLS=$(2>/dev/null grep 'fallback="xbmc-logo.png"' -l 720p/*)
	perlregex 's| fallback="xbmc-logo.png"||g' $XMLS
	check_and_remove media/xbmc-logo.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step
	
printf "\nReplacing scroll bar textures: "
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
step
	
printf "\nReformating vertical scroll bar controls: "
if grep -q -zo -P '<control type="scrollbar" id="60">\n\s*<posx>850</posx>\n\s*<posy>78</posy>\n\s*<width>25</width>' \
	720p/ViewsMusicLibrary.xml ; then
	XMLS=$(2>/dev/null grep '<control type="scrollbar"' -l 720p/*)
	R='s|(<control type="scrollbar"[^#]*#(\s*<[a-z][^#]*#)*?\s*<width)>25<|\1>14<|g'
	perlregex $XMLS "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nMoving vertical scroll bars to the right: "
if grep -q -zo -P '<control type="scrollbar" id="60">\n\s*<posx>1250</posx>' 720p/CustomAddMenuItems.xml
then
	for FILE in 720p/* ; do
		IFS=$'\n' ; for XPOS in $( grep -zo -P -I '<control type="scrollbar" id="[0-9]*">\n\s*<posx>[0-9]*</posx>\n\s*<posy>[0-9]*</posy>\n\s*<width>14</width>' "$FILE" \
			| grep -o '<posx>[0-9]*</posx>' | grep -o '[0-9]*' )
		do
			NEWX=$((XPOS+12))
			#echo "'$XPOS' -> '$NEWX'"
			R='s|(<control type="scrollbar" id="[0-9]*">#'
			R+='\s*<posx)>'"$XPOS"'<(/posx>#\s*<posy>[0-9]*</posy>#'
			R+='\s*<width>14</width>)'
			R+='|\1>'"$NEWX"'<\2|g'
			#echo "$R"
			perlregex $FILE "$R" --nocheck
		done
	done
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReformating horizontal scroll bar controls: "
if grep -q -zo -P '<control type="scrollbar" id="60">\n\s*<posx>[0-9]*</posx>\n\s*<posy>[0-9]*</posy>\n\s*<width>[0-9]*</width>\n\s*<height>25</height>' \
	720p/ViewsMusicLibrary.xml ; then
	XMLS=$(2>/dev/null grep '<control type="scrollbar"' -l 720p/*)
	R='s|(<control type="scrollbar"[^#]*#(\s*<[a-z][^#]*#)*?\s*<height)>25<|\1>14<|g'
	perlregex $XMLS "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving GlassOverlay.png: "
if [ -f  media/GlassOverlay.png ] ; then
	XMLS=$(2>/dev/null grep '>GlassOverlay.png<' -l 720p/*)
	remove_control 'image' '<texture>GlassOverlay.png</texture>' "$XMLS"
	check_and_remove media/GlassOverlay.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving separators: "
if [ -f media/separator2.png ] ; then
	XMLS=$(2>/dev/null grep '>separator.png<' -l 720p/*)
	remove_control 'image' '<texture>separator.png</texture>' "$XMLS"
	XMLS=$(2>/dev/null grep '>separator2.png<' -l 720p/*)
	remove_control 'image' '<texture>separator2.png</texture>' "$XMLS"
	#not all controls can be removed, some have an id and are used for navigation
	XMLS=$(2>/dev/null grep 'separator2.png' -l 720p/*)
	perlregex $XMLS 's|separator2.png|'$BUTTON_NF'|g'
	check_and_remove media/separator.png
	check_and_remove media/separator2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving menu items separator 'MenuItemNF.png': "
if [ -f media/MenuItemNF.png ] ; then
	XMLS=$(2>/dev/null grep '>MenuItemNF.png<' -l 720p/*)
	remove_control 'image' '<texture[^>]*>MenuItemNF.png</texture>' "$XMLS"
	XMLS=$(2>/dev/null grep 'MenuItemNF.png' -l 720p/*)
	R='s|>MenuItemNF.png<|>-<|g'
	perlregex $XMLS "$R"
	check_and_remove media/MenuItemNF.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving content panel mirrors: "
if [ -f media/ContentPanelMirror.png ] ; then
	XMLS=$(2>/dev/null grep '>ContentPanelMirror.png<' -l 720p/*)
	remove_control 'image' '<texture[^>]*>ContentPanelMirror.png</texture>' "$XMLS"
	check_and_remove 'media/ContentPanelMirror.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving floor image: "
if [ -f media/floor.png ] ; then
	XMLS=$(2>/dev/null grep '>floor.png<' -l 720p/*)
	remove_control 'image' '<texture[^>]*>floor.png</texture>' "$XMLS"
	check_and_remove 'media/floor.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving HomeNowPlayingBack.png: "
if grep -q '<texture flipy="true">HomeNowPlayingBack.png</texture>' 720p/VideoFullScreen.xml ; then
	# remove from top
	XMLS=$(2>/dev/null grep '>HomeNowPlayingBack.png<' -l 720p/*)
	remove_controlid 'image' '<texture flipy="true">HomeNowPlayingBack.png</texture>' "$XMLS"
	# remove on bottom for some windows
	#remove_control 'image' '<texture[^>]*>HomeNowPlayingBack.png</texture>'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving thumb shadows: "
if [ -f media/ThumbShadow.png ] ; then
	XMLS=$(2>/dev/null grep 'ThumbShadow.png' -l 720p/*)
	R='s|(\s*<bordertexture[^>]*>ThumbShadow.png</bordertexture>#\|'
	R+='\s*<bordersize>[0-9]*</bordersize>#){2}'
	R+='||g'
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep 'ThumbShadow.png' -l 720p/*)
	R='s|\s*<bordertexture border="8">ThumbShadow.png</bordertexture>#'
	R+='(\s*<visible>!Skin.HasSetting.HideEpisodeThumb. . StringCompare.ListItem.Label,...</visible>#)'
	R+='\s*<bordersize>8</bordersize>#'
	R+='|\1|g'
	perlregex $XMLS "$R"
	check_and_remove 'media/ThumbShadow.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving thumb background: "
if [ -f media/ThumbBG.png ] ; then
	XMLS=$(2>/dev/null grep '>ThumbBG.png<' -l 720p/*)
	remove_control 'image' '<texture border="2">ThumbBG.png</texture>' "$XMLS"
	check_and_remove 'media/ThumbBG.png'	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving thumb border: "
if [ -f media/ThumbBorder.png ] ; then
	XMLS=$(2>/dev/null grep 'ThumbBorder.png' -l 720p/*)
	R='s|(\s*<bordertexture[^>]*>ThumbBorder.png</bordertexture>#\|'
	R+='\s*<bordersize>[0-9]*</bordersize>#){2}'
	R+='||g'
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep 'ThumbBorder.png' -l 720p/*)
	R='s|\s*<bordersize>8</bordersize>#'
	R+='(\s*<texture background="true">.VAR.PosterThumb.</texture>#)'
	R+='\s*<bordertexture border="8">ThumbBorder.png</bordertexture>#'
	R+='|\1|g'
	perlregex $XMLS "$R"
	check_and_remove media/ThumbBorder.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving page count info info: "
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
step

printf "\nRemoving more page count info: "
if grep -q 'HideNumItemsCount' 720p/* ; then		
	XMLS=$(2>/dev/null grep 'HideNumItemsCount' -l 720p/*)
	remove_control label '<visible>.Skin.HasSetting.HideNumItemsCount.</visible>' "$XMLS"
	XMLS=$(2>/dev/null grep '<selected>Skin.HasSetting.HideNumItemsCount.</selected>' -l 720p/*)
	if ! [ -z "$XMLS" ] ; then 
		remove_controlid radiobutton '<selected>Skin.HasSetting.HideNumItemsCount.</selected>' "$XMLS"
	fi
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving even more PageCounts: "
if grep -q '>Description Page Count<' 720p/DialogAddonInfo.xml ; then
	remove_control label '<posx>130r</posx>' 720p/DialogAlbumInfo.xml
	R='s|\s*<control type="label">#(\s*<[a-z]*[^#]*#)*?\s*<label>.LOCALIZE.207.[^#]*#\s*</control>||g'
	#perlregex 720p/DialogPVRRecordingInfo.xml "$R"
	remove_control label '<label>(\|.COLOR=blue.).LOCALIZE.207.[^#]*#' 720p/DialogPVRRecordingInfo.xml
	remove_control label '<label>(\|.COLOR=blue.).LOCALIZE.20[67].[^#]*#' 720p/DialogVideoInfo.xml
	remove_control label '<description>Description Page Count</description>' 720p/DialogAddonInfo.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging genre background settings: "
if grep -q 'Skin.SetString.UsrGenreFanartDir,special://skin/backgrounds/moviegenre/.' 720p/Home.xml ; then		
	perlregex 720p/Home.xml 's|\s*<onload condition="IsEmpty.Skin.String.UsrGenreFanartDir..">Skin.SetString.UsrGenreFanartDir,special://skin/backgrounds/moviegenre/.</onload>#||g'
	perlregex 720p/includes.xml 's|special://skin/backgrounds/moviegenre/||g'
	R='s|<visible>(!StringCompare.ListItem.Label,... . Container.Content.genres.</visible>)'
	R+='|<visible>!IsEmpty\(Skin\.String\(UsrGenreFanartDir\)\) \+ \1|g'
	perlregex 720p/IncludesBackgroundBuilding.xml "$R"
	rm -rf backgrounds/moviegenre
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging weather fanart: "
if [ -d backgrounds/weather ] ; then
	perlregex 720p/Home.xml 's|\s*<onload condition="IsEmpty.Skin.String.WeatherFanartDir..">Skin.SetString.WeatherFanartDir,special://skin/backgrounds/weather/.</onload>#||g'
	perlregex 720p/includes.xml 's|special://skin/backgrounds/weather/||g'	
	R='s|(Skin.HasSetting.ShowWeatherFanart.)">'
	R+='|\1 \+ \!IsEmpty\(Skin.String\(WeatherFanartDir\)\)">|g'
	perlregex 720p/IncludesVariables.xml "$R"
	R='s|(Skin.HasSetting.ShowWeatherFanart.)<'
	R+='|\1 \+ \!IsEmpty\(Skin.String\(WeatherFanartDir\)\)<|g'
	perlregex 720p/MyWeather.xml "$R"
	rm -rf backgrounds/weather
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging time display: "
if grep -q '<description>date label</description>' 720p/includes.xml ; then
	#remove date label - in 720p/includes.xml and 720p/VideoFullScreen.xml
	XMLS=$(2>/dev/null grep '<description>date label</description>' -l 720p/*)
	remove_controlid 'label' '<description>date label</description>' "$XMLS"
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
step

printf "\nRemoving references to 'media/separator_vertical.png': "
if [ -f media/separator_vertical.png ] ; then
	XMLS=$(2>/dev/null grep '>separator_vertical.png<' -l 720p/*)
	remove_control 'image' '<texture>separator_vertical.png</texture>' "$XMLS"
	check_and_remove media/separator_vertical.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing button-focus2.png: "
if [ -f media/button-focus2.png ] ; then
	XMLS=$(2>/dev/null grep '>button-focus2.png<' -l 720p/*)
	perlregex $XMLS 's|>button-focus2.png<|>'$BUTTON_FO'<|g'
	check_and_remove media/button-focus2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing button-focus.png: "
if [ -f media/button-focus.png ] ; then
	XMLS=$(2>/dev/null grep '>button-focus.png<' -l 720p/*)
	perlregex $XMLS 's|>button-focus.png<|>'$BUTTON_FO'<|g'
	check_and_remove media/button-focus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing MenuItemFO.png: "
if [ -f media/MenuItemFO.png ] ; then
	XMLS=$(2>/dev/null grep 'MenuItemFO.png' -l 720p/*)
	perlregex $XMLS 's|>MenuItemFO.png|>'$BUTTON_FO'|g'
	check_and_remove media/MenuItemFO.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving up and down arrows from several dialogs: "
if [ -f media/arrow-big-up.png ] ; then
	XMLS=$(2>/dev/null grep '>arrow-big-' -l 720p/*)
	remove_control 'button' '<texturefocus>arrow-big-up.png</texturefocus>' "$XMLS"
	remove_control 'button' '<texturefocus>arrow-big-down.png</texturefocus>' "$XMLS"
	check_and_remove media/arrow-big-up.png
	check_and_remove media/arrow-big-down.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving section header images: "
if [ -f media/icon-weather.png ] ; then
	#section icon
	XMLS=$(2>/dev/null grep '<description>Section header image</description>' -l 720p/*)
	remove_control 'image' '<description>Section header image</description>' "$XMLS"
	check_and_remove media/icon_addons.png
	check_and_remove media/icon_system.png
	check_and_remove media/icon_music.png
	check_and_remove media/icon_video.png
	check_and_remove media/icon_weather.png
	check_and_remove media/icon-video.png
	check_and_remove media/icon-weather.png
	check_and_remove media/icon_pictures.png	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving location headers: "
if grep -I -q '<include>WindowTitleCommons</include>' 720p/FileManager.xml
then
	#remove location labels
	XMLS=$(2>/dev/null grep '<include>WindowTitleCommons</include>' -l 720p/*)
	remove_control 'label' '<include>WindowTitleCommons</include>' "$XMLS"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving location grouplists: "
if grep -I -q '<posx>65</posx>' 720p/AddonBrowser.xml
then
	XMLS=$(2>/dev/null grep '<control type="grouplist">' -l 720p/*)
	#remove location grouplists
	R='s|\s*<control type="grouplist">\s*#'
	R+='\s*<posx>65</posx>\s*#'
	R+='\s*<posy>5</posy>\s*#'
	R+='\s*<width>1000</width>\s*#'
	R+='\s*<height>30</height>\s*#'
	R+='(\s*<[a-z][^>]*>[^>]*>\s*?#)*'
	R+='\s*</control>\s*#||'
	perlregex "$R" $XMLS
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging keyboard: "
if [ -f media/KeyboardEditArea.png ] ; then
	XMLS=$(2>/dev/null grep '>Keyboard' -l 720p/*)
	perlregex $XMLS 's|>KeyboardCornerTopNF.png|>'$BUTTON_NF'|g'
	perlregex $XMLS 's|>KeyboardCornerTop.png|>'$BUTTON_FO'|g'
	perlregex $XMLS 's|>KeyboardCornerBottomNF.png|>'$BUTTON_NF'|g'
	perlregex $XMLS 's|>KeyboardCornerBottom.png|>'$BUTTON_FO'|g'
	perlregex $XMLS 's|>KeyboardEditArea.png|>'$KEYBOARD_EDITAREA'|g'
	perlregex $XMLS 's|>KeyboardKeyNF.png|>'$BUTTON_NF'|g'
	perlregex $XMLS 's|>KeyboardKey.png|>'$BUTTON_FO'|g'
	check_and_remove media/KeyboardCornerTopNF.png
	check_and_remove media/KeyboardCornerTop.png
	check_and_remove media/KeyboardCornerBottomNF.png
	check_and_remove media/KeyboardCornerBottom.png
	check_and_remove media/KeyboardEditArea.png
	check_and_remove media/KeyboardKeyNF.png
	check_and_remove media/KeyboardKey.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing MediaBladeSub: "
if [ -f media/MediaBladeSub.png ] ; then
	XMLS=$(2>/dev/null grep 'MediaBladeSub.png' -l 720p/*)
	perlregex $XMLS 's|>MediaBladeSub.png|>'$MEDIA_BLADE'|g'
	check_and_remove media/MediaBladeSub.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing HomeBladeSub: "
if [ -f media/HomeBladeSub.png ] ; then
	XMLS=$(2>/dev/null grep 'HomeBladeSub.png' -l 720p/*)
	perlregex $XMLS 's|>HomeBladeSub.png|>'$HOME_BLADE'|g'
	check_and_remove media/HomeBladeSub.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving MediaItemDetailBG.png: "
if [ -f media/MediaItemDetailBG.png ] ; then
	XMLS=$(2>/dev/null grep '>MediaItemDetailBG.png<' -l 720p/*)
	remove_control 'image' '<texture border="[0-9,]*">MediaItemDetailBG.png</texture>' "$XMLS"
	check_and_remove media/MediaItemDetailBG.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving CD shadows: "
if [ -f media/livecdcase/cdglass.png ] ; then
	XMLS=$(2>/dev/null grep '>livecdcase/cdglass.png<' -l 720p/*)	
	remove_control 'image' '<texture background="true">livecdcase/cdglass.png</texture>' "$XMLS"
	check_and_remove media/livecdcase/cdglass.png
	check_and_remove media/livecdcase/cdshadow.png	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging progress bars: "
if [ -f media/OSDProgressBack.png ] ; then
	XMLS=$(2>/dev/null grep 'OSDProgress' -l 720p/*)
	perlregex $XMLS 's|OSDProgressMidLight.png|'$PROGRESS_MIDLIGHT'|g'
	perlregex $XMLS 's|OSDProgressMid.png|'$PROGRESS_MID'|g'
	perlregex $XMLS 's|OSDProgressBack.png|'$PROGRESS_BACK'|g'
	check_and_remove media/OSDProgressMidLight.png
	check_and_remove media/OSDProgressMid.png
	check_and_remove media/OSDProgressBack.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving NoCover border: "
if grep -q '<bordertexture border="3">NoCover_1.png</bordertexture>' 720p/SlideShow.xml ; then
	R='s|\s*<bordertexture border="3">NoCover_1.png</bordertexture>#'
	R+='\s*<bordersize>5</bordersize>#'
	R+='||g'
	perlregex 720p/SlideShow.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing folder-focus.png: "
if [ -f media/folder-focus.png ] ; then
	XMLS=$(2>/dev/null grep 'folder-focus.png' -l 720p/*)
	perlregex $XMLS 's|folder-focus.png|buttons/folder-focus_light.png|g'
	check_and_remove media/folder-focus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing backgrounds: "
if [ -f backgrounds/homescreen/weather.jpg ] ; then
	R='s|\s*<value condition="stringcompare[^>]*>special://skin/backgrounds/homescreen/[a-z]*.jpg</value>#||g'
	perlregex 720p/IncludesVariables.xml "$R"
	XMLS=$(2>/dev/null grep 'backgrounds/homescreen/' -l 720p/*)
	R='s|skin/backgrounds/homescreen/[a-z]*.jpg|skin/backgrounds/default_light.jpg|g' 
	perlregex $XMLS "$R"
	rm -rf backgrounds/homescreen
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving standard intro: "
if [ -f extras/Intro/XBMC-Intro-Video.mkv ] ; then
	XMLS=$(2>/dev/null grep '<onclick>Skin.ToggleSetting.HideXBMCIntro.</onclick>' -l 720p/*)
	remove_controlid radiobutton '<onclick>Skin.ToggleSetting.HideXBMCIntro.</onclick>' "$XMLS"
	perlregex 720p/SkinSettings.xml 's|\s*<onclick>Skin.SetBool.HideXBMCIntro.</onclick>#||g'
	perlregex 720p/Startup.xml 's| . Skin.HasSetting.HideXBMCIntro.||'
	XMLS=$(2>/dev/null grep 'Skin.HasSetting.HideXBMCIntro.' -l 720p/*)
	remove_controlid button '<visible>!Skin.HasSetting.HideXBMCIntro.</visible>' "$XMLS"
	perlregex 720p/VideoFullScreen.xml 720p/VideoOSD.xml 's|\s*<visible>!StringCompare.VideoPlayer.Title,XBMC-Intro-Video.mkv.</visible>#||g'
	if grep -q '<ondown>157</ondown>' 720p/SkinSettings.xml ; then
		perlregex 720p/SkinSettings.xml 's|<ondown>157</ondown>|<ondown>158</ondown>|g'
	elif grep -q '<ondown>159</ondown>' 720p/SkinSettings.xml ; then
		perlregex 720p/SkinSettings.xml 's|<ondown>159</ondown>|<ondown>160</ondown>|g'
	elif grep -q '<ondown>158</ondown>' 720p/SkinSettings.xml ; then
		perlregex 720p/SkinSettings.xml 's|<ondown>158</ondown>|<ondown>159</ondown>|g'
	fi
	rm -rf extras/Intro
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging dialog headers: "
if [ -f media/dialogheader.png ] ; then
	XMLS=$(2>/dev/null grep 'e>dialogheader.png<' -l 720p/*)
	remove_control image '<texture>dialogheader.png</texture>' "$XMLS"
	check_and_remove media/dialogheader.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging title bars: "
if [ -f media/GlassTitleBar.png ] ; then
	XMLS=$(2>/dev/null grep '>GlassTitleBar.png<' -l 720p/*)
	remove_control image '<texture(\| flipy="true")>GlassTitleBar.png</texture>' "$XMLS"
	check_and_remove media/GlassTitleBar.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving gradient.png: "
if [ -f media/gradient.png ] ; then
	XMLS=$(2>/dev/null grep '>gradient.png<' -l 720p/*)
	remove_control image '<texture>gradient.png</texture>' "$XMLS"
	>/dev/null check_and_remove media/gradient.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving Confluence_Logo.png: "
if [ -f media/Confluence_Logo.png ] ; then
	XMLS=$(2>/dev/null grep '>Confluence_Logo.png<' -l 720p/*)
	remove_control image '<texture>Confluence_Logo.png</texture>' "$XMLS"
	>/dev/null check_and_remove media/Confluence_Logo.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing seeksliders: "
if [ -f media/seekslider2.png ] ; then
	XMLS=$(2>/dev/null grep 'seekslider' -l 720p/*)
	perlregex $XMLS 's|seekslider2.png|-|g'
	perlregex $XMLS 's|seekslider.png|-|g' --nocheck
	check_and_remove media/seekslider.png
	check_and_remove media/seekslider2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nCorrecting filenames: "
if grep -q 'OSD_' 720p/VideoOSD.xml ; then
	perlregex 720p/VideoOSD.xml 's|OSD_|osd_|g'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving reference to non-existing file home-power-focus.gif: "
if grep -q 'home-power-focus.gif' 720p/LoginScreen.xml ; then
	XMLS=$(2>/dev/null grep '>home-power-focus.gif<' -l 720p/*)
	remove_control 'image' '<texture>home-power-focus.gif</texture>' "$XMLS"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing left and right scrollers: "
if [ -f media/scroll-left.png ] || [ -f media/scroll-right-focus.png ] ; then
	XMLS=$(2>/dev/null grep '>scroll-left.png<' -l 720p/*)
	R='s|>scroll-left.png<|>'$SPINLEFT_NF'<|g'
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep '>scroll-left-focus.png<' -l 720p/*)
	R='s|>scroll-left-focus.png<|>'$SPINLEFT_FO'<|g'
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep '>scroll-right.png<' -l 720p/*)
	R='s|>scroll-right.png<| flipx="true">'$SPINLEFT_NF'<|g'
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep '>scroll-right-focus.png<' -l 720p/*)
	R='s|>scroll-right-focus.png<| flipx="true">'$SPINLEFT_FO'<|g'
	perlregex $XMLS "$R"
	check_and_remove media/scroll-left.png
	check_and_remove media/scroll-left-focus.png
	check_and_remove media/scroll-right.png
	check_and_remove media/scroll-right-focus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing slider and sliderex textures: "
if [ -f media/osd_slider_bg_2.png ] ; then
	XMLS=$(2>/dev/null grep '>osd_slider_bg.png<' -l 720p/*)
	perlregex $XMLS 's|>osd_slider_bg.png<|>'$SLIDER_BG'<|g'
	XMLS=$(2>/dev/null grep '>osd_slider_bg_2.png<' -l 720p/*)
	perlregex $XMLS 's|>osd_slider_bg_2.png<|>'$SLIDER_BG'<|g'
	XMLS=$(2>/dev/null grep '>osd_slider_nibNF.png<' -l 720p/*)
	perlregex $XMLS 's|>osd_slider_nibNF.png<|>'$SLIDER_NIB_NF'<|g'
	XMLS=$(2>/dev/null grep '>osd_slider_nib.png<' -l 720p/*)
	perlregex $XMLS 's|>osd_slider_nib.png<|>'$SLIDER_NIB_FO'<|g'
	check_and_remove media/osd_slider_nibNF.png
	check_and_remove media/osd_slider_nib.png
	check_and_remove media/osd_slider_bg_2.png
	check_and_remove media/osd_slider_bg.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing spin controls: "
if [ -f media/scroll-down-2.png ] ; then
	XMLS=$(2>/dev/null grep '>scroll-' -l 720p/*)
	perlregex $XMLS 's|>scroll-down-2.png<|>'$SPINDOWN_NF'<|g'
	perlregex $XMLS 's|>scroll-down-focus-2.png<|>'$SPINDOWN_FO'<|g'
	perlregex $XMLS 's|>scroll-up-2.png<| flipy="true">'$SPINDOWN_NF'<|g'
	perlregex $XMLS 's|>scroll-up-focus-2.png<| flipy="true">'$SPINDOWN_FO'<|g'
	R='s|(<default type="spincontrol">\s*#'
	R+='\s*<posx>330</posx>\s*#'
	R+='\s*<posy>126</posy>\s*#'
	R+='\s*<textureup[^<]*</textureup>\s*#'
	R+='\s*<texturedown[^<]*</texturedown>#'
	R+='\s*<textureupfocus[^<]*</textureupfocus>#'
	R+='\s*<texturedownfocus[^<]*</texturedownfocus>#'
	R+='\s*<align>right</align>#'
	R+='\s*<width)>33<(/width>#'
	R+='\s*<height)>22<'
	R+='|\1>23<\2>13<|g'
	perlregex 720p/defaults.xml "$R"
	perlregex $XMLS 's|<spinwidth>33</spinwidth>|<spinwidth>23</spinwidth>|g'
	perlregex $XMLS 's|<spinheight>22</spinheight>|<spinheight>13</spinheight>|g'
	check_and_remove media/scroll-down-2.png
	check_and_remove media/scroll-down-focus-2.png
	check_and_remove media/scroll-up-2.png
	check_and_remove media/scroll-up-focus-2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing toggle buttons: "
if [ -f media/scroll-down.png ] ; then
	XMLS=$(2>/dev/null grep '>scroll-' -l 720p/*)
	R='s|(<default type="togglebutton">#'
	R+='\s*<posx>140</posx>#'
	R+='\s*<posy>167</posy>#'
	R+='\s*<width)>20<(/width>#'
	R+='\s*<height)>20<'
	R+='|\1>23<\2>13<|g'
	perlregex 720p/defaults.xml "$R"
	perlregex $XMLS 's|>scroll-down.png<|>'$SPINDOWN_NF'<|g'
	perlregex $XMLS 's|>scroll-down-focus.png<|>'$SPINDOWN_FO'<|g'
	perlregex $XMLS 's|>scroll-up.png<| flipy="true">'$SPINDOWN_NF'<|g'
	perlregex $XMLS 's|>scroll-up-focus.png<| flipy="true">'$SPINDOWN_FO'<|g'
	check_and_remove media/scroll-down.png
	check_and_remove media/scroll-down-focus.png
	check_and_remove media/scroll-up.png
	check_and_remove media/scroll-up-focus.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing left/right arrows: "
if [ -f media/arrow-big-left.png ] ; then
	perlregex 720p/IncludesHomeWidget.xml 's|<texturenofocus>arrow-big-left.png</texturenofocus>|<texturenofocus>'$SPINLEFT_FO'</texturenofocus>|g'
	perlregex 720p/IncludesHomeWidget.xml 's|<texturenofocus>arrow-big-right.png</texturenofocus>|<texturenofocus flipx="true">'$SPINLEFT_FO'</texturenofocus>|g'
	perlregex 720p/IncludesHomeWidget.xml 's|<texturefocus>arrow-big-left.png</texturefocus>|<colordiffuse>BBFFFFFF</colordiffuse>|g'
	perlregex 720p/IncludesHomeWidget.xml 's|<texturefocus>arrow-big-right.png</texturefocus>|<colordiffuse>BBFFFFFF</colordiffuse>|g'
	XMLS=$(2>/dev/null grep 'arrow-big-' -l 720p/*)
	perlregex $XMLS 's|>arrow-big-left.png<|>'$SPINLEFT_FO'<|g'
	perlregex $XMLS 's|>arrow-big-right.png<| flipx="true">'$SPINLEFT_FO'<|g'
	check_and_remove media/arrow-big-left.png
	check_and_remove media/arrow-big-right.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing black-back.png: "
if [ -f media/black-back.png ] ; then
	# remove where not needed
	remove_control 'image' '<texture(\| background="true")>black-back.png</texture>' 720p/ViewsVideoLibrary.xml
	remove_control 'image' '<texture(\| background="true")>black-back.png</texture>' 720p/ViewsMusicLibrary.xml
	remove_control 'image' '<texture(\| background="true")>black-back.png</texture>' 720p/DialogVideoInfo.xml
	# replace with dialog background
	perlregex 720p/SlideShow.xml 720p/MyMusicPlaylistEditor.xml 720p/MusicVisualisation.xml 's|>black-back.png<|>'$DIALOG_BG'<|g'
	# replace with nf-background
	perlregex 720p/SkinSettings.xml 720p/VideoFullScreen.xml 's|>black-back.png<|>'$BUTTON_NF'<|g'	
	# replace where used as overlay background
	XMLS=$(2>/dev/null grep 'black-back.png' -l 720p/*)
	perlregex $XMLS 's|>black-back.png<|>'$OVERLAY_BG'<|g'	
	check_and_remove media/black-back.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing black-back2.png: "
if [ -f media/black-back2.png ] ; then
	XMLS=$(2>/dev/null grep '>black-back2.png<' -l 720p/*)
	perlregex $XMLS 's|<texture(\| border="[0-9]*")>black-back2.png</texture>|<texture>dialogs/dialog-sub_light.png</texture>|g'
	XMLS=$(2>/dev/null grep '>black-back2.png<' -l 720p/*)
	R='s|\s*<bordertexture(\| border="[0-9]*")>black-back2.png</bordertexture>#'
	R+='\s*<bordersize>2</bordersize>#'
	R+='||g'
	perlregex $XMLS "$R"
	check_and_remove media/black-back2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing calibration controls: "
if [ -f media/CalibrateSubtitles.png ] ; then
	perlregex 720p/SettingsScreenCalibration.xml 's|<texturefocus>CalibrateTopLeft.png</texturefocus>|<texturefocus border="6">'$CALIBRATE_TOPLEFT'</texturefocus>|g'
	perlregex 720p/SettingsScreenCalibration.xml 's|<texturefocus>CalibrateBottomRight.png</texturefocus>|<texturefocus flipx="true" flipy="true" border="6">'$CALIBRATE_TOPLEFT'</texturefocus>|g'
	perlregex 720p/SettingsScreenCalibration.xml 's|<texturefocus>CalibratePixelRatio.png</texturefocus>|<texturefocus>'$CALIBRATE_PIXELRATIO'</texturefocus>|g'
	perlregex 720p/SettingsScreenCalibration.xml 's|<texturefocus>CalibrateSubtitles.png</texturefocus>|<texturefocus>'$CALIBRATE_SUBTITLES'</texturefocus>|g'
	check_and_remove media/CalibrateTopLeft.png
	check_and_remove media/CalibrateBottomRight.png
	check_and_remove media/CalibrateSubtitles.png
	check_and_remove media/CalibratePixelRatio.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving cdwall-grid.png: "
if [ -f media/cdwall-grid.png ] ; then
	XMLS=$(2>/dev/null grep '>cdwall-grid.png<' -l 720p/*)
	remove_control image '<texture background="true">cdwall-grid.png</texture>' "$XMLS"
	check_and_remove media/cdwall-grid.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving ClearCases: "
if [ -d media/ClearCase ] ; then
	remove_control image '<visible>\!Skin.HasSetting\(View724DisableCases\)</visible>' 720p/ViewsLowlist.xml
	perlregex 's|\s*<visible>Skin.HasSetting\(View724DisableCases\)</visible>\s*#||' 720p/ViewsLowlist.xml
	remove_controlid radiobutton '<onclick>Skin.ToggleSetting\(View724DisableCases\)</onclick>' 720p/MyVideoNav.xml
	remove_controlid radiobutton '<onclick>Skin.ToggleSetting\(UseDiscTypeCase\)</onclick>' 720p/MyVideoNav.xml
	remove_variable 'VideoListCase' '720p/IncludesVariables.xml'
	rm -rf media/ClearCase
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing floor buttons: "
if [ -f media/floor_buttonFO.png ] ; then
	XMLS=$(2>/dev/null grep 'floor_button.png' -l 720p/*)
	perlregex $XMLS 's|floor_button.png|'$BUTTON_NF'|g'
	XMLS=$(2>/dev/null grep 'floor_buttonFO.png' -l 720p/*)
	perlregex $XMLS 's|floor_buttonFO.png|'$BUTTON_FO'|g'
	check_and_remove media/floor_button.png
	check_and_remove media/floor_buttonFO.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing standard album cover: "
if [ -f media/FallbackAlbumCover.png ] ; then
	XMLS=$(2>/dev/null grep 'FallbackAlbumCover.png' -l 720p/*)
	perlregex $XMLS 's|FallbackAlbumCover.png|DefaultAlbumCover.png|g'
	#XMLS=$(2>/dev/null grep 'FallbackAlbumCover.png' -l 720p/*)
	#perlregex $XMLS 's|>FallbackAlbumCover.png<|>DefaultAlbumCover.png<|g'
	rm media/DefaultAlbumCover.png
	mv media/FallbackAlbumCover.png media/DefaultAlbumCover.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing livecd DefaultAlbumCover.png: "
if [ -f media/livecdcase/DefaultAlbumCover.png ] ; then
	XMLS=$(2>/dev/null grep '"livecdcase/DefaultAlbumCover.png"' -l 720p/*)
	perlregex $XMLS 's|"livecdcase/DefaultAlbumCover.png"|"DefaultAlbumCover.png"|g'
	#XMLS=$(2>/dev/null grep 'FallbackAlbumCover.png' -l 720p/*)
	#perlregex $XMLS 's|>FallbackAlbumCover.png<|>DefaultAlbumCover.png<|g'
	rm media/livecdcase/DefaultAlbumCover.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

#printf "\nReplacing livecd cd art: "
#if [ -f media/livecdcase/DefaultCDArt.png ] ; then
#	XMLS=$(2>/dev/null grep '"livecdcase/DefaultAlbumCover.png"' -l 720p/*)
#	perlregex $XMLS 's|"livecdcase/DefaultAlbumCover.png"|"DefaultAlbumCover.png"|g'
#	#XMLS=$(2>/dev/null grep 'FallbackAlbumCover.png' -l 720p/*)
#	#perlregex $XMLS 's|>FallbackAlbumCover.png<|>DefaultAlbumCover.png<|g'
#	rm media/livecdcase/DefaultAlbumCover.png
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

printf "\nReplacing warning sign: "
if [ -f media/warning.png ] ; then
	XMLS=$(2>/dev/null grep 'warning.png' -l 720p/*)
	perlregex $XMLS 's|>warning.png<|>DefaultIconWarning.png<|g'
	check_and_remove media/warning.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving VisibleFadeEffect: "
if grep -q 'VisibleFadeEffect' 720p/DialogAlbumInfo.xml ; then
	XMLS=$(2>/dev/null grep 'VisibleFadeEffect' -l 720p/*)
	perlregex $XMLS 's|\s*<include>VisibleFadeEffect</include>#||g'
	remove_include 'VisibleFadeEffect' 720p/includes.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging color scheme: "
if ! grep -q 'buttonfocus' colors/defaults.xml ; then
	R='s|(\s*<colors>#)(\s*)'
	R+='|\1\2<color name="buttonfocus">ffb15e1e</color>#'
	R+='\2<color name="buttonnofocus">ff577490</color>#'
	R+='\2<color name="heading1">ff0084ff</color>#'
	R+='\2<color name="heading2">ff7fc1ff</color>#'
	R+='\2<color name="textfocus">ffffffff</color>#'
	R+='\2<color name="textnofocus">ffb4b4b4</color>#'
	R+='\2<color name="textdisabled">ff505050</color>#'
	R+='\2<color name="itemselected">ffeb9e17</color>#'
	R+='\2|'
	perlregex colors/defaults.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving other color schemes: "
if [ -f colors/Fire.xml ] ; then
	rm colors/Fire.xml
	rm colors/Kryptonite.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

#printf "\nRemoving multi-color strings: "
#if grep -q 'COLOR=' 720p/SkinSettings.xml ; then
#	XMLS=$(2>/dev/null grep 'COLOR=' -l 720p/*)
#	perlregex $XMLS 's|\[COLOR\=[a-z0-9]*\]||g'	
#	XMLS=$(2>/dev/null grep 'COLOR' -l 720p/*)
#	perlregex $XMLS 's|\[/COLOR\]||g'	
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

printf "\nModifying weather info in the upper left corner: "
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
step

printf "\nRemoving font dropshadows: "
if grep -I -q '<shadowcolor>' 720p/* ; then
	XMLS=$(2>/dev/null grep '<shadowcolor>' -l 720p/*)
	perlregex $XMLS 's|\s*<shadowcolor>[a-z]*</shadowcolor>#||g'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging font colors for original 'grey' strings: "
if grep -q '>grey<' 720p/* ; then
	XMLS=$(2>/dev/null grep 'COLOR=grey\]' -l 720p/*)
	perlregex $XMLS "s|COLOR=grey\]|COLOR=textnofocus\]|g"
	CONTROLS='button
label
textbox'
	XMLS=$(2>/dev/null grep 'textcolor>grey<' -l 720p/*)
	for CONTROL in $CONTROLS ; do
		R="s|( type=\"$CONTROL\"[^#]*#"				#1
		R+="(\s*(?!<textcolor)<[a-z][^#]*#)*"
		R+="\s*<textcolor)>grey<"
		R+="|\1>textnofocus<|g"
		perlregex $XMLS "$R" --nocheck
	done
	XMLS=$(2>/dev/null grep 'selectedcolor>grey<' -l 720p/*)
	for CONTROL in $CONTROLS ; do
		R="s|( type=\"$CONTROL\"[^#]*#"				#1
		R+="(\s*(?!<selectedcolor)<[a-z][^#]*#)*"
		R+="\s*<selectedcolor)>grey<"
		R+="|\1>itemselected<|g"
		perlregex $XMLS "$R" --nocheck
	done
	if grep -q 'grey[^0-9]' 720p/* ; then
		printf "\nERROR: Grey color still used!"
		printf "\n"
		grep 'grey[^0-9]' 720p/*
		exit 4
	fi
	perlregex colors/defaults.xml "s|\s*<color name=\"grey\"[^#]*#||g"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step
#printf "\nChanging font colors for original 'grey' strings: "
#if false ; then #grep -q '>grey<' 720p/ViewsPVR.xml ; then
#
#	R='s|(<description>header label</description>#'
#	R+='(\s*<[a-z][^#]*#)*?'
#	R+='\s*<textcolor)>grey<'
#	R+='|\1>heading2<|g'
#	perlregex 720p/DialogPVRChannelsOSD.xml "$R"
#	
#	XMLS="720p/DialogPVRChannelsOSD.xml 720p/DialogSelect.xml 720p/FileManager.xml 720p/ViewsPVR.xml"
#	for (( i=0 ; i<10 ; i++)) ; do
#		R='s|(<(item\|channel)layout height="[0-9]*"(\| width="[0-9]*")>#'
#		R+='(\s*<control type="[labelimage]*"[^#]*#'
#		R+='(\s*<[a-z][^#]*#)*?'
#		R+='\s*</control>#\|\s*<animation[^#]*#)*?'
#		R+='\s*<control type="(label\|textbox)">#'
#		R+='(\s*<[a-z][^#]*#)*?'
#		R+='\s*<(textcolor\|selectedcolor))>grey<'
#		R+='|\1>textnofocus<|g'
#		perlregex $XMLS "$R" --nocheck
#		
#		R='s|(<(focused\|focusedchannel)layout height="[0-9]*"(\| width="[0-9]*")>#'
#		R+='(\s*<control type="[labelimage]*"[^#]*#'
#		R+='(\s*<[a-z][^#]*#)*?'
#		R+='\s*</control>#\|\s*<animation[^#]*#)*?'
#		R+='\s*<control type="(label\|textbox)">#'
#		R+='(\s*<[a-z][^#]*#)*?'
#		R+='\s*<(textcolor\|selectedcolor))>grey<'
#		R+='|\1>textfocus<|g'
#		perlregex $XMLS "$R" --nocheck
#	done
#	
#	R='s|<textcolor>grey</textcolor>|<textcolor>textnofocus</textcolor>|g'
#	XMLS="720p/includes.xml 720p/MusicVisualisation.xml 720p/script-XBMC_Lyrics-main.xml 720p/SkinSettings.xml"
#	XMLS+=" 720p/VideoFullScreen.xml 720p/VideoOSD.xml"
#	perlregex $XMLS "$R"
#	
#	if grep -q '>grey<' 720p/* ; then
#		printf "\nERROR: Grey color still used!"
#		printf "\n"
#		grep '>grey<' 720p/*
#		exit 4
#	fi
#
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

#printf "\nChanging font colors for original 'selected color' strings: "
#if false ; then #grep -q '>selected<' 720p/VisualisationPresetList.xml ; then
#	XMLS=$(2>/dev/null grep '>selected<' -l 720p/*)
#	perlregex $XMLS 's|<selectedcolor>selected</selectedcolor>|<selectedcolor>itemselected</selectedcolor>|g'	
#	XMLS=$(2>/dev/null grep '>selected<' -l 720p/*)
#	perlregex $XMLS 's|<textcolor>selected</textcolor>|<textcolor>itemselected</textcolor>|g'
#	
#	if grep -q '>selected<' 720p/* ; then
#		printf "\nERROR: Selected color still used!"
#		printf "\n"
#		grep '>selected<' 720p/*
#		exit 4
#	fi
#	
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

#printf "\nChanging font colors for original blue strings: "
#if false ; then #grep -q 'blue' 720p/ViewsVideoLibrary.xml ; then
#
#	perlregex 720p/Home.xml 's|(<font>font_MainMenu</font>#\s*<textcolor)>blue<|\1>textnofocus<|g'
#	perlregex 720p/Home.xml 's|(<font>font_MainMenu</font>#\s*<textcolor)>grey3<|\1>buttonfocus<|g'
#	
#	R='s|(<control type="label">#'
#	R+='\s*<description>(header label\|Title label)</description>#'
#	R+='(\s*<[a-z][^#]*#)*?'
#	R+='\s*<textcolor)>blue</'
#	R+='|\1>heading1</'
#	R+='|g'
#	XMLS="720p/DialogPVRChannelsOSD.xml 720p/DialogPVRGuideInfo.xml 720p/DialogPVRRecordingInfo.xml "
#	perlregex $XMLS "$R"
#	
#	R='s|(<control type="rss">#'
#	R+='\s*<description>RSS feed</description>#'
#	R+='(\s*<[a-z][^#]*#)*?'
#	R+='\s*<textcolor)>blue</'
#	R+='|\1>textfocus</'
#	R+='|g'
#	XMLS="720p/Home.xml "
#	perlregex $XMLS "$R"	
#
#	R='s|<textcolor>blue</textcolor>|<textcolor>heading1</textcolor>|g'
#	XMLS="720p/CustomAddMenuItems.xml 720p/CustomAddonSelection.xml 720p/CustomAddonType.xml 720p/CustomAddSubMenuItems.xml "
#	XMLS+="720p/CustomSubMenuType.xml 720p/CustomWidgetType.xml 720p/DialogPVRChannelManager.xml "
#	XMLS+="720p/DialogPVRGuideOSD.xml 720p/DialogPVRGuideSearch.xml 720p/DialogSlider.xml "
#	XMLS+="720p/MyMusicPlaylistEditor.xml 720p/script-globalsearch-main.xml 720p/SettingsSystemInfo.xml "
#	XMLS+=" 720p/FileManager.xml "
#	XMLS+=" "
#	perlregex $XMLS "$R"
#
#	R='s|<textcolor>blue</textcolor>|<textcolor>heading2</textcolor>|g'
#	XMLS="720p/AddonBrowser.xml 720p/DialogAddonInfo.xml 720p/DialogAlbumInfo.xml 720p/DialogContentSettings.xml "
#	XMLS+="720p/DialogKaraokeSongSelector.xml 720p/DialogKaraokeSongSelectorLarge.xml 720p/DialogMediaSource.xml "
#	XMLS+="720p/DialogPVRGroupManager.xml 720p/DialogSeekBar.xml 720p/DialogSongInfo.xml 720p/DialogVideoInfo.xml "
#	XMLS+=" 720p/includes.xml 720p/MusicKaraokeLyrics.xml 720p/MusicOSD.xml "
#	XMLS+="720p/MyMusicNav.xml 720p/MyMusicPlaylist.xml 720p/DialogPeripheralManager.xml "
#	XMLS+="720p/DialogPVRChannelsOSD.xml 720p/DialogPVRGuideInfo.xml 720p/DialogPVRRecordingInfo.xml "
#	XMLS+="720p/Home.xml 720p/MyPics.xml  720p/MyMusicSongs.xml 720p/MyPrograms.xml 720p/MyPVR.xml 720p/MyVideoNav.xml "
#	XMLS+="720p/MyVideoPlaylist.xml 720p/MyWeather.xml 720p/ProfileSettings.xml 720p/script-NextAired-TVGuide.xml "
#	XMLS+="720p/script-RSS_Editor-rssEditor.xml 720p/script-RSS_Editor-setEditor.xml 720p/script-XBMC_Lyrics-main.xml "
#	XMLS+="720p/SettingsProfile.xml 720p/SkinSettings.xml 720p/SmartPlaylistEditor.xml 720p/SmartPlaylistRule.xml "
#	XMLS+="720p/VideoFullScreen.xml 720p/ViewsAddonBrowser.xml 720p/ViewsLiveTV.xml 720p/ViewsMusicLibrary.xml "
#	XMLS+="720p/ViewsPVR.xml 720p/ViewsVideoLibrary.xml "
#	perlregex $XMLS "$R"
#	
#	R='s|<textcolor>blue</textcolor>|<textcolor>textfocus</textcolor>|g'
#	XMLS="720p/DialogAddonSettings.xml 720p/IncludesHomeWidget.xml "
#	XMLS+=" "
#	perlregex $XMLS "$R"
#	
#	perlregex 's|\s*<selectedcolor>blue</selectedcolor>#||g' 720p/DialogPVRChannelsOSD.xml
#	perlregex 's|<titlecolor>blue</titlecolor>|<titlecolor>heading2</titlecolor>|g' 720p/Home.xml
#
#	if grep -q '>blue<' 720p/* ; then
#		printf "\nERROR: Blue color still used!"
#		printf "\n"
#		grep '>blue<' 720p/*
#		exit 4
#	fi
#	
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

#printf "\nChanging font colors for original 'grey2' strings: "
#if false ; then #grep -q '>grey2<' 720p/* ; then
#
#	XMLS=$(2>/dev/null grep '<disabledcolor>grey2</disabledcolor>' -l 720p/*)
#	R='s|<disabledcolor>grey2</disabledcolor>|<disabledcolor>textdisabled</disabledcolor>|g'
#	perlregex $XMLS "$R"
#
#	XMLS=$(2>/dev/null grep '>grey2<' -l 720p/*)
#	R='s|(<control type="(button\|radiobutton\|spincontrolex\|sliderex\|togglebutton\|edit\|textbox)"[^#]*#'
#	R+='(\s*<[a-z][^#]*#)*?'
#	R+='\s*<textcolor)>grey2<'
#	R+='|\1>textnofocus<|g'
#	perlregex $XMLS "$R"
#	
#	XMLS=$(2>/dev/null grep '>grey2<' -l 720p/*)
#	for (( i=0 ; i<6 ; i++)) ; do
#		R='s|(<(item\|channel)layout[^#]*#'
#		R+='(\s*<control type="[a-z]*"[^#]*#'
#		R+='(\s*<[a-z][^#]*#)*?'
#		R+='\s*</control>#\|\s*<animation[^#]*#)*?'
#		R+='\s*<control type="(label\|textbox)">#'
#		R+='(\s*<[a-z][^#]*#)*?'
#		R+='\s*<(textcolor\|selectedcolor))>grey2<'
#		R+='|\1>textnofocus<|g'
#		perlregex $XMLS "$R" --nocheck
#		
#		R='s|(<(focused\|focusedchannel)layout[^#]*#'
#		R+='(\s*<control type="[a-z]*"[^#]*#'
#		R+='(\s*<[a-z][^#]*#)*?'
#		R+='\s*</control>#\|\s*<animation[^#]*#)*?'
#		R+='\s*<control type="(label\|textbox)">#'
#		R+='(\s*<[a-z][^#]*#)*?'
#		R+='\s*<(textcolor\|selectedcolor))>grey2<'
#		R+='|\1>textfocus<|g'
#		perlregex $XMLS "$R" --nocheck
#	done
#	
#	XMLS="720p/DialogFileStacking.xml 720p/DialogKaiToast.xml 720p/DialogPVRGuideOSD.xml"
#	XMLS+=" 720p/DialogVideoInfo.xml 720p/includes.xml 720p/IncludesGenreFlagging.xml"
#	XMLS+=" 720p/MusicVisualisation.xml 720p/MyPVR.xml 720p/MyWeather.xml 720p/LoginScreen.xml"
#	XMLS+=" 720p/script-XBMC_Lyrics-main.xml 720p/SettingsProfile.xml 720p/VideoFullScreen.xml"
#	XMLS+=" 720p/ViewsMusicLibrary.xml 720p/ViewsPVR.xml 720p/ViewsVideoLibrary.xml"
#	perlregex $XMLS 's|<textcolor>grey2</textcolor>|<textcolor>textnofocus</textcolor>|g'
#	
#	if grep -q '>grey2<' 720p/* ; then
#		printf "\nERROR: Grey2 color still used!"
#		printf "\n"
#		grep '>grey2<' 720p/* | head
#		exit 4
#	fi
#	
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

#printf "\nChanging font colors for original 'grey3' strings: "
#if false ; then #grep -q '>grey3<' 720p/SkinSettings.xml ; then
#
#	XMLS=$(2>/dev/null grep '<disabledcolor>grey3</disabledcolor>' -l 720p/*)
#	R='s|<disabledcolor>grey3</disabledcolor>|<disabledcolor>textdisabled</disabledcolor>|g'
#	perlregex $XMLS "$R"
#	
#	perlregex 's|<textcolor>grey3</textcolor>|<textcolor>textdisabled</textcolor>|g' 720p/DialogPVRChannelManager.xml
#
#	XMLS="720p/script-globalsearch-main.xml 720p/Settings.xml 720p/SkinSettings.xml"
#	perlregex $XMLS 's|<textcolor>grey3</textcolor>|<textcolor>textnofocus</textcolor>|g'
#
#	if grep -q '>grey3<' 720p/* ; then
#		printf "\nERROR: Grey3 color still used!"
#		printf "\n"
#		grep '>grey3<' 720p/* | head
#		exit 4
#	fi
#	
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

#printf "\nChanging font colors for original 'black' strings: "
#if false ; then #grep -q '>black<' 720p/DialogKeyboard.xml ; then
#
#	XMLS=$(2>/dev/null grep '<focusedcolor>black</focusedcolor>' -l 720p/*)
#	R='s|<focusedcolor>black</focusedcolor>|<focusedcolor>textfocus</focusedcolor>|g'
#	perlregex $XMLS "$R"
#	
#	if grep -q '>black<' 720p/* ; then
#		printf "\nERROR: Black color still used!"
#		printf "\n"
#		grep '>black<' 720p/* | head
#		exit 4
#	fi
#	
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

printf "\nReplacing unknown-user.png: "
if [ -f media/unknown-user.png ] ; then
	XMLS=$(2>/dev/null grep 'unknown-user.png' -l 720p/*)
	perlregex $XMLS 's|>unknown-user.png<|>DefaultActor.png<|g' >/dev/null
	perlregex $XMLS 's|"unknown-user.png"|"DefaultActor.png"|g'
	check_and_remove media/unknown-user.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing stack buttons: "
if [ -f media/StackNF.png ] ; then
	XMLS=$(2>/dev/null grep 'StackNF.png' -l 720p/*)
	perlregex $XMLS 's|>StackNF.png<|>'$BUTTON_NF'<|g'
	XMLS=$(2>/dev/null grep 'StackFO.png' -l 720p/*)
	perlregex $XMLS 's|>StackFO.png<|>'$BUTTON_FO'<|g'
	check_and_remove media/StackNF.png
	check_and_remove media/StackFO.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving GenreFlagging: "
if [ -d media/DefaultGenre ] ; then
	XMLS=$(2>/dev/null grep '<visible>.Skin.HasSetting.View501GenreIcons.<.visible>' -l 720p/*)
	remove_control 'grouplist' '<visible>\!Skin.HasSetting\(View501GenreIcons\)</visible>' "$XMLS"
	remove_include 'MultiVideoGenreFlagging' 720p/IncludesGenreFlagging.xml
	remove_include 'MultiGenreFlag' 720p/IncludesGenreFlagging.xml
	remove_variable 'GenreFlagPath' 720p/IncludesVariables.xml
	XMLS=$(2>/dev/null grep '<onclick>Skin.ToggleSetting.View501GenreIcons.</onclick>' -l 720p/*)
	remove_controlid 'radiobutton' '<onclick>Skin.ToggleSetting.View501GenreIcons.</onclick>' "$XMLS"
	XMLS=$(2>/dev/null grep 'condition=".Skin.HasSetting.View501GenreIcons.' -l 720p/*)
	perlregex $XMLS 's|\s*<anima[^#]*?condition=".Skin.HasSetting.View501GenreIcons.[^#]*#||g'
	#XMLS=$(2>/dev/null grep '<visible>Skin.HasSetting.View501GenreIcons.</visible>' -l 720p/*)
	#perlregex $XMLS 's|\s*<visible>Skin.HasSetting.View501GenreIcons.</visible>\s*#||g'
	rm -rf media/DefaultGenre
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving RSS icon: "
if [ -f media/icon-rss.png ] ; then
	XMLS=$(2>/dev/null grep 'icon-rss.png' -l 720p/*)
	remove_control 'image' '<texture>icon-rss.png</texture>' "$XMLS"
	check_and_remove media/icon-rss.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing DefaultCDArt: "
if [ -f media/livecdcase/DefaultCDArt.png ] ; then
	XMLS=$(2>/dev/null grep 'DefaultCDArt.png' -l 720p/*)
	perlregex $XMLS 's|(fallback="livecdcase/DefaultCDAr)t.png"( diffuse="livecdcase/cddiffuse.png")|\1t\.jpg"\2|g'
	perlregex $XMLS 's|(<width>170</width><height>175</height><include>CDArtSpinner</include><texture fallback="livecdcase/DefaultCDAr)t.png"|\1t_small.png"|g'
	check_and_remove media/livecdcase/DefaultCDArt.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing some bordertextures: "
if grep -q '>buttons/nf_light.png</bordertexture>' 720p/DialogAlbumInfo.xml ; then
	R='s|<bordertexture[^>]*>buttons/nf_light.png</bordertexture>|<bordertexture>'$FOLDER_NF'</bordertexture>|g'
	perlregex 720p/SettingsProfile.xml 720p/ViewsFileMode.xml 720p/ViewsVideoLibrary.xml 720p/ViewsMusicLibrary.xml 720p/ViewsAddonBrowser.xml "$R"
	R='s|<bordertexture[^>]*>buttons/nf_light.png</bordertexture>|<bordertexture>-</bordertexture>|g'
	perlregex 720p/IncludesHomeWidget.xml "$R"
	R='s|\s*<bordertexture[^>]*>buttons/nf_light.png</bordertexture>\s*#'
	R+='\s*<bordersize>[0-9]*</bordersize>\s*#'
	R+='||g'
	perlregex 720p/FileManager.xml 720p/DialogVideoInfo.xml 720p/DialogAlbumInfo.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\n############# APPLYING HOME SCREEN MODIFICATIONS ##############################"

printf "\nRemoving main menu items separator: "
if grep -I -q 'HomeSeperator' '720p/Home.xml' ; then
	remove_control 'image' '<texture>HomeSeperator.png</texture>' 720p/Home.xml
	check_and_remove 'media/HomeSeperator.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging main menu layout: "
if grep -q -zPo '<font>font_MainMenu</font>\s*\n\s*<textcolor>blue</textcolor>' 720p/Home.xml ; then
	#fixing list
	#perlregex 720p/Home.xml 's|\s*<movement>1</movement>#||'
	#changing height
	R='s|>60<(/height>#\s*<onleft>9000</onleft>#\s*<onright>9000</onright>#)|>70<\1|'
	perlregex 720p/Home.xml "$R"
	#texture focusing selected item
	R='s|(\s*<focusedlayout height="60" width="340">\s*#)' 	#\1
	R+='(\s*)(<control type="label">\s*#'				 	#\2\3
	R+='(\s*)<posx>170</posx>\s*#'							#\4
	R+='(\s*<[a-z][^#]*#)*'									#\5
	R+='\s*</control>\s*#)'
	R+='\s*<control type="label">\s*#'
	R+='(\s*<[a-z][^#]*#)*'									#\6
	R+='\s*</control>\s*#'
	R+='(\s*</focusedlayout>\s*#)'								#\7
	R+='|\1\2<control type="image">#'
	R+='\4<posx>-50</posx>#'
	R+='\4<posy>0</posy>#'
	R+='\4<width>440</width>#'
	R+='\4<height>65</height>#'
	R+='\4<texture>'$HOME_MAIN_FO'</texture>#'
	R+='\4<visible>Control.HasFocus\(9000\)</visible>#'
	R+='\2</control>#'
	R+='\2\3\7|'
	perlregex 720p/Home.xml "$R"
	#font color for focused item
	R='s|(<focusedlayout height="60" width="340">\s*#)' #\1
	R+='(\s*<control type="image">\s*#'					#\2
	R+='(\s*<[a-z][^#]*#)*'								#\3
	R+='\s*</control>\s*#'
	R+='\s*<control type="label">\s*#'
	R+='(\s*<[a-z][^#]*#)*?'							#\4
	R+='\s*<textcolor)>[a-z0-9]*<'						#\5
	R+='|\1\2>buttonfocus<|'
	perlregex 720p/Home.xml "$R"
	R='s|(\s*<itemlayout height="60" width="340">\s*#'
	R+='(\s*<[a-z][^#]*#)*?'
	R+='\s*<textcolor)>[a-z0-9]*<'
	R+='|\1>buttonnofocus<|'
	perlregex 720p/Home.xml "$R"	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing submenu item textures: "
if [ -f media/HomeSubFO.png ] ; then
	XMLS=$(2>/dev/null grep 'HomeSubNF.png' -l 720p/*)
	perlregex $XMLS 's|HomeSubNF.png|'$HOME_SUB_NF'|g'
	XMLS=$(2>/dev/null grep 'HomeSubFO.png' -l 720p/*)
	perlregex $XMLS 's|HomeSubFO.png|'$HOME_SUB_FO'|g'
	check_and_remove media/HomeSubNF.png
	check_and_remove media/HomeSubFO.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving main menu side fade effect: "
if [ -f media/SideFade.png ] ; then
	XMLS=$(2>/dev/null grep '>SideFade.png<' -l 720p/*)
	remove_control 'image' '<texture[^>]*>SideFade.png</texture>' "$XMLS"
	check_and_remove media/SideFade.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving main menu overlay: "
if grep -I -q 'HomeOverlay1.png' '720p/Home.xml' ; then
	XMLS=$(2>/dev/null grep '>HomeOverlay1.png<' -l 720p/*)
	remove_control 'image' '<texture>HomeOverlay1.png</texture>' "$XMLS"
	check_and_remove 'media/HomeOverlay1.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

#printf "\nRemoving labels for addons on the main menu: "
#if grep -q '<posx>91</posx>' 720p/includes.xml | head -n 1 ; then
#	remove_control 'label' '<posx>91</posx>' 720p/includes.xml
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

printf "\nChanging widgets on the home screen: "
if [ -f media/RecentAddedBack.png ] ; then
	#changing widgets background
	XMLS=$(2>/dev/null grep '>RecentAddedBack.png<' -l 720p/*)
	perlregex 's|>RecentAddedBack.png<|>'$BUTTON_NF'<|g' $XMLS
	#remove_control 'image' '<texture[^>]*>RecentAddedBack.png</texture>'
	#widget group title label
	remove_control 'label' '<description>Title label</description>' '720p/IncludesHomeWidget.xml'
	remove_control 'label' '<description>Random Title label</description>' '720p/IncludesHomeWidget.xml'
	remove_control 'label' '<description>Recent Title label</description>' '720p/IncludesHomeWidget.xml'
	#label for widgets without focus
	#remove_control 'label' '<textcolor>white</textcolor>' '720p/IncludesHomeWidget.xml'
	#remove_control 'label' '<textcolor>grey2</textcolor>' '720p/IncludesHomeWidget.xml'
	check_and_remove 'media/RecentAddedBack.png'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving home floor: "
if [ -f media/homefloor.png ] ; then
	remove_control 'image' '<texture>homefloor.png</texture>' 720p/Home.xml
	check_and_remove media/homefloor.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

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
step

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
	R+='(\s*)<posx>5[01][026]</posx>|\1\2<posx>212</posx>|'
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
	R='s|(\s*<control type="image">\s*#'
	R+='\s*)<posx>10</posx>(\s*#'
	R+='\s*)<posy>10</posy>(\s*#'
	R+='\s*)<width>124</width>(\s*#'
	R+='\s*)<height>124</height>(\s*#'
	R+='\s*<aspectratio>keep</aspectratio>\s*#)'
	R+='(\s*)(<texture background="true">.INFO.ListItem.Icon.</texture>\s*#)'
	R+='(\s*</control>\s*#)'
	R+='(\s*</focusedlayout>\s*#)'
	R+='|\1<posx>8</posx>\2<posy>8</posy>\3<width>128</width>\4<height>128</height>\5'
	R+='\6<bordersize>5</bordersize>#'
	R+='\6<bordertexture border="6">buttons/folder-focus_light.png</bordertexture>#'
	R+='\6<visible>Control\.HasFocus\(514\)</visible>#\6\7\8'
	R+='\1<posx>8</posx>\2<posy>8</posy>\3<width>128</width>\4<height>128</height>\5'
	R+='\6<bordersize>5</bordersize>#'
	R+='\6<bordertexture border="6">'$FOLDER_NF'</bordertexture>#'
	R+='\6<visible>\!Control\.HasFocus\(514\)</visible>#\6\7\8\9|'
	perlregex 720p/ViewsPictures.xml "$R"
	#add border texture directly to the picture that is not focused in the left selection panel
	R='s|(<control type="image">\s*#'
	R+='\s*)<posx>10</posx>(\s*#'
	R+='\s*)<posy>10</posy>(\s*#'
	R+='\s*)<width>124</width>(\s*#'
	R+='\s*)<height>124</height>(\s*#'
	R+='\s*<aspectratio>keep</aspectratio>\s*#)'
	R+='(\s*)(<texture background="true">.INFO.ListItem.Icon.</texture>\s*#'
	R+='\s*</control>\s*#'
	R+='\s*</itemlayout>\s*#)'
	R+='|\1<posx>8</posx>\2<posy>8</posy>\3<width>128</width>\4<height>128</height>\5'
	R+='\6<bordersize>5</bordersize>#'
	R+='\6<bordertexture border="6">'$FOLDER_NF'</bordertexture>#'
	R+='\6\7|'
	perlregex 720p/ViewsPictures.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

#printf "\n############# APPLYING MODIFICATIONS TO VIDEO LIBRARY #########################"

#printf "\n############# APPLYING MODIFICATIONS TO VIDEO OSD #############################"

printf "\n############# APPLYING MODIFICATIONS TO SMALL DIALOGS #########################"

#printf "\nChanging busy dialog: "
#if [ -f media/busy.png ] ; then
#	remove_control 'image' '<texture>busy.png</texture>' 720p/DialogBusy.xml
#	perlregex 's|(<description>Busy label</description>#\s*<posx)>60|\1>40|' 720p/DialogBusy.xml
#	check_and_remove media/busy.png
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

printf "\nChanging shutdown menu: "
if [ -f media/DialogContextTop.png ] ; then
	remove_controlid 'image' '<description>background top image</description>' 720p/DialogButtonMenu.xml
	remove_controlid 'image' '<description>background bottom image</description>' 720p/DialogButtonMenu.xml
	perlregex '720p/DialogButtonMenu.xml' 's|texturenofocus border="25,5,25,5">ShutdownButtonNoFocus.png|texturenofocus>'$BUTTON_NF'|g'
	perlregex '720p/DialogButtonMenu.xml' 's|ShutdownButtonFocus.png|'$BUTTON_FO'|g'
	check_and_remove media/ShutdownButtonFocus.png
	check_and_remove media/ShutdownButtonNoFocus.png
	check_and_remove media/DialogContextBottom.png
	check_and_remove media/DialogContextMiddle.png
	check_and_remove media/DialogContextTop.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

#printf "\nChanging context menu: "
#if grep -I -q '<itemgap>2</itemgap>' 720p/DialogContextMenu.xml ; then
	#remove itemgap
	#perlregex '720p/DialogContextMenu.xml' 's|<itemgap>2</itemgap>|<itemgap>0</itemgap>|g'
	#printf "%sDONE!%s" $GREEN $RESET
#else
	#printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

printf "\n############# CLEANING UP #####################################################"

printf "\nRemoving buttons/nf_light.png where not nedded: "
if grep -I -q 'buttons/nf_light.png' 720p/DialogPictureInfo.xml ; then
	remove_control image '<texture[^>]*>buttons/nf_light.png</texture>' 720p/CustomAddMenuItems.xml
	remove_control image '<texture[^>]*>buttons/nf_light.png</texture>' 720p/CustomAddonSelection.xml
	remove_control image '<texture[^>]*>buttons/nf_light.png</texture>' 720p/CustomAddonType.xml
	remove_control image '<texture[^>]*>buttons/nf_light.png</texture>' 720p/CustomAddSubMenuItems.xml
	remove_control image '<texture[^>]*>buttons/nf_light.png</texture>' 720p/CustomSubMenuType.xml
	remove_control image '<texture[^>]*>buttons/nf_light.png</texture>' 720p/CustomWidgetType.xml
	remove_control image '<texture[^>]*>buttons/nf_light.png</texture>' 720p/DialogFavourites.xml
	remove_control image '<texture[^>]*>buttons/nf_light.png</texture>' 720p/DialogPictureInfo.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nUnifying bordersizes: "
if grep -I -q '<bordersize>[^5]' 720p/* ; then
	XMLS=$(2>/dev/null grep '<bordersize>[^5]' -l 720p/*)
	perlregex $XMLS 's|<bordersize>[^5]<|<bordersize>5<|g'
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving useless visible conditions: "
if grep -I -q '<visible>!.Window.IsVisible.FullscreenVideo. . Window.IsVisible.Visualisation..</visible>' 720p/DialogAddonSettings.xml
then
	R='s|(\s*<control type="image">#'
	R+='\s*<description>background image</description>#'
	R+='\s*<posx>0</posx>#'
	R+='\s*<posy>0</posy>#'
	R+='\s*<width>[0-9]*</width>#'
	R+='\s*<height>[0-9]*</height>#'
	R+='\s*<texture[^>]*>dialogs/dialog-back_light.png</texture>#)'
	R+='\s*<visible>[^<]*</visible>#'
	R+='(\s*</control>#)'
	R+='\s*<control type="image">#'
	R+='\s*<description>background image</description>#'
	R+='\s*<posx>0</posx>#'
	R+='\s*<posy>0</posy>#'
	R+='\s*<width>[0-9]*</width>#'
	R+='\s*<height>[0-9]*</height>#'
	R+='\s*<texture[^>]*>dialogs/dialog-back_light.png</texture>#'
	R+='\s*<visible>[^<]*</visible>#'
	R+='\s*</control>#'
	R+='|\1\2|g'
	perlregex "$R" 720p/DialogAddonSettings.xml 720p/DialogPeripheralManager.xml 720p/DialogPictureInfo.xml 720p/DialogPVRGuideInfo.xml 720p/DialogPVRRecordingInfo.xml 720p/DialogSelect.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nSetting pulseonselect to false for all controls: "
if grep -I -q '<pulseonselect>no</pulseonselect>' 720p/defaults.xml ; then
	XMLS=$(2>/dev/null grep '<pulseonselect>no</pulseonselect>' -l 720p/*)
	perlregex $XMLS 's|<pulseonselect>no</pulseonselect>|<pulseonselect>false</pulseonselect>|g'
	R='s|(\s*)(<default type="[a-z]*"[^#]*#'
	#opening tags, but not pulseonselect
	R+='((\s*)(?!<pulseonselect)<[a-z][^#]*#)*?' 		
	R+=')\s*</default>'
	R+='|\1\2\4<pulseonselect>false</pulseonselect>#\1</default>|g'
	perlregex 720p/defaults.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nDon't clear background: "
if ! grep -I -q '<backgroundcolor>0</backgroundcolor>' 720p/AddonBrowser.xml ; then
	XMLS=$(2>/dev/null grep '<window>' -l 720p/*)
	R='s|(\s*<window[^#]*#)'
	#all kind of lines, but not <backgroundcolor
	R+='(((\s*)(?!<backgroundcolor)(?!</window)[^#]*#)*?' 		
	R+=')\s*</window>'
	R+='|\1\4<backgroundcolor>0</backgroundcolor>#\2</window>|g'
	perlregex $XMLS "$R"
	#not for dialogs without background
	R='s|\s*<backgroundcolor>0</backgroundcolor>#||g'
	perlregex 720p/SettingsScreenCalibration.xml 720p/SlideShow.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving unused include WindowTitleCommons: "
if grep -I -q 'WindowTitleCommons' 720p/includes.xml ; then
	remove_structure include ' name="WindowTitleCommons"' '' 720p/includes.xml	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step


source textures.sh
OLDIFS=$IFS ; IFS=$'\n'
for T in $TEXLIST ; do
	if [ -z "$T" ] ; then
		continue
	fi
	TEXTURE=$(echo "$T" | cut -f1 -d';')
	BORDER=$(echo "$T" |cut -f2 -d';')
	printf "\nSetting correct borders for $TEXTURE: "
	if [ "$BORDER" != "0" ] ; then
		debug "Border is not zero: '$BORDER'."
		if grep ">$TEXTURE" 720p/* | grep -v -q 'border="'$BORDER'"' ; then
			XMLS=$(2>/dev/null grep "$TEXTURE" -l 720p/*)
			R='s|border="[0-9,]*"(\| flipx="true")>('"$TEXTURE"')</|border="'$BORDER'"\1>\2</|g'
			perlregex $XMLS "$R" --nocheck
			R='s|([a-z])>('"$TEXTURE"')</|\1 border="'$BORDER'">\2</|g'
			perlregex $XMLS "$R" --nocheck
			printf "%sDONE!%s" $GREEN $RESET
		else
			printf "%sSKIPPED.%s" $CYAN $RESET
		fi
	else
		debug "Border is '$BORDER'."
		if grep ">$TEXTURE" 720p/* | >/dev/null grep 'border="' ; then
			XMLS=$(2>/dev/null grep "$TEXTURE" -l 720p/*)
			R='s| border="[0-9,]*">('"$TEXTURE"')</|>\1</|g'
			perlregex $XMLS "$R"
			printf "%sDONE!%s" $GREEN $RESET
		else
			printf "%sSKIPPED.%s" $CYAN $RESET
		fi
	fi
done ; IFS=$OLDIFS
step

#printf "\nRemoving unused include MediaStudioFlagging: "
#if grep -I -q 'MediaStudioFlagging' 720p/includes.xml ; then
#	remove_include 'MediaStudioFlagging' 720p/includes.xml	
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

INVALID='button;altlabel
textbox;scroll
textbox;wrapmultiline'

printf "\nRemoving invalid tags: "
if grep -I -q '<wrapmultiline>true</wrapmultiline>' 720p/MusicOSD.xml ; then
	IFS=$'\n' ; for T in $INVALID ; do
		CONTROL=$(echo "$T" | cut -f1 -d';')
		TAG=$(echo "$T" | cut -f2 -d';')
		R="s|(<control type=\"$CONTROL\"[^#]*#"
		R+="(\s*<(?!$TAG)[a-z][^#]*#)*)"
		R+="\s*<$TAG[^#]*#"
		R+="((\s*<(?!$TAG)[a-z][^#]*#)*"
		R+="\s*</control>)"
		R+="|\1\3|g"
		XMLS=$(2>/dev/null grep "$TAG" -l 720p/*)
		perlregex $XMLS "$R"
	done
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving double tags from defaults.xml: "
TAGCOUNT=$(grep -a -z -Po "<default type=\"selectbutton\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<font[ >]" | wc -l )
if [ $TAGCOUNT -gt 1 ] ; then
	DEFCONS=$(grep -o 'default type="[a-z]*"' 720p/defaults.xml | grep -o '"[a-z]*"' | tr -d '"' )
	IFS=$'\n' ; for CONTROL in $DEFCONS ; do
		for TAG in $(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep -o "<[a-z]*[ >]" | grep -v "default" | sed 's|^\s*<||' | sed 's|[ >]$||g' ) ; do
			TAGCOUNT=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<$TAG[ >]" | wc -l )
			while [ $TAGCOUNT -gt 1 ] ; do
				R="s|(default type=\"$CONTROL\"[^#]*#"
				R+="(\s*<(?!$TAG[ >])[a-z][^#]*#)*)"
				R+="\s*<$TAG[ >][^#]*#"
				R+="|\1|"
				perlregex "$R" 720p/defaults.xml
				CHANGED=true
				TAGCOUNT=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<$TAG[ >]" | wc -l )
			done
		done
	done
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

CONTROLS=$(grep -o '<control type="[a-z]*"' 720p/* | grep -o '"[a-z]*"' | tr -d '"' | sort -u -r | egrep -v 'list|group|panel|epggrid|karvisualisation')
for CONTROL in $CONTROLS ; do
	printf "\nAdding '$CONTROL' to defaults.xml: "
	if ! grep -q "<default type=\"$CONTROL\"" 720p/defaults.xml ; then
		R='s|(<includes>#)(\s*)|\1\2<default type="'$CONTROL'">#\2<\/default>#\2|g'
		perlregex 720p/defaults.xml "$R"					
		printf "%sDONE!%s" $GREEN $RESET
	else
		printf "%sSKIPPED.%s" $CYAN $RESET
	fi
done
step

printf "\nScanning for tags to optimize: "
OPTTAGS=""
for CONTROL in $CONTROLS ; do
	TAGS=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep -o "<[a-z]*[ >]" | grep -v "<control" | tr -d '<> ' | sort -u )
	INCLUDES=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep "<include>" | sed 's|<[/]*include>||g' | sed 's|^\s*||' | sort -u )
	INCLUDETAGS=""
	for INCLUDE in $INCLUDES ; do
		INCLUDETAGS="$INCLUDETAGS"$'\n'$(grep -a -z -Po "<include name=\"$INCLUDE\".*\n(\s*<[a-z].*\n)*\s*</include>" 720p/* | grep -o "<[a-z]*[ >]" | grep -v "<include" | tr -d '<>' | sort -u)
	done
	INCLUDETAGS=$(echo "$INCLUDETAGS" | sort -u)
	for TAG in $TAGS ; do
		if ! [[ *$INCLUDETAGS* = *$TAG* ]] ; then
			OPTTAGS="$OPTTAGS"$'\n'"$CONTROL;$TAG"
		fi
	done
done
OPTTAGS=$(echo "$OPTTAGS" | egrep -v 'description|include|onup|ondown|onleft|onright|onclick')
printf "%sDONE!%s" $GREEN $RESET
step

#printf "\nAdding xbmc defaults to defaults.xml: "
#if false; then #! grep -q '<loop>yes</loop>' 720p/defaults.xml ; then
#	XBMCDEFS='
#;visible;<visible>true</visible>
#;colordiffuse;<colordiffuse>FFFFFFFF</colordiffuse>
#;enable;<enable>true</true>
#;pulseonselect;<pulseonselect>true</pulseonselect>
#edit;aligny;<aligny>top</aligny>
#fadelabel;resetonlabelchange;<resetonlabelchange>true</resetonlabelchange>
#fadelabel;scrollspeed;<scrollspeed>60</scrollspeed>
#label;align;<align>left</align>
#label;aligny;<aligny>top</aligny>
#label;scroll;<scroll>false</scroll>
#label;scrollspeed;<scrollspeed>60</scrollspeed>
#label;scrollsuffix;<scrollsuffix>|</scrollsuffix>
#multiimage;loop;<loop>yes</loop>
#radiobutton;align;<align>left</align>
#radiobutton;aligny;<aligny>top</aligny>
#scrollbar;orientation;<orientation>vertical</orientation>
#scrollbar;showonepage;<showonepage>true</showonepage>
#selectbutton;align;<align>left</align>
#selectbutton;aligny;<aligny>top</aligny>
#'
#	for CONTROL in $CONTROLS ; do
#		for TAG in $(echo "$OPTTAGS" | grep "^$CONTROL;") ; do
#			TAG=$(echo "$TAG" | cut -f2 -d';')
#			DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<$TAG[ >]" | sed 's|^\s*||')
#			NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
#			if [ -z "$DEFTAG" ] && [ $NUMMISSING -gt 0 ] ; then
#				XBMCDEF=$(echo "$XBMCDEFS" | grep "^;$TAG;" | head -1 )
#				if [ -z "$XBMCDEF" ] ; then
#					XBMCDEF=$(echo "$XBMCDEFS" | grep "^$CONTROL;$TAG;" | head -1 )
#				fi
#				if ! [ -z "$XBMCDEF" ] ; then
#					NEWDEFAULT=$(echo "$XBMCDEF" | cut -f3 -d';')
#					R="s|(\s*)(<default type=\"$CONTROL\"[^#]*#)"		#1#2
#					R+="|\1\2\1\1$NEWDEFAULT#|g"
#					perlregex "$R" 720p/defaults.xml
#				fi
#			fi
#		done
#	done
#	printf "%sDONE!%s" $GREEN $RESET
#else
#	printf "%sSKIPPED.%s" $CYAN $RESET
#fi
#step

printf "\nOptimizing tags with existing default values: "
for CONTROL in $CONTROLS ; do
	printf "\nOptimizing '$CONTROL' control: "
	CHANGED=false
	for TAG in $(echo "$OPTTAGS" | grep "^$CONTROL;") ; do
		TAG=$(echo "$TAG" | cut -f2 -d';')
		DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<$TAG[ >]" | sed 's|^\s*||')
		if ! [ -z "$DEFTAG" ] ; then
			NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
			MOST=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep "<$TAG[ >]" | sed 's|^\s*||' | sort --batch-size=1021 | uniq -c | sort -n -r | head -1 | sed 's|^\s*||')
			NUMMOST=$(echo "$MOST" | cut -f1 -d' ')
			MOST=$(echo "$MOST" | sed 's|^[0-9]*\s*||')
			if [ "$MOST" != "$DEFTAG" ] && [ $NUMMOST -gt $NUMMISSING ] ; then
				if [ $NUMMISSING -gt 0 ] ; then
					R="s|(<control type=\"$CONTROL\"[^#]*#)(\s*)"
					R+="((\s*(?!<$TAG[ >])<[a-z][^#]*#)*"
					R+="\s*</control>\s*#)"
					R+="|\1\2$DEFTAG#\2\3|g"
					XMLS=$(2>/dev/null grep "<control type=\"$CONTROL\"" -l 720p/*)
					perlregex $XMLS "$R"
				fi
				NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
				if [ $NUMMISSING -gt 0 ] ; then
					echo "There should be no more controls with missing tag, but we found some!"
					exit
				fi
				MOST=$(echo "$MOST" | sed 's/|/\\|/g')
				R="s|(<default type=\"$CONTROL\"[^#]*#"		#1
				R+="(\s*<[a-z][^#]*#)*?"					#2
				R+="\s*)$DEFTAG(#"							#3
				R+="(\s*<[a-z][^#]*#)*?"					#4
				R+="\s*</default>#)"
				R+="|\1$MOST\3|g"
				perlregex 720p/defaults.xml "$R"
				CHANGED=true
			fi
		fi
	done
	if $CHANGED ; then
		printf "%sDONE!%s" $GREEN $RESET
	else
		printf "%sSKIPPED.%s" $CYAN $RESET
	fi
done
step

printf "\nOptimizing tags with missing default values: "
for CONTROL in $CONTROLS ; do
	printf "\nOptimizing '$CONTROL' control: "
	CHANGED=false
	for TAG in $(echo "$OPTTAGS" | grep "^$CONTROL;") ; do
		TAG=$(echo "$TAG" | cut -f2 -d';')
		DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<$TAG[ >]" | sed 's|^\s*||')
		if [ -z "$DEFTAG" ] ; then
			NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
			if [ $NUMMISSING == 0 ] ; then
				MOST=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep "<$TAG[ >]" | sed 's|^\s*||' | sort --batch-size=1021 | uniq -c | sort -n -r | head -1 | sed 's|^\s*||')
				NUMMOST=$(echo "$MOST" | cut -f1 -d' ')
				MOST=$(echo "$MOST" | sed 's|^[0-9]*\s*||')
				MOST=$(echo "$MOST" | sed 's/|/\\|/g')
				R="s|(\s*)(<default type=\"$CONTROL\"[^#]*#)"		#1#2
				R+="|\1\2\1\1$MOST#|g"
				perlregex "$R" 720p/defaults.xml	
				CHANGED=true
			fi
		fi
	done
	if $CHANGED ; then
		printf "%sDONE!%s" $GREEN $RESET
	else
		printf "%sSKIPPED.%s" $CYAN $RESET
	fi
done
step

LINES=$(more 720p/* | wc -l)
printf "\n$LINES lines in xmls."
DEFCONS=$(grep -o 'default type="[a-z]*"' 720p/defaults.xml | grep -o '"[a-z]*"' | tr -d '"' )
IFS=$'\n' ; for CONTROL in $DEFCONS ; do
	printf "\nRemoving default tags for control type '$CONTROL': "
	for TAG in $(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<[a-z]*[ >]" | grep -v "default" | sed 's|^\s*||' | sed 's|\s*$||' ) ; do
		#echo "'$CONTROL', '$TAG'"
		R="s|(<control type=\"$CONTROL\"[^#]*#(\s*<[a-z][^#]*#)*)\s*$TAG#|\1|g"
		XMLS2=""
		XMLS=$(2>/dev/null grep "$TAG" -l 720p/*)
		for X in $XMLS ; do
			if grep -q "<control type=\"$CONTROL\"" "$X" ; then
				XMLS2="$XMLS2"$'\n'"$X"
			fi
		done
		if [ ! -z "$XMLS2" ] ; then
			perlregex "$R" $XMLS2 --nocheck
		fi
	done
	printf "%sDONE!%s" $GREEN $RESET
done
step
LINES=$(more 720p/* | wc -l)
printf "\n$LINES lines in xmls."

printf "%s\nAll modifications are completed.\n%s" $GREEN $RESET

exit
