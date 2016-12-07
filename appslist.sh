#!/bin/bash
#Great Tuto used: http://smokey01.com/yad/
#Script Made by George Vasiliou, October 2016, Greece
#

{ #Declarations
export TMPFILE=/tmp/yadvalues
stop="false"
selections=""
location=""
files="" 
fileedited=0
declare -g list
comindex=0
fileindex=1 #Could be required to be 0, depending on the method used.
#Declarations 
}

function yadlistselect { 
#echo "Args Received =" $0 " , " $1 " , " $2 " , " $3 " , " $4 " , " $5
echo -e "FILEID=\"$1\"\nFILENAME=\"$4\"\nFILECOMMAND=\"$5\"" > $TMPFILE
}
export -f yadlistselect

function filedisplay { 
source $TMPFILE
filetodisplay="$FILENAME"
ftd=$(yad --title="File Display-$filetodisplay" --width=800 --height=500 --center --text-info --filename=$filetodisplay --wrap --editable --button="Go Back":0)
}
export -f filedisplay

function fileedit  
{ 
source $TMPFILE
#echo "Args Received =" $0 " , " $1 " , " $2 " , " $3
filetoedit=$FILENAME
abb=$(yad --title="Edit File: $filetoedit" --width=800 --height=500 --center --text-info --filename=$filetoedit --wrap --editable \
--button=gtk-save:0 --button=gtk-save-as:10 --button="Go Back":1 --button=gtk-quit:3)
fileaction=$?
abbsaveas=$abb

case $fileaction in
0)  
	counter=1
	yad --title="Confirm Save" --center --text="Write Changes to $filetoedit?"
	retsave=$?
	if [[ $retsave -eq 0 ]]; then
		while IFS= read -r linenew; do
			if [ $counter -eq 1 ]; then
				echo $linenew > $filetoedit
			else
				echo $linenew >> $filetoedit 
			fi
		counter=$(($counter +1))
		done <<< "$abb"
	fi
	;;
3) yad --text="Are you sure?"
	ret2=$?
	if [ $ret2 -eq 0 ]; then exit 3; fi # this exits completely the whole script.
	;;
10) 
#	"Save As" Selected
	saveas=$(yad --center --file --filename=$filetoedit --save )
	countersa=1
	overwrite=0
	if [ $saveas = $filetoedit ]; then
		yad --title="OverWrite"--center --text="overwrite file?"
		overwrite=$?
	fi

	if [ $overwrite -eq 0 ];then
		while IFS= read -r linesaveas; do
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
		$torunfull
		;;
	11) echo 'quit code';;
	12)	torunbasic=`echo $runcommand | awk -F' ' '{print $1}'`
		$torunbasic		
		;;
esac
}
export -f filerun

function selectfiles
{
ret2=1
ret=1
#startingdir="/usr/share/applications/"
startingdir="/home/gv/Desktop/PythonTests/appsfiles/"
while [[ $ret2 -eq 1 ]] && [[ $ret -eq 1 ]]; do
#Multi Dir Solution (MDIR). Provides an icon to browse for directory
#	selections=$(yad --title="Select Files" --window-icon="gtk-find" --center --form --separator="," \
#		--date-format="%Y-%m-%d" \
#		--field="Location":MDIR "$startingdir" --field="Filename" "g*.desktop" )
#
#check box editable (CBE) solution 
	selections=$(yad --title="Select Files" --window-icon="gtk-find" --center \
				--form --separator="," --item-separator="," \
				--field="Location":CBE "/usr/share/applications/,/home/gv/Desktop/PythonTests/appsfiles/" \
				--field="Filename" "g*.desktop")
	ret=$?
	location=`echo $selections | awk -F',' '{print $1}' |sed 's![^/]$!&/!'`  
	files=`echo $selections | awk -F',' '{print $2}'`  
#echo "Selection= $selection"
echo "Full Path=$location$files"
#exit

	if [[ $ret -eq 1 ]]; then # Cancel Selected
		yad --text="Are you sure?"
		ret2=$?
		if [ $ret2 -eq 0 ]; then 
			exit 1
		fi 
	fi
done
}

function printarray {
arr=("${@}")
ind=0
	echo "Start of Array"	
	echo "Array[@]=" "${arr[@]}"
	for e in "${arr[@]}"; do
		echo "Array[$ind]=" $e
		ind=$(($ind+1))
	done
 	printf "End of Array\n\n"

}

function performance {

if [[ $1 == "start" ]]; then
declare -g TimeStarted=$(date +%s.%N)
declare -g Started="Yes"
echo "Time Started=" $TimeStarted
fi

if [[ $1 = "stop" ]] && [[ $Started="Yes" ]]; then 
declare -g TimeFinished=$(date +%s.%N)
declare -g TimeDiff=$(echo "$TimeFinished - $TimeStarted" | bc -l)
echo "Time Finished=" $TimeFinished
echo "Run Time= " $TimeDiff
fi
}


function buildlist8 {
	readarray -t executable < <(grep -m 1 "^Exec=" $i |cut -f 2 -d '=')
	readarray -t comment < <(grep -m 1 "^Comment=" $i |cut -f 2 -d '=')
	readarray -t comment2 < <(grep -m 1 "^Generic Name=" $i |cut -f 2 -d '=')
	readarray -t mname < <(grep -m 1 "^Name=" $i |cut -f 2 -d '=')
	readarray -t icon < <(grep -m 1 "^Icon=" $i |cut -f 2 -d '=')
	#echo "Icon=" ${ficon[0]}	
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist12 {
	IFS=$'\n'
	readarray -t fi < <(printf '%s\n' $i)
	readarray -t executable < <(grep  -m 1 '^Exec=' $i)
	readarray -t noexecutable < <(grep  -L '^Exec=' $i)
	readarray -t comment < <(grep -m 1 "^Comment=" $i )
	readarray -t nocomment < <(grep -L "^Comment=" $i )
	readarray -t comment2 < <(grep -m 1 "^GenericName=" $i )
#a	readarray -t nocomment2 < <(grep -L "^GenericName=" $i )
	readarray -t mname < <(grep -m 1 "^Name=" $i )
	readarray -t nomname < <(grep -L "^Name=" $i )
	readarray -t icon < <(grep -m 1 "^Icon=" $i )
	readarray -t noicon < <(grep -L "^Icon=" $i )
	#printarray ${nocomment[@]} #;exit
	printf "%s\n" "NoExec Items"
	for items1 in ${noexecutable[@]}; do
		executable+=($(echo "$items1"":Exec=None"))
	done

	for items2 in ${nocomment[@]}; do
		comment+=($(echo "$items2"":Comment=None"))
	done
	
#a	for items3 in ${nocomment2[@]}; do
#a		comment2+=($(echo "$items3"":GenericName=None"))
#a	done

	for items4 in ${nomname[@]}; do
		mname+=($(echo "$items4"":Name=None"))
	done

	for items5 in ${noicon[@]}; do
		icon+=($(echo "$items5"":Icon=None"))
	done

	sortexecutable=($(sort <<<"${executable[*]}"))
	sortcomment=($(sort <<<"${comment[*]}"))
#a	sortcomment2=($(sort <<<"${comment2[*]}"))
	sortmname=($(sort <<<"${mname[*]}"))
	sorticon=($(sort <<<"${icon[*]}"))

	trimexecutable=($(grep  -Po '(?<=Exec=)[ --0-9A-Za-z/]*' <<<"${sortexecutable[*]}"))
	trimcomment=($(grep -Po '(?<=Comment=)[ --0-9A-Za-z/]*' <<<"${sortcomment[*]}"))
#a	trimcomment2=($(grep -Po '(?<=GenericName=)[ --0-9A-Za-z/]*' <<<"${sortcomment2[*]}"))
	trimmname=($(grep -Po '(?<=Name=)[ --0-9A-Za-z/]*' <<<"${sortmname[*]}"))
	trimicon=($(grep -Po '(?<=Icon=)[ --0-9A-Za-z/]*' <<<"${sorticon[*]}"))
	
	
	#printarray ${fi[@]}
	#unset IFS

	ae=0
	for aeitem in ${fi[@]};do
		if [[ ${trimcomment[ae]} = "None" ]]; then
			trimcomment2=$(grep -m 1 "^GenericName=" $aeitem |cut -f 2 -d "=")
			trimcomment[ae]=$trimcomment2 #this method seems to be faster than grep + sort all the non existant values.
#a			trimcomment[ae]=${trimcomment2[ae]} 
		fi
		list+=( "$fileindex" "${trimicon[$ae]}" "${trimmname[$ae]}" "${fi[$ae]}" "${trimexecutable[$ae]}" "${trimcomment[$ae]}" ) #this sets double quotes in each variable.
		fileindex=$(($fileindex+1))
		ae=$(($ae+1))
	done
unset IFS
}

#--------------------------------MAIN PROGRAM---------------------------------------------#

while [ $stop == "false" ]; do
clear
if [ $fileedited -eq 0 ]; then
selectfiles #If a file has been edited, just reload the list of previous selection
fi
performance start

#for i in $(ls $location$files); do
#OR for i in $location$files; do 
#	buildlist8 # grep each file  with readarray < <(grep + cut)
#done
i=$location$files
buildlist12	#grep all files at once


performance stop

yad --list --title="Application Files Browser" --no-markup --width=1200 --height=600 --center --print-column=0 \
--select-action 'bash -c "yadlistselect %s "' \
--dclick-action='bash -c "filedisplay"' \
--button="Display":'bash -c "filedisplay"' --button="Edit":4 --button="Run":'bash -c "filerun"' \
--button="New Selection":2 --button=gtk-quit:1 --column "No" --column="Icon":IMG --column="Menu Name" \
--column "File" --column "Exec" --column "Description" "${list[@]}" 

btn=$?
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

rm -f $TMPFILE
exit
