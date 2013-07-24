#!/bin/bash
#set -e
SCRIPTFILE=$0
source "bashlib.sh"

2>/dev/null rm debug.log
TILL=0


# removes <$STRUCTURE$TAGS> .... </$STRUCTURE> structure from a xml file
# the controle structure to remove is identified by the characteristic line
# $1 type of structure (control, include, etc...)
# $2 structure tags ( type="" id="", etc...)
# $3 characteristic line
# $4 files where to search
remove_structure() {(
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
)}


# removes <include name="?"> .... </include> structure from a xml file
# $1 name of include
# $2 files where to search
remove_include() {(
	local NAME=$1
	local FILES=$2
	if [ -z "$FILES" ] ; then
		FILES=$(2>/dev/null grep -a -l "<include name=\"$NAME\"" 720p/*)
	fi
	local REGEX='s|\s*<include name="'$NAME'">#'
	REGEX+='(\s*<[/a-z][^#]*#\|)*?'
	REGEX+='\s*</include>#'
	REGEX+='||g'
	perlregex "$REGEX" "$FILES"
	if grep -I -q "$NAME[^a-zA-Z]" 720p/* ; then
		printf "\n'Removed include $NAME' was found in the .xmls: \n"
		grep "$NAME[^a-zA-Z]" 720p/*
	fi
)}



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
	if [ -z "$FILES" ] ; then
		FILES=$(2>/dev/null grep -a -l "<variable name=\"$NAME\"" 720p/*)
	fi
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
remove_control() {(
	local TYPE=$1
	local LINE="$2"
	local FILES="$3"
	remove_structure "control" " type=\"$TYPE\"" "$LINE" "$FILES"
)}



# removes <control type="?"> .... </control> structure from a xml file
# this function removes also controls with an id!
# the controle structure to remove is identified by the characteristic line
# $1 type of controle (image, button, etc...)
# $2 characteristic line
# $3 files where to search
remove_controlid() {
	(
	local TYPE=$1
	local LINE="$2"
	local FILES="$3"
	remove_structure "control" " type=\"$TYPE\"[^>]*" "$LINE" "$FILES"
)
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

		if ! grep -I "[^a-z_\.\(]$BASE[^a-zA-Z0-9 _\.=/]" 720p/* | grep -v -q '<description>' ; then
			rm "$FILE" # 2>/dev/null
		else
			printf "\n'$BASE' ('$FILE') was found in the .xmls (deleting anyway): \n"
			grep "[^a-z_\.\(]$BASE[^a-zA-Z0-9 _\.=/]" 720p/*  | grep -v -q '<description>'
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

printf "\n############# PREPARING MODIFICATIONS #########################################"

printf "\nReplacing '#'s in original xmls: "
if grep -q '#' 720p/SkinSettings.xml ; then 
	sed 's/#/No\./g' -i 720p/SkinSettings.xml 
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\n############# REPLACING... ####################################################"

REPL='\s*<\!--(?!-->).*?-->[^#]*#;;Removing uncommented tags;<\!--
>yes</;>true</;
>no</;>false</;
>-</;></;
>(<[^/]);>#\1;Adding missing newlines before opening tags
>(</control>);>#\1;Adding missing newlines befor closing controls
 fallback="xbmc-logo.png";;Removing xbmc logo fallback from music visualisation
\s*<shadowcolor>[a-z]*</shadowcolor>#;;Removing font dropshadows
\s*<include>VisibleFadeEffect</include>#;;Removing VisibleFadeEffect
<textoffsetx>[0-9]*<;<textoffsetx>10<;Unifying textoffsetx tags;<textoffsetx>0<
<pulseonselect>true<;<pulseonselect>false<;Setting pulseonselect to false for all controls
<bordersize>[^5]<;<bordersize>5<;Unifying bordersizes
OSD_;osd_;Correcting filenames
.INFO.Skin.CurrentTheme,special://skin/backgrounds/,.jpg.;'$BACKGROUND_DEF';Replacing some backgrounds'
IFS=$'\n' ; for R in $REPL ; do
	REPLACE=$(echo "$R" | cut -f1 -d';')
	WITH=$(echo "$R" | cut -f2 -d';')
	MESSAGE=$(echo "$R" | cut -f3 -d';')
	PATTERN=$(echo "$R" | cut -f4 -d';')
	if [ -z "$PATTERN" ] ; then
		PATTERN=$(echo "$REPLACE" | tr -d '#')
	fi
	if [ -z "$MESSAGE" ] ; then
		printf "\nReplacing '$REPLACE' with '$WITH': "
	else
		printf "\n$MESSAGE: "
	fi
	XMLS=$(2>/dev/null grep -a -l -P "$PATTERN" 720p/*)
	if ! [ -z "$XMLS" ] ; then
		perlregex $XMLS "s|$REPLACE|$WITH|g"
		printf "%sDONE!%s" $GREEN $RESET
	else
		printf "%sSKIPPED.%s" $CYAN $RESET
	fi
done
step

printf "\n############# REMOVING CONTROLS... ############################################"

REMCONTROLS='<texture>.INFO.listitem.Studio,studios.,.png.</texture>;image;;Removing studio logos: 
<texture flipy="true">HomeNowPlayingBack.png</texture>;image;id;Removing HomeNowPlayingBack.png where not needed: 
<texture>home-power-focus.gif</texture>;image;;Removing reference to non-existing file home-power-focus.gif: '
for R in $REMCONTROLS ; do
	LINE=$(echo "$R" | cut -f1 -d';')
	TYPE=$(echo "$R" | cut -f2 -d';')
	MESSAGE=$(echo "$R" | cut -f4 -d';')
	if [ -z "$MESSAGE" ] ; then
		printf "\nRemoving '$TYPE' control with '$LINE': "
	else
		printf "\n$MESSAGE"
	fi
	XMLS=$(2>/dev/null grep -a -l "$LINE" 720p/*)
	if ! [ -z "$XMLS" ] ; then
		CMD=remove_control$(echo "$R" | cut -f3 -d';')
		$CMD "$TYPE" "$LINE" "$XMLS"
		printf "%sDONE!%s" $GREEN $RESET
	else
		printf "%sSKIPPED.%s" $CYAN $RESET
	fi
done
step

printf "\n############# REMOVING MEDIA FILES ############################################"

REMOVE='
media/GlassOverlay.png;
media/icon_volume.png;
media/poster_diffuse.png;
media/defaultDVDFull.png;
backgrounds/Fire.jpg;
backgrounds/Kryptonite.jpg;
media/OverlayWatching.png;
media/Invisable.png;
media/diffuse_mirror2.png;
media/diffuse_mirror3.png;
media/DialogCloseButton.png;id
media/DialogCloseButton-focus.png;id
media/ContentPanelMirror.png;
media/floor.png;
media/ThumbBG.png;
media/arrow-big-up.png;
media/arrow-big-down.png;
media/icon-rss.png;
media/separator_vertical.png;
media/separator.png;
media/xbmc-logo.png;
media/DialogContextBottom.png;id
media/DialogContextMiddle.png;
media/DialogContextTop.png;
media/icon_addons.png;
media/icon_system.png;
media/icon_music.png;
media/icon_video.png;
media/icon_weather.png;
media/icon-video.png;
media/icon-weather.png;
media/icon_pictures.png;
media/MediaItemDetailBG.png;
media/livecdcase/cdglass.png;
media/livecdcase/cdshadow.png;
media/dialogheader.png;
media/GlassTitleBar.png;
media/gradient.png;
media/Confluence_Logo.png;
media/cdwall-grid.png;
media/HomeSeperator.png;
media/homefloor.png;
media/SideFade.png;
media/HomeOverlay1.png;
'

printf "\nRemoving media files: "
for R in $REMOVE ; do
	if [ -z "$R" ] ; then continue ; fi
	FILE=$(echo "$R" | cut -f1 -d';')
	NAME=$(echo "$FILE" | sed 's|^media/||')
	if [ -f "$FILE" ] ; then
		printf "\nRemoving '$FILE'."
		XMLS=$(2>/dev/null grep "$NAME" -l 720p/*)
		if ! [ -z "$XMLS" ] ; then
			CMD=remove_control$(echo "$R" | cut -f2 -d';')
			>/dev/null $CMD "(label\|button\|image)" "<texture[^>]*>$NAME</texture[^>]*>" "$XMLS"
			>/dev/null $CMD "(label\|button\|image)" "<texture(\| flipy=\"true\"\| background=\"true\")* diffuse=\"$NAME\"[^<]*</texture>" "$XMLS"
		else
			printf " ('$NAME' does not occur in the XMLs.)"
		fi
		rm "$FILE"
	else 
		debug "'$FILE' doesn't exist."
	fi
done
printf "\n%sDONE!%s" $GREEN $RESET
step

printf "\nRemoving ClearCases: "
if [ -d media/ClearCase ] ; then
	remove_control image '<visible>\!Skin.HasSetting\(View724DisableCases\)</visible>' 720p/ViewsLowlist.xml
	perlregex 's|\s*<visible>Skin.HasSetting\(View724DisableCases\)</visible>\s*#||' 720p/ViewsLowlist.xml
	remove_controlid radiobutton '<onclick>Skin.ToggleSetting\(View724DisableCases\)</onclick>' 720p/MyVideoNav.xml
	remove_controlid radiobutton '<onclick>Skin.ToggleSetting\(UseDiscTypeCase\)</onclick>' 720p/MyVideoNav.xml
	rm -rf media/ClearCase
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

printf "\nRemoving thumb shadows: "
if [ -f media/ThumbShadow.png ] ; then
	XMLS=$(2>/dev/null grep 'ThumbShadow.png' -l 720p/*)
	R='s|(\s*<bordertexture[^>]*>ThumbShadow.png</bordertexture>#\|'
	R+='\s*<bordersize>[0-9]*</bordersize>#){2}'
	R+='||g'
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep 'ThumbShadow.png' -l 720p/*)
	R='s|\s*<bordertexture[^>]*>ThumbShadow.png</bordertexture>#'
	R+='(\s*<(?!control)[a-z][^#]*#)*'
	R+='\s*<bordersize>[0-9]*</bordersize>#'
	R+='|\1|g'
	perlregex $XMLS "$R"
	check_and_remove 'media/ThumbShadow.png'
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
	R='s|\s*<bordersize>[0-9]*</bordersize>#'
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

printf "\nRemoving NoCover border: "
if grep -q '<bordertexture border="3">NoCover_1.png</bordertexture>' 720p/SlideShow.xml ; then
	R='s|\s*<bordertexture border="3">NoCover_1.png</bordertexture>#'
	R+='\s*<bordersize>[0-9]*</bordersize>#'
	R+='||g'
	perlregex 720p/SlideShow.xml "$R"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nRemoving GenreFlagging: "
if [ -d media/DefaultGenre ] ; then
	XMLS=$(2>/dev/null grep '<visible>.Skin.HasSetting.View501GenreIcons.<.visible>' -l 720p/*)
	remove_control 'grouplist' '<visible>\!Skin.HasSetting\(View501GenreIcons\)</visible>' "$XMLS"
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

printf "\n############# REPLACING MEDIA FILES ###########################################"

REPLACE="
media/HasSub.png;
media/unknown-user.png;DefaultActor.png
media/StackNF.png;$BUTTON_NF
media/StackFO.png;$BUTTON_FO
media/ShutdownButtonFocus.png;$BUTTON_FO
media/ShutdownButtonNoFocus.png;$BUTTON_NF
media/radiobutton-focus.png;$RADIOBUTTON_FO
media/radiobutton-nofocus.png;$RADIOBUTTON_NF
media/button-nofocus.png;$BUTTON_NF
media/DialogBack.png;$DIALOG_BG
media/DialogBack2.png;$DIALOG_BG
media/InfoMessagePanel.png;$DIALOG_BG
media/OverlayDialogBackground.png;$DIALOG_BG
media/ContentPanel.png;$CONTENT_BG
media/media-overlay.jpg;$BACKGROUND_DEF
backgrounds/SKINDEFAULT.jpg;$BACKGROUND_DEF
media/ScrollBarH_bar.png;$SCROLLBAR_HOR_BAR
media/ScrollBarV_bar.png;$SCROLLBAR_VER_BAR
media/ScrollBarH.png;$SCROLLBAR_HOR
media/ScrollBarV.png;$SCROLLBAR_VER
media/ScrollBarH_bar_focus.png;$SCROLLBAR_HOR_BAR_FO
media/ScrollBarV_bar_focus.png;$SCROLLBAR_VER_BAR_FO
media/ScrollBarNib.png;
media/warning.png;DefaultIconWarning.png
media/button-focus2.png;$BUTTON_FO
media/button-focus.png;$BUTTON_FO
media/MenuItemFO.png;$BUTTON_FO
media/KeyboardCornerTopNF.png;$BUTTON_NF
media/KeyboardCornerTop.png;$BUTTON_FO
media/KeyboardCornerBottomNF.png;$BUTTON_NF
media/KeyboardCornerBottom.png;$BUTTON_FO
media/KeyboardEditArea.png;$KEYBOARD_EDITAREA
media/KeyboardKeyNF.png;$BUTTON_NF
media/KeyboardKey.png;$BUTTON_FO
media/MediaBladeSub.png;$MEDIA_BLADE
media/HomeBladeSub.png;$HOME_BLADE
media/OSDProgressMidLight.png;$PROGRESS_MIDLIGHT
media/OSDProgressMid.png;$PROGRESS_MID
media/OSDProgressBack.png;$PROGRESS_BACK
media/folder-focus.png;buttons/folder-focus_light.png
media/seekslider.png;
media/seekslider2.png;
media/osd_slider_bg.png;$SLIDER_BG
media/osd_slider_bg_2.png;$SLIDER_BG
media/osd_slider_nibNF.png;$SLIDER_NIB_NF
media/osd_slider_nib.png;$SLIDER_NIB_FO
media/floor_button.png;$BUTTON_NF
media/floor_buttonFO.png;$BUTTON_FO
media/HomeSubNF.png;$HOME_SUB_NF
media/HomeSubFO.png;$HOME_SUB_FO
media/RecentAddedBack.png;$BUTTON_NF
"

printf "\nReplacing media files: "
for R in $REPLACE ; do
	if [ -z "$R" ] ; then continue ; fi
	FILE=$(echo "$R" | cut -f1 -d';')
	NAME=$(echo "$FILE" | sed 's|^media/||')
	WITH=$(echo "$R" | cut -f2 -d';')
	if [ -f "$FILE" ] ; then
		printf "\nReplacing '$FILE'."
		XMLS=$(2>/dev/null grep "$NAME" -l 720p/*)
		if ! [ -z "$XMLS" ] ; then
			perlregex $XMLS "s|([/>\"])$NAME([<\"])|\1$WITH\2|g"
		else
			printf " ('$NAME' does not occur in the XMLs.)"
		fi
		rm "$FILE"
	else 
		debug "'$FILE' doesn't exist."
	fi
done
printf "\n%sDONE!%s" $GREEN $RESET
step

printf "\nReplacing standard album cover: "
if [ -f media/FallbackAlbumCover.png ] ; then
	XMLS=$(2>/dev/null grep 'FallbackAlbumCover.png' -l 720p/*)
	perlregex $XMLS 's|FallbackAlbumCover.png|DefaultAlbumCover.png|g'
	XMLS=$(2>/dev/null grep 'livecdcase/DefaultAlbumCover.png' -l 720p/*)
	perlregex $XMLS 's|livecdcase/DefaultAlbumCover.png|DefaultAlbumCover.png|g'
	#XMLS=$(2>/dev/null grep 'FallbackAlbumCover.png' -l 720p/*)
	#perlregex $XMLS 's|>FallbackAlbumCover.png<|>DefaultAlbumCover.png<|g'
	rm media/livecdcase/DefaultAlbumCover.png
	rm media/DefaultAlbumCover.png
	mv media/FallbackAlbumCover.png media/DefaultAlbumCover.png
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
	R+='\s*<bordersize>[0-9]*</bordersize>#'
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

printf "\nReplacing DefaultCDArt: "
if [ -f media/livecdcase/DefaultCDArt.png ] ; then
	XMLS=$(2>/dev/null grep 'DefaultCDArt.png' -l 720p/*)
	perlregex $XMLS 's|(fallback="livecdcase/DefaultCDAr)t.png"( diffuse="livecdcase/cddiffuse.png")|\1t\.jpg"\2|g'
	perlregex $XMLS 's|(<width>170</width>#\s*<height>175</height>#\s*<include>CDArtSpinner</include>#\s*<texture fallback="livecdcase/DefaultCDAr)t.png"|\1t_small.png"|g'
	check_and_remove media/livecdcase/DefaultCDArt.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing separators: "
if [ -f media/separator2.png ] ; then
	XMLS=$(2>/dev/null grep '>separator2.png<' -l 720p/*)
	remove_control 'image' '<texture>separator2.png</texture>' "$XMLS"
	#not all controls can be removed, some have an id and are used for navigation
	XMLS=$(2>/dev/null grep 'separator2.png' -l 720p/*)
	perlregex $XMLS 's|separator2.png|'$BUTTON_NF'|g'
	check_and_remove media/separator2.png
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nReplacing some bordertextures: "
if grep -q '>buttons/nf_light.png</bordertexture>' 720p/DialogAlbumInfo.xml 720p/includes.xml ; then
	R='s|<bordertexture[^>]*>buttons/nf_light.png</bordertexture>|<bordertexture>'$FOLDER_NF'</bordertexture>|g'
	perlregex 720p/includes.xml 720p/SettingsProfile.xml 720p/ViewsFileMode.xml 720p/ViewsVideoLibrary.xml 720p/ViewsMusicLibrary.xml 720p/ViewsAddonBrowser.xml "$R"
	R='s|<bordertexture[^>]*>buttons/nf_light.png</bordertexture>|<bordertexture></bordertexture>|g'
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

printf "\n############# APPLYING GENERIC/SKIN-WIDE MODIFICATIONS ########################"

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

printf "\nRemoving other color schemes: "
if [ -f colors/Fire.xml ] ; then
	rm colors/Fire.xml
	rm colors/Kryptonite.xml
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

printf "\nRemoving page count info: "
if grep -q 'CommonPageCount</include>' 720p/* ; then		
	#includes
	XMLS=$(2>/dev/null grep 'CommonPageCount' -l 720p/*)
	perlregex $XMLS 's|\s*<include[^>]*>CommonPageCount</include>\s*#||g'

	XMLS=$(2>/dev/null grep 'HideNumItemsCount' -l 720p/*)
	remove_control label '<visible>.Skin.HasSetting.HideNumItemsCount.</visible>' "$XMLS"
	XMLS=$(2>/dev/null grep '<selected>Skin.HasSetting.HideNumItemsCount.</selected>' -l 720p/*)
	if ! [ -z "$XMLS" ] ; then 
		remove_controlid radiobutton '<selected>Skin.HasSetting.HideNumItemsCount.</selected>' "$XMLS"
	fi
	remove_control label '<posx>130r</posx>' 720p/DialogAlbumInfo.xml
	R='s|\s*<control type="label">#(\s*<[a-z]*[^#]*#)*?\s*<label>.LOCALIZE.207.[^#]*#\s*</control>||g'
	#perlregex 720p/DialogPVRRecordingInfo.xml "$R"
	remove_control label '<label>(\|.COLOR=blue.).LOCALIZE.207.[^#]*#' 720p/DialogPVRRecordingInfo.xml
	remove_control label '<label>(\|.COLOR=blue.).LOCALIZE.20[67].[^#]*#' 720p/DialogVideoInfo.xml
	remove_control label '<description>Description Page Count</description>' 720p/DialogAddonInfo.xml
	rm -rf media/CommonCount/
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

printf "\nModifying weather info in the upper left corner: "
if grep -I -q '<description>Location label</description>' 720p/* ; then
	XML=$(2>/dev/null grep '<description>Location label</description>' -l 720p/* )
	#remove weather location
	remove_control 'label' '<description>Location label</description>' $XML
	#center temp label
	R='s|(<posx>65</posx>\s*#'
	R+='\s*<posy)>20</posy>'
	R+='|\1>15</posy>|'
	perlregex $XML "$R"
	#remove weather condition
	remove_control 'label' '<description>Conditions Label</description>' $XML
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nMoving tags out of includes: "
TOMOVE='button;textwidth,font,height,texturefocus,pulseonselect,texturenofocus,focusedcolor,textcolor,posx,posy,width,height,align,aligny,textoffsetx
label;textcolor,width,height,font,posx,posy
image;posx,posy,width,height
togglebutton;font'
IFS=$'\n'; for MOVE in $TOMOVE ; do
	CONTROL=$(echo "$MOVE" | cut -f1 -d';')
	TAGS=$(echo "$MOVE" | cut -f2 -d';' | tr ',' '\n')
	printf "\nFor '$CONTROL' controls: "
	INCS=$(grep -z -Po '<control type="'$CONTROL'".*\n(\s*<[a-z].*\n)*' 720p/* | grep '<include>' | sed 's|^\s*<include>||'  | sed 's|</include>\s*||'| sort -u)
	for TAG in $TAGS; do
		for INC in $INCS ; do
			INCTAG=$(grep -z -Po "<include name=\"$INC\".*\n(\s*<[a-z].*\n)*" 720p/* | grep "<$TAG[ >]" | sed 's|^\s*||' | sed 's|\s*$||' )
			if ! [ -z "$INCTAG" ] ; then
				XMLS=$(2>/dev/null grep -a -l "include name=\"$INC\"" 720p/*)
				perlregex $XMLS "s|(<include name=\"$INC\"[^#]*#(\s*<(?!$TAG)[a-z][^#]*#)*)\s*<$TAG[ >][^#]*#|\1|"
				R="s|(\s*)(<include>$INC</include>\s*#)|\1\2\1$INCTAG#|g"
				XMLS=$(2>/dev/null grep "<include>$INC</include>" -l 720p/*)
				perlregex "$R" $XMLS
			fi
		done
	done
	printf "%sDONE!%s" $GREEN $RESET
done
step

printf "\nChanging color scheme: "
if ! grep -q 'buttonfocus' colors/defaults.xml ; then
	R='s|(\s*<colors>#)(\s*)'
	R+='|\1\2<color name="buttonfocus">ffb15e1e</color>#'
	R+='\2<color name="buttonnofocus">ff577490</color>#'
	R+='\2<color name="heading1">ffeb9e17</color>#'
	R+='\2<color name="heading2">ff0084ff</color>#'
	R+='\2<color name="heading3">ffffffff</color>#'
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

printf "\nChanging font colors for original 'white' strings: "
if grep -q 'white' 720p/* ; then

	CONTROL='label'
	TAG='textcolor'
	DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<$TAG[ >]" | sed 's|^\s*||')
	R="s|(<control type=\"$CONTROL\"[^#]*#)(\s*)"
	R+="((\s*(?!<$TAG[ >])<[a-z][^#]*#)*"
	R+="\s*</control>\s*#)"
	R+="|\1\2$DEFTAG#\2\3|g"
	XMLS=$(2>/dev/null grep "<control type=\"$CONTROL\"" -l 720p/*)
	perlregex $XMLS "$R"
	
	R="s|(<default type=\"$CONTROL\">#"
	R+="(\s*<[a-z][^#]*#)*?)"
	R+="\s*$DEFTAG#"
	R+="|\1|g"
	perlregex "$R" 720p/defaults.xml

	XMLS=$(2>/dev/null grep 'headlinecolor>white' -l 720p/*)
	perlregex $XMLS 's|<headlinecolor>white</headlinecolor>|<headlinecolor>heading2</headlinecolor>|g'

	XMLS=$(2>/dev/null grep 'selectedcolor>white' -l 720p/*)
	perlregex $XMLS 's|<selectedcolor>white</selectedcolor>|<selectedcolor>itemselected</selectedcolor>|g'

	XMLS=$(2>/dev/null grep 'focusedcolor>white' -l 720p/*)
	perlregex $XMLS 's|<focusedcolor>white</focusedcolor>|<focusedcolor>textfocus</focusedcolor>|g'

	XMLS=$(2>/dev/null grep 'textcolor>white' -l 720p/*)
	perlregex $XMLS "s|<textcolor>white|<textcolor>textnofocus|g"
	
	R="s|COLOR=white|COLOR=textnofocus|g"
	perlregex "$R" 720p/ViewsVideoLibrary.xml 720p/VideoFullScreen.xml 720p/IncludesVariables.xml 720p/MyWeather.xml

	R="s|COLOR=white|COLOR=heading2|g"
	perlregex "$R" 720p/SkinSettings.xml

	if grep -q 'white' 720p/* ; then
		printf "\nERROR: White color still used!"
		printf "\n"
		grep 'white' 720p/*
		exit 4
	fi
	perlregex colors/defaults.xml "s|\s*<color name=\"white\"[^#]*#||g"

	NTEXTNF=0
	TEXTNF=$(grep -z -Po '<focusedlayout.*\n(\s*(<[a-z]|</[vac]|[!a-zA-Z\[]).*\n)*\s*</focused' 720p/* | grep '<textcolor' | grep 'textnofocus' | wc -l)
	while ! [ $TEXTNF -eq $NTEXTNF ] ; do
		TEXTNF=$(grep -z -Po '<focusedlayout.*\n(\s*(<[a-z]|</[vac]|[!a-zA-Z\[]).*\n)*\s*</focused' 720p/* | grep '<textcolor' | grep 'textnofocus' | wc -l)
		XMLS=$(2>/dev/null grep 'focusedlayout' -l 720p/* | egrep -v '720p/IncludesHomeWidget.xml')
		R="s|(<focusedlayout[^#]*#"
		R+="(\s*(<[a-z]\|</[vac]\|[a-zA-Z\[\!])[^#]*#)*"
		R+="\s*<textcolor)>textnofocus<"
		R+="|\1>textfocus<|g"
		perlregex $XMLS "$R" --nocheck
		NTEXTNF=$(grep -z -Po '<focusedlayout.*\n(\s*(<[a-z]|</[vac]|[!a-zA-Z\[]).*\n)*\s*</focused' 720p/* | grep '<textcolor' | grep 'textnofocus' | wc -l)
	done

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

printf "\nChanging font colors for original 'grey2' strings: "
if grep -q 'grey2' 720p/* ; then
	XMLS=$(2>/dev/null grep 'disabledcolor>grey2<' -l 720p/*)
	R="s|disabledcolor>grey2<|disabledcolor>textdisabled<|g"
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep 'textcolor>grey2<' -l 720p/*)
	R="s|textcolor>grey2<|textcolor>textnofocus<|g"
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep 'COLOR=grey2\]' -l 720p/*)
	perlregex $XMLS "s|COLOR=grey2\]|COLOR=textnofocus\]|g"
	XMLS=$(2>/dev/null grep 'COLOR=grey2' -l -r language/*)
	R="s|COLOR=grey2|COLOR=textnofocus|g"
	for X in $XMLS ; do
		sed "$R" -i "$X"
	done

	if grep -q 'grey2' 720p/* ; then
		printf "\nERROR: Grey2 color still used!"
		printf "\n"
		grep 'grey2' 720p/*
		exit 4
	fi
	perlregex colors/defaults.xml "s|\s*<color name=\"grey2\"[^#]*#||g"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging font colors for original 'grey3' strings: "
if grep -q 'grey3' 720p/* ; then
	XMLS=$(2>/dev/null grep 'disabledcolor>grey3<' -l 720p/*)
	R="s|disabledcolor>grey3<|disabledcolor>textdisabled<|g"
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep 'textcolor>grey3<' -l 720p/*)
	R="s|textcolor>grey3<|textcolor>textdisabled<|g"
	perlregex $XMLS "$R"
	XMLS=$(2>/dev/null grep 'COLOR=grey3' -l -r language/*)
	R="s|COLOR=grey3|COLOR=textnofocus|g"
	for X in $XMLS ; do
		sed "$R" -i "$X"
	done
	
	if grep -q 'grey3' 720p/* ; then
		printf "\nERROR: Grey3 color still used!"
		printf "\n"
		grep 'grey3' 720p/*
		exit 4
	fi
	perlregex colors/defaults.xml "s|\s*<color name=\"grey3\"[^#]*#||g"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging font colors for original 'black' strings: "
if grep -q 'black' 720p/* ; then
	XMLS=$(2>/dev/null grep '<focusedcolor>black</focusedcolor>' -l 720p/*)
	R="s|<focusedcolor>black</focusedcolor>|<focusedcolor>textfocus</focusedcolor>|g"
	perlregex $XMLS "$R"

	if grep -q 'black' 720p/* ; then
		printf "\nERROR: Black color still used!"
		printf "\n"
		grep 'black' 720p/*
		exit 4
	fi
	perlregex colors/defaults.xml "s|\s*<color name=\"black\"[^#]*#||g"
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging font colors for special strings: "
if false ; then
	R="s|(control type=\"label\"[^#]*#"
	R+="(\s*<(?!textcolor)(?!font)[a-z][^#]*#)*"
	R+="\s*<font>font35_title</font>#"
	R+="(\s*<(?!textcolor)(?!font)[a-z][^#]*#)*"
	R+="\s*<textcolor)>[a-z]*<"
	R+="|\1>heading1<|g"
	perlregex "$R" 720p/FileManager.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging font colors for original blue strings: "
if grep 'blue' 720p/* | grep -q -v ',blue/' ; then
	XMLS=$(2>/dev/null grep -a -l '<textcolor>blue</textcolor>' 720p/*)
	R="s|(\s*<description>header label</description>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>blue<"
	R+="|\1>heading1<|g"
	perlregex $XMLS "$R" --nocheck
	
	R="s|(\s*<align>(right\|center)</align>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>blue<"
	R+="|\1>heading2<|g"
	perlregex $XMLS "$R" --nocheck
	R="s|(<textcolor)>blue<([^#]*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<align>(right\|center)</align>\s*#)"
	R+="|\1>heading2<\2|g"
	perlregex $XMLS "$R" --nocheck

	R="s|(\s*<font>(font1[023]_title\|font12caps)</font>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>blue<"
	R+="|\1>heading2<|g"
	perlregex $XMLS "$R" --nocheck
	R="s|(<textcolor)>blue<([^#]*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<font>(font1[023]_title\|font12caps)</font>\s*#)"
	R+="|\1>heading2<\2|g"
	perlregex $XMLS "$R" --nocheck

	R="s|(\s*<description>(Description txt\|Song Name Label\|channel options Header\|Name Label\|rules label)</description>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>blue<"
	R+="|\1>heading2<|g"
	perlregex $XMLS "$R" --nocheck
	
	R="s|(\s*<description>(RSS feed)</description>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>blue<"
	R+="|\1>textfocus<|g"
	perlregex $XMLS "$R" --nocheck
	
	R="s|(\s*<font>font16</font>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>blue<"
	R+="|\1>heading1<|g"
	perlregex $XMLS "$R" --nocheck
	
	perlregex $XMLS "s|<textcolor>blue</textcolor>|<textcolor>textnofocus</textcolor>|g"	
	
	XMLS=$(2>/dev/null grep -a -l "COLOR=blue" 720p/*)
	perlregex $XMLS "s|\[COLOR=blue\]([ ]*.[ ]*)\[/COLOR\]|\1|g"
	perlregex $XMLS "s|\[COLOR=blue\]|\[COLOR=heading2\]|g"
	
	XMLS=$(2>/dev/null grep -a -l ">blue<" 720p/*)
	perlregex $XMLS "s|<selectedcolor>blue<|<selectedcolor>itemselected<|g"
	perlregex $XMLS "s|<titlecolor>blue<|<titlecolor>itemselected<|g"
	
	if grep 'blue' 720p/* | grep -v -q ',blue/' ; then
		printf "\nERROR: Blue color still used!"
		printf "\n"
		grep 'blue' 720p/* | grep -v ',blue/' | head -n 10
		exit 4
	fi
	perlregex colors/defaults.xml "s|\s*<color name=\"blue\"[^#]*#||g"	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging font colors for 'selected' colored strings: "
if grep "selected" 720p/* | egrep -q -v '<selected|itemselected' ; then
	XMLS=$(2>/dev/null grep -a -l '<selectedcolor>selected</selectedcolor>' 720p/*)
	perlregex $XMLS "s|<selectedcolor>selected</selectedcolor>|<selectedcolor>itemselected</selectedcolor>|g" --nocheck
	
	XMLS=$(2>/dev/null grep -a -l '<textcolor>selected</textcolor>' 720p/*)
	R="s|(\s*<description>(header label\|dialog Heading\|Header Label)</description>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*?"
	R+="\s*<textcolor)>selected<"
	R+="|\1>heading1<|g"
	perlregex $XMLS "$R" --nocheck
	
	R="s|(\s*<description>(Used Scaper Label\|Edit Text)</description>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>selected<"
	R+="|\1>itemselected<|g"
	perlregex $XMLS "$R" --nocheck
	
	R="s|(\s*<description>(current directory text label\|Song Number Label)</description>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>selected<"
	R+="|\1>heading2<|g"
	perlregex $XMLS "$R" --nocheck

	R="s|(\s*<description>(Episode Number\|Episode Name)</description>\s*#"
	R+="(\s*<(?!control)[a-z][^#]*#)*"
	R+="\s*<textcolor)>selected<"
	R+="|\1>textfocus<|g"
	perlregex $XMLS "$R" --nocheck

	perlregex $XMLS "s|<textcolor>selected</textcolor>|<textcolor>textnofocus</textcolor>|g"
	
	XMLS=$(2>/dev/null grep -a -l '\[COLOR=selected\]' 720p/*)
	perlregex $XMLS "s|\[COLOR=selected\]|\[COLOR=heading3\]|g"

	if grep "selected" 720p/* | egrep -q -v '<selected|itemselected' ; then
		printf "\nERROR: Selected color still used!"
		printf "\n"
		grep "selected" 720p/* | egrep -v '<selected|itemselected' | head -n 10
		exit 4
	fi
	perlregex colors/defaults.xml "s|\s*<color name=\"selected\"[^#]*#||g"	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging home widgets labels: "
if grep -q 'font10' 720p/IncludesHomeWidget.xml ; then
	grep -zo -P -I '<control type="label".*\n(\s*<[a-z].*\n)*\s*<font>font10</font>\n(\s*<[a-z].*\n)*\s*</control>' 720p/IncludesHomeWidget.xml \
		| grep '<posy>' | sed 's|^\s*<posy>||g' | sed 's|</posy>||g' >ypos.tmp
	IFS=$'\n' ; for YPOS in $( more ypos.tmp | sort -u )
	do
		NEWY=$((YPOS-5))
		R="s|posy>$YPOS<([^#]*#"
		R+="(\s*<[a-z][^#]*#)*"
		R+="\s*<font>font10<)"
		R+="|posy>$NEWY<\1|g"
		perlregex "$R" 720p/IncludesHomeWidget.xml
	done
	perlregex 's|<font>font10<|<font>font13<|g' 720p/IncludesHomeWidget.xml
	# label width
	R="s|(control type=\"label\"[^#]*#"
	R+="(\s*<[a-z][^#]*#)*"
	R+="\s*<width)>200<"
	R+="|\1>230<|g"
	perlregex "$R" 720p/IncludesHomeWidget.xml	
	# weather widget y pos
	R="s|>163<(/posy>#"
	R+="(\s*<[a-z][^#]*#)*"
	R+="\s*<label>.INFO.ListItem.Property.Temperatures..)"
	R+="|>158<\1|g"
	perlregex "$R" 720p/IncludesHomeWidget.xml
	R="s|>180<(/posy>#"
	R+="(\s*<[a-z][^#]*#)*"
	R+="\s*<label>.INFO.ListItem.Label2.</label>)"
	R+="|>185<\1|g"
	perlregex "$R" 720p/IncludesHomeWidget.xml	
	# font size 13 everywhere
	R="s|(control type=\"label\"[^#]*#)(\s*)"
	R+="((\s*<(?!font)[a-z][^#]*#)*"
	R+="\s*</control)"
	R+="|\1\2<font>font13</font>#\2\3|g"
	perlregex "$R" 720p/IncludesHomeWidget.xml --nocheck
	# remove uppercase
	perlregex "s|\[[/]*UPPERCASE\]||g" 720p/IncludesHomeWidget.xml
	# remove bold
	perlregex "s|\[[/]*B\]||g" 720p/IncludesHomeWidget.xml	
	# weather day textcolor
	perlregex "s|<textcolor>heading2</textcolor>|<textcolor>textnofocus</textcolor>|g" 720p/IncludesHomeWidget.xml
	#remove extra colors for selected elements
	remove_control 'label' '<visible>Control.HasFocus.(800[0-9]\|801[0-5]).</visible>' 720p/IncludesHomeWidget.xml
	rm ypos.tmp
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging label fonts: "
if grep -q 'font12' 720p/AddonBrowser.xml ; then
	R="s|(control type=\"label\"[^#]*#"
	R+="(\s*<(?!font)[a-z][^#]*#)*"
	R+="\s*<font)>font12<"
	R+="|\1>font13<|g"
	XMLS=$(2>/dev/null grep -a -l 'font12' 720p/*)
	perlregex $XMLS "$R"
	R="s|(control type=\"label\"[^#]*#"
	R+="(\s*<(?!font)[a-z][^#]*#)*"
	R+="\s*<font)>font10<"
	R+="|\1>font13<|g"
	perlregex 720p/includes.xml "$R"
	R="s|(control type=\"label\"[^#]*#"
	R+="(\s*<(?!font)[a-z][^#]*#)*"
	R+="\s*<font)>font11<"
	R+="|\1>font13<|g"
	XMLS=$(2>/dev/null grep -a -l 'font11' 720p/*)
	perlregex $XMLS "$R"
	R="s|(control type=\"label\"[^#]*#"
	R+="(\s*<(?!font)[a-z][^#]*#)*"
	R+="\s*<font)>font12_title<"
	R+="|\1>font13<|g"
	XMLS=$(2>/dev/null grep -a -l 'font12_title' 720p/*)
	perlregex $XMLS "$R"
	
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\nChanging button fonts: "
if grep -q 'font12' 720p/IncludesHomeMenuItems.xml ; then
	R="s|(control type=\"button\"[^#]*#"
	R+="(\s*<(?!font)[a-z][^#]*#)*"
	R+="\s*<font)>font12<"
	R+="|\1>font13<|g"
	XMLS=$(2>/dev/null grep -a -l 'font12' 720p/*)
	perlregex $XMLS "$R"
	perlregex "s|<width>180</width>|<width>200</width>|g" 720p/IncludesHomeMenuItems.xml
	perlregex "s|<textwidth>195</textwidth>|<textwidth>220</textwidth>|g" 720p/IncludesHomeMenuItems.xml
	printf "%sDONE!%s" $GREEN $RESET
else
	printf "%sSKIPPED.%s" $CYAN $RESET
fi
step

printf "\n############# APPLYING HOME SCREEN MODIFICATIONS ##############################"

printf "\nChanging main menu layout: "
if ! grep -q "$HOME_MAIN_FO" 720p/Home.xml ; then
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

printf "\nChanging widgets on the home screen: "
if  grep -q '<description>Title label</description>' '720p/IncludesHomeWidget.xml' ; then
	#widget group title label
	remove_control 'label' '<description>Title label</description>' '720p/IncludesHomeWidget.xml'
	remove_control 'label' '<description>Random Title label</description>' '720p/IncludesHomeWidget.xml'
	remove_control 'label' '<description>Recent Title label</description>' '720p/IncludesHomeWidget.xml'
	#label for widgets without focus
	#remove_control 'label' '<textcolor>white</textcolor>' '720p/IncludesHomeWidget.xml'
	#remove_control 'label' '<textcolor>grey2</textcolor>' '720p/IncludesHomeWidget.xml'
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

printf "\n############# CLEANING UP #####################################################"

#printf "\nRemoving image controls without texture: "
#XMLS=$(2>/dev/null grep '<texture[^>]*></texture>' -l 720p/*)
#remove_control 'image' '<texture[^>]*></texture>' "$XMLS"
#printf "%sDONE!%s" $GREEN $RESET
#step

printf "\nRemoving directories: "
2>/dev/null rm -rf media/studios
printf "%sDONE!%s" $GREEN $RESET

EMPTYINCS=$(grep -a -z -Po '<include name="[^"]*">\n\s*</include>' 720p/* | grep -v '</include>' | sed 's|^[^<]*<include name="||' | sed 's|">||')
for INC in $EMPTYINCS ; do
	if [ -z "$INC" ] ; then continue ; fi
	printf "\nRemoving empty include '$INC': "
	if grep -I -q "$INC" 720p/* ; then
		XMLS=$(2>/dev/null grep -a -l "$INC" 720p/*)
		perlregex $XMLS "s|\s*<include>$INC</include>\s*#||g"
		remove_include "$INC"
		printf "%sDONE!%s" $GREEN $RESET
	else
		printf "%sSKIPPED.%s" $CYAN $RESET
	fi
done
step

printf "\nRemoving unused include definitions: "
INCDEFS=$(grep "<include name=\"[^\"]*" 720p/* | grep -o "\"[^\"]*\"" | sort -u | tr -d '"')
for DEF in $INCDEFS ; do
	if ! grep -q ">$DEF</include>" 720p/* ; then
		printf "\nRemoving unused include '$DEF'."
		remove_include "$DEF"
	fi
done
printf "%sDONE!%s" $GREEN $RESET
step

printf "\nRemoving unused variables: "
VARDEFS=$(grep "<variable name=\"[^\"]*" 720p/* | grep -o "\"[^\"]*\"" | sort -u | tr -d '"')
for DEF in $VARDEFS ; do
	if ! grep -q "[^\"]$DEF[^\"]" 720p/* ; then
		printf "\nRemoving unused variable '$DEF'."
		remove_variable "$DEF"
	fi
done
printf "%sDONE!%s" $GREEN $RESET
step

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

printf "\nRemoving invalid tags: "
INVALID='button;altlabel
edit;textwidth
fadelabel;align
fadelabel;aligny
fadelabel;scroll
image;align
image;aligny
image;visibility
label;pauseatend
label;scrollout
textbox;scroll
textbox;wrapmultiline
textbox;aligny
textbox;selectedcolor
spincontrolex;textwidth
radiobutton;textwidth
multiimage;aligny'
if grep -I -q '<wrapmultiline>true</wrapmultiline>' 720p/MusicOSD.xml ; then
	IFS=$'\n' ; for T in $INVALID ; do
		CONTROL=$(echo "$T" | cut -f1 -d';' | tr -d '\n')
		TAG=$(echo "$T" | cut -f2 -d';' | tr -d '\n')
		printf "'$CONTROL','$TAG' "
		R="s|(<control type=\"$CONTROL\"[^#]*#"
		R+="(\s*<(?!$TAG)[a-z][^#]*#)*)"
		R+="\s*<$TAG[^#]*#"
		R+="|\1|g"
		XMLS=$(2>/dev/null grep -a "$TAG" -l 720p/*)
		perlregex $XMLS "$R" --nocheck
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

printf "\nAdding defaults to defaults.xml: "
if ! grep -q '<loop>true</loop>' 720p/defaults.xml ; then
	DEFS='
togglebutton;align;<align>left</align>
togglebutton;aligny;<aligny>center</aligny>
togglebutton;textoffsetx;<textoffsetx>10</textoffsetx>
togglebutton;textwidth;<textwidth>290</textwidth>
togglebutton;focusedcolor;<focusedcolor>textfocus</focusedcolor>
button;label;<label></label>
button;align;<align>left</align>
button;angle;<angle>0</angle>
button;textoffsety;<textoffsety>0</textoffsety>
button;textwidth;<textwidth>730</textwidth>
button;colordiffuse;<colordiffuse>ffffffff</colordiffuse>
button;focusedcolor;<focusedcolor>textfocus</focusedcolor>
radiobutton;focusedcolor;<focusedcolor>textfocus</focusedcolor>
radiobutton;align;<align>left</align>
edit;align;<align>left</align>
edit;label;<label></label>
edit;focusedcolor;<focusedcolor>textfocus</focusedcolor>
multiimage;loop;<loop>true</loop>
multiimage;pauseatend;<pauseatend>0</pauseatend>
selectbutton;focusedcolor;<focusedcolor>textfocus</focusedcolor>
sliderex;posx;<posx>0</posx>
sliderex;posy;<posy>0</posy>
sliderex;focusedcolor;<focusedcolor>textfocus</focusedcolor>
slider;focusedcolor;<focusedcolor>textfocus</focusedcolor>
slider;aligny;<aligny>center</aligny>
slider;texturefocus;<texturefocus></texturefocus>
slider;texturenofocus;<texturenofocus></texturenofocus>
spincontrol;focusedcolor;<focusedcolor>textfocus</focusedcolor>
spincontrolex;label;<label></label>
spincontrolex;focusedcolor;<focusedcolor>textfocus</focusedcolor>
fadelabel;pauseatend;<pauseatend>1000</pauseatend>
fadelabel;textoffsetx;<textoffsetx>10</textoffsetx>
fadelabel;scrollspeed;<scrollspeed>60</scrollspeed>
fadelabel;scrollout;<scrollout>false</scrollout>
fadelabel;label;<label></label>
image;bordertexture;<bordertexture></bordertexture>
image;colordiffuse;<colordiffuse>ffffffff</colordiffuse>
image;width;<width>1280</width>
label;aligny;<aligny>center</aligny>
label;align;<align>left</align>
label;angle;<angle>0</angle>
label;height;<height>0</height>
label;scroll;<scroll>false</scroll>
label;selectedcolor;<selectedcolor>itemselected</selectedcolor>
label;width;<width>1280</width>
label;wrapmultiline;<wrapmultiline>false</wrapmultiline>
'
	for D in $DEFS ; do
		CONTROL=$(echo "$D" | cut -f1 -d';')
		TAG=$(echo "$D" | cut -f2 -d';')
		STD=$(echo "$D" | cut -f3 -d';')
		DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<$TAG[ >]" | sed 's|^\s*||')
		if [ -z "$DEFTAG" ] ; then
			NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
			if [ $NUMMISSING -gt 0 ] ; then
				R="s|(\s*)(<default type=\"$CONTROL\"[^#]*#)"		#1#2
				R+="|\1\2\1\1$STD#|g"
				perlregex "$R" 720p/defaults.xml
			fi
		fi
	done
fi

printf "\nOptimizing tags with existing default values: "
for CONTROL in $CONTROLS ; do
	printf "\nOptimizing '$CONTROL' control: "
	CHANGED=false
	for TAG in $(echo "$OPTTAGS" | grep "^$CONTROL;") ; do
		TAG=$(echo "$TAG" | cut -f2 -d';')
		DEFTAG=$(grep -a -z -Po "<default type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</default>" 720p/defaults.xml | grep "<$TAG[ >]" | sed 's|^\s*||')
		if ! [ -z "$DEFTAG" ] ; then
			MOST=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | grep "<$TAG[ >]" | sed 's|^\s*||' | sort --batch-size=1021 | uniq -c | sort -n -r | head -1 | sed 's|^\s*||')
			NUMMOST=$(echo "$MOST" | cut -f1 -d' ')
			MOST=$(echo "$MOST" | sed 's|^[0-9]*\s*||')
			if [ "$MOST" != "$DEFTAG" ] ; then
				NUMMISSING=$(grep -a -z -Po "<control type=\"$CONTROL\".*\n(\s*<[a-z].*\n)*\s*</control>" 720p/* | tr -d $'\n' | sed 's|</control>|\n|g' | grep -v "<$TAG[ >]" | wc -l)
				if [ $NUMMOST -gt $NUMMISSING ] ; then
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
