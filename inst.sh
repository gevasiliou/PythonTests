#!/bin/bash
function aptinstall {
for i in ${toinstall[@]}; do
echo "preparing to install :" $i
sleep 5
apt install $i
done
echo "installation finished"
}

function selectpackages {
selections=$(yad --title="Select Files"--window-icon="gtk-find" --center --form --separator="," \
		--date-format="%Y-%m-%d" \
		--field="Pattern:" "xfce*" --field="Exclude1:" "dbg" --field="Exclude2:" "dev" --field="Show installed":CB "Installed!Not Installed!All" )
echo $selections
pattern=`echo $selections | awk -F',' '{print $1}'`
exclude1=`echo $selections | awk -F',' '{print $2}'`
exclude2=`echo $selections | awk -F',' '{print $3}'`
installed=`echo $selections | awk -F',' '{print $4}'`

}

#readarray -t fti < <(apt list xfce* |grep -v "installed" |grep -v "dbg" |cut -f 1 -d "/")

#if [[ $1 == "" ]]; then
#echo "No pattern provided".
#exit
#fi

selectpackages
#exit
#readarray -t fti < <(apt list $1 |grep -v "dbg" | grep -v "installed" |cut -f 1 -d "/")
if [[ $installed == "Not Installed" ]];then
readarray -t fti < <(apt list $pattern |grep -v $exclude1 | grep -v $exclude2 |grep -v "installed" |cut -f 1 -d "/")
fi

if [[ $installed == "Installed" ]];then
readarray -t fti < <(apt list $pattern |grep  "installed" |cut -f 1 -d "/")
fi

IFS=$'\n' 
#printf "%s\n" ${fti[@]} ${pd[@]} 

c=${#fti[@]}

for (( item=1; item<$c; item++ )); do
echo "${fti[item]}"
pd+=("${fti[item]}")
done

pds=$(apt show ${pd[@]} |grep "Description:")
pdss=($(printf "%s\n" ${pds[@]} |cut -f2 -d ":"))

for (( item=1; item<$c; item++ )); do
pdssitem=$(($item-1))
list+=( "FALSE" "${fti[item]}" "${pdss[pdssitem]}") #set true to all the packages by default
done

toinstall=($(yad --list --title="Files Browser" --no-markup --width=800 --height=600 --center --checklist \
--print-column=2 --separator="\n" --column="Install":CHK --column="File" --column="Description" "${list[@]}"))
#the --checklist option is required by yad in order to print all entries with value of "true". If you ommit this option, only the last entry is printed.
#alternativelly with option --print-all you can print ALL the list with true - false in front.

echo "Button Pressed:" $?
printf "%s\n" ${toinstall[@]} #this prints the list correctly.

aptinstall

unset IFS

exit
