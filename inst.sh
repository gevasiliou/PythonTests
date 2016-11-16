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
		--field="Pattern:" "xfce*" --field="Exclude1:" "dbg" --field="Exclude2:" "dev" \
		--field="Show installed":CB "Not Installed!Installed!All" )
echo $selections
pattern=`echo $selections | awk -F',' '{print $1}'`
exclude1=`echo $selections | awk -F',' '{print $2}'`
exclude2=`echo $selections | awk -F',' '{print $3}'`
installed=`echo $selections | awk -F',' '{print $4}'`

}

#-----------------------MAIN PROGRAM----------------------------------#
selectpackages

case "$installed" in
"Not Installed") 
readarray -t fti < <(apt list $pattern |grep -v -e $exclude1 -e $exclude2 -e "installed" |cut -f 1 -d "/");;
"Installed")
readarray -t fti < <(apt list $pattern |grep  "installed" |cut -f 1 -d "/");;
"All")
readarray -t fti < <(apt list $pattern |cut -f 1 -d "/");;
esac

IFS=$'\n' 
c=${#fti[@]} # number of packages 

for (( item=0; item<=$c; item++ )); do
echo "${fti[item]}"
pd+=("${fti[item]}")
done

pdshow=$(apt show ${pd[@]} |grep "Description:")
pdpolicy=$(apt policy ${pd[@]} |grep -e "Installed:" -e "Candidate:" )
pdss=($(printf "%s\n" ${pdshow[@]} |cut -f2 -d ":"))
pdpi=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Installed:" |cut -f4 -d " "))
pdpc=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Candidate:" |cut -f4 -d " "))

#echo ${pdps[@]};exit

for (( item=0; item<=$c; item++ )); do
pdssitem=$item
#pdssitem=$(($item-1))
pdpsitem=$pdssitem

#Build the list for yad with double quotes and space.
list+=( "FALSE" "${fti[item]}" "${pdss[pdssitem]}" "${pdpi[pdpsitem]}" "${pdpc[pdpsitem]}" )
done

toinstall=($(yad --list --title="Files Browser" --no-markup --width=800 --height=600 --center --checklist \
--print-column=2 --separator="\n" \
--button="gtk-ok":0 --button="gtk-cancel":1 --button="Info":5 \
--column="Install":CHK --column="File" \
--column="Description" --column="Installed" --column="Candidate" "${list[@]}"))
#the --checklist option is required by yad in order to print all entries with value of "true". If you ommit this option, only the last entry is printed.
#alternativelly with option --print-all you can print ALL the list with true - false in front.

echo "Button Pressed:" $?
printf "%s\n" ${toinstall[@]} #this prints the list correctly.

#aptinstall

unset IFS

exit
