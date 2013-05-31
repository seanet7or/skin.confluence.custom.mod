#!/bin/bash


# $1 file
# $2 regex
perlregex() {
	local FILE="$1"
	local REGEX="$2"
	cp "$FILE" "$FILE.tmp"
	cat "$FILE.tmp" | tr '\n' '\0' | ssed -R "$REGEX" | tr '\0' '\n' >"$FILE"
	rm "$FILE.tmp"
}


# apply regex to all files in 720p subfolder
# $1 regex
replace_all() {
	local REGEX="$1"
	local LIST=$(find 720p -type f)
	for F in $LIST ; do
		perlregex "$F" "$REGEX"
	done
}


# removes <control type="? .... </control> structure from xml file
# the controle structure to remove is identified by the characteristic line
# $1 regex matching the opening control tag, example: '<control type="label" id="[0-9]*">'
# $2 regex matching all other lines (incl. whitespace), example:
#		'(\s*<(description\|posx\|posy\|height\|width)[^>]*>[^>]*>\s*\000)*?'\
# $3 characteristic line, example: '<description>time label</description>
# $4 .xml file ; if empty, all occurrencies are searched
remove_control() {
	local TAG=$1
	local OTHERS=$2
	local LINE=$3 #$(echo "$1" | tr ' ' '.')

	if [ -z "$4" ] ; then
		#echo "Param4 is empty, building file list:"
		local LIST=$(grep "$LINE" 720p/*.xml | cut -f1 | uniq | tr -d ':' | tr '\n' ' ')
		local CHECK=true
		#echo "$LIST"
	else
		local LIST="$4"
		local CHECK=false
	fi

	for F in $LIST ; do
		perlregex "$F" 's|\s*?'"$TAG"'\s*?\000'\
"$OTHERS"\
'\s*'"$LINE"'\s*\000'\
"$OTHERS"\
'\s*</control>\s*?\000||g'
	done

	if $CHECK ; then
		if grep -q "$LINE" 720p/* ; then
			echo "WARNING: Not all occurrences of '$LINE' could be removed, please check:"
			grep "$LINE" 720p/*
		fi
	fi
}


# removes <control type="image"> .... </control> structure from xml file
# this function removes only controls without an id!
# the controle structure to remove is identified by the characteristic line
# $1 characteristic line
# $2 .xml file ; if empty, all occurrencies are searched
remove_imagecontrol() {
	remove_control '<control type="image">' \
'(\s*<(colordiffuse\|texture\|description\|bordersize\|bordertexture\|fadetime\|posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
 "$1" "$2"
}


# removes <control type="image"> .... </control> structure from xml file
# this function removes controls with and without an id!
# the controle structure to remove is identified by the characteristic line
# $1 characteristic line
# $2 .xml file ; if empty, all occurrencies are searched
remove_imagecontrolid() {
	remove_control '<control type="image"[^>]*>' \
'(\s*<(colordiffuse\|texture\|description\|bordersize\|bordertexture\|fadetime\|posx\|posy\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|animation\|include)[^>]*>[^>]*>\s*\000)*?'\
 "$1" "$2"
}


# removes <control type="label .... </control> structure from xml file
# the controle structure to remove is identified by the characteristic line
# $1 characteristic line
# $2 .xml file ; if empty, all occurrencies are searched
remove_labelcontrol() {
	local LINE=$1 #$(echo "$1" | tr ' ' '.')
	if [ -z "$2" ] ; then
		#echo "Param2 is empty, building file list:"
		local LIST=$(grep "$LINE" 720p/*.xml | cut -f1 | uniq | tr -d ':' | tr '\n' ' ')
		local CHECK=true
		#echo "$LIST"
	else
		local LIST="$2"
		local CHECK=false
	fi
	
	for F in $LIST ; do
		perlregex "$F" 's|\s*?<control type="label"(\| id="1")>\s*?\000'\
'(\s*<(animation\|include\|info\|posx\|posy\|visible\|height\|width\|label\|align\|aligny\|selectedcolor\|font\|textcolor\|shadowcolor)[^>]*>[^>]*>\s*?\000)*'\
'\s*'"$LINE"'\s*\000'\
'(\s*<(animation\|include\|info\|posx\|posy\|visible\|height\|width\|label\|align\|aligny\|selectedcolor\|font\|textcolor\|shadowcolor)[^>]*>[^>]*>\s*?\000)*'\
'\s*</control>\s*?\000||g'
	done
	
	if $CHECK ; then
		if grep -q "$LINE" 720p/* ; then
			echo "WARNING: Not all occurrences of '$LINE' could be removed, please check:"
			grep "$LINE" 720p/*
		fi
	fi
}


# removes <control type="button .... </control> structure from xml file
# the controle structure to remove is identified by the characteristic line
# $1 characteristic line
# $2 .xml file ; if empty, all occurrencies are searched
remove_buttoncontrol() {
	local LINE=$1 #$(echo "$1" | tr ' ' '.')
	if [ -z "$2" ] ; then
		#echo "Param2 is empty, building file list:"
		local LIST=$(grep "$LINE" 720p/*.xml | cut -f1 | uniq | tr -d ':' | tr '\n' ' ')
		local CHECK=true
		#echo "$LIST"
	else
		local LIST="$2"
		local CHECK=false
	fi
	
	for F in $LIST ; do
		perlregex "$F" 's|\s*?<control type="button"(\| id="[0-9]*")>\s*?\000'\
'(\s*<(description\|posx\|posy\|width\|height\|label\|font\|onclick\|include\|texturefocus\|texturenofocus\|onleft\|onright\|onup\|ondown\|visible)[^>]*>[^>]*>\s*?\000)*'\
'\s*'"$LINE"'\s*\000'\
'(\s*<(description\|posx\|posy\|width\|height\|label\|font\|onclick\|include\|texturefocus\|texturenofocus\|onleft\|onright\|onup\|ondown\|visible)[^>]*>[^>]*>\s*?\000)*'\
'\s*</control>\s*?\000||g'
	done
	
	if $CHECK ; then
		if grep -q "$LINE" 720p/* ; then
			echo "WARNING: Not all occurrences of '$LINE' could be removed, please check:"
			grep "$LINE" 720p/*
		fi
	fi
}


# checks if image file is linked in the xmls ; if not, the image is deleted
# $1 image file with full path
check_and_remove() {
	F=$1
	if [ ! -f "$F" ] ; then
		#echo "'$F' doesn't exist."
		return 0
	fi
	
	FS=$(basename $F)
	if ! grep -q "[^a-z]$FS" 720p/* ; then
		
		BASE=$(echo "$FS" | sed 's|\.[a-zA-Z]*||g')
		#echo "Occurences of '$BASE':"
		if ! grep -q "[^a-z]$BASE[^a-zA-Z0-9 _]" 720p/* ; then
			rm "$F" 2>/dev/null
		else
			echo "'$BASE' ('$F') was found in the .xmls:"
			grep "$BASE" 720p/*
			exit 3
		fi
	else
		echo "'$FS' ('$F') was found in the .xmls:"
		grep "$FS" 720p/*
		exit 3
	fi
}

findunused() {
	FILES=$(find media -type f)
	IFS_OLD=$IFS
	IFS=$'\n'

	#generic
	for F in DefaultAddSource.png DefaultCDDA.png DefaultDVDEmpty.png DefaultDVDRom.png DefaultFile.png DefaultFolder.png DefaultFolderBack.png DefaultHardDisk.png DefaultNetwork.png DefaultPicture.png DefaultPlaylist.png DefaultProgram.png DefaultRemovableDisk.png DefaultScript.png DefaultShortcut.png DefaultVCD.png OverlayHasTrainer.png OverlayHD.png OverlayLocked.png OverlayRAR.png OverlayTrained.png OverlayUnwatched.png OverlayWatched.png OverlayZIP.png ; do
		FILES=$(echo "$FILES" | grep -v $F)
	done
	#music
	for F in DefaultAlbumCover.png DefaultArtist.png DefaultAudio.png DefaultMusicAlbums.png DefaultMusicArtists.png DefaultMusicCompilations.png DefaultMusicGenres.png DefaultMusicPlaylists.png DefaultMusicPlugins.png DefaultMusicRecentlyAdded.png DefaultMusicRecentlyPlayed.png DefaultMusicSearch.png DefaultMusicSongs.png DefaultMusicTop100.png DefaultMusicTop100Albums.png DefaultMusicTop100Songs.png DefaultMusicVideos.png DefaultMusicVideoTitle.png DefaultMusicYears.png ; do
		FILES=$(echo "$FILES" | grep -v $F)
	done
	#video
	for F in DefaultActor.png DefaultCountry.png DefaultDirector.png DefaultGenre.png DefaultInProgressShows.png DefaultMovies.png DefaultMovieTitle.png DefaultRecentlyAddedEpisodes.png DefaultRecentlyAddedMovies.png DefaultRecentlyAddedMusicVideos.png DefaultSets.png DefaultStudios.png DefaultTVShows.png DefaultTVShowTitle.png DefaultVideo.png DefaultVideoCover.png DefaultVideoPlaylists.png DefaultVideoPlugins.png DefaultYear.png ; do
		FILES=$(echo "$FILES" | grep -v $F)
	done	
	#addons
	for F in DefaultAddon.png DefaultAddonAlbumInfo.png DefaultAddonArtistInfo.png DefaultAddonLyrics.png DefaultAddonMovieInfo.png DefaultAddonMusic.png DefaultAddonMusicVideoInfo.png DefaultAddonNone.png DefaultAddonPicture.png DefaultAddonProgram.png DefaultAddonPVRClient.png DefaultAddonRepository.png DefaultAddonScreensaver.png DefaultAddonService.png DefaultAddonSkin.png DefaultAddonSubtitles.png DefaultAddonTvInfo.png DefaultAddonVideo.png DefaultAddonVisualization.png DefaultAddonWeather.png DefaultAddonWebSkin.png	; do
		FILES=$(echo "$FILES" | grep -v $F)
	done	
	#own
	for F in genre-numbers.txt Thumbs.db media/Language/*.png media/flagging/* media/DefaultGenre/* media/LeftRating/* media/CenterRating/* Makefile.in ; do
		FILES=$(echo "$FILES" | grep -v $F)
	done
	
	for F in $FILES ; do
		FS=$(basename $F)
		if ! grep -q "$FS" 720p/* ; then
			#echo "'$FS' was not found in the .xmls."
			#echo "File is '$F'."
			BASE=$(echo "$FS" | sed 's|\.[a-zA-Z]*||g')
			#echo "Occurences of '$BASE':"
			if ! grep -q "$BASE" 720p/* ; then
				echo "Whether '$FS' nor '$BASE' was found in the .xmls."
				echo "File is '$F'."
			fi
		else
			#echo "'$FS' was found in the .xmls."
			#echo "File is '$F'."	
			:
		fi
	done
	IFS=$IFS_OLD
}

read_origmaster() {
	ZIP='Mudislander-master.zip'
	echo "Downloading from GitHub."
	wget -O- --no-check-certificate https://github.com/Mudislander/skin.confluence.custom.mod/archive/master.zip >$ZIP
	mkdir -p Mudislander-master
	echo "Extracting the archive."
	unzip -o -q "$ZIP" -d Mudislander-master
	echo "Copying the files to the right place."
	rm -rf media
	rm -rf backgrounds
	rm -rf colors
	rm -rf language
	rm -rf themes
	rm -rf extras
	cp -r Mudislander-master/skin.confluence.custom.mod-master/* .
	cp -r lightmod/* .
	echo "Copied all files."
}

#findunused

if [ "$1" == "read" ] ; then
	echo "#################### BUILDING BASE FILES ########################"
	echo "Reading original repository."
	read_origmaster
	echo "Completed creating the base files."
fi

#exit

#remove temporary files (if script was canceled before)
rm 720p/*.tmp 2>/dev/null

echo "#################### APPLYING GENERIC/SKIN-WIDE MODIFICATIONS ########################"

#remove unnecessary files
	check_and_remove media/icon-weather.png
	check_and_remove media/icon-video.png
	check_and_remove media/icon_volume.png
	check_and_remove media/poster_diffuse.png
	check_and_remove media/OSDFullScreenFO.png
	check_and_remove media/OSDFullScreenNF.png
	check_and_remove media/defaultDVDFull.png

#already included in original
	#only run intial setup if not already done
		#if grep -q '<include>DefaultInitialSetup</include>' 720p/*; then
			#echo "Only run intial setup if not already done."
			#replace_all 's|<include>DefaultInitialSetup</include>|'\
	#'<include condition="!Skin.HasSetting(InitialSetUpRun)">DefaultInitialSetup</include>|g'
		#fi

#change dialog background
	if grep -q "DialogBack.png" 720p/* ; then
		echo "Changing Dialog background."
		#change background image
		replace_all 's|(\s*)<texture border="[0-9]*">DialogBack.png</texture>|'\
'\1<texture>white100_light.png</texture>\000\1<colordiffuse>DF0C0C0C</colordiffuse>|g'
	fi
	check_and_remove media/DialogBack.png
		
#remove close button for mouse
	if grep -q '<texturenofocus>DialogCloseButton.png</texturenofocus>' 720p/*
	then
		echo "Removing mouse close buttons."
		remove_buttoncontrol '<texturenofocus>DialogCloseButton.png</texturenofocus>'
	fi
	check_and_remove media/DialogCloseButton.png
	check_and_remove media/DialogCloseButton-focus.png
	
#correct translation
	if cat language/German/strings.po | tr '\n' '\000' | grep -q -P 'msgid "Home Menu"\s*\000\s*msgstr "Gesehen Status Overlay benutzen'
	then
		echo "Correcting wrong translation."
		perlregex language/German/strings.po 's|(\s*msgctxt "#31153"\s*\000\s*msgid "Home Menu"\s*\000\s*msgstr ")Gesehen Status Overlay benutzen|\1Haupt Menü|'
	fi
	
#replace ContentPanel.png
	if grep -q 'ContentPanel.png' 720p/* ; then
		echo "Replacing content panel background."
		replace_all 's|<texture[^>]*>ContentPanel.png|<texture>black-back.png|g'
	fi
	check_and_remove media/ContentPanel.png
	

#replace default background	
	if grep -q 'SKINDEFAULT.jpg' 720p/* ; then
		echo "Replacing default background."
		replace_all 's|<value>special://skin/backgrounds/SKINDEFAULT.jpg</value>|<value>special://skin/extras/lightmod/default.jpg</value>|g'
		replace_all 's|.INFO.Skin.CurrentTheme,special://skin/backgrounds/,.jpg.|special://skin/extras/lightmod/default.jpg|g'
	fi

#changed scroll bar to make it besser visible
	if grep ScrollBarH_bar.png 720p/* >/dev/null ; then
		echo "Replacing scroll bars with better visible ones."
		replace_all 's|ScrollBarH_bar.png|ScrollBarH_bar_light.png|g'
		replace_all 's|ScrollBarV_bar.png|ScrollBarV_bar_light.png|g'
	fi
	check_and_remove 'media/ScrollBarH_bar.png'
	check_and_remove 'media/ScrollBarV_bar.png'
	
#remove left panel arrow
	if grep -q HasSub.png 720p/* ; then
		echo "Removing hidden panel arrow."
		perlregex 720p/includes.xml 's|<texturefocus>HasSub.png</texturefocus>|<texturefocus>-</texturefocus>|g'
		perlregex 720p/includes.xml 's|<texturenofocus>HasSub.png</texturenofocus>|<texturenofocus>-</texturenofocus>|g'
	fi
	check_and_remove media/HasSub.png	
	
#remove xbmc logo
	if grep -q xbmc-logo.png 720p/* ; then
		echo "Removing xbmc logo."
		#remove logo from all screens
		remove_imagecontrol '<texture>xbmc-logo.png</texture>'
		#remove logo fallback from music visualisation
		perlregex 720p/MusicVisualisation.xml 's| fallback="xbmc-logo.png"||g'
	fi
	check_and_remove media/xbmc-logo.png
	
#remove GlassOverlay.png
	if grep -q 'GlassOverlay.png' 720p/* ; then
		echo "Removing GlassOverlay.png."
		remove_imagecontrol '<texture>GlassOverlay.png</texture>'
	fi
	check_and_remove media/GlassOverlay.png

#removed some separator images to get a cleaner look
	if grep separator.png 720p/* >/dev/null ; then
		echo "Removing references to 'media/separator.png'".
		remove_imagecontrol '<texture>separator.png</texture>'
	fi
	check_and_remove media/separator.png
	if grep separator2.png 720p/* >/dev/null ; then
		echo "Removing references to 'media/separator2.png'".
		remove_imagecontrol '<texture>separator2.png</texture>' >/dev/null
		#not all controls can be removed, some have an id and are used for navigation
		replace_all 's|separator2.png|-|g'
	fi
	check_and_remove media/separator2.png
	if grep -q 'MenuItemNF.png' 720p/* ; then
		echo "Removing menu items separator 'MenuItemNF.png'."
		remove_imagecontrol '<texture[^>]*>MenuItemNF.png</texture>'
		replace_all 's|(\s*?<texturenofocus[^>]*>)MenuItemNF.png(</texturenofocus>\s*?\000)|\1-\2|g'
	fi
	check_and_remove 'media/MenuItemNF.png'
	
#removed content panel mirrors
	if grep -q 'ContentPanelMirror' 720p/* ; then
		echo "Removing content panel mirrors."
		remove_imagecontrol '<texture[^>]*>ContentPanelMirror.png</texture>'
	fi
	check_and_remove 'media/ContentPanelMirror.png'

#removed mirrors from everywhere
	if grep -q 'diffuse_mirror2.png' 720p/* ; then
		echo "Removing diffuse_mirror2.png."
		remove_imagecontrol '<texture[^>]*diffuse="diffuse_mirror2.png"[^>]*>[^<]*</texture>'
	fi
	check_and_remove media/diffuse_mirror2.png

#removed poster mirrors
	if grep -q 'diffuse_mirror3.png' 720p/* ; then
		echo "Removing diffuse_mirror3.png."
		remove_imagecontrol '<texture[^>]*diffuse="diffuse_mirror3.png"[^>]*>[^<]*</texture>'
	fi
	check_and_remove media/diffuse_mirror3.png

#remove floor.png
	if grep -q 'floor.png' 720p/* ; then
		echo "Removing floor image."
		remove_imagecontrol '<texture[^>]*>floor.png</texture>'
	fi
	check_and_remove 'media/floor.png'

#remove HomeNowPlayingBack.png from most places (but not behind the seek bar on video osd)
	if grep -q '<texture flipy="true">HomeNowPlayingBack.png' 720p/* ; then
		echo "Removing HomeNowPlayingBack.png."
		remove_imagecontrol '<texture[^>]*>HomeNowPlayingBack.png</texture>' >/dev/null
		#remove behind time label on video osd
		replace_all 's|\s*<control type="image" id="1">\s*\000'\
'\s*<posx>[a-z0-9-]*</posx>\s*\000'\
'\s*<posy>[a-z0-9-]*</posy>\s*\000'\
'\s*<width>[a-z0-9]*</width>\s*\000'\
'\s*<height>[a-z0-9]*</height>\s*\000'\
'\s*<texture flipy="true">HomeNowPlayingBack.png</texture>\s*\000'\
'\s*<visible>[^<]*</visible>\s*\000'\
'\s*</control>\s*\000'\
'||g'
	fi
	
#removed ThumbShadow
	if grep -q 'ThumbShadow.png' 720p/* ; then
		echo "Removing thumb shadows."
		replace_all 's|\s*.bordertexture[^>]*>ThumbShadow.png</bordertexture.\s*\000||g'
	fi
	check_and_remove 'media/ThumbShadow.png'
	
#remove ThumbBG.png
	if grep -q 'ThumbBG.png' 720p/* ; then
		echo "Removing thumb background."
		remove_imagecontrol '<texture border="2">ThumbBG.png</texture>'
	fi
	check_and_remove 'media/ThumbBG.png'	
	
#remove all references to ThumbBorder.png
	if grep -q 'ThumbBorder.png' 720p/* ; then
		echo "Removing thumb border."
		replace_all 's|\s*.bordertexture[^>]*>ThumbBorder.png</bordertexture.\s*\000||g'
	fi
	check_and_remove media/ThumbBorder.png
	
#removed CommonPageCount
	if grep -q 'CommonPageCount' 720p/* ; then
		echo "Removing page count info."
		#includes
		replace_all 's|\s*<include[^>]*>CommonPageCount</include>\s*\000||g'
		#CommonPageCount definition
		perlregex 720p/includes.xml 's|\s*<include name="CommonPageCount">\s*\000'\
'(\s*<(animation\|control\|/control\|description\|posx\|posy\|scroll\|height\|width\|align\|aligny\|font\|textcolor\|shadowcolor\|label\|info\|visible\|aspectratio\|include)[^>]*>.*?\000)*?'\
'\s*</include>\s*\000||'
		if grep -q 'CommonPageCount' 720p/* ; then
			echo "Error: CommonPageCount could not be removed totally."
			exit 3
		fi
	fi
	
#change time
	if grep -q '<description>date label</description>' 720p/includes.xml ; then
		echo "Changing time display mode."
		#remove date label
		remove_labelcontrol '<description>date label</description>' 720p/includes.xml
		#move time label up
		perlregex 720p/includes.xml 's|(<control type="label"[^>]*>\s*\000'\
'\s*<description>time label</description>\s*\000'\
'\s*<posx>15r</posx>\s*\000'\
'\s*<posy)>20<|\1>5<|'
	fi
	
# enable German movie ratings
	if ! grep -q 'fsk-18' '720p/IncludesVariables.xml' ; then
		echo "Enabling German movie ratings."
		#uncommenting the "Germany" option from the settings window
		perlregex '720p/SkinSettings.xml' 's|<!--(item>\s*\000'\
'\s*<label>.LOCALIZE.31702.</label>\s*\000'\
'\s*<onclick>noop</onclick>\s*\000'\
'\s*<icon>.</icon>\s*\000'\
'\s*<thumb>.</thumb>\s*\000'\
'\s*</item>\s*\000'\
'\s*)<item>'\
'|<\1<!--item>|'
		#choose right flag depending on the FSK
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

#not needed anymore as it is in the original now
	#lets choose all types of addons for the home window addons
	#	echo "Changing selection of addons for the home screen."
	#	perlregex '720p/SkinSettings.xml' 's|(Skin.SetAddon.[^,]*),[^\)]*\)|\1,xbmc.addon.video,xbmc.addon.executable,xbmc.addon.audio,xbmc.addon.image)|g'	


	
echo "#################### APPLYING HOME SCREEN MODIFICATIONS ##############################"

#replace submenu item (not focused)
	if grep -q 'HomeSubNF.png' 720p/* ; then
		echo "Replacing submenus item texture (for items that are not focused)."
		replace_all 's|HomeSubNF.png|HomeSubNF_light.png|g'
	fi
	check_and_remove media/HomeSubNF.png

#changed weather info
	if grep -q '<description>Location label</description>' '720p/Home.xml' ; then
		echo "Modifying weather info."
		#remove weather location
		remove_labelcontrol '<description>Location label</description>' 720p/Home.xml
		#center temp label
		perlregex 720p/Home.xml 's|(<posx>65</posx>\s*\000'\
'\s*<posy)>20</posy>|\1>15</posy>|'
		#remove weather condition
		remove_labelcontrol '<description>Conditions Label</description>' 720p/Home.xml
	fi
	
#removed side fade
	if grep SideFade.png 720p/* >/dev/null ; then
		echo "Removing Main menu side fade effect."
		remove_imagecontrol '<texture[^>]*>SideFade.png</texture>'
	fi
	check_and_remove media/SideFade.png

# remove Home menu seperator
	if grep -q 'HomeSeperator' '720p/Home.xml' ; then
		echo "Removing Main menu items separator."
		remove_imagecontrol '<texture>HomeSeperator.png</texture>'
	fi
	check_and_remove 'media/HomeSeperator.png'

# remove Home overlay
	if grep -q 'HomeOverlay1.png' '720p/Home.xml' ; then
		echo "Removing main menu overlay."
		remove_imagecontrol '<texture>HomeOverlay1.png</texture>'
	fi
	check_and_remove 'media/HomeOverlay1.png'
	
#changed addons on the home screen
	if grep -q '<bordertexture border="5">button-nofocus.png</bordertexture>' 720p/includes.xml
	then
		echo "Changing addons on the home screen."
		#remove border from addons that are not focused on the home view
		perlregex 720p/includes.xml 's|(\s*<width>180</width>\s*\000)'\
'(\s*<height>120</height>\s*\000)'\
'(\s*<aspectratio aligny="bottom">keep</aspectratio>\s*\000)'\
'\s*<bordertexture border="5">button-nofocus.png</bordertexture>\s*\000'\
'\s*<bordersize>3</bordersize>\s*\000'\
'|\1\2\3|g'
		#remove label for addons that are not focused on the home view
		remove_labelcontrol '<posx>91</posx>' 720p/includes.xml
	fi
	
#Changed widgets on home screen
	if grep -q 'RecentAddedBack.png' 720p/* ; then
		echo "Changing widgets on the home screen."
		#removing widgets background
		remove_imagecontrol '<texture[^>]*>RecentAddedBack.png</texture>' '720p/IncludesHomeWidget.xml'
		#widget group title label
		remove_labelcontrol '<description>Title label</description>' '720p/IncludesHomeWidget.xml'
		#label for widgets without focus
		remove_labelcontrol '<textcolor>white</textcolor>' '720p/IncludesHomeWidget.xml'
		remove_labelcontrol '<textcolor>grey2</textcolor>' '720p/IncludesHomeWidget.xml'
		#remove bordertexture for widgets that are not focused
		echo "Removing bordertexture from widgets without focus."
		perlregex 720p/IncludesHomeWidget.xml 's|\s*<bordertexture border="5">button-nofocus.png</bordertexture>\s*\000||g'	
	fi
	check_and_remove 'media/RecentAddedBack.png'

#remove homefloor
	if grep -q "homefloor.png" 720p/* ; then
		echo "Removing home floor."
		remove_imagecontrol '<texture>homefloor.png</texture>' 720p/Home.xml
	fi
	check_and_remove media/homefloor.png
	

echo "#################### APPLYING MODIFICATIONS TO PICTURE LIBRARY #######################"

# use thumb in picture view for preview
	if grep -q '<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>' 720p/ViewsPictures.xml
	then
		echo "Changing picture views to use thumbnails for preview."
		perlregex 720p/ViewsPictures.xml 's|<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>|<texture background="true">\$INFO\[ListItem.Icon\]</texture>|g'
		perlregex 720p/MyPics.xml 's|<texture background="true">.INFO.ListItem.FilenameAndPath.</texture>|<texture background="true">\$INFO\[ListItem.Icon\]</texture>|g'
	fi
		
# change picturethumbview
	if grep -q '<description>Date time txt</description>' 720p/ViewsPictures.xml ; then
		echo "Changing picture preview/thumb view."
		#resize left selection panel (to 1 column, 6 rows and fixedlist)
		perlregex 720p/ViewsPictures.xml 's|(\s*<control type)="panel" id="514">\s*\000'\
'(\s*<posx>60</posx>\s*\000)'\
'(\s*)<posy>75</posy>\s*\000'\
'(\s*)<width>432</width>\s*\000'\
'(\s*)<height>576</height>\s*\000'\
'|\1="fixedlist" id="514">\000\2\3\<posy>-72</posy>\000\4<width>144</width>\000\5<height>864</height>\000\5<focusposition>1</focusposition>\000|'
		#resize background of the left panel accordingly
		perlregex 720p/IncludesBackgroundBuilding.xml 's|(\s*<visible>Control.IsVisible.514.</visible>\s*\000'\
'\s*<control type="image">\s*\000'\
'\s*<posx>50</posx>\s*\000'\
'\s*)<posy>60</posy>(\s*\000'\
'\s*)<width>490</width>(\s*\000'\
'\s*)<height>600</height>'\
'|\1<posy>-15</posy>\2<width>202</width>\3<height>750</height>|'
		#move the scrollbar of the selection panel left
		perlregex 720p/ViewsPictures.xml 's|(\s*<control type="scrollbar" id="60">\s*\000)'\
'(\s*)<posx>500</posx>|\1\2<posx>212</posx>|'
		#resize and move the picture preview on the right
		perlregex 720p/ViewsPictures.xml 's|<posx>570</posx>|<posx>282</posx>|'
		perlregex 720p/ViewsPictures.xml 's|<width>640</width>|<width>928</width>|g'
		perlregex 720p/ViewsPictures.xml 's|<height>470</height>|<height>570</height>|g'
		#and the background of the preview on the right side accordingly
		perlregex 720p/IncludesBackgroundBuilding.xml 's|<width>680</width>\s*\000'\
'(\s*)<height>600</height>|<width>968</width>\000\1<height>640</height>|'
		perlregex 720p/IncludesBackgroundBuilding.xml 's|<posx>550</posx>|<posx>262</posx>|'
		#remove date+res labels for the preview panel
		remove_labelcontrol '<description>Date time txt</description>' 720p/ViewsPictures.xml
		remove_labelcontrol '<description>Resolution txt</description>' 720p/ViewsPictures.xml
		#add border texture directly to the picture that is focused in the left selection panel
		perlregex 720p/ViewsPictures.xml 's|(<control type="image">\s*\000'\
'\s*)<posx>10</posx>(\s*\000'\
'\s*)<posy>10</posy>(\s*\000'\
'\s*)<width>124</width>(\s*\000'\
'\s*)<height>124</height>(\s*\000'\
'\s*<aspectratio>keep</aspectratio>\s*\000)'\
'(\s*)(<texture background="true">.INFO.ListItem.Icon.</texture>\s*\000'\
'\s*</control>\s*\000'\
'\s*</focusedlayout>\s*\000)'\
'|\1<posx>8</posx>\2<posy>8</posy>\3<width>128</width>\4<height>128</height>\5'\
'\6<bordersize>2</bordersize>\000'\
'\6<bordertexture border="2">folder-focus.png</bordertexture>\000'\
'\6\7|'
	fi
	
#remove location header
	if grep -q '<description>Section header image</description>' 720p/MyPics.xml 
	then
		echo "Removing location header."
		#section icon
		remove_imagecontrol '<description>Section header image</description>' 720p/MyPics.xml
		#remove location labels
		remove_labelcontrol '<include>WindowTitleCommons</include>' 720p/MyPics.xml
		#remove location grouplist
perlregex 720p/MyPics.xml 's|\s*<control type="grouplist">\s*\000'\
'\s*<posx>65</posx>\s*\000'\
'\s*<posy>5</posy>\s*\000'\
'(\s*<(height\|width\|orientation\|align\|itemgap\|aspectratio\|texture\|visible\|label)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||'
	fi
	check_and_remove media/icon_pictures.png

echo "#################### APPLYING MODIFICATIONS TO VIDEO LIBRARY #########################"

#Removing location info.
	if grep -q '<description>Section header image</description>' 720p/MyVideoNav.xml
	then
		echo "Removing location info."
		#remove sections icon
		remove_imagecontrol '<description>Section header image</description>' 720p/MyVideoNav.xml
		#remove location labels
		remove_labelcontrol '<include>WindowTitleCommons</include>' 720p/MyVideoNav.xml
		#remove location grouplist
		perlregex 720p/MyVideoNav.xml 's|\s*<control type="grouplist">\s*\000'\
'\s*<posx>65</posx>\s*\000'\
'\s*<posy>5</posy>\s*\000'\
'(\s*<(height\|width\|orientation\|align\|itemgap\|aspectratio\|texture\|visible\|label)>[^>]*>\s*?\000)*'\
'\s*</control>\s*\000||'
	fi

echo "#################### APPLYING MODIFICATIONS TO VIDEO OSD #############################"

#change time on video osd
	if grep -q '<description>date label</description>' 720p/VideoFullScreen.xml ; then
		echo "Changing time on video osd."
		#remove date label
		remove_labelcontrol '<description>date label</description>' 720p/VideoFullScreen.xml
		#move time label up
		perlregex 720p/VideoFullScreen.xml 's|(<control type="label">\s*\000'\
'\s*<description>time label</description>\s*\000'\
'\s*<posx>15r</posx>\s*\000'\
'\s*<posy)>20<|\1>5<|'
	fi

echo "#################### APPLYING MODIFICATIONS TO SPECIAL DIALOGS #######################"

#removed media/separator_vertical.png
	if grep -q "separator_vertical.png" 720p/* ; then
		echo "Removing references to 'media/separator_vertical.png'".
		remove_imagecontrol '<texture>separator_vertical.png</texture>'
	fi
	check_and_remove media/separator_vertical.png

#simplified shutdown menu
	if grep -q "ShutdownButtonNoFocus" 720p/* \
		|| grep -q DialogContextBottom.png 720p/* \
		|| grep -q DialogContextMiddle.png 720p/*
	then
		echo "Changing shutdown menu."
		remove_imagecontrolid '<description>background [a-z]* image</description>' 720p/DialogButtonMenu.xml
		perlregex '720p/DialogButtonMenu.xml' 's|texturenofocus border="25,5,25,5">ShutdownButtonNoFocus.png|texturenofocus>black-back.png|g'
		perlregex '720p/DialogButtonMenu.xml' 's|ShutdownButtonFocus.png|button-focus.png|g'
	fi
	check_and_remove media/ShutdownButtonFocus.png
	check_and_remove media/ShutdownButtonNoFocus.png
	check_and_remove media/DialogContextBottom.png
	check_and_remove media/DialogContextMiddle.png
	check_and_remove media/DialogContextTop.png
	
#changed context menu
	if grep -q '<itemgap>2</itemgap>' 720p/DialogContextMenu.xml
	then
		echo "Changing context menu."
		#changing texturenofocus for buttons (instead default one)
		perlregex '720p/DialogContextMenu.xml' 's|(\s*)<description>button template</description>|\1<description>button template</description>\000\1<texturenofocus>black-back.png</texturenofocus>|g'
		perlregex '720p/DialogContextMenu.xml' 's|(\s*)<description>Watch it Later</description>|\1<description>Watch it Later</description>\000\1<texturenofocus>black-back.png</texturenofocus>|g'		
		#remove itemgap
		perlregex '720p/DialogContextMenu.xml' 's|<itemgap>2</itemgap>|<itemgap>0</itemgap>|g'
		#no more necessary because done generally now...
			#remove background image
			#perlregex '720p/DialogContextMenu.xml' 's|<texture border="20">DialogBack.png</texture>|<texture>black-back.png</texture>|g'
	fi

echo "All modifications are completed."
exit
