TEXLIST='button-focus2.png;2
button-focus_light.png;2
folder-focus.png;2
button-focus.png;2
black-back2.png;0
KeyboardKey.png;4
KeyboardEditArea_light.png;0
KeyboardKeyNF.png;1'

OLDIFS=$IFS ; IFS=$'\n'
for T in $TEXLIST ; do
	TEXTURE=$(echo "$T" | cut -f1 -d';')
	BORDER=$(echo "$T" |cut -f2 -d';')
	ARGS+='|'$TEXTURE
	if [ "$BORDER" == "0" ] ; then
		if grep ">$TEXTURE" 720p/* 2>/dev/null | grep -q 'border="' ; then
			echo "ERROR: $TEXTURE"
			grep ">$TEXTURE" 720p/* 2>/dev/null | grep 'border="'	| head -n 1	
		fi
		else
		if grep ">$TEXTURE" 720p/* 2>/dev/null | grep -v -q 'border="'$BORDER'"' ; then
			echo "ERROR: $TEXTURE"
			grep ">$TEXTURE" 720p/* 2>/dev/null | grep -v 'border="'$BORDER'"'	| head -n 1	
		fi
	fi
done

ARGS=$(echo "$ARGS" | sed 's/^|//')
REMOVED='>DialogContextTop.png|>DialogContextMiddle.png|>KeyboardEditArea.png|>KeyboardCornerTop.png|>ScrollBarV_bar_focus.png|>ShutdownButtonNoFocus.png|>ShutdownButtonFocus.png|>KeyboardCornerTopNF.png|>KeyboardCornerBottom.png|>KeyboardCornerBottomNF.png'
#echo "ARGS: '$ARGS'"	
echo ""
echo ""
echo "Others: "
grep 2>/dev/null border 720p/* | grep -v '<bordersize>' | egrep -v "$REMOVED" | egrep -v $ARGS | head -n 10
