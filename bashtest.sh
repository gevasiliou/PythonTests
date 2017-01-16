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


# VARIOUS HOW TO
# Cool way to cat/view files using GTK3 libs and not get lost in terminal lines:
# for f in /etc/apt/apt.conf.d/*;do echo $f;a=$(cat $f |yt --title="$f");done #where yt is an alias yt='yad --text-info --center --width=800 --height=600 --no-markup --wrap'
# It is nice that although we have an alias of yad with some flags , by calling yt with more flags those are also passed to yad.
# Another cool alias could be => alias catg=''yad --text-info --center --width=800 --height=600 --no-markup --wrap <<<$(cat $1)' , where $1 could be an arg passed to alias.
# But alias do not handle args. So is better to do it a separate script with name catg. putit in /usr/bin , chmod it to +x and you will be able to launch it from everywhere just like catg file
# See the mang script that does similar job

# Run a command as a different user : gksu -u gv command. Usefull if you are in root terminal and want to execute i.e google-chrome-stable
# Print environmental variables : export -p , printenv or just env, ( set -o posix ; set ) , declare -p (or -xp)
# One line if check : This is based to the operation of && which executes the next command only if previous command exit with 0 = succesfull exit = pseudocode as TRUE (if it maybe the only time that something with value zero is translated to true!)
# For else conditions or for performing actions under false conditions you can use ! operator (not) in front of expression which will reverse exit code.
# [ "$USER" = "root" ] && echo "hello root" -> hello root # displays nothing if user is not root
# [ "$USER" = "root" ]  || [ "$LOGNAME" = "root" ] && echo "hello root" --> hello root #
# [ "$USER" = "root" ]  || [ "$LOGNAME" = "root" ];echo $? -> 0 #zero = all ok = true
# [ "$USER" = "root" ]  || [ "$LOGNAME" = "rot" ];echo $? -> 0 #zero = all ok = true due to the OR operator || (for and you should use &&)
# [ "$USER" = "rot" ]  || [ "$LOGNAME" = "rot" ];echo $? --> 1 #one = not ok = false since i'm logged in as root and not rot
# ! [ "$USER" = "rot" ]  || ! [ "$LOGNAME" = "rot" ];echo $? --> 0  #expression ok = true means that it is true that i'm not user rot or logname rot (true since i'm logged in as root)
# When you gksu terminal from normal user account then $USER and $LOGNAME are set to root.

# Run Google Chrome as Root : http://unix.stackexchange.com/questions/175967/how-to-run-google-chrome-as-root-in-linux/332128#332128
# Easy trick : gksu -u gv google-chrome-stable - works fine either by root terminal or by root login

# Check out the split prog which can split a file to more files based on certain criteria (i.e from line N to line M)
# Check if a slash '/' exist in the end of variable and add it if it is missing
# root@debi64:/home/gv/Desktop/PythonTests# echo "/home/gv/Desktop" |sed 's![^/]$!&/!'
# /home/gv/Desktop/

# multi grep with reverse operation : grep -v -e "pattern" -e "pattern"
# grep -nA1 -e "====" c.txt |grep -B1 -e "====" |grep -v -e ":" -e "--"

# sed: http://stackoverflow.com/questions/83329/how-can-i-extract-a-range-of-lines-from-a-text-file-on-unix
# get a range of lines with sed: sed -n '16224,16482p;16483q' filename
# mind the 16483q command. Instructs sed to quit. Without this , sed will keep scanning up to EOF.
# To do that with variables: $ sed -n "$FL,$LL p" file.txt

# sed -n '/WORD1/,/WORD2/p' /path/to/file # this prints all the lines between word1 and word2
# There is a direct awk alternative: awk '/Tatty Error/,/suck/' a.txt
# you can get line numbering if you first cat -n the file , but you will need an extra pipe for that.

# Find a word in file/stdin and grep from this word up to the last \n = new line = eof.
# Remember that $ represents "last"-end of line in regex
# apt show xfce4-wmdock* |sed -n '/Description/,/$\/n/p'
# You can do the same starting from a line up to eof. 
# Also this should work sed -n '/matched/,$p' file , wher matched can be a line number or a string

# Replace a string with s/ switch
# sed  -n 's/Tatty Error/suck/p' a.txt # This one replaces Tatty Error with word suck and prints the whole changed line
# echo "192.168.1.0/24" | sed  -n 's/0.24/2/p' 
# More Sed replace acc to http://unix.stackexchange.com/questions/112023/how-can-i-replace-a-string-in-a-files
# Replace foo with bar only if there is a baz later on the same line:
# sed -i 's/foo\(.*baz\)/bar\1/' file #mind the -i switch which writes the replacement in file (-i = inplace).
# Multiple replace operations: replace with different strings
# You can combine sed commands: sed -i 's/foo/bar/g; s/baz/zab/g; s/Alice/Joan/g' file #/g means global = all matches in file
#
# Replace any of foo, bar or baz with foobar : sed -Ei 's/foo|bar|baz/foobar/g' file

# Trick to get only one line from file using head and tail
# Usage: bash viewline myfile 4
# head -n $2 "$1" | tail -n 1
#
# ls alternatives
# find /home/gv -maxdepth 1 -type d -> list only directories
# find /home/gv -maxdepth 1 -type f -> lists only files
# find /home/gv -maxdepth 1 -> lists both
# output of find can be piped to wc -l as well.
#
# More Text Replace with sed
# Consider file containing:
# ltm node /test/10.90.0.1 {
#    address 10.90.0.1
#}
# 1. Let's suppose you want to add at the end of address %200
# sed '/address/ s/$/%200/' a.txt
# s = replace, $= end of line
# Alternatives
# str="address 10.90.0.1";newstr=$(awk -F"." '{print $1"."$2"."$3"."$4"%200"}'<<<$str);echo $newstr 
# awk '/address/ && sub("$","%200") || 1' file.txt
#
# 2. Lets suppose you want to replace the last digit with .20
# sed '/address/ s/.[0-9]*$/.20/' a.txt
# .[0-9]*$ = regex = starts with dot, contains numbers in range 0-9, multiple numbers (*) and then EOL ($)
# alternatives
# str="address 10.90.0.1";newstr=$(awk -F"." '{print $1"."$2"."$3".20"}'<<<$str);echo $newstr

# Use a variable in sed
# You just need to double qute the sed actions instead of single quotes.

# Search for a process using top . Top seems to catch all processes:
# top -p $(echo $(pgrep time) |sed 's/ /,/g')
# pgrep search for processes matching pattern even partially. pidof could be used if exact process name is known.
# Defaut output of pgrep is to seperate processes found with new lines. By echo \n is removed and a space is used.
# If you replaace that space with a comma, then can be fed to top -p which accepts multiple pids (comma seperated)

# Comparing files and variables:
# diff can compare two files line by line.
# You can also trick use diff like this to compare two variables line by line : diff <(echo "$a") <(echo "$b") or diff <(cat <<<"$a") <(cat <<<"$b")

# Processes List and Kill
# ps all and ps aux
# list all of tty1 : ps -t tty1
# Isolate pids: ps -t tty1 |cut -d" " -f1
# Remove new line chars: ps -t tty1 |echo $(cut -d" " -f1)
# Kill all those processes at once: kill -9 $(ps -t tty1 |echo $(cut -d" " -f1)) # kill requires pids to be seperated by spaces, not new lines.
#Best Solution : kill -9 $(echo $(ps -t tty1 --no-headers -o pid))


#List and Manipulating files with strange names.
#Consider files with spaces in their name (i.e a a (01).txx)

#In order you want to get the basename of this file the following command fails:
#for file in "$(find . -name "*.txx")";do basename "$file";done
#But if you just type find . -name "*.txx" files will be listed correctly.
#Also this command works ok: for file in "$(find . -name "*.txx")";do echo "$file";done
#Mind the double quotes outside $(find...)

#To correctly handle file names with spaces you need to combine find with  while read.
#This works ok: find . -name "*.txx" |while read -r line;do basename "$line";done

#Also this works ok , and it is more simple to use: for file in *.txx;do basename "$file";done
#The problem here is that this method doesn't go inside subdirs, while the find method does.
#http://stackoverflow.com/questions/4638874/how-to-loop-through-a-directory-recursively-to-find-files-with-certain-extension
#http://www.commandlinefu.com/commands/view/14209/repeat-any-string-or-char-n-times-without-spaces-between
#http://wiki.bash-hackers.org/syntax/expansion/brace
#http://stackoverflow.com/questions/2372719/using-sed-to-mass-rename-files
#linux   /boot/vmlinuz-4.0.0-1-amd64 root=UUID=5e285652 ro  quiet text

# BASH MANUAL : http://tiswww.case.edu/php/chet/bash/bashref.html#SEC31 - Search for "replace"
# BASH HACKERS EXAMPLES / PARAMETER EXPANSION , ETC: http://wiki.bash-hackers.org/syntax/pe
# ADVANCED BASH SCRIPTING : ftp://ftp.monash.edu.au/pub/linux/docs/LDP/abs/html/abs-guide.html#PIPEREF
# IO REDIRECTION: http://tldp.org/LDP/abs/html/io-redirection.html
# https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
# http://ss64.com/bash/expr.html
# https://debian-administration.org/article/150/Easily_renaming_multiple_files

# a="this is some TEXT"; echo ${a: -10} 	-> some TEXT
# a="this is some TEXT"; echo ${a: 10} 		-> me TEXT
# a="this is some TEXT"; echo ${a: 5:7} 	-> is some
# a="/home/gv/Desktop/PythonTests/a<>rte.zip";echo $(basename ${a/<>/_}) 	->a_rte.zip
# a="/home/gv/Desktop/PythonTests/a<>rte.zip";echo ${a#/} 					-> removes only the first / 
# a="/home/gv/Desktop/PythonTests/azip<>rte.zip";echo ${a%.zip} 			->removes the last .zip (but not middle zip) 
# basename c.jpg .jpg -> c
# basename c.jpg pg -> c.j #basename can be used as a tricky tool to remove chars from the end of ANY string but requires exact match
# a="logfiletxt";basename $a txt -> logfile
# a="logfile.txt";echo ${a/.txt} -> logfile #similar to basename but match starts from 1st char to the last. 1st occurence to be removed.
# a="logfile.txt";echo ${a/fil} -> loge.txt #remove fil - exact match
# a="logfilefilo.txt";echo ${a/lo} -> gfilefilo.txt #only first occurence of exact pattern removed
# a="logfilelofi.txt";echo ${a/lo} -> gfilelofi.txt #only first occurence of exact pattern removed
# a="logfilelofi.txt";echo ${a//lo} -> gfilefi.txt #all occurences of exact pattern removed.
# a="logfilelofi.txt";echo ${a/lf/_} -> logfilelofi.txt #no replacement made since lf is not present in $a (exact match)
# a="logfilelofi.txt";echo ${a//[lf]/_} -> _og_i_e_o_i.txt #all occurences of l and f - not exact match due to [] regex synthax
# a="logfilelofi.txt";echo ${a/*l/_} -> _ofi.txt #from start up and including last l
# a="logfilelofi.txt";echo ${a/*g/_} -> _filelofi.txt #from start up & including last g
# a="logfilelofi.txt";echo ${a/*l/} -> ofi.txt #from start up to last l (if no replace string is specified then delete)
# a="logfilelofi.txt";echo ${a/#/_} -> _logfilelofi.txt #replace first char with underscore
# a="logfilelofi.txt";echo ${a/%/_} -> logfilelofi.txt_ #replace last char with underscore
# a="logfilelofi.txt";echo ${a/.txt/_} -> logfilelofi_ #replace .txt with underscore
# a="logfilelofi.txt";echo ${a/.txt} -> logfilelofi #delete .txt
# MYSTRING=xxxxxxxxxx;echo ${MYSTRING/#x/y}  # RESULT: yxxxxxxxxx # Here the sign # is like an anchor to beginning
# MYSTRING=xxxxxxxxxx;echo ${MYSTRING/%x/y}  # RESULT: xxxxxxxxxy # Here symbol % is an anchor to the end of string
# a="logfilelofi.mp3";echo ${a/.[a-z0-9A-Z]*/} -> logfilelofi #delete any extension with a dot and any of a-z,0-9 and A-Z range
# CLIP=$'http://abc\".x\'y`.com';cleanclip=$(echo ${CLIP//[\'\`\"]});echo $cleanclip ->http://abc.xy.com #mind the special var declaration of CLIP.
# for i in *.JPG; do mv "$i" "${i/.JPG}".jpg; done -> finds files with JPG extension and renames them to .jpg
# a="/home/gv/Desktop/PythonTests/a?<>rt*eew?.zip";echo $(basename ${a//[\/<>:\\|*\'\"?]/_}) 	-> _home_gv_Desktop_PythonTests_a___rt_eew_.zip
# bash manual: ${parameter/pattern/string} . If pattern begins with ‘/’, all matches of pattern are replaced with string. Normally only the first match is replaced. If pattern begins with ‘#’, it must match at the beginning of the expanded value of parameter. If pattern begins with ‘%’, it must match at the end of the expanded value of parameter.
# bash manual command substitution: Command $(cat file) can be replaced by the equivalent but faster $(< file).

# a="somefile.txt";echo ${a%%.txt} -> somefile #delete from end exact match
# a="somefile.txt";echo ${a%.txt} -->somefile
# a="sometxtfile.txt";echo ${a%txt} -->sometxtfile. #delete from end only exact match. midle txt is not deleted.
# a="sometxtfile.txt";echo ${a##txt} --> sometxtfile.txt #no valid -no effect 
# a="sometxtfile.txt";echo ${a##some} --> txtfile.txt #delete pattern (xact match) from the beginning
# a="sometxtfile.txt";echo ${a#some} --> txtfile.txt
# a="sometxtfile.txt";echo ${a#txt} --> sometxtfile.txt #no effect . there is no "txt" in the beginning.
# a="Be conservative in what you send";echo ${a#* } --> conservative in what you send ("Be" is deleted. Single # removes the first word from beginning)
# a="Be conservative in what you send";echo ${a##* } --> send #All text deleted except "send" Double ## removes all words from beginning except last
# a="this.is.a.file.gz";echo ${a##*.} -->gz #all text deleted except last part (DOT separated)
# a="apt";echo ${a:0:1} --> a #prints the first character of a variable (from zero give me 1)
# a="Be conservative in what you send";echo ${a% *} --> Be conservative in what you #first word from end deleted. 
# a="Be conservative in what you.send";echo ${a% *} --> Be conservative in what #works only for space separated words (IFS makes some effect in the resulted text)
# a="Be conservative in what you send";echo ${a%% *} --> Be #all words from the end deleted (space separated)

# a="some text here";echo ${a@Q} ->'some text here' #printing with single quotes
# a="some text here";echo ${a@A} -> a='some text here' #operators available Q-E-P-A-a
# a[0]="some text";a[1]="more text";echo ${a[@]} -> some text more text
# a[0]="some text";a[1]="more text";echo ${a[@]@A} ->declare -a a=([0]="some text" [1]="more text")
# a[0]="some text";a[1]="more text";echo ${a[@]@Q} ->'some text' 'more text'
# a[0]="some text";a[1]="more text";a[2]="much more text";echo ${!a[@]} -> 0 1 2 #index of elements . This can be used in for i in ${a![@]} - i will be 0 , 1, 2 
# a[0]="some text";a[1]="more text";a[2]="much more text";echo ${#a[@]} -> 3 #Total number of elements
# a[0]="some text";a[1]="more text";a[2]="much more text";echo ${a[-1]} -> much more text. Use of -1 in index prints the last array element.
# a="This is some Text";echo "${a^^}" --> THIS IS SOME TEXT #All chars converted to uppercase
# array=(This is some Text);echo "${array[@]^^}" --> THIS IS SOME TEXT #All chars converted to uppercase
# array=(This is some Text);echo "${array[@],}" --> this is some text
# array=(This is some Text);echo "${array[@],,}" --> this is some text #all chars in lower case
# array=(This is some Text);echo "${array[@]^}" --> This Is Some Text
# array=(This is a text);echo "${array[@]%is}" --> Th a text ("is" is deleted from all elements of array : array=([0]="This" [1]="is" [2]="a" [3]="text"))
# http://wiki.bash-hackers.org/syntax/pe : "As for most parameter expansion features, working on arrays will handle each expanded element, for individual expansion and also for mass expansion."
# array=(This is a text);echo "${array[@]/t/d}" ⇒ This is a dext #first found t replaced with d. Capital T is intact.
# array=(This is a text);echo "${array[@]//t/d}" ⇒ This is a dexd #all t replaced with d
# array=(This is a text);echo "${array[@]/[tT]/d}" -> dhis is a dext #First found small and first found capital T replaced using regex

# a="logfilelofi.mp3";av="anotherfile";echo ${!a@} -> a av #lists all active/stored parameters starting with letter a
# echo ${!BASH*} -> BASH BASH_ARGC BASH_ARGV BASH_COMMAND BASH_LINENO BASH_SOURCE BASH_SUBSHELL BASH_VERSINFO BASH_VERSION
#mv path/you/do/not/want/to/type/twice/oldname !#$:h/newname #!$ returns the argument of last command /history
#Similarry to !$ there is alsos !! which prints last commad (full) and last result
# path/you/do/not/want/to/type/twice/oldname !#$:h/newname -> path/you/do/not/want/to/type/twice/oldname path/you/do/not/want/to/type/twice/newname

# Check if an array contains a value : 
# if [[ " ${array[@]} " =~ " ${value} " ]]; then whatever fi
# if [[ ! " ${array[@]} " =~ " ${value} " ]]; then whatever fi

# expr 40 - 3 ->37 #expr is available in GNU Bash. 
# expr substr "the is a kind of test" 5 10 -> is a kind  
# a="the is a kind of test";echo ${a: 5:10} -> s a kind o
# export -p -> gives infor about global vars : declare -x USER="root" , declare -x XDG_CURRENT_DESKTOP="XFCE"
# IFS=:;a[0]="some text";a[1]="more text";echo "${a[*]}" -> some text:more text #the use of * instead of @ seperates array elements by IFS 

# Print / Refer to array elements in a different way using parameters expansion / string manipulation
#array=(0 1 2 3 4 5 6 7 8 9 0 a b c d e f g h)
#echo ${array[@]:7} -> 7 8 9 0 a b c d e f g h
#echo ${array[@]:7:2} -> 7 8
#echo ${array[@]: -7:2} -> b c
#echo ${array[@]: -7:-2} ->bash: -2: substring expression < 0
#echo ${array[@]:0} -> 0 1 2 3 4 5 6 7 8 9 0 a b c d e f g h  #equivalent to echo ${array[@]}
#echo ${array[@]:0:2} -> 0 1 #extract part of array / sub-array
#echo ${array[@]:2:1} -> 2   #Start from position 0 and print 1 . eqivalent to echo ${array[2]} 
# MYARR=(a b c d e f g);echo ${MYARR[@]:2:3}  -->c d e            # Extract a sub-array
# MYARR=(a b c d e f g);echo ${MYARR[@]/d/FOO} --> a b c FOO e f g  # Replace elements that match pattern (d) with word FOO)
# MYARR=(a b c d e f g);declare -p MYARR  #Print array in the smart way ;-) Works even with associative arrays.
#Output --> declare -a MYARR=([0]="a" [1]="b" [2]="c" [3]="d" [4]="e" [5]="f" [6]="g")

# Arguments : http://wiki.bash-hackers.org/scripting/posparams#range_of_positional_parameters
# START at the last positional parameter: echo "${@: -1}" or -1:1 to get one char from end.
# function test { argn=${#@};for ((i=$argn;i>0;i--)); do args[$i]=${@: -$i:1};done;};test a b c;declare -p args
# Output --> declare -a args=([1]="c" [2]="b" [3]="a")

#Reverse any word : echo "nixcraft" | rev

# Rename using for and bash parameter expansion
# for f in 0[12]/I00[12]0001 ; do mv "$f" "${f}.dcm" ; done # This will go in two folders (01 and 02) and read two files inside each folder (I0010001 and I0020001) and add dcm extension to each of them.

# Tricky sed usage if strings replace strange chars like slashes:
# a="https://www.google.gr";echo " log <sitepath />/<sitename />/platform_dir/logs/nginxerror.log" | sed -r "s#<sitepath /># $a #"  --> log  https://www.google.gr /<sitename />/platform_dir/logs/nginxerror.log
# Trick is that you can seperate actions with any char and not only /

#Remove new line char from strings and replace it with space using trim (tr)
# echo -e "hello\nyou asshole" |tr "\n" " " ->hello you asshole #If you remove the tr you will see the text to be printed in two different lines. If you apply -d "\n" new lines will be deleted.
# With sed it supposed to be sed -e 's/[\n]//g' but is not working. Texts keeps priting in terminal in two lines.


# FILE DESCRIPITORS
# http://stackoverflow.com/questions/4102475/bash-redirection-with-file-descriptor-or-filename-in-variable
# IF you try : test=$(java -version);echo $test then you will receive output of java -version in your terminal but var test will be empty.
# But if you try test=$(java -version 2>&1);echo $test works ok.
# Obviously you can assign in vars output of commands that send their output to &1 (=stdout) and not to &2 (stderr).
# With the 2>&1 you redirect stderr to stdout and thus you can store that output in a variable.
# Redirect stderr to file and stdout + stderr to screen :
# exec 3>&1 
# foo 2>&1 >&3 | tee stderr.txt


#ASSOCIATIVE ARRAYS (declare -A array)
# http://www.artificialworlds.net/blog/2012/10/17/bash-associative-array-examples/
# http://www.artificialworlds.net/blog/2013/09/18/bash-arrays/  #Tips / Examples of Normal Arrays.
# Works like dictionaries of advanced programming languages.
# You can assign whatever index you want (i.e array[file])
# declare -A MYMAP=( [foo]=bar [baz]=quux [corge]=grault ); echo ${MYMAP[foo]};echo ${MYMAP[baz]} -> bar \n quux
# K=baz; MYMAP[$K]=quux;echo ${MYMAP[$K]} -->quux   #also echo ${MYMAP[baz]} works 
# declare -A MYMAP=( [foo a]=bar [baz b]=quux );echo "${!MYMAP[@]}" --> foo a baz b #prints only the keys
# declare -A MYMAP=( [foo a]=bar [baz b]=quux );for K in "${!MYMAP[@]}"; do echo $K; done  #loop on keys only - mind double quotes.
# --> foo a 
# --> baz b
# declare -A MYMAP=( [foo a]=bar [baz b]=quux );for V in "${MYMAP[@]}"; do echo $V; done #loop on values only
# --> bar
# --> quux
# declare -A MYMAP=( [foo a]=bar [baz b]=quux );for K in "${!MYMAP[@]}"; do echo $K --- ${MYMAP[$K]}; done #loop on keys and values
# --> foo a --- bar
# --> baz b --- quux
# declare -A MYMAP=( [foo a]=bar [baz b]=quux );echo ${#MYMAP[@]}  --> 2 # Number of keys in an associative array

# Number Indexing of Associative Array :
# declare -A MYMAP=( [foo a]=bar [baz b]=quux );KEYS=("${!MYMAP[@]}");echo "${KEYS[0]} --- ${MYMAP[${KEYS[0]}]}" -> foo a --- bar   # KEYS=(${!MYMAP[@]}) = a normal array containing all the keys of the associative array. You can then refer to associative array with numerical index (0,1,2,etc)
# declare -A MYMAP=( [foo a]=bar [baz b]=quux );for (( I=0; $I < ${#MYMAP[@]}; I+=1 )); do KEY=${KEYS[$I]};  echo $KEY --- ${MYMAP[$KEY]}; done
# --> foo a --- bar
# --> baz b --- quux

#PRACTICAL USE OF BASH PARAMETERS EXPANSION (http://wiki.bash-hackers.org/syntax/pe)
#Get name without extension -> ${FILENAME%.*} ⇒ bash_hackers.txt
#Get extension -> ${FILENAME##*.} ⇒ bash_hackers.txt
#Get extension : find $PWD -type f -exec bash -c 'echo "${0##*.}"' {} \; -> Lists all extensions found.
#Get directory name -> ${PATHNAME%/*} ⇒ /home/bash/bash_hackers.txt
#Get filename -> ${PATHNAME##*/} ⇒ /home/bash/bash_hackers.txt

# AWK
# Depending on the application you can call AWK once to load the file and then you can manipulate the fields within AWK.
# Typical usage advantage is when you need to read multiple patterns / values /columns / data from the same file.
# If you do that with loop & grep you most probably it will be necessary to grep many times the same file and this makes the script slow.
# Instead you can just once AWK the file and do whatever nanipulation you need inside AWK.
# For complicated data manipulation is usual to have a seperate file full with AWK code and then call AWK with -f flag (=from file) to apply the code in your file/input
# Remember the 48H log example that you need to see events logged in any minute of the 48H time frame. The use of loop and grep per minute leads to 3000 greps of the file, while you can do it with one AWK access.
# Another great advantage is that you can use as field seperator (F) anything (a char, a word, two delimiters, etc).
# Compared to cut : with cut you allowed to use only one delimiter (-d), or to define a chars range using -c (i.e -c1-10 : seperate file in character 1-10 , whatever this char is).
# echo "This is something new for us" |cut -c1-12 --> This is some # You can not combine -c with -f or with another -c, but you can print a range -c1-10, or particular chars using -c1,10,12

# echo "value1,string1;string2;string3;string4" |awk -F"[;,]" '{print $2}' -->string1
# echo "value1,string1;string2;string3;string4" |awk -F"[;,]" 'NR==1{for(i=2;i<=NF;i++)print $1","$i}'
# -->value1,string1
# -->value1,string2
# -->value1,string3
# -->value1,string4
# In case of file , separated with new lines you need to apply this a bit different version: # awk -F"[;,]" 'NR==1{print;next}{for(i=2;i<=NF;i++)print $1","$i}' file

# See this article for AWK reserved variables :http://www.thegeekstuff.com/2010/01/8-powerful-awk-built-in-variables-fs-ofs-rs-ors-nr-nf-filename-fnr/?ref=binfind.com/web
#

#awk -F ':' '$3==$4' file.txt -->  
# echo "Geo 123 bg ty 123" |awk -F" " '$2==$5' -> Geo 123 bg ty 123  # Print lines in which field 2 = field 5, otherwise returns nothing.
# echo "Geo 123 bg ty 123 Geo" |awk -F" " '$1==$6' --> Geo 123 bg ty 123 Geo # Print if field1=filed6 , meaning Geo=Geo. Works even with strings!!!

#Export AWK variables
#$ mkfifo fifo
#$ echo MYSCRIPT_RESULT=1 | awk '{ print > "fifo" }' &
#$ IFS== read var value < fifo
#$ eval export $var=$value



#WHEREIS & WHATIS
#whereis finds where is the executable of a programm (whereis sed). 
# whatis shows one-line info of the program.
#Trick : whatis /bin/* 2>&1 |grep -v "nothing appropriate" |grep "file" -> Scans the whole bin directory for all executables/commands 
# excluding "nothing appropriate" that appears in execs without a single line description and matching file in description

:<<HERE-DOCS
Best explained : http://tldp.org/LDP/abs/html/here-docs.html
Basic format : cat <<EOF >file or >/dev/stdout or nothing=stdout

when using here-doc format within a script, the input to cat comes from the script.
Example:
#! /bin/bash
l="line 3"
cat <<End-of-message
-------------------------------------
	This is line 1 of the message.
This is line 2 of the message.
This is $l of the message.
This is line 4 of the message.
This is the last line of the message.
-------------------------------------
End-of-message

when the script finishes above lines are printed in stdout.
If you apply cat <<-ENDOFMESSAGE (mind the dash) then white space is trimmed (except space)
Tricky script usage:
You can use the here-doc format to comment big blocks of text or code for debugging.
format is :<<whatever ...... whatever
if instead of :<< you use cat << , everything bellow tags will be printed on screen or to >file if defined.

Another trick usage inside script:

GetPersonalData ()
{
  read firstname
  read lastname
} # This certainly appears to be an interactive function, but . . .


# Supply input to the above function.
GetPersonalData <<RECORD001
Bozo
Bozeman
RECORD001
exit 0

Use a cat here-doc to insert a new line to the end of an existed file
cat <<EOF >>file.txt
This line will be appended to the end of file
EOF

Use cat to insert a line in the BEGINNING of the file:
cat <<EOF >file.txt
This line will go at the beginning
$(cat file.txt)
EOF

You can offcourse use tac instead of cat. But in tac lines of here-doc will be inserted from the last to the first.
This is what tac does = reverse of cat.


HERE-DOCS

:<<Bash_Tricks
#### Special IFS settings used for string parsing. ####
# Whitespace == :Space:Tab:Line Feed:Carriage Return:
WSP_IFS=$'\x20'$'\x09'$'\x0A'$'\x0D'
# No Whitespace == Line Feed:Carriage Return
NO_WSP=$'\x0A'$'\x0D'

later, you can just set IFS=${WSP_IFS}
Bash_Tricks

:<<Bash_Options Globbing ,filename expansion
Bash Debugging: http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_02_03.html#sect_02_03_02
The Set Builtin: https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
The Shopt Builtin: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html#The-Shopt-Builtin
Shell Expansion: http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_03_04.html

Bash has by default enabled filename expansion.
This means that a simple echo a* will print all the files starting with a (if any).

This is why sometimes the command apt list a* prints results and sometimes not. 
If there is a file starting with a in the directory you run apt list a*, then a* is expanded due to bash filename expansion.

You can disable this behavior using set -f , but this command will also disable the globbing in general, meaning that ls a* will result to literal a* and not global *

Most used debuging commands: set -fvx (f for filename expansion disable, v for verbose, x for xtrace

To print all bash set parameters run #echo $SHELLOPTS && echo $-
Typical Output: 
braceexpand:emacs:hashall:histexpand:history:interactive-comments:monitor
himBHs

To print all bash shopt parameters run #shopt -s && shopt -u
Typical Output:
extquote       	on
force_fignore  	on
hostcomplete   	on
dirspell       	off
dotglob        	off
execfail       	off
extdebug       	off
extglob        	off
failglob       	off

Bash_Options
