#!/bin/bash

#    for dir in /home/gv/dir1/*/ ; do
#      echo $dir
#    done
#    for dir in /home/gv/dir1/* ; do
#      echo $dir
#    done
#    for dir in $(ls /home/gv/dir1/*/) ; do
#      echo $dir
#     done

function numcheck {
echo "Give a number:" && read var
#var=1

if [ "$var" -eq "$var" ] 2>/dev/null; then #if you ommit the 2>/dev/null then if you enter a worng value, bash will complain in your screen.
  echo number
else
  echo not a number
fi
}

#numcheck

#bc <<< "scale=2;$var1/$var2" or answer=$(bc <<< "scale=2;$var1/$var2")


function readlog1 {
finddivider () {
groups=$(bc <<< "scale=1;$NoOfLines/$1")
decimals=$(cut -f 2 -d "." <<<$groups)
}

readarray -O 1 FileContents < <(cat test.log)
NoOfLines=${#FileContents[@]}
divider=3 # initial setting
finddivider $divider

while [[ $decimals != "0" ]]; do
divider=$(($divider + 1))
finddivider $divider
done

if [[ $divider == $NoOfLines ]]; then
echo "No integer divider found. Default divider of 3 will be used".
divider=3
echo "Divider=" $divider
fi

for ((i=1;i<=$divider;i++)); do
echo $i ${FileContents[$i]} 
done

#readarray tt 
}

function fileread {
datasource=$(cat test.log)
while IFS='' read -r line; do
filename=$(cut -f 1 -d " " <<<$line)
contents=$(cut -f 2 -d " " <<<$line)
echo "$contents" > "$filename"
done <<< "$datasource" 
}

function importvars {
#import vars from file and use them in your prog
source ./a.txt
echo "value x=" $x
echo "value y=" $y
echo "value z=" $z
}

function filecount {
while read i; do
echo -e "$i:  \c" 
ls -Fall "$i" | wc -l
done < "b.txt"
}

function valreplcae {
optadd=13016
source=$(cat c.txt)
while IFS='' read -r line; do
sed -ie "0,/{OPTIONS}/ s/{OPTIONS}/{OPTIONS_$optadd}/" c.txt
optadd=$(($optadd + 2))
done <<< "$source" 
cat c.txt
}

function autoscript {
FILE=`readlink -f "${BASH_SOURCE[0]}"` #Gets current script filename
DIR=`dirname "${FILE}"` #Gets current script directory.
echo "File=$FILE - Dir = $DIR"

repl() {
    STRING=$(cat $DIR/d.txt) #read existed file d.txt
    STRING=$(echo "$STRING" | sed "s/%%NUMBER%%/$1/") #without double quotes the new line character is removed from $STRING
    echo "$STRING"
}
repl 50 > e.sh #send the output of repl function to a new file called e.sh
cat e.sh
exit
}

function fileinarray {
IFS=$'\n'
readarray -t -O1 data< <(grep -h -e "\^D" -e "\^A" -e "^F" a.txt)
posA=1
for i in "${data[@]}"; do
if [[ "$i" = "^A"* ]]; then
	textA="${data[$posA]}"
	posD=$posA
	posF=$posA
	textD=""
	textF=""
	while [ "$posD" -ge 1 ] && [[ "$textD" != "^D"* ]]; do
	posD=$(($posD - 1))
	textD="${data[$posD]}"
	done

	while [ "$posF" -le "${#data[@]}" ] && [[ "$textF" != "F"* ]]; do
	posF=$(($posF + 1))
	textF="${data[$posF]}"
	done
	textADF="$textA | $textD | $textF"
	echo "ADF=$textADF"
fi
posA=$(($posA + 1))
done
unset IFS
exit
}

function renamewithdirname {
#http://stackoverflow.com/questions/40645931/can-i-get-only-parent-directory-for-naming-to-filename-in-unix
#search for files, check existance and then appends to filename the last directory (i.e file a.zip is renamed to a_PythonTests.zip

WORKDIR="/home/gv/Desktop/PythonTests" #assigned for my case
find "$WORKDIR" -type f -name '*.zip' | while read file
do
  basename=$(basename "$file")
  dirname=$(dirname "$file")
  suffix=$(basename "$dirname")
  if [[ "$basename" != *"_${suffix}.zip" ]]; then
    mv -v "$file" "${dirname}/${basename%.zip}_${suffix}.zip"
  fi
done
# GV way - similar to above but working only for one file:
#dir="/home/gv/Desktop/PythonTests/"
#filename="a"
#filesuffix=".txt"
#filedir=$(dirname "$dir$filename$filesuffix" | grep -o '[^/]*$')
#echo "Directory of $filename$filesuffix : $filedir" 
#oldname="$dir$filename$filesuffix"
#ls -l $oldname
#echo "Old name : $oldname"
#echo -e "press any key \c";read anykey
#newname="$dir$filename""_""$filedir""$filesuffix"
#echo "New Name: $newname"
#mv "$oldname" "$newname" #this works ok
#find $dir -type f -name "$filename$filesuffix" -exec mv "$oldname" "$newname" \;
#ls -l /home/gv/Desktop/PythonTests/*.txt
}

function lettercheck { 
#reads lines from a file containing only one word per line, and checks if this word has duplicate chars in any position.
#To do this we store the line in an array of chars ($word) using the fold -w1 or grep -o . technique.
#to verify if the char exists in word we use the wc -w trick (count after grep - gives a number of 2 or n if char is found 2 or n times in word).
#
datasource=$(cat b.txt)
newdata=""
while IFS='' read -r line; do
found=0
readarray word < <(echo "$line" |fold -w1)
	for eachletter in ${word[@]}; do
		found=$(echo "$line" | grep -o $eachletter |wc -w)
		if [[ $found -ge 2 ]] && [[ ${newdata[@]} != *"$line"* ]]; then 
			newdata+=( "$line" )
		fi
	done
unset word eachletter found
done <<< "$datasource"
echo -e "New Data \n" 
printf '%s\n' ${newdata[@]}
# Alternative exercise : in a given string  find chars that are present only two times: 
# read -p "Data :" data;echo $data |grep -o . |sort |uniq -c |grep 2
# combine even with |egrep -o '[a-zA-Z]' at the end to remove number 2 from the grep 2 results.
# remove grep 2 and you will have a print out of counting all chars.

}

function simplenameread {
read -p "Enter Name: " name #mind the -p option (=prompt). i used to do it with echo -e "Enter Name\c";read name
if [ "$name" == "" ]; then
    sleep 1
    echo "Oh Great! You haven't entered name."
    exit
else
echo "You enter name $name"
fi
}

function comparetwofiles {
readarray data < <(comm --nocheck-order --output-delimiter "-"  b.txt c.txt)
for ((i=0;i<${#data[@]};i++)); do
va=$(grep -e "-" <<<"${data[$i]}")
if [[ $va == "" ]]; then
	echo ${data[$i]} " null"
elif [[ $va == "--"* ]]; then 
		data2=$(echo ${data[$i]} | grep -Po '[0-9]*')
		echo $data2 " " $data2
else
	data2=$(echo ${data[$i]} | grep -Po '[0-9]*')
	echo "null " $data2
fi
done

}

function listfilesindir {
#for files in /home/gv/Desktop/PythonTests/*.sh; do #this does not handle subfolders and files with spaces in their name
IFS=$'\n'
for files in $(find /home/gv/Desktop/PythonTests/ -name "*.txt" ); do
old_filename="$files"
old_filename_stripped=$(basename -a "$files")
echo "filename full : $old_filename - file name stripped: $old_filename_stripped"
done
unset IFS
# old_filename will look like this /user/***/documents/testmapa/afile.pdf
# If you need to have only the filename without directory}{/ then you can use
#old_filename=$(basename -a $files)
# this will result to old_filename=afile.pdf without directory info

#read -p "Press any key to rename file : $old_filename "

#your rest codes here
#done
}

function logicalduplicate {
#this one gets a text (or a line from file) and finds a logical duplicate line 
word1+=( $(echo "this is my life" |fold -w1) )
sortedword1=($(echo ${word1[@]} | tr " " "\n" | sort))
echo "${sortedword1[@]}"
echo "${sortedword2[@]}"

if [[ $sortedword1 == $sortedword2 ]]; then
echo "Word 1 and Word 2 are the same, delete one of them"
fi
}

function jointwofiles {
#based on the second field of file a.
#can also be done with join --nocheck-order -1 2 -t"|" a.txt b.txt
#mind the possible extra spaces in field 2 of file a

while IFS="|" read -r line title1 rest; do
title2=$(echo $title1)
genre=$(grep -e "$title2" b.txt |cut -f2 -d"|")
echo $line "|" $genre "|" $rest
done <a.txt
}

function extensions {
read -a extensions -p "give me extensions seperated by spaces:  " # read extensions and put them in array $extensions
for ext in ${extensions[@]}; do  #for each extension stored in the array
echo -e "- Working with extension $ext"
destination="/home/gv/Desktop/folder$ext"
#misc="/Users/christopherdorman/desktop/misc"
mkdir -p "$destination"
mv  -v unsorted/*.$ext "$destination";
done
#mv  -v unsorted/*.* "$misc"; 
# since previously you moved the required extensions to particular folders
# move what ever is left on the unsorted folder to the miscelanius folder

}

function Rename_Extensionless_Files {
#this looks for files without extension and adds .txt extension
IFS=$'\n'
direc="/home/gv/Desktop/PythonTests/"
for fi in $(find $direc -maxdepth 1 -type f -regextype egrep -regex "(^$direc)+[^.]*"); do
echo "File found: $fi"
mv -v "$fi" "$fi.txt"
done
unset IFS
#you can remove the maxdepth option to grab all files in subdirs.
#Same job can be done in one line much better like this:
#(http://unix.stackexchange.com/questions/313819/add-file-extension-to-files-that-have-no-extension)
#find . -type f  ! -name "*.*" -exec mv -v {} {}.txt \;
#OR
# find . -type f ! -name "*.*" -exec bash -c 'mv "$0" "$0".mp4' {} \;
#mind the ! operator (can be written also as -not) . 
#Actually find with ! operator finds files that their name does NOT match *.* format = extensionless files.

}

function splitword {
echo "Welcome"
read -p "Give me a word" resp
readarray letter < <(echo "$resp" |fold -w1)
for ((i=0;i<${#letter[@]};i++)); do
echo "letter[$i] : ${letter[$i]}"
done
}

function another_rename {
for file in *.txt
# rename files with name "a a (01).txt to "a a (001).txt" - file name containing spaces.
do 
number=$(grep -Eo '[0-9]*' <<<$file)
newname=$(sed "s/([0-9]*).txt/(0$number).txt/"<<<$file)
echo "old file = $file - new name=$newname"
mv "$file" "$newname"
done
ls -l *.txt
}

function trick_rename {
# This function handles filenames with spaces and renames them using mv (i.e file "a a (01<>).txx)
# The tricky assignment of mv commands replaces unwanted characters with a low dash _
find . -name "*.txx" |while read -r file ;do
bn=$(basename "$file")
dn=$(dirname "$file")
echo "Full Filename: $file - basename: $bn - Dirname: $dn"
#cp -v "$i" "/home/gv/Desktop/dtmp/$bn"
mv -v "$dn/$bn" "$dn/${bn//[\/<>:\\|*\'\"?]/_}"
done
}


# find /tmp -name '*.pdf' -or -name '*.doc' | xargs rm #mind the -or operator
# find . -type f  ! -name "*.*" -exec mv -v {} {}.txt \;
# find . -type f -name "*.txx" -exec bash -c 'mv -v "$0" "$0".mp4' {} \;
# find /dir1 -type f -printf "%f\n" #prints only file name, without directory in front.
# If printf is combined with -exec {} or bash -c $0, those variables still get the whole file name./ 
# printf is only used for print formating.
# for f in "$(find . -type f -name "*.txx" -printf '%f\n')";do echo "$f";done -> Works perfect even with spaces in filenames due to double quotes in find.

# find . -type f -name "*.txx" -exec bash -c 'mv -v "$0" "${0//[\/<>:\\|*\"?]/_}"' {} \; #this somehow worked but is mixing up directories.

# IFS=$'\n';startdir=$PWD;dr+=($(find $PWD -type d));for i in ${dr[@]}; do cd $i;for fl in *; do echo "Inside directpry $i i will mv : $fl to " "${fl//[\/<>:\\|*\'\"?]/_}";done;done;cd $startdir

function test {
IFS=$'\n'
dr+=($(find $PWD -type d))
for i in ${dr[@]};do 
	echo "--: $i"
	#read -p "press to enter $i"
	cd $i
	echo "Now you are on $PWD"
		for fl in *;do 
			echo "--Fl: $fl"
			echo "Inisde directory $i i will mv : $fl -" "${fl//[\/<>:\\|*\'\"?]/_}"
		done
	#read -p "Press a key to go on"
done
#Output : Inisde directory /home/gv/Desktop/PythonTests/appsfiles/temp i will mv : a b (02?<>).txx - a b (02___).txx

# Alternative
#for i in "$(find $PWD)";do echo "gonna mv $i -" "${i//[\/<>:\\|*\'\"?]/_}";done  
#This one will correctly list all files, but the {} expansion will also remove / from the whole path = folders name.
#gonna mv /home/gv/Desktop/PythonTests/?[{rec-r(<ui>)t.txx - _home_gv_Desktop_PythonTests__[{rec-r(_ui_)t.txx
#Seems mandatory to separate basename and dirname to avoid renaming / removing chars from the whole path.

#for i in $(find $PWD);do echo "gonna mv $i -" "$(dirname $i)/$(basename ${i//[\/<>:\\|*\'\"?]/_})";done  |grep -v "appsfiles" 
#gonna mv /home/gv/Desktop/PythonTests/?[{rec-r(<ui>)t.txx - /home/gv/Desktop/PythonTests/_home_gv_Desktop_PythonTests__[{rec-r(_ui_)t.txx

#for i in $(find $PWD);do bn=$(basename $i);echo "gonna mv $i -" "$(dirname $i)/${bn//[\/<>:\\|*\'\"?]/_}";done  |grep -v "appsfiles"
#gonna mv /home/gv/Desktop/PythonTests/?[{rec-r(<ui>)t.txx - /home/gv/Desktop/PythonTests/_[{rec-r(_ui_)t.txx

}

function case_menu {
while [ "$ch" != "4" ]
do
echo -e "1.System Information \n2.Calculation \n3.Server Configuration \n4.Exit"
read -p "Enter Your Choice " ch
case $ch in
1 )     while [ "$ch1" != "d" ];do
		echo -e " \t\t 1. System Information Menu"
		echo -e "a.Basic Information \nb.Intermedite Information \nc.All Information \nd.Exit from case \ne.Exit from program"
        read -p "Enter Your Choice" ch1
			case $ch1 in
			a ) echo "-->run basic information script";;
			b ) echo "-->run intermediate information script";;
			c ) echo "-->run allinformation script";;
			d ) echo "-->Exit from case";;
			e ) echo "-->Exit from program";;
			esac
        done
        ;;
2 )     echo "2. Calculation Menu"
		echo -e "a.Addition \nb.Subtraction \nc.multiplication \nd.Exit from case \ne.Exit from program"
        read -p "Enter your Choice " ch2
        case $ch2 in
        a ) echo "-->run add_numbers script";;
        b ) echo "-->run sub_numbers script";;
        c ) echo "-->run mul_numbers script";;
        d ) echo "-->Exit from Loop";;
        e ) echo "-->Exit from program";;
        * ) echo "-->Please enter correct choice";;
        esac
        ;;
3 ) echo "3. Server Menu";;
4 ) echo "4. Exiting "
	exit ;;
* ) ;;
esac
done
}

function simple_case_loop {
while [ "$ch1" != "d" ];do
	echo -e "a.Basic Information \nb.Intermedite Information \nc.All Information \nd.Exit from case \ne.Exit from program"
	read -p "Enter Your Choice  : " ch1
	case $ch1 in
		a ) echo "-->run basic information script";;
		b ) echo "-->run intermediate information script";;
		c ) echo "-->run allinformation script";;
		d ) echo "-->Exit from case";;
		e ) echo "-->Exit from program"
			exit;;
		* ) echo "Wrong Selection - Try Again"
	esac
done
echo "Command X: This is command X after the case"
}

function menu_with_select {
IFS=$'\n'
op=( "Basic Information" "Intermedite Information" "All Information" "Exit from case" "Exit from program" )
select ch1 in ${op[@]}; do
echo "ch1 = $ch1"
	case $ch1 in																		#or case $ch1 in
			"Basic Information" ) 		echo "-->run basic information script";; 		#${op[0} )....;;
			"Intermedite Information" ) echo "-->run intermediate information script";; #${op[1} )....;;
			"All Information" ) 		echo "-->run allinformation script";; 			#${op[2} )....;;
			"Exit from case" ) 			echo "-->Exit from case" 						#${op[3} )....;;
										break;;
			"Exit from program" ) 		echo "-->Exit from program" 					#${op[4} )....;;
										exit;;
			* ) 						echo "Wrong Selection - Try Again"
	esac																				#esac
done
echo "Command X: This is command X after the menu"
}

function ifargisinteger {
for i in $@;do
if [ "$i" -eq "$i" ] 2>/dev/null #makes use of -eq operator suitable to compare numbers in bash
then
    echo "$i is an integer !!"
else
    echo "ERROR: not an integer."
fi
done
}

function ifargisnumber {
for i in $@;do
if [[ "$(bc <<< "scale=2; $i/$i")" == "1.00" ]] 2>/dev/null;then
    echo "$i is a number and thus is accepted"
else 
	echo "Argument $i not accepted"
fi
done
}

function copy_duplicate_files { 
echo "Folder A"
ls -l ./foldera/
echo "Folder B"
ls -l ./folderb/
echo "Folder C"
ls -l ./folderc/
read -p "Press any key to start"
duplicates=( "$(find foldera folderb -type f -exec basename {} \; |sort |uniq -d)" ) #uniq -d gives you only duplicate files by default
for file in ${duplicates[@]}; do
cp  "./foldera/$file" "./folderc/$file"
done
echo "Script Finish. Folder C"
ls -l ./folderc/
}

function concatenate_ids {
header=$(head -1 a.txt) #get the 1st line and store it as header.
readarray -t ids< <(awk -F" " '{print $1}' a.txt |uniq |tail -n+2) #tail helps to exlude the header. Uniq just prints ids once.
echo "$header"
for id in ${ids[@]}
do
data=($(grep $id a.txt))
echo -e "${data[0]}\t${data[1]}\t${data[2]}\t${data[-1]}"
done 
# Target : Group Ids and keep start and End time of each IT
# cat a.txt
#Id       Chr     Start   End  
#Prom_1   chr1    3978952 3978953  
#Prom_1   chr1    3979165 3979166  
#Prom_1   chr1    3979192 3979193  
#Prom_2   chr1    4379047 4379048  
#Prom_2   chr1    4379091 4379092  
#Prom_2   chr1    4379345 4379346  
#Prom_2   chr1    4379621 4379622  
#Prom_3   chr1    5184469 5184470  
#Prom_3   chr1    5184495 5184496 
#
# readarray -t ids< <(awk -F" " '{print $1}' a.txt |uniq |tail -n+2);declare -p ids
# Output --> declare -a ids=([0]="Prom_1" [1]="Prom_2" [2]="Prom_3")
# id="Prom_1";data=($(grep $id a.txt));declare -p data
#Output --> declare -a data=([0]="Prom_1" [1]="chr1" [2]="3978952" [3]="3978953" [4]=$'\nProm_1' [5]="chr1" [6]="3979165" [7]="3979166" [8]=$'\nProm_1' [9]="chr1" [10]="3979192" [11]="3979193")
# Mind the difference of data=(...) and readarray -t.
# readarray is good for the jobe when fields are separated by new lines.
# data=(..) or declare -a data assigns to different index any value separated by spaces and new lines. 
# mind also the use of declare -p data which prints nice the array in terminal
}

function timestamp_check {
#http://unix.stackexchange.com/questions/331610/print-statistics-of-a-text-file/331618#331622
#Find if in one minute of a log file you have more than 60 events.
readarray -t stamps < <(awk -F" " '{print $2,$3;}' c.txt |cut -f1-2 -d: |sort |uniq)
for stamp in "${stamps[@]}";do
ev=$(grep "$stamp" c.txt |wc -l)
echo "In $stamp found $ev events "
#if [ "$ev" -gt 60 ]; then
#echo "In $stamp found $ev events "
#fi
done

# Alternative Solution: 
# awk '{ print $2,$3;}' c.txt |cut -c1-16 |sort |uniq -c |awk '{ if ($1 > 60) print $2 }' #time performance half of timestamp_check()
# If you need to count, instead of grep + wc -l you can do it directly with awk-cut-sort-uniq -c. Uniq -c will not count correctly if file is not sorted.
#cat c.txt
#RepID12 01/01/2010 20:56:00 S10
#RepID12 01/01/2010 20:56:00 S03
#RepID20 01/01/2010 20:56:00 S17
#RepID33 01/01/2010 20:56:00 S02
#RepID33 01/01/2010 20:56:00 S18
#RepID38 01/01/2010 20:56:00 S11
#RepID39 01/01/2010 20:56:00 S20
#RepID26 02/01/2010 01:39:00 S20
#RepID29 02/01/2010 01:39:00 S16
#RepID29 02/01/2010 01:39:00 S03
#RepID22 02/01/2010 01:39:09 S01
#RepID26 02/01/2010 01:39:09 S02
#RepID40 02/01/2010 01:39:18 S02
#RepID38 02/01/2010 01:39:09 S05
#RepID31 02/01/2010 01:39:09 S06
#RepID31 02/01/2010 01:39:09 S08
#RepID09 02/01/2010 01:39:09 S09
#RepID23 02/01/2010 01:39:18 S09
#RepID19 02/01/2010 01:40:09 S09
#RepID21 02/01/2010 01:40:18 S09
#RepID28 02/01/2010 01:40:27 S09
#RepID43 02/01/2010 01:40:09 S14
#RepID12 02/01/2010 20:56:00 S10
#RepID12 02/01/2010 20:56:00 S03
#RepID20 02/01/2010 20:56:00 S17
#RepID33 02/01/2010 20:56:00 S02
#RepID33 02/01/2010 20:56:00 S18
#RepID38 02/01/2010 20:56:00 S11
#RepID39 02/01/2010 20:56:00 S20
}


function grep_by_custom_column {
header=$(head -1 b.txt)
read -p "Field Number" fld
readarray -t countries< <(cut -f "$fld" -d":" b.txt |uniq |tail -n+2) #tail helps to exlude the header. Uniq just prints ids once.
for country in ${countries[@]}
do
echo "$header" >> data_"$country"_.log
grep $country b.txt >> data_"$country"_.log
break #using break i can allow loop to run only one time.
done 
}

function just_numbers {
read -p "Give me num1:" num1
read -p "Give me num2:" num2
if (($num1==0)) || (($num2==0))
#if ( $num1 -eq 0 ) || ( $num2 -eq 0 ) #Shellcheck gives no error for this syntax but my bash complains 
then 
	echo "One of the numbers given is zero. Exiting now..."
	exit
else 
	echo "num1 + num2 = $((num1+num2))" #as advised by shellcheck.net you can ommit $ inside double parenthesis for numbers
	echo "num1 - num2 = $((num1-num2))"
	echo "num1 * num2 = $((num1*num2))"
	echo "num1 / num2 = $((num1/num2))"
	echo "num1 + num1 * num2 = $((num1+num1*num2))" 
	echo "num1 + num1 * num2 = $(($num1+$num1*$num2))" #Just for testing that result is same as in previous example (no dollars)
fi
}

function gitignore {
#http://stackoverflow.com/questions/41608860/find-all-files-recursively-which-are-not-in-an-exclude-file/41624862#41624862
args=()
while read -r pattern; do
  [[ ${#args[@]} -gt 0 ]] && args+=( '-o' )
  [[ $pattern == */* ]]   && args+=( -path "./$pattern" ) || args+=( -name "$pattern" )
done < .ignore

find . -name '*.js' ! \( "${args[@]}" \)	

function heredocs {
	
l="line 3"
read -p "press any key:" k
cat <<End-of-message
-------------------------------------
	This is line 1 of the message.
This is line 2 of the message.
This is $l of the message.
This is line 4 of the message.
This is the last line of the message.
$k
-------------------------------------
End-of-message


variable=$(cat <<SETVAR
This variable
runs over multiple lines.
SETVAR
)

echo "$variable"
}
# gv solution that fails under circumstances: find . -name '*.js' | grep -vEf .ignore (or -vE "$(cat .ignore)")
# .ignore contents:
# *.min.js
# directory/directory2/* (i applied foo/bar/*)
# directory/file_56.js (i applied tmp/file_56.js)

# problems with grep solution in GV answer:
# 1. If you apply rule foo/bar/* this will also exclude find results from /anotherdir/foo/bar/* or even from foo/barrage/ directory
# 2. If you apply rule /tmp/file_56.js	and you have also a directory called /sometmp/file_56.js , even the sometemp dir will be excluded.
# 3. This file is excluded and it should not be excluded by the rules applied: a@min@js.js
}


function adding_agrs {
if [[ $# -lt 1 ]]
then
        echo "Please input a valid amount of numbers. Need at least one."
        exit 1
else
        n=$#
        sum=0
        for arg in "$@"
        do
          echo "arg=$arg"
          sum=$(($sum+$arg))
        done
fi

echo "sum=$sum"
echo "number of parameters=$n"
}


function adding_args_with_shift {
if [[ $# -lt 1 ]]
then
        echo "Please input a valid amount of numbers. Need at least one."
        exit 1
else
        n=$#
        sum=0
        while [[ $# -ne 0 ]];
        do
          echo "arg=$1"
          sum=$(($sum+$1))
          shift
        done
fi

echo "sum=$sum"
echo "number of parameters=$n"
}

function extension_checker {
	for file in "$1"/*;do
		if [[ "$file" =~ \.(c|cpp|h|cc)$ ]]; then
			echo "hello"
		fi
	done

# =~ is considered a REGEX operator. Above if code checks for file with extension c or cpp or h or cc.
#
}

function dir_byte_checks {

if [[ ! -d $1 ]]
then
    echo usage: ./activity.sh directory
elif [[ $# -gt 1 ]]
then
    echo usage: ./activity.sh directory
else
# find the active files (last 24 hrs)
a=($(find $1 -mtime -1))
# find recent files (between 24 hrs-3 days)
b=($(find $1 -mtime 1 -o -mtime +1 -a -mtime -3))
# find idel files (before 3 days)
c=($(find $1 -mtime 3 -o -mtime +3))

# hold numbers of files
x=0
y=0
z=0
# byte count, active, recent, and idle files
count1=0
count2=0
count3=0

# number of active files and adds bytes
for i in ${a[@]}
do
    if [[ -f $i ]]
    then
        ((count1+=$(wc -c $i | cut -f1 -d' ')))
        let x++
    fi
done

# number of recent files and adds bytes
for i in ${b[@]}
do
    if [[ -f $i ]]
    then
        ((count2+=$(wc -c $i | cut -f1 -d' ')))
        let y++
    fi
done

# number of idle files and adds bytes
for i in ${c[@]}
do
    if [[ -f $i ]]
    then
        ((count3+=$(wc -c $i | cut -f1 -d' ')))
        let z++
    fi
done

# output
echo $1 
echo active: $x "("$count1 "bytes)"
echo recent: $y "("$count2 "bytes)"
echo idle: $z "("$count3 "bytes)"
fi

exit

}

set -vx
function onac {
	onpower=$(upower -i /org/freedesktop/UPower/devices/line_power_AC |grep online |awk -F " " '{print $NF}')
[[ "$onpower" == "yes" ]] && ret=0 || ret=1
}

http://askubuntu.com/questions/69556/how-to-check-battery-status-using-terminal
while inotifywait -e modify /sys/class/power_supply/BAT0/status; do
#your code here
done
inotifywait -e create /path/to/watch
echo "ding!" #will ding when a file or directory gets created in that path.


while : ;do
onac &
sleep 10
done

while [[ $ret -eq 1 ]]; do
echo "keep going"
sleep 5
done
