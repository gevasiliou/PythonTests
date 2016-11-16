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

function finddivider {
groups=$(bc <<< "scale=1;$NoOfLines/$1")
decimals=$(cut -f 2 -d "." <<<$groups)
}

function readlog1 {
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

function importvals {
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
#ls alternative: 
# find /home/gv -maxdepth 1 -type d -> list only directories
# find /home/gv -maxdepth 1 -type f -> lists only files
# find /home/gv -maxdepth 1 -> lists both
# output of find can be piped to wc -l as well.
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

function fileread2 {
#IFS=$'\n'
data=$(cat b.txt)
headers=$(cat c.txt)
echo "headers = $headers"
message=$(echo "$headers")
message+=$(echo "\n")
#while IFS=$'\n' read -r line; do
message+=$(echo "$data")
#done <<< "$data" 
echo -e "message=\n$message"
unset IFS
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

posA=$(grep -hn "\^A" a.txt | cut -f 1 -d ":")
echo $posA
