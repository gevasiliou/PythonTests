#!/bin/bash

TimeStarted=$(date +%s.%N)
#echo "Time Started=" $TimeStarted

for i in $( ls /usr/share/applications/*.desktop); do
	executable=$(grep -m 1 -Po '(?<=^Exec=)[ --0-9A-Za-z/:space:]*' $i )
	comment=$(grep -m 1 -Po '(?<=^Comment=)[ --0-9A-Za-z/:space:]*' $i )
	comment2=$(grep -m 1 -Po '(?<=^Generic Name=)[ --0-9A-Za-z/:space:]*' $i)
	mname=$(grep -m 1 -Po '(?<=^Name=)[ --0-9A-Za-z/:space:]*' $i)
	icon=$(grep -m 1 -Po '(?<=^Icon=)[ --0-9A-Za-z/:space:]*' $i)
#	echo "Icon=" ${ficon[0]}	
	# With this alternative method (direct awk instead of grep pipe awk) i get ~ 29 sec VBox - 13 secs at home. 
	# It is strange that this method works much faster than cat + grep in Vbox (60secs), but in home  cat+grep works better (9 secs)
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
	# Mind the -m 1 trick in grep... stops after 1st match !

#	executable=$(grep "^Exec=" $i |cut -f 2 -d '=' |head -1)
#	comment=$(grep "^Comment=" $i |cut -f 2 -d '=' |head -1)
#	comment2=$(grep "^Generic Name=" $i |cut -f 2 -d '=' |head -1)
#	mname=$(grep "^Name=" $i |cut -f 2 -d '=' |head -1)
#	icon=$(grep "^Icon=" $i |cut -f 2 -d '=' |head -1)
#	if [[ $comment = "" ]]; then
#		comment=$comment2
#	fi
	
#	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
#	fileindex=$(($fileindex+1))
done

TimeFinished=$(date +%s.%N)
TimeDiff=$(echo "$TimeFinished - $TimeStarted" | bc -l)
#echo "Time Finished=" $TimeFinished
echo "Run Time= " $TimeDiff

# Runtime : 50 seconds at VBOx.
# Also verified using time ./greptest.sh
#real	0m50.113s
#user	0m7.244s
#sys	0m27.404s
