#!/bin/bash
#Great Tuto:http://smokey01.com/yad/
clear
export TMPFILE=/tmp/yadvalues #obviously this creates a super global variable accesible from script and functions!

now=$(pwd) #Keep current working directory
stop="false"
selections=""
location=""
files="" 
fileedited=0

function yadlistselect { 
echo "Received =" $0 " , " $1 " , " $2 " , " $3 " , " $4 " , " $5
echo -e "FILEID=\"$1\"\nFILENAME=\"$4\"\nFILECOMMAND=\"$5\"" > $TMPFILE
}
export -f yadlistselect

function filedisplay { 
source $TMPFILE
filetodisplay=/usr/share/applications/$FILENAME
yad --title="File Display" --width=800 --height=500 --center --text-info --filename=$filetodisplay --wrap --button="Go Back":0
}
export -f filedisplay

function fileedit  
{ 
source $TMPFILE
#echo "Received =" $0 " , " $1 " , " $2 " , " $3
filetoedit=/usr/share/applications/$FILENAME
abb=$(yad --title="Edit Files" --width=800 --height=500 --center --text-info --filename=$filetoedit --wrap --editable \
--button=gtk-save:0 --button=gtk-save-as:10 --button="Go Back":1 --button=gtk-quit:3)
fileaction=$?
#echo "abb:" $abb
abbsaveas=$abb

case $fileaction in
0)  
	counter=1
#	echo "Save Selected"
	while IFS= read -r linenew; do
		if [ $counter -eq 1 ]; then
			echo $linenew > $filetoedit
		else
			echo $linenew >> $filetoedit 
		fi
	counter=$(($counter +1))
	done <<< "$abb"
	;;
3) yad --text="Are you sure?"
	ret2=$?
	if [ $ret2 -eq 0 ]; then exit 3; fi # this exits completely the whole script.
	#exit 3
	;;
10) 
#	echo "Save As Selected"
	saveas=$(yad --center --file --filename=$filetoedit --save )
	countersa=1
	overwrite=0
	if [ $saveas = $filetoedit ]; then
		yad --title="OverWrite"--center --text="overwrite file?"
		overwrite=$?
	fi

	if [ $overwrite -eq 0 ];then
		while IFS= read -r linesaveas; do
			#echo "contents: " $linesaveas
			if [ $countersa -eq 1 ]; then
				echo $linesaveas > $saveas
			else
				echo $linesaveas >> $saveas
			fi
		countersa=$(($countersa +1))
		done <<< "$abbsaveas"
	fi
	;;	
esac

fileedited=1
}


function filerun   
{ 
source $TMPFILE
runcommand=$(yad --center --title="Run File" --entry --entry-label="File to Run" --entry-text="$FILECOMMAND" \
--button=gtk-quit:11 --button="Run With Args":10 --button="Run No Args":12)
# If entry-text contains spaces and is not given within quotes will be treated as two different values.
sel=$?
case $sel in
	10)	torunfull=$runcommand 		
#		echo 'run full command:' $torunfull
		$torunfull
		;;
	11) echo 'quit code';;
	12)	torunbasic=`echo $runcommand | awk -F' ' '{print $1}'`
#		echo 'run no arguments:' $torunbasic 
		$torunbasic		
		;;
esac
}
export -f filerun

function selectfiles
{
ret2=1
ret=1
while [[ $ret2 -eq 1 ]] && [[ $ret -eq 1 ]]; do
	selections=$(yad --title="Select Files"--window-icon="gtk-find" --center --form --separator="," \
		--date-format="%Y-%m-%d" \
		--field="Location":MDIR "/usr/share/applications/" --field="Filename" "gnome-m*.desktop" )
	ret=$?
	location=`echo $selections | awk -F',' '{print $1}'`  
	files=`echo $selections | awk -F',' '{print $2}'`  
#	echo $location $files

	#echo $selections
	#echo "ret:" $ret #This one returns 0 for OK button, 1 for cancel button
	if [[ $ret -eq 1 ]]; then # Cancel Selected
		yad --text="Are you sure?"
		ret2=$?
#		[[ $ret2 -eq 0 ]] && exit 1
		if [ $ret2 -eq 0 ]; then 
			exit 1
		fi 
	fi
done
}

#--------------------------------MAIN PROGRAM---------------------------------------------#
while [ $stop == "false" ]; do
if [ $fileedited -eq 0 ]; then
selectfiles #If a file has been edited, just reload the list of previous selection.
fi
cd $location
fileindex=0
comindex=0

for i in $( ls $files); do
	executable=$(cat "$i" |grep -v 'TryExec' |grep 'Exec' |grep -Po '(?<=Exec=)[ --0-9A-Za-z/]*')
	comment=$(cat "$i" |grep '^Comment=' |grep -Po '(?<=Comment=)[ --0-9A-Za-z/.]*')
	comment2=$(cat "$i" |grep '^GenericName=' |awk -F'=' '{print $2}' )
		if [[ $comment = "" ]]; then
			comment=$comment2
		fi	
	icon=$(cat "$i" |grep '^Icon=' |awk -F'=' '{print $2}')	
	mname=$(cat "$i" |grep '^Name=' |head -1 |awk -F'=' '{print $2}')


	fileindex=$(($fileindex + 1))
	desktopfiles["$fileindex"]=$i	
	filecomment["$fileindex"]=$comment
	fmn["$fileindex"]=$mname
	ficon["$fileindex"]=$icon	

	while IFS= read -r line; do
		comindex=$(($comindex + 1))
#		printf '%s\n' "$line" 	# this prints correctly.
		fileindex2=$(($fileindex * 10))
		echo "$fileindex2"
		echo "# $line" #| yad --progress --pulsate			# this also prints correctly! 
		commands["$comindex"]=$line
		if [[ "$comindex" -gt "$fileindex" ]]; then
#			echo 'comindex greater than fileindex'
			fileindex=$(($fileindex + 1))
			desktopfiles["$fileindex"]=$i
			filecomment["$fileindex"]=$comment
			fmn["$fileindex"]=$mname
			ficon["$fileindex"]=$icon
		fi
	done <<< "$executable"
done

#echo "command index last value:" $comindex
#echo "file index last value:" $fileindex
	
k=1

while [[ "$k" -le "$comindex" ]]; do
#	echo $k " -- " ${desktopfiles[$k]} " -- " ${commands[$k]} " -- " ${filecomment[$k]} " -- " ${fmn[$k]}
	list+=( "$k" "${ficon[$k]}" "${fmn[$k]}" "${desktopfiles[$k]}" "${commands[$k]}" "${filecomment[$k]}" ) #this sets double quotes in each variable.
	k=$(($k + 1))
done
#echo "list for yad:" "${list[@]}"

yad --list --title="Application Files Browser" --no-markup --width=1200 --height=600 --center --print-column=0 \
--select-action 'bash -c "yadlistselect %s "' \
--dclick-action='bash -c "filedisplay"' \
--button="Display":'bash -c "filedisplay"' --button="Edit":4 --button="Run":'bash -c "filerun"' \
--button="New Selection":2 --button=gtk-quit:1 --column "No" --column="Icon":IMG --column="Menu Name" \
--column "File" --column "Exec" --column "Description" "${list[@]}" 

btn=$?
#echo "button pressed:" $? "-" $btn
if [ $btn -eq 1 ]; then
stop="true" 
#Tip: Click on buttons with id , yad list exits. If list exits with button 1 then stop the loop
fi

if [ $btn -eq 2 ]; then
# if yad list exits with code 2 (new selection) then clear variables and go to the beginning!
unset list commands desktopfiles filecomment fmn
fileedited=0
fi

if [ $btn -eq 4 ]; then
fileedit #Call file edit function.
unset list commands desktopfiles filecomment fmn
fi
done
cd $now
 
# find / -name gnome-mines -type f -executable |egrep -v 'help|icon|locale'
# if you assign commands in buttons id , then yad list does not exit (unless you press cancel, id 0) but yad selected row is not parsed to external command/script
# --button="Display":'bash -c "filedisplay %s "' --> This one doesn't work in button, works only with --select-action. Also works on yad --form (using %1, %2, etc)
# If list is not given to yad as array but as a plain variable (i.e $list), is not working correctly.
# Typical yad list => yad --list --column "A" --column "B" DataA1 DataB1 DataA2 DataB2
# Strip the exec command of desktop file:=> executable=$(cat "$i" |grep -v 'TryExec' |grep 'Exec' |grep -Po '(?<=Exec=)[ --0-9A-Za-z/]*')
# cat $i = cat each file from ls. 
# grep -V means do not select lines containing TryExec (works like not operator) while grep Exec means select lines containing Exec
# grep -Po : -o means only. -P probably means Perl regex type. ?<= means Look forward after the literally given expression (Exec=)
# [ --0-9A-Za-z/]* what to select after Exec=. Equals to any character that bellongs in ranges :
# space to dash or A-Z or a-z or 0-9 or a single backslash / . Obviously two dashes bellong in range space to dash
# The asterisk works like a multiplier = multiple chars selection. if you ommit the * multiplier only one character will be selected after Exec=

# Alternative Strip :=> `grep '^Exec' filename.desktop | tail -1 | sed 's/^Exec=//' | sed 's/%.//'` &
# tail -1 get the last exec, sed 's dont get the arguments , & run in background


#	while read -r line
#	do
#    	name="$line"
#		name2=$(echo "${name:0:5}")		    	#this works. Returns five first chars of each line.
#		if [[ "$name2" = "Exec=" ]];then
#			echo "Name read from file: $name"
#			echo "command: ${name:5}" # This also works ok. gives the whole string after 5th character
#		fi
#	done < "$i"  
# the last line (done) is getting feeded by variable $i = current file in ls.
#  The above while read -r method is too slow. For one file i want some seconds, imagine all the desktop files to be opened for Exec commands to be extracted.

# http://tldp.org/LDP/abs/html/special-chars.html
# Endless loop:
#while :
#do
#   operation-1
#   operation-n
#done
# Bellow works ok, but you can not send to external command/script the --list selected row. 
# Button calls with yad selection is supported only in forms , using %N, where N is the number of the field to be parsed as argument to external command/scipt.
#yad --list --width=800 --height=600 --center --always-print-result \
#	--button="Display":"/home/gv/PythonTests/yadabout.sh" --button="Run":"bash -c yad_call" --button="Cancel":0  \
#	--column "ID" --column "File" --column "Exec" "${list[@]}"
# the end
