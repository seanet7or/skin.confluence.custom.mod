TEXLIST='button-focus2.png;2
folder-focus.png;2
HomeBladeSub.png;15,0,0,0
button-focus.png;2
button-focus_light;2
KeyboardKey.png;4
black-back2.png;0
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
#echo "ARGS: '$ARGS'"	
echo ""
echo ""
echo "Others: "
grep 2>/dev/null border 720p/* | grep -v '<bordersize>' | egrep -v 'KeyboardCorner|KeyboardCornerTop' | egrep -v $ARGS | head -n 10
