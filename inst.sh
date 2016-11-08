#!/bin/bash
function aptinstall {
for i in ${toinstall[@]}; do
echo "preparing to install :" $i
sleep 5
apt install $i
done
echo "installation finished"
}

#readarray -t fti < <(apt list xfce* |grep -v "installed" |grep -v "dbg" |cut -f 1 -d "/")

if [[ $1 == "" ]]; then
echo "No pattern provided".
exit
fi

readarray -t fti < <(apt list $1 |grep -v "dbg" | grep -v "installed" |cut -f 1 -d "/")

IFS=$'\n' 
#printf "%s\n" ${fti[@]}

c=${#fti[@]}

#for item in $(seq 1 $c); do
for (( item=1; item<=$c; item++ )); do
list+=( "TRUE" "${fti[item]}" ) #set true to all the packages by default
done

toinstall=($(yad --list --title="Files Browser" --width=300 --height=600 --center --checklist --print-column=2 --separator="\n" --column="Install":CHK --column="File" "${list[@]}"))
#the --checklist option is required by yad in order to print all entries with value of "true". If you ommit this option, only the last entry is printed.
#alternativelly with option --print-all you can print ALL the list with true - false in front.

echo "Button Pressed:" $?
printf "%s\n" ${toinstall[@]} #this prints the list correctly.

aptinstall

unset IFS

exit
