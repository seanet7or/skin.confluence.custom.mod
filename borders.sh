source textures.sh

OLDIFS=$IFS ; IFS=$'\n'
for T in $TEXLIST ; do
	if [ -z "$T" ] ; then
		continue
	fi
	TEXTURE=$(echo "$T" | cut -f1 -d';')
	BORDER=$(echo "$T" |cut -f2 -d';')
	ARGS+="|$TEXTURE"
	continue
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
REMOVED+='>MediaBladeSub.png|>MediaStatus/OverlayUnwatched.png|'
REMOVED+='>OverlayDialogBackground.png|'
REMOVED+='>ThumbShadow.png|'
REMOVED+='>ScrollBarV.png|>ScrollBarV_bar.png|>ScrollBarV_bar_focus.png|>ShutdownButtonNoFocus.png|>ShutdownButtonFocus.png'
#echo "ARGS: '$ARGS'"	
echo ""
echo ""
echo "Others: "
grep 2>/dev/null border 720p/*.xml | egrep -v '<bordersize>|<usealttexture>' | egrep -v $ARGS | head -n 10
grep 2>/dev/null texture 720p/*.xml | egrep -v '<bordersize>|<usealttexture>|_light.png' | grep -v '>-<' | grep -v '<bordersize>' | egrep -v $ARGS | head -n 10
