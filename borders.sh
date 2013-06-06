TEXLIST='button-focus2.png;2
folder-focus.png;2'
CMD='grep \'border="\' 720p/* '
OLDIFS=$IFS ; IFS=$'\n'
for T in $TEXLIST ; do
	TEXTURE=$(echo "$T" | cut -f1 -d';')
	BORDER=$(echo "$T" |cut -f2 -d';')
	