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

# enable 'germany' as option in mpaa settings
perlregex '720p/SkinSettings.xml' 's|<!--(item>\s*\000'\
'\s*<label>.LOCALIZE.31702.</label>\s*\000'\
'\s*<onclick>noop</onclick>\s*\000'\
'\s*<icon>.</icon>\s*\000'\
'\s*<thumb>.</thumb>\s*\000'\
'\s*</item>\s*\000'\
'\s*)<item>'\
'|<\1<!--item>|'

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
if grep -q "MenuItemNF.png" 720p/* ; then
	echo "ERROR: Not all occurrences of 'MenuItemNF.png' could be removed, please check:"
	grep "MenuItemNF.png" 720p/*
	exit 3
fi
if [ -f media/MenuItemNF.png ] ; then rm media/MenuItemNF.png ; fi

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

exit

# use thumb in picture preview view
perlregex 720p/ViewsPictures.xml 's|<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>|<texture background="true">\$INFO\[ListItem.Icon\]</texture>|g'

# use thumb in picture wrap view
perlregex 720p/MyPics.xml 's|<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>|<texture background="true">\$INFO\[ListItem.Icon\]</texture>|g'

# remove panel mirrors
LIST=$(grep "ContentPanelMirror.png" 720p/* | cut -f1 | uniq | tr -d ':' | tr '\n' ' ')
for F in $LIST ; do
	perlregex "$F" 's|\s*?<control type="image">\s*?\000'\
'\s*?<posx>[0-9]*?</posx>\s*?\000'\
'\s*?<posy>[0-9]*?</posy>\s*?\000'\
'\s*?<width>[0-9]*?</width>\s*?\000'\
'\s*?<height>[0-9]*?</height>\s*?\000'\
'\s*?<texture border="[0-9]+">ContentPanelMirror.png</texture>\s*?\000*'\
'\s*</control>\s*?\000||g'
done
if grep -q "ContentPanelMirror.png" 720p/* ; then
	echo "ERROR: Not all occurrences of 'ContentPanelMirror.png' could be removed, please check:"
	grep "ContentPanelMirror.png" 720p/*
	exit 3
fi
rm media/ContentPanelMirror.png 2>/dev/null

#remove common page count
INC='CommonPageCount'
LIST=$(grep "<include>$INC</include>" 720p/* | cut -f1 | uniq | tr -d ':' | tr '\n' ' ')
for F in $LIST ; do
	perlregex "$F" 's|\s*<include>'$INC'</include>\s*\000||g'
done
#remove CommonPageCount definition
perlregex 720p/includes.xml 's|\s*<include name="CommonPageCount">\s*\000'\
'(\s*<(animation\|control\|/control\|description\|posx\|posy\|scroll\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|include)[^>]*>.*?\000)*?'\
'\s*</include>\s*\000||'

# change picturethumbview
	#selection panel
	perlregex 720p/ViewsPictures.xml 's|(\s*<control type)="panel" id="514">\s*\000'\
'(\s*<posx>60</posx>\s*\000)'\
'(\s*)<posy>75</posy>\s*\000'\
'(\s*)<width>432</width>\s*\000'\
'(\s*)<height>576</height>\s*\000'\
'|\1="fixedlist" id="514">\000\2\3\<posy>-72</posy>\000\4<width>144</width>\000\5<height>864</height>\000\5<focusposition>1</focusposition>\000|'
	#scrollbar
	perlregex 720p/ViewsPictures.xml 's|(\s*<control type="scrollbar" id="60">\s*\000)'\
'(\s*)<posx>500</posx>|\1\2<posx>212</posx>|'
	#left panel
	perlregex 720p/IncludesBackgroundBuilding.xml 's|(\s*<visible>Control.IsVisible.514.</visible>\s*\000'\
'\s*<control type="image">\s*\000'\
'\s*<posx>50</posx>\s*\000'\
'\s*)<posy>60</posy>(\s*\000'\
'\s*)<width>490</width>(\s*\000'\
'\s*)<height>600</height>'\
'|\1<posy>-15</posy>\2<width>202</width>\3<height>750</height>|'
	#picture preview
	perlregex 720p/ViewsPictures.xml 's|<posx>570</posx>|<posx>282</posx>|'
	perlregex 720p/ViewsPictures.xml 's|<width>640</width>|<width>928</width>|g'
	perlregex 720p/ViewsPictures.xml 's|<height>470</height>|<height>570</height>|g'
	perlregex 720p/IncludesBackgroundBuilding.xml 's|<width>680</width>\s*\000'\
'(\s*)<height>600</height>|<width>968</width>\000\1<height>640</height>|'
	perlregex 720p/IncludesBackgroundBuilding.xml 's|<posx>550</posx>|<posx>262</posx>|'
	#remove date+res labels
	perlregex 720p/ViewsPictures.xml 's|\s*<control type="label">\s*\000'\
'\s*<description>Date time txt</description>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|label\|align\|aligny\|font\|textcolor\|shadowcolor)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||'
	perlregex 720p/ViewsPictures.xml 's|\s*<control type="label">\s*\000'\
'\s*<description>Resolution txt</description>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|label\|align\|aligny\|font\|textcolor\|shadowcolor)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||'
	#remove sections icon
	perlregex 720p/MyPics.xml 's|\s*<control type="image">\s*\000'\
'\s*<description>Section header image</description>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|texture)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||'
	#remove location labels
	perlregex 720p/MyPics.xml 's|\s*<control type="label">\s*\000'\
'\s*<include>WindowTitleCommons</include>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|texture\|visible\|label)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||g'
	#remove location grouplist
perlregex 720p/MyPics.xml 's|\s*<control type="grouplist">\s*\000'\
'\s*<posx>65</posx>\s*\000'\
'\s*<posy>5</posy>\s*\000'\
'(\s*<(height\|width\|orientation\|align\|itemgap\|aspectratio\|texture\|visible\|label)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||'
	#remove thumbshadows
perlregex 720p/ViewsPictures.xml 's|\s*<bordertexture[^>]*>ThumbShadow.png</bordertexture>\s*\000||g'
	#remove ThumbBG.png
IMG='ThumbBG.png'
LIST=$(grep "$IMG" 720p/* | cut -f1 | uniq | tr -d ':' | tr '\n' ' ')
for F in $LIST ; do
	perlregex "$F" 's|\s*?<control type="image">\s*?\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|animation\|include\|bordersize\|fadetime)[^>]*>[^>]*>\s*\000)*'\
'\s*<texture[^>]*>'ThumbBG.png'</texture>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|animation\|include\|bordersize\|fadetime)[^>]*>[^>]*>\s*\000)*'\
'\s*</control>\s*?\000||g'
done
	perlregex 720p/ViewsPictures.xml 's|<texture border="2">ThumbBG.png</texture>|<texture border="10">folder-Focus.png</texture>|g'
	perlregex 720p/ViewsPictures.xml 's|\s*<bordertexture border="10">folder-Focus.png</bordertexture>\s*\000||g'
if grep -q "$IMG" 720p/* ; then
	echo "ERROR: Not all occurrences of '$IMG' could be removed, please check:"
	grep "$IMG" 720p/*
	exit 3
fi
rm "media/$IMG" 2>/dev/null

#remove homefloor
perlregex 720p/Home.xml 's|\s*<control type="image">\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|animation)>[^>]*>\s*\000)*'\
'\s*<texture>homefloor.png</texture>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|animation)[^>]*>[^>]*>\s*\000)*'\
'\s*</control>\s*\000||'
if grep -q "homefloor.png" 720p/* ; then
	echo "ERROR: Not all occurrences of 'homefloor.png' could be removed, please check:"
	grep "homefloor.png" 720p/*
	exit 3
fi
rm media/homefloor.png 2>/dev/null

#remove floor.png
IMG='floor.png'
LIST=$(grep "$IMG" 720p/* | cut -f1 | uniq | tr -d ':' | tr '\n' ' ')
for F in $LIST ; do
	perlregex "$F" 's|\s*?<control type="image">\s*?\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*'\
'\s*<texture>'$IMG'</texture>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*'\
'\s*</control>\s*?\000||g'
done
if grep -q "$IMG" 720p/* ; then
	echo "ERROR: Not all occurrences of '$IMG' could be removed, please check:"
	grep "$IMG" 720p/*
	exit 3
fi
rm "media/$IMG" 2>/dev/null

#remove ThumbShadow.png from list view
perlregex 720p/ViewsFileMode.xml 's|\s*<bordertexture border="8">ThumbShadow.png</bordertexture>\s*\000||g'

#remove border from addons that are not focused on the home view
perlregex 720p/includes.xml 's|(\s*<width>180</width>\s*\000)'\
'(\s*<height>120</height>\s*\000)'\
'(\s*<aspectratio aligny="bottom">keep</aspectratio>\s*\000)'\
'\s*<bordertexture border="5">button-nofocus.png</bordertexture>\s*\000'\
'|\1\2\3|g'
#remove mirror of addons on the home view
perlregex 720p/includes.xml 's|\s*?<control type="image">\s*?\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*<texture diffuse="diffuse_mirror2.png" flipy="true" background="true">.INFO.ListItem.Icon.</texture>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*</control>\000'\
'||g'
#remove label for addons that are not focused on the home view
perlregex 720p/includes.xml 's|\s*<control type="label">\s*\000'\
'\s*<posx>91</posx>\s*\000'\
'\s*<posy>125</posy>\s*\000'\
'\s*<width>180</width>\s*\000'\
'\s*<height>20</height>\s*\000'\
'\s*<font>font12</font>\s*\000'\
'\s*<textcolor>grey2</textcolor>\s*\000'\
'\s*<align>center</align>\s*\000'\
'\s*<aligny>center</aligny>\s*\000'\
'\s*<label>.VAR.MainItemLabel.</label>\s*\000'\
'(\|\s*<visible>.Control.HasFocus.9002.</visible>\s*\000)'\
'\s*</control>\s*\000||g'

#remove weather location
perlregex 720p/Home.xml 's|\s*<control type="label">\s*\000'\
'\s*<description>Location label</description>\s*\000'\
'\s*<posx>65</posx>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*</control>\s*\000||'
#center temp label
perlregex 720p/Home.xml 's|(<posx>65</posx>\s*\000'\
'\s*<posy)>20</posy>|\1>15</posy>|'
#remove weather condition
perlregex 720p/Home.xml 's|\s*<control type="label">\s*\000'\
'\s*<description>Conditions Label</description>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*</control>\s*\000||'

#remove date label
perlregex 720p/includes.xml 's|\s*<control type="label">\s*\000'\
'\s*<description>date label</description>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*</control>\s*\000||'
#move time label up
perlregex 720p/includes.xml 's|(<control type="label">\s*\000'\
'\s*<description>time label</description>\s*\000'\
'\s*<posx>15r</posx>\s*\000'\
'\s*<posy)>20<|\1>5<|'

#remove Fanart_Diffuse.png
#perlregex 720p/ViewsVideoLibrary.xml 's| diffuse="Fanart_Diffuse.png"||g'
#rm media/Fanart_Diffuse.png 2>/dev/null
#remove ThumbShadow from video views
perlregex 720p/ViewsVideoLibrary.xml 's|\s*<bordertexture border="8">ThumbShadow.png</bordertexture>\s*\000||g'
	#remove sections icon
	perlregex 720p/MyVideoNav.xml 's|\s*<control type="image">\s*\000'\
'\s*<description>Section header image</description>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|texture)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||'
	#remove location labels
	perlregex 720p/MyVideoNav.xml 's|\s*<control type="label">\s*\000'\
'\s*<include>WindowTitleCommons</include>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|aspectratio\|texture\|visible\|label)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||g'
	#remove location grouplist
perlregex 720p/MyVideoNav.xml 's|\s*<control type="grouplist">\s*\000'\
'\s*<posx>65</posx>\s*\000'\
'\s*<posy>5</posy>\s*\000'\
'(\s*<(height\|width\|orientation\|align\|itemgap\|aspectratio\|texture\|visible\|label)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||'

#remove HomeNowPlayingBack.png
IMG='HomeNowPlayingBack.png'
LIST=$(grep "$IMG" 720p/* | cut -f1 | uniq | tr -d ':' | tr '\n' ' ')
for F in $LIST ; do
	perlregex "$F" 's|\s*?<control type="image"[^>]*>\s*?\000'\
'(\s*<(posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*<texture[^>]*>'$IMG'</texture>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*</control>\s*?\000||g'
done
if grep -q "$IMG" 720p/* ; then
	echo "ERROR: Not all occurrences of '$IMG' could be removed, please check:"
	grep "$IMG" 720p/*
	exit 3
fi
rm "media/$IMG" 2>/dev/null

#remove background top
perlregex 720p/IncludesBackgroundBuilding.xml 's|\s*<control type="image">\s*\000'\
'(\s*<(posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*<texture[^>]*>HomeNowPlayingBack.png</texture>\s*\000'\
'(\s*<(posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
'\s*</control>\s*\000||'

exit
