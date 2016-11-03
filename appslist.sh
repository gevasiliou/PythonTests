#!/bin/bash
#Great Tuto:http://smokey01.com/yad/
#

{ #Declarations
export TMPFILE=/tmp/yadvalues #obviously this creates a super global variable accesible from script and functions!
now=$(pwd) 
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
#echo "Received =" $0 " , " $1 " , " $2 " , " $3 " , " $4 " , " $5
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

function buildlist {
	readarray -t executable < <(cat "$i" |grep '^Exec' |grep -Po '(?<=Exec=)[ --0-9A-Za-z/]*')
	comment=$(cat "$i" |grep '^Comment=' |grep -Po '(?<=Comment=)[ --0-9A-Za-z/.]*')
	comment2=$(cat "$i" |grep '^Generic Name=' |grep -Po '(?<=Generic Name=)[ --0-9A-Za-z/.]*')
	icon=$(cat "$i" |grep '^Icon=' |grep -Po '(?<=Icon=)[ --0-9A-Za-z/.]*')	
	readarray -t mname < <(cat "$i" |grep '^Name=' |grep -Po '(?<=Name=)[ --0-9A-Za-z/.]*')
	# this method achieves 9.3 at home but goes to 60 secs at VBox!
		if [[ $comment = "" ]]; then
			comment=$comment2
		fi
#	printarray "${mname[@]}"

	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist2 {
	executable=$(cat "$i" |grep '^Exec' |awk -F'=' '{print $2}')
	comment=$(cat "$i" |grep '^Comment=' |awk -F'=' '{print $2}')
	comment2=$(cat "$i" |grep '^GenericName=' |awk -F'=' '{print $2}' )
	icon=$(cat "$i" |grep '^Icon=' |awk -F'=' '{print $2}')	
	mname=$(cat "$i" |grep '^Name=' |head -1 |awk -F'=' '{print $2}')
	# this one goes to 10,3@home
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist3 {
	readarray -t executable < <(grep -e '^Exec=' $i |awk -F'=' '{print $2}')
	readarray -t comment < <(grep -e '^Comment=' $i |awk -F'=' '{print $2}')
	readarray -t comment2 < <(grep -e '^Generic Name' $i |awk -F'=' '{print $2}')
	readarray -t mname < <(grep -e '^Name=' $i |awk -F'=' '{print $2}')
	readarray -t icon < <(grep -e '^Icon=' $i |awk -F'=' '{print $2}')
	# Multiple readarrays - multiple grep without awk 22-23 sec.
	# Multiple readarrays - multiple grep WITH awk 44 sec - 9 at home.
	# Using egrep and awk instead of grep : 51 sec at VB - ??? at home
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist4 {
	readarray foo < <(grep -e '^Exec=' -e '^Name=' -e '^Icon=' -e '^Comment=' -e '^Generic Name=' $i) 
	# Above line - grep with multiple expressions goes to 2 secs at home / 5 secs at VBox
	executable=""
	comment=""
	fname=""
	ficon=""
	generic=""	
	for ii in "${foo[@]}"; do
		foo1=$(echo "$ii" |awk -F'=' '{print $1}')
#		echo $foo1
		foo2=$(echo "$ii" |awk -F'=' '{print $2}')
#		echo $foo2	

		case $foo1 in
			"Exec") executable=$foo2
					#echo "exec=" $foo2
					;;
			'Comment') comment=$foo2
						#echo "comment=" $foo2
						;;
			'Name') mname=$foo2
					#echo "name=" $foo2
					;;
			'Generic Name') comment2=$foo2
							#echo "generic=" $foo2
							;;
			'Icon') icon=$foo2
					#echo "icon=" $foo2
					;;
		esac
		if [[ $comment = "" ]]; then
			comment=$comment2
		fi	
	done
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist5 {
	readarray foo < <(grep -e '^Exec=' -e '^Name=' -e '^Icon=' -e '^Comment=' -e '^Generic Name=' $i) 
	executable=$(grep -e 'Exec=' <<< "${foo[@]}")
	#echo $executable	
	comment=$(grep -e 'Comment=' <<< "${foo[@]}")
	mname=$(grep -e 'Name=' <<< "${foo[@]}")
	comment2=$(grep -e 'Generic Name=' <<< "${foo[@]}")
	icon=$(grep -e 'Icon=' <<< "${foo[@]}")
	#  Grep at $foo array is slower than grep directly each file (32 seconds VBox - 16secs @home)
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist6 {
	readarray foo < <(grep -e '^Exec=' -e '^Name=' -e '^Icon=' -e '^Comment=' -e '^Generic Name=' $i)
	#echo ${foo[@]}
	executable=$(echo "${foo[@]}" |awk -F'=' '/Exec=/{print $2}')
	#echo $executable
	comment=$(echo "${foo[@]}" |awk -F'=' '/Comment=/{print $2}')
	mname=$(echo "${foo[@]}" |awk -F'=' '/Name=/{print $2}')
	comment2=$(echo "${foo[@]}" |awk -F'=' '/Generic Name=/{print $2}')
	icon=$(echo "${foo[@]}" |awk -F'=' '/Icon=/{print $2}')
	#  Grep at $foo array is slower than grep directly each file (32 seconds VBox - 16secs @home)
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist7 {
	readarray -t executable < <(awk -F'=' '/^Exec=/{print $2}' $i)
	readarray -t comment < <(awk -F'=' '/^Comment=/{print $2}' $i)
	readarray -t comment2 < <(awk -F'=' '/^Generic Name=/{print $2}' $i)
	readarray -t mname < <(awk -F'=' '/^Name=/{print $2}' $i)
	readarray -t icon < <(awk -F'=' '/^Icon=/{print $2}' $i)
#	echo "Icon=" ${ficon[0]}	
	# With this alternative method (direct awk instead of grep pipe awk) i get ~ 29 sec VBox - 13 secs at home. 
	# It is strange that this method works much faster than cat + grep in Vbox (60secs), but in home  cat+grep works better (9 secs)
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist8 {
	readarray -t executable < <(grep "^Exec=" $i |cut -f 2 -d '=')
	readarray -t comment < <(grep "^Comment=" $i |cut -f 2 -d '=')
	readarray -t comment2 < <(grep "^Generic Name=" $i |cut -f 2 -d '=')
	readarray -t mname < <(grep "^Name=" $i |cut -f 2 -d '=')
	readarray -t icon < <(grep "^Icon=" $i |cut -f 2 -d '=')
#	echo "Icon=" ${ficon[0]}	
	# With this alternative method (direct awk instead of grep pipe awk) i get ~ 29 sec VBox - 13 secs at home. 
	# It is strange that this method works much faster than cat + grep in Vbox (60secs), but in home  cat+grep works better (9 secs)
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist9 {
	executable=$(grep "^Exec=" $i |cut -f 2 -d '=' |head -1)
	comment=$(grep "^Comment=" $i |cut -f 2 -d '=' |head -1)
	comment2=$(grep "^Generic Name=" $i |cut -f 2 -d '=' |head -1)
	mname=$(grep "^Name=" $i |cut -f 2 -d '=' |head -1)
	icon=$(grep "^Icon=" $i |cut -f 2 -d '=' |head -1)
#	echo "Icon=" ${ficon[0]}	
	# With this alternative method (direct awk instead of grep pipe awk) i get ~ 29 sec VBox - 13 secs at home. 
	# It is strange that this method works much faster than cat + grep in Vbox (60secs), but in home  cat+grep works better (9 secs)
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist10 {
	readarray -t executable < <(grep -Po '(?<=^Exec=)[ --0-9A-Za-z/:space:]*' $i)
	readarray -t comment < <(grep -Po '(?<=^Comment=)[ --0-9A-Za-z/:space:]*' $i)
	readarray -t comment2 < <(grep -Po '(?<=^Generic Name=)[ --0-9A-Za-z/:space:]*' $i)
	readarray -t mname < <(grep -Po '(?<=^Name=)[ --0-9A-Za-z/:space:]*' $i)
	readarray -t icon < <(grep -Po '(?<=^Icon=)[ --0-9A-Za-z/:space:]*' $i)
#	echo "Icon=" ${ficon[0]}	
	# With this alternative method (direct awk instead of grep pipe awk) i get ~ 29 sec VBox - 13 secs at home. 
	# It is strange that this method works much faster than cat + grep in Vbox (60secs), but in home  cat+grep works better (9 secs)
	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
}

function buildlist11 {
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
}


#--------------------------------MAIN PROGRAM---------------------------------------------#
while [ $stop == "false" ]; do
clear
if [ $fileedited -eq 0 ]; then
selectfiles #If a file has been edited, just reload the list of previous selection.
fi
cd $location
performance start

for i in $( ls $files); do
#	buildlist #		var = cat + grep + grep 							|57.4 at VBox 	| 9,16 at home
#	buildlist2 #	var = cat + grep + awk 								|76 at VBox 	| 11,6 at home
#	buildlist3 #	Readarray var = grep + awk							|47.5 at VBox 	| 8,9 at home
#	buildlist4 #	readarray = all greps and then var=for i in array	|100.6 at VBox 	| 31,6 at home
#	buildlist5 #	readarray = all greps and then var=grep array 		|50.3 at VBox 	| 18 at home
#	buildlist6 #	readarray = all greps and then var=echo array + awk	|57.2 at VBox 	| 12,5 at home
#	buildlist7 #	readarray var= Awk only								|43.2 at VBox 	| 12,5 at home
#	buildlist8 # 	readarray var = grep + cut							|47 at VBox		|6.9
#	buildlist9 # 	var=grep + cut + head -1							|53 at Vbox		|8.8
#	buildlist10 #	readarray var = one grep only  						|29.3 at Vbox(!)|11
	buildlist11 #	var=one grep only									|18.5 at Vbox(!)|12
done

performance stop
#exit 0

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
exit
{ #HowTos 
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


# Script Performance
# TimeStarted=$(date +%s.%N) --> The %s refers to seconds, the dot is literal, and the %N refers to nanoseconds
# TimeFinished=$(date +%s.%N)
# TimeDiff=$(echo "$TimeFinished - $TimeStarted" | bc -l)
# The trick $((var1-var2)) is not working in bash when vars include decimanl points; works only with integers - no decimals . Other shells (like zsh) support this operation.

# Script Run Time Results (SRT) for *.desktop in Vbox (1 cpu - 1.2 GB RAM)
# Using multiple cat , echos disabled = ~ 61 seconds (10 at home)
# Using grep with many patterns, and one if, no echos = ~73 second
# Using one grep with many patterns , no ifs, no echos, nothing = ~5 seconds! Bug is that if a pattern is not found, array is messed up.
# Using one grep - many patterns and just an array print = ~10 seconds.
# Using multi cats, no ifs, no echos, only variable=cat = ~60 seconds.
# Using multi greps , each assigned to it's array, no ifs, no echos = ~23 seconds.
# Using multi greps , each assigned to it's array, no ifs, no echos but WITH pipe to awk = ~48 seconds.
# Using multi arrays and multi direct awks instead of pipes, gives the correct result at 30 seconds.


#	Code for manipulating cases that we have more exec commands in one desktop file
#	fileindex=$(($fileindex + 1))
#	desktopfiles["$fileindex"]=$i	
#	filecomment["$fileindex"]=$comment
#	fmn["$fileindex"]=$mname
#	ficon["$fileindex"]=$icon	
#
#	while IFS= read -r line; do
#		comindex=$(($comindex + 1))
##		printf '%s\n' "$line" 	# this prints correctly.
##		fileindex2=$(($fileindex * 10))
##		echo "$fileindex2"
##		echo "# $line" #| yad --progress --pulsate			# this echo prints correctly, but yad progress is not operating 
#		commands["$comindex"]=$line
#		if [[ "$comindex" -gt "$fileindex" ]]; then
##			echo 'comindex greater than fileindex'
#			fileindex=$(($fileindex + 1))
#			desktopfiles["$fileindex"]=$i
#			filecomment["$fileindex"]=$comment
#			fmn["$fileindex"]=$mname
#			ficon["$fileindex"]=$icon
#		fi
#	done <<< "$executable"
##echo "command index last value:" $comindex
##echo "file index last value:" $fileindex
#	End of Manipulating Code	

# Super Fast Search Tips:

#time grep  "^Exec=" /usr/share/applications/*.desktop |cut -f 2 -d '=' (this is ~buildlist9)
#real	0m0.116s --- 0.074 (>/dev/null)
#user	0m0.012s --- 0.004
#sys	0m0.064s --- 0.032

#time grep  "^Exec=" /usr/share/applications/*.desktop |awk -F'=' '{print $2}'
#real	0m0.140s --- 0.109 (>/dev/null)
#user	0m0.012s --- 0.004
#sys	0m0.048s --- 0.048

#time awk  "/^Exec=/" /usr/share/applications/*.desktop
#real	0m0.427s --- 0.124 (>/dev/null)
#user	0m0.008s --- 0.028
#sys	0m0.096s --- 0.048

#time cat /usr/share/applications/*.desktop |grep '^Exec=' |grep -Po '(?<=Exec=)[ --0-9A-Za-z/]*'
#real	0m0.239s --- 0.193 (>/dev/null) 

#time grep '^Exec=' /usr/share/applications/*.desktop |grep -Po '(?<=Exec=)[ --0-9A-Za-z/]*'
#real	0m0.129s --- 0.095 (>/dev/null) 

#time readarray -t executable < <(grep "^Exec=" /usr/share/applications/*.desktop |cut -f 2 -d '=')
#real	0m0.141s


# Strange Speed Behaviors in VBox
#time grep  "^Exec=" /usr/share/applications/*.desktop  --> real 0.224
#time grep  "^Exec=" /usr/share/applications/*.desktop |cut -f 1-2 -d '=' --> real 0.150 (ps: using "cut -f 1-2" actually disables cut)

#more about cut : http://www.computerhope.com/unix/ucut.htm

} 
