VERSION="$1"
BUILDDIR="snapshots"
ADDONNAME="skin.ccm-lite"

if [ -z "$VERSION" ] ; then
	echo "ERROR: Please give the version number as parameter."
	exit 2
fi

2>/dev/null rm -rf "$BUILDDIR/$VERSION"

TARGETDIR="$BUILDDIR/$VERSION/$ADDONNAME"

2>/dev/null rm -rf "$TARGETDIR"
mkdir -p "$TARGETDIR"

sed "s|version=\"[0-9\.]*\"$|version=\"$VERSION\"|g" -i addon.xml

FILES="fanart.jpg
icon.png"

IFS=$'\n'
for F in $FILES ; do
	cp "$F" "$TARGETDIR/$F"
done

touch "$TARGETDIR/changelog.txt"
cp -r 720p "$TARGETDIR"
cp addon.xml "$TARGETDIR"
cp -r sounds "$TARGETDIR"
cp LICENSE.GPL.txt "$TARGETDIR" 
cp -r backgrounds "$TARGETDIR"
cp -r colors "$TARGETDIR"
cp -r extras "$TARGETDIR"
cp -r fonts "$TARGETDIR"
cp -r language "$TARGETDIR"    
cp -r media "$TARGETDIR"

PROG=7z
PACK=p7zip-full
while ! 2>/dev/null >/dev/null which $PROG ; do
	printf "\nERROR: $PROG was not found."
	if 2>/dev/null >/dev/null which apt-get ; then
		printf "\nExecuting sudo apt-get install $PACK: "
		sudo apt-get install $PACK
	else
		exit 3
	fi
done

2>/dev/null rm "$BUILDDIR/$VERSION/$ADDONNAME-$VERSION.zip"
cpulimit -e 7za -l 30 -b
cd "$TARGETDIR"
cd ..
7za a -tzip -mx=9 "$ADDONNAME-$VERSION.zip" "*"
