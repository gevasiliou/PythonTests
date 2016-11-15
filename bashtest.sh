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

function sersoft {
yad --text "Server Prerequesites Will be installed now"
}
export -f sersoft

function clientsoft {
yad --text "Client Prerequesites Will be installed now"
}
export -f clientsoft

function install_ser_soft {
yad --text "Server SOFTWARE to be installed now"
}

function install_client_soft {
yad --text "Client SOFTWARE to be installed now"
}


	MSP="Install Prerequesites for Server"
    MCP="Install Prerequesites for Client"
    MSP1="Software for Server"
    MCP1="Software for Client"

    yad --plug=12346 --tabnum=1 --form --image="abp.png" --separator='\n' &\
    yad --plug=12346 --tabnum=2 --form --separator='\n' --text="Please install softwares" --text-align=center \
    --field="$MSP!gtk-yes:2:FBTN" "bash -c sersoft" --align=center --field="$MCP!gtk-yes:3:FBTN" "bash -c clientsoft" \
    --align=center &\
    action=$(yad --plug=12346 --tabnum=3 --form --seperator=' ' --field="Select:CBE" "\--Install\--!$MSP1!$MCP1" &\
    yad --center --notebook --key=12346 --tab="Welcome Tab" --tab="Prerequesites" --tab="Install" --title="Software Setup Wizard" --image="abp.png" --button="OK:0" --button="Exit:1" --height=560 --width=665 --image-on-top --text="Software version 3")
	ret=$?
	echo "output=" $ret
	echo "answer=" $action
	case $action in
	$MSP1*) install_ser_soft ;;
	$MCP1*) install_client_soft ;;
	*) yad --center --text="error";;
	esac		


    #yad --plug=$KEY --tabnum=1 --form --image="$banner" --separator='\n' --quoted-output \
             #> $res4 &

    #yad --plug=$KEY --tabnum=2 --form --separator='\n' --text="\n\nPlease install the required softwares needed to configure Monosek software. \n\nClick any one of the options.\n\n" --text-align=center --quoted-output \
            #--field="$MSP!gtk-yes:2":FBTN --align=center \
            #--field="$MCP!gtk-yes:3":FBTN --align=center  > $res1 &

    #action=$(yad --plug=$KEY --tabnum=3 --form --seperator='\n' --quoted-output \
            #--field="Select:CBE" "\--Install\--!$MSP1!$MCP1") > $res2 &

    #yad --center --fixed --notebook --key=$KEY --tab-pos=left --tab="Welcome Tab" --tab="Prerequesites" --tab="Install" \
    #--title="Software Setup Wizard" --image="$icon" \
    #--button="OK:0" \
    #--button="Exit:1" \
    #--height=560 --width=665 --image-on-top --text="  Software version $VERSION"
#case $action in
#$MSP1*) TAB2=install_ser_soft ;;
#$MCP1*) TAB3=instal_client_soft ;;
#*) yad --center --text="error";;
#esac


