#!/bin/bash

function yadcall 
{ 
rec0=$0
echo "Received0 =" $rec0
rec1=$1
echo "Received1 =" $rec1

echo 'List:' "${list[@]}" # Prints nothing. $list is not accesible by yadcall, even that list is "ready" when yadcall is called by yad list at the end.
#yad --width=200 --height=200 --center --text $received 
}

export -f yadcall

clear
now=$(pwd) #Keep current working directory
# http://smokey01.com/yad/
selections=$(yad --window-icon="gtk-find" --title="Look4 Files" --center --form --separator="," --date-format="%Y-%m-%d" \
	--field="Location":MDIR "/usr/share/applications/" --field="Filename" "*a.desktop" ) 
ret=$?
echo "ret:" $ret #This one returns 0 for OK button, 1 for cancel button
if [[ $ret -eq 1 ]]; then # Cancel Selected
	exit 0
fi 
location=`echo $selections | awk -F',' '{print $1}'`  
files=`echo $selections | awk -F',' '{print $2}'`  
#echo $location $files


cd $location
fileindex=0
comindex=0

for i in $( ls $files); do
	##executable=$(cat "$i" |grep -v 'TryExec' |grep 'Exec' |grep -Po '(?<=Exec=)[A-Za-z0-9]*+[ --0-9A-Za-z-a-zA-Z0-9]*')
	executable=$(cat "$i" |grep -v 'TryExec' |grep 'Exec' |grep -Po '(?<=Exec=)[ --0-9A-Za-z/]*')
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
done

#echo "command index last value:" $comindex
#echo "file index last value:" $fileindex
	
k=1

while [[ "$k" -le "$comindex" ]]; do
	echo $k " -- "${desktopfiles[$k]} " -- " ${commands[$k]}
	list+=( "$k" "${desktopfiles[$k]}" "${commands[$k]}" ) #this sets double quotes in each variable.
	k=$(($k + 1))
done
echo "${list[@]}"


#while : loop
#do
yad --list --width=800 --height=600 --center --print-column=0 --select-action 'bash -c yadcall %s %s %s' \
	--button="Display":100 --button="Run":120 --button="Cancel":110  \
	--column "ID" --column "File" --column "Exec" "${list[@]}"
btn=$?
#If list is not given to yad as array but as a plain variable, is not working.
echo "button pressed:" $? "-" $btn
#PS: it seems that button code 11 is assigned for cancel by default.
#if you assign commands in buttons id , then yad list does not exit (unless you press cancel, id 0) but yad selected row is not parsed to external command/script
case $btn in
	10)
		todisplay=`echo $yadselection | awk -F'|' '{print $2}'`		
		echo 'display code'  - 'yad selection=' $yadselection  - 'file to display' $todisplay
#		yad --file $todisplay 
		;;
	11)
		echo 'cancel code - yad selection=' $yadselection
		exit
		;;
	12)
		echo 'run code' 
		echo "yad selection=" $yadselection
		torun=`echo $yadselection | awk -F'|' '{print $3}'`		
		echo "yad file to run=" $torun 
		;;
esac
#done

cd $now

#yad --list --column "A" --column "B" DataA1 DataB1 DataA2 DataB2

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
#			echo "command: ${name:5}" # This also works ok. gives the whole string after 5th character
#		fi
#	done < "$i"  #feed the while. variable $i = current file in ls.
#  The above while read -r method is too slow. For one file i want some seconds, imagine all the desktop files to be opened for Exec commands to be extracted.

# http://tldp.org/LDP/abs/html/special-chars.html
# Endless loop:
#while :
#do
#   operation-1
#   operation-2
#   operation-n
#done
# Bellow works ok, but you can not send to external command/script the --list selected row. 
# Button calls with yad selection is supported only in forms , using %N, where N is the number of the field to be parsed as argument to external command/scipt.
#yad --list --width=800 --height=600 --center --always-print-result \
#	--button="Display":"/home/gv/PythonTests/yadabout.sh" --button="Run":"bash -c yad_call" --button="Cancel":0  \
#	--column "ID" --column "File" --column "Exec" "${list[@]}"
# the end