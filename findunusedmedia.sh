#!/bin/bash
FILES=$(find media -type f)

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
	
IFS_OLD=$IFS
IFS=$'\n'
for F in $FILES ; do
	FS=$(basename $F)
	if ! grep -I -q "$FS" 720p/* ; then
		#echo "'$FS' was not found in the .xmls."
		#echo "File is '$F'."
		BASE=$(echo "$FS" | sed 's|\.[a-zA-Z]*||g')
		#echo "Occurences of '$BASE':"
		if ! grep -I -q "$BASE" 720p/* ; then
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
