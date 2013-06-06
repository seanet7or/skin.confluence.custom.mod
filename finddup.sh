IFS=$'\n'


# prints the size of a file in bytes on stdout
#     $1 file name
filesize() {
	stat "$1" | awk '/Size/ { print $2 }'
}


echo "Looking for files to check..."
declare -a FILES=( $(find -type f) );
COUNT=${#FILES[@]}
declare -a SIZES
for ((X = 0; X < $COUNT-1; X++)) ; do
	#set -x
	SIZES[$X]=$(filesize "${FILES[$X]}")
	#set +x
done

declare -a SUMS

echo "$COUNT files found, comparing..."
for ((X = 0; X < $COUNT-1; X++)) ; do
	printf "\r%d/%d " $X $COUNT
	for ((Y = X+1; Y < $COUNT; Y++)) ; do
		if [ "${SIZES[$X]}" == "${SIZES[$Y]}" ] ; then
			if [ -z "${SUMS[$X]}" ] ; then
				SUMS[$X]=$(md5sum "${FILES[$X]}" | cut -d ' ' -f 1)
			fi
			if [ -z "${SUMS[$Y]}" ] ; then
				SUMS[$Y]=$(md5sum "${FILES[$Y]}" | cut -d ' ' -f 1)
			fi
			if [ "${SUMS[$X]}" == "${SUMS[$Y]}" ] ; then
				echo "'${FILES[$X]}', '${FILES[$Y]}'."
			fi
		fi
	done
done

#  for ((y = x+1; y < $cnt; y++))
#  do
#    if [ "${sums[$x]}" == "${sums[$y]}" ];then
#      if [ ${list[$x]} != ${list[$y]} ];then
		#if [ ! -z "${sums[$x]}" ] && [ ! -z "${sums[$y]}" ] ; then
        #remove '#' in next line to enable
		#	echo "'${list[$x]}', '${list[$y]}'."
        #echo "Delete file ${list[$y]}" # && rm -f ${list[$y]}
		#fi
      #fi
    #fi
  #done
#done

#declare -a sums;

#echo "creating md5sum list"
#for ((x = 0; x < $cnt -1; x++))
#do
#    sums[$x]=`md5sum "${list[$x]}" | cut -d ' ' -f 1`
#    progress=$((($x*100)/$cnt))
#    echo -ne "progress $progress %\r"
#done

#echo "doing compare"
#for ((x = 0; x < $cnt -1; x++))
#do
#  for ((y = x+1; y < $cnt; y++))
#  do
#    if [ "${sums[$x]}" == "${sums[$y]}" ];then
#      if [ ${list[$x]} != ${list[$y]} ];then
		#if [ ! -z "${sums[$x]}" ] && [ ! -z "${sums[$y]}" ] ; then
        #remove '#' in next line to enable
		#	echo "'${list[$x]}', '${list[$y]}'."
        #echo "Delete file ${list[$y]}" # && rm -f ${list[$y]}
		#fi
      #fi
    #fi
  #done
#done
