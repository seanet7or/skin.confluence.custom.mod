#!/bin/bash

# $1 file
# $2 regex
perlregex() {
	local FILE=$1
	local REGEX=$2
	cp "$FILE" "$FILE.tmp"
	cat "$FILE.tmp" | tr '\n' '\0' | ssed -R "$REGEX" | tr '\0' '\n' >"$FILE"
	rm "$FILE.tmp"
}

findunused() {
	FILES=$(find media -type f)
	IFS_OLD=$IFS
	IFS=$'\n'
	for F in $FILES ; do
		FS=$(basename $F)
		if ! grep -q "$FS" 720p/* ; then
			echo "'$FS' was not found in the .xmls."
			echo "File is '$F'."
			BASE=$(echo "$F" | sed "s|\.[a-zA-Z]+||")
			echo "Occurences of '$BASE':"
			grep "$BASE" 720p/*
		else
			echo "'$FS' was found in the .xmls."
			echo "File is '$F'."	
		fi
	done
	IFS=$IFS_OLD
}

# enable germany mpaa setting 
perlregex '720p/SkinSettings.xml' 's|<!--(item[^>]*id="3".*31702.*?)/item-->|<\1/item>|'

# choose right flag for german mpaa ratings
if ! grep -q 'fsk-18' '720p/IncludesVariables.xml' ; then
	perlregex '720p/IncludesVariables.xml' \
	's|(\000\s*)(<variable name="rating">).*?\000|\1\2'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,18)">de/fsk-18</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,16)">de/fsk-16</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,12)">de/fsk-12</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,6)">de/fsk-6</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,0)">de/fsk-0</value>'\
	'\1\t<value condition="stringcompare(Skin.String(MPAACountryCert),$LOCALIZE[31702]) + substring(listitem.mpaa,o)">de/fsk-0</value>'\
	'\n\n|' 
fi

# remove Home menu seperator
if grep -q 'HomeSeperator' '720p/Home.xml' ; then
	perlregex '720p/Home.xml' 's|\000\s*?<control type="image">\s*?\000\s*?<posx>[0-9]+</posx>\s*?\000\s*?<posy>[0-9]+</posy>\s*?\000\s*?<width>[0-9]+</width>\s*?\000\s*?<height>[0-9]+</height>\s*?\000\s*?<texture>HomeSeperator.png</texture>\s*?\000\s*?</control>\s*?||g'
	rm 'media/HomeSeperator.png'
fi

# remove Home overlay
if grep -q 'HomeOverlay1.png' '720p/Home.xml' ; then
	perlregex '720p/Home.xml' 's|\000\s*?<control type="image">\s*?\000\s*?<posx>[0-9]+</posx>\s*?\000\s*?<posy>[0-9]+</posy>\s*?\000\s*?<width>[0-9]+</width>\s*?\000\s*?<height>[0-9]+</height>\s*?\000\s*?<texture>HomeOverlay1.png</texture>\s*?\000\s*?</control>\s*?||g'
	rm 'media/HomeOverlay1.png'
fi

# remove widgets background
if grep -q 'RecentAddedBack' '720p/IncludesHomeWidget.xml' ; then
	perlregex '720p/IncludesHomeWidget.xml' 's|\000\s*?<control type="image">\s*?\000'\
'\s*?<description>background</description>\s*?\000'\
'\s*?<posx>[0-9]+</posx>\s*?\000'\
'\s*?<posy>[0-9]+</posy>\s*?\000'\
'\s*?<width>[0-9]+</width>\s*?\000'\
'\s*?<height>[0-9]+</height>\s*?\000'\
'\s*?<texture[^>]*>RecentAddedBack.png</texture>\s*?\000'\
'\s*?</control>\s*?||g'
	rm media/RecentAddedBack.png
fi

# remove menu items seperator
for F in 720p/ViewsVideoLibrary.xml 720p/ViewsPVR.xml 720p/ViewsMusicLibrary.xml 720p/ViewsLiveTV.xml 720p/ViewsFileMode.xml 720p/ViewsAddonBrowser.xml 720p/SkinSettings.xml 720p/Settings.xml 720p/script-XBMC_Lyrics-main.xml 720p/script-globalsearch-main.xml 720p/MyWeather.xml 720p/FileManager.xml 720p/FileBrowser.xml ; do
	perlregex "$F" 's|\s*?<control type="image">\s*?\000'\
'\s*?<posx>[0-9]+</posx>\s*?\000'\
'\s*?<posy>[0-9]+</posy>\s*?\000'\
'\s*?<width>[0-9]+</width>\s*?\000'\
'\s*?<height>[0-9]+</height>\s*?\000'\
'(\s*\|\s*?<visible>[^<]*?</visible>\s*?\000\|\s*?<include>[^<]*?</include>\s*?\000)'\
'\s*?<texture[^>]*>MenuItemNF.png</texture>\s*?\000'\
'(\s*\|\s*?<visible>[^<]*?</visible>\s*?\000\|\s*?<include>[^<]*?</include>\s*?\000)'\
'(\s*\|\s*?<include>[^<]*?</include>\s*?\000\|\s*?<visible>[^<]*?</visible>\s*?\000)'\
'\s*?</control>\s*?\000||g'	
	perlregex "$F" 's|(\s*?<texturenofocus[^>]*>)MenuItemNF.png(</texturenofocus>\s*?\000)|\1-\2|g'
done
for F in 720p/SettingsCategory.xml 720p/SettingsSystemInfo.xml 720p/SettingsProfile.xml ; do
	perlregex "$F" 's|(\s*?<texturenofocus[^>]*>)MenuItemNF.png(</texturenofocus>\s*?\000)|\1-\2|g'
done
if [ -f media/MenuItemNF.png ] ; then rm media/MenuItemNF.png ; fi

# remove widgets titel label
perlregex 720p/IncludesHomeWidget.xml 's|\s*?<control type="label">\s*?\000'\
'\s*?<description>Title label</description>\s*?\000'\
'(\s*<(posx\|posy\|height\|width\|label\|align\|aligny\|font\|textcolor\|shadowcolor)>[^>]*>\s*?\000)*'\
'\s*</control>\s*?\000||g'

# remove label for widgets that are not focused
perlregex 720p/IncludesHomeWidget.xml 's|\s*?<control type="label">\s*?\000'\
'\s*?<posx>[0-9]*?</posx>\s*?\000'\
'\s*?<posy>[0-9]*?</posy>\s*?\000'\
'(\s*<(height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|selectedcolor)>[^>]*>\s*?\000)*'\
'\s*?<label>.VAR.MainItemLabel.</label>\s*?\000*'\
'\s*</control>\s*?\000||g'

# remove info for widgets that are not focused
perlregex 720p/IncludesHomeWidget.xml 's|\s*?<control type="label">\s*?\000'\
'\s*?<posx>[0-9]*?</posx>\s*?\000'\
'\s*?<posy>[0-9]*?</posy>\s*?\000'\
'(\s*<(height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|selectedcolor)>[^>]*>\s*?\000)*'\
'\s*?<label>.INFO.ListItem.Label2.</label>\s*?\000*'\
'\s*</control>\s*?\000||g'

# remove bordertexture for widgets that are not focused
perlregex 720p/IncludesHomeWidget.xml 's|\s*<bordertexture border="5">button-nofocus.png</bordertexture>\s*\000||g'

# use thumb in picture preview view
perlregex 720p/ViewsPictures.xml 's|<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>|<texture background="true">\$INFO\[ListItem.Icon\]</texture>|g'

exit
