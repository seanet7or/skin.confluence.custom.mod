TAGS='
label;aligny
fadelabel;label;done
fadelabel;info;done
fadelabel;font
fadelabel;textcolor
fadelabel;textoffsetx;done
fadelabel;shadowcolor;done
fadelabel;angle;done
fadelabel;scrollout;done;check
fadelabel;pauseatend;done;check
fadelabel;resetonlabelchange;done
fadelabel;scrollspeed;done
fadelabel;description;done
fadelabel;type;done
fadelabel;id;done
fadelabel;posx
fadelabel;posy
fadelabel;width;done;<width>400</width>
fadelabel;height;done;<height>25</height>
fadelabel;visible;done
fadelabel;animation;done
fadelabel;camera;done
fadelabel;colordiffuse;done
image;aspectratio;done
image;texture
image;bordertexture;done
image;bordersize;done
image;info;done
image;fadetime;done
image;description;done
image;type;done
image;id;done
image;posx
image;posy
image;width;done;<width>150</width>
image;height;done;<height>40</height>
image;visible;done
image;animation;done
image;camera;done
image;colordiffuse;done
label;align;done;<align>left</align>
label;aligny;done;<aligny>center</aligny>
label;scroll;done;<scroll>false</scroll>
label;label
label;info;done
label;number;done
label;angle;done
label;haspath;done
label;font
label;textcolor
label;shadowcolor;done
label;wrapmultiline;done
label;scrollspeed
label;scrollsuffix
label;description
label;type
label;id
label;posx
label;posy
label;width
label;height
label;visible
label;animation
label;camera
label;colordiffuse
button;texturefocus
button;texturenofocus
button;label
button;font
button;textcolor
button;focusedcolor
button;disabledcolor
button;shadowcolor
button;angle
button;align
button;aligny
button;textoffsetx
button;textoffsety
button;textwidth
button;onclick
button;onfocus
button;onunfocus
button;description
button;type
button;id
button;posx
button;posy
button;width
button;height
button;visible
button;animation
button;camera
button;colordiffuse
togglebutton;texturefocus
togglebutton;texturenofocus
togglebutton;alttexturefocus
togglebutton;alttexturenofocus
togglebutton;usealttexture
togglebutton;label
togglebutton;altlabel
togglebutton;font
togglebutton;textcolor
togglebutton;disabledcolor
togglebutton;shadowcolor
togglebutton;align
togglebutton;aligny
togglebutton;textoffsetx
togglebutton;textoffsety
togglebutton;onclick
togglebutton;onfocus
togglebutton;onunfocus
togglebutton;description
togglebutton;type
togglebutton;id
togglebutton;posx
togglebutton;posy
togglebutton;width
togglebutton;height
togglebutton;visible
togglebutton;animation
togglebutton;camera
togglebutton;colordiffuse
'

IFS=$'\n' ; for T in $TAGS ; do
	if $(echo "$T" | cut -f3 -d';' | grep -q 'done' ) ; then
		continue
	fi
	CONTROL=$(echo "$T" | cut -f1 -d';')
	TAG=$(echo "$T" | cut -f2 -d';')
	printf "\nControl is '$CONTROL', tag is '$TAG'."
	DEFSTART=$(grep -n '<default type="'"$CONTROL"'">' 720p/defaults.xml | cut -f1 -d:)
	if [ ! -z "$DEFSTART" ] ; then
		DEFSTOP=$(tail -n+"$DEFSTART" 720p/defaults.xml | grep -n '</default>' | head -n 1 | cut -f1 -d:)
		DEFTAG=$(tail -n+"$DEFSTART" 720p/defaults.xml | head -n "$DEFSTOP" | grep -v '<[/]*default' | \
			grep "<$TAG[ >]" | sed 's|^\s*||' )
		if [ -z "$DEFTAG" ] ; then
			printf "\nThere is no default tag."
		else
			printf "\nDefault value is '$DEFTAG'."
		fi
	fi
	
	if ! [ -z "$DEFTAG" ] ; then
		continue
	fi
	
	2>/dev/null rm tags.tmp
	EMPTY=0
	COUNT=0
	INCS=0
	for F in 720p/* ; do
		IFS=$'\n' ; for CONTROLSTART in $(grep -n '<control type="'"$CONTROL"'">' "$F" | cut -f1 -d:)
		do
			let COUNT=COUNT+1
			CONTROLSTOP=$(tail -n+"$CONTROLSTART" "$F" | grep -n '</control>' | head -n 1 | cut -f1 -d:)
			STRUCT=$(tail -n+"$CONTROLSTART" "$F" | head -n "$CONTROLSTOP" )
			STAG=$(echo "$STRUCT" | grep "<$TAG[ >]" | sed 's|^\s*||' )
			if false ; then #echo "$STRUCT" | grep -q "<include>" ; then
				let INCS=INCS+1
			else
				if [ -z "$STAG" ] ; then
					let EMPTY=EMPTY+1
				else
					echo "$STAG" >>tags.tmp
				fi
			fi
		done
	done
	printf "\n$COUNT '$CONTROL' controls."
	#printf "\n%d controls with <include> tags." $INCS
	printf "\n%d controls with missing tags.\n" $EMPTY
	#printf "\nMost frequent tags:\n"
	2>/dev/null more tags.tmp | sort --batch-size=1021 | uniq -c | sed 's|^\s*||' | sort -r -n | head -n 5
done