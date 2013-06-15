TEXLIST='button-focus2.png;2
button-focus_light.png;2
folder-focus.png;2
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
\$INFO\[ListItem\.Icon\];0
epg-genres/\$INFO\[ListItem.Property\(GenreType\)\].png;3
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
grep 2>/dev/null border 720p/*.xml | grep -v '<bordersize>' | egrep -v "$REMOVED" | egrep -v $ARGS | head -n 10
