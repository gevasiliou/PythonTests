#!/bin/bash
now=$(pwd) #Keep current working directory
clear
cd /usr/share/applications
fileindex=0
comindex=0

for i in $( ls brasero.desktop); do
	##executable=$(cat "$i" |grep -v 'TryExec' |grep 'Exec' |grep -Po '(?<=Exec=)[A-Za-z0-9]*+[ --0-9A-Za-z-a-zA-Z0-9]*')
	executable=$(cat "$i" |grep -v 'TryExec' |grep 'Exec' |grep -Po '(?<=Exec=)[ --0-9A-Za-z]*')
#	executable=`cat $i |grep -v 'TryExec' |grep 'Exec'`		# This also works ok.
	echo "file:" $i "-- executable:" $executable

	fileindex=$(($fileindex + 1))
	desktopfiles["$fileindex"]=$i	
	
	while IFS= read -r line; do
		comindex=$(($comindex + 1))
#		printf '%s\n' "$line" 	# this prints correctly.
#		echo "$line"			# this also prints correctly! 
		commands["$comindex"]=$line
		if [[ "$comindex" -gt "$fileindex" ]]; then
#			echo 'comindex greater than fileindex'
			fileindex=$(($fileindex + 1))
			desktopfiles["$fileindex"]=$i
		fi
	done <<< "$executable"
	
#	echo "command index last value:" $comindex
#	echo "file index last value:" $fileindex
	
#	k=1
#	while [[ "$k" -lt "$comindex" ]]; do
#		echo ${desktopfiles[$k]} "-" ${commands[$k]} 
#		k=$(($k + 1))
#	done

#	# This for prints correctly the commands array	
#	for k in "${commands[@]}"; do
#		echo "command:" $k #Array is printed correctly.
#	done


#	echo "index corrected value:" $(($index - 1))

#	while read -r line
#	do
#    	name="$line"
#		name2=$(echo "${name:0:5}")		    	#this works. Returns five first chars of each line.
#		if [[ "$name2" = "Exec=" ]];then
#			echo "Name read from file: $name"
#			echo "command: ${name:5}"
#		fi
#	done < "$executable"

#		#list+="$i $executable "

done

#echo "command index last value:" $comindex
#echo "file index last value:" $fileindex
	
k=1
c='"'
while [[ "$k" -le "$comindex" ]]; do
	echo "ID: " $k " -- "${desktopfiles[$k]} " -- " ${commands[$k]} #Array is printed correctly.
	
#	list= $(echo "'" "$k" "' '" ${desktopfiles[$k]} "' '" ${commands[$k]} "'" )
	k=$(($k + 1))
echo $list
done


#echo $list
#yad --list --column "A" --column "B" DataA1 DataB1 DataA2 DataB2
#yad --list --column "Desktop File" --column "Exec Value" $list

cd $now
# grep -V means do not select lines containing TryExec (works like not operator)
# grep Exec means select lines containing Exec
# grep -Po gets part of the previous line. Operator ?<= means Look forward after the literal given expression Exec=
# [A-Za-z0-9] means match after Exec=, any character that bellongs in range A-Z or range a-z or range 0-9. 
# The asterisk works like a multiplier => multiple chars selection. if you ommit the * multiplier only one character will be selected after Exec=
# +[ --0-9A-Za-z-a-zA-Z0-9]* --> combine (plus) another set of chars that include either a space, or two dashes (literally), or one dash or chars in given ranges 
# 0-9A-Za-z are ranges. after a-z there is a single - = literally a dash. After this dash another range of a-zA-Z0-9.
# Also this works: grep -Po '(?<=Exec=)[A-Za-z0-9]*+[ --0-9A-Za-z]*'
# More over it seems that grep -Po can be further simplified to grep -Po '(?<=Exec=)[ --0-9A-Za-z]*'
# This is strange; in the beginning the simple greps did not return the required results .
# Above grep gets correct Exec all Exec entries from brasero.desktop: brasero %U, brasero --no-existing-session, brasero --image, etc
# and also gets correct Exec entries from xfce-mouse-settings: xfce4-mouse-settings or even simple exec entries like smtube from smtube.desktop. 
# With other words, get's correctly everything.

# yad is not working ok, due to the case that yad needs data in a very specific way (Data a1 Data b1) and we have a case more than one exec entries to belong in
# a single desktop file , mixing all things up

#	while read -r line
#	do
#    	name="$line"
#		name2=$(echo "${name:0:5}")		    	#this works. Returns five first chars of each line.
#		if [[ "$name2" = "Exec=" ]];then
#			echo "Name read from file: $name"
#			echo "command: ${name:5}"
#		fi
#	done < "$i"  #variable $i has the name of the current file in ls.
#  The above while read -r method is too slow. For one file i want some seconds, imagine all the desktop files to be opened for Exec commands to be extracted.