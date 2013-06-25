
TEXLIST='button-focus2.png;2
icon-mute.png;0
OverlayWatched.png;0
DefaultIconError.png;0
Fanart_Fallback_Music_Small.jpg;0
black-back.png;0
StackNF.png;3
StackFO.png;3
DefaultFile.png;0
DefaultIconWarning;0
DefaultIconInfo;0
button-focus_light.png;2
folder-focus_light.png;2
button-focus.png;2
black-back2.png;0
KeyboardKey.png;4
KeyboardEditArea_light.png;0
MediaBladeSub_light.png;7,0,7,0
HomeBladeSub_light.png;7,0,7,0
MenuItemFO_light.png;2
HomeSubNF_light.png;0,2,0,0
HomeSubFO.png;2
HomeSubEnd.png;0,2,0,2
floor_button.png;5
floor_buttonFO.png;5
StackFO.png;5
\$INFO\[ListItem.Property\(Icon\)\];0
\$INFO\[ListItem.Property\(Addon.StarRating\),LeftRating/\];0
\$INFO\[ListItem.Art\(fanart\)\];0
\$INFO\[ListItem\.Icon\];0
OSDProgressMidLight_light.png;0
OSDProgressMid_light.png;0
OSDProgressBack_light.png;0
\$INFO\[Container\(50\).Listitem.Icon\];0
epg-genres/\$INFO\[ListItem.Property\(GenreType\)\].png;3
\$INFO\[Listitem.Icon\];0
NoCover_1.png;4
flagging/blank.png;4
HomeBack.png;0,6,0,6
scroll-down-2.png;12
scroll-up-2.png;12
scroll-down-focus-2.png;12
scroll-up-focus-2.png;12
scroll-right-focus.png;0
scroll-left-focus.png;0
scroll-right.png;0
scroll-left.png;0
osd_slider_nib.png;0
osd_slider_nibNF.png;0
osd_slider_bg.png;0
radiobutton-nofocus.png;0
scroll-down-focus.png;0
scroll-down.png;0
scroll-up-focus.png;0
scroll-up.png;0
KeyboardKeyNF.png;1'
OLDIFS=$IFS ; IFS=$'\n'
for T in $TEXLIST ; do
	TEXTURE=$(echo "$T" | cut -f1 -d';')
	BORDER=$(echo "$T" |cut -f2 -d';')
	ARGS+='|'$TEXTURE
	if [ "$BORDER" == "0" ] ; then
		if grep ">$TEXTURE" 720p/*.xml 2>/dev/null | grep -q 'border="' ; then
			echo "ERROR: $TEXTURE"
			grep ">$TEXTURE" 720p/*.xml 2>/dev/null | grep 'border="'	| head -n 1	
		fi
		else
		if grep ">$TEXTURE" 720p/*.xml 2>/dev/null | grep -v -q 'border="'$BORDER'"' ; then
			echo "ERROR: $TEXTURE"
			grep ">$TEXTURE" 720p/*.xml 2>/dev/null | grep -v 'border="'$BORDER'"'	| head -n 1	
		fi
	fi
done

ARGS=$(echo "$ARGS" | sed 's/^|//')
REMOVED='>DialogBack.png|>DialogContextBottom.png|>DialogContextMiddle.png|>DialogContextTop.png|'
REMOVED+='>InfoMessagePanel.png|'
REMOVED+='>KeyboardEditArea.png|>KeyboardCornerTop.png|>KeyboardCornerTopNF.png|>KeyboardCornerBottom.png|>KeyboardCornerBottomNF.png'
REMOVED+='>MediaBladeSub.png|'
REMOVED+='>OverlayDialogBackground.png|'
REMOVED+='>ThumbShadow.png|'
REMOVED+='>ScrollBarV.png|>ScrollBarV_bar.png|>ScrollBarV_bar_focus.png|>ShutdownButtonNoFocus.png|>ShutdownButtonFocus.png'
#echo "ARGS: '$ARGS'"	
echo ""
echo ""
echo "Others: "
grep 2>/dev/null border 720p/*.xml | egrep -v '<bordersize>|<usealttexture>' | egrep -v "$REMOVED" | egrep -v $ARGS | head -n 10
grep 2>/dev/null texture 720p/*.xml | egrep -v '<bordersize>|<usealttexture>|_light.png' | grep -v '>-<' | grep -v '<bordersize>' | egrep -v "$REMOVED" | egrep -v $ARGS | head -n 10
