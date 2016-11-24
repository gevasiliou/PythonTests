#!/bin/bash
function aptinstall {
for i in ${toinstall[@]}; do
echo "preparing to install :" $i
read -p "Press any key to continue installing $i or type s/q to skip/exit:" next
if [[ $next == "q" ]]; then
exit
elif [[ $next != "s" ]]; then
#sleep 5
apt install $i
fi
echo "installation of package #$i# finished"
done
}

function selectpackages {
selections=$(yad --title="Select Files"--window-icon="gtk-find" --center --form --separator="," \
		--date-format="%Y-%m-%d" \
		--field="Pattern:" "xfce*" --field="Exclude1:" "dbg" --field="Exclude2:" "dev" \
		--field="Show installed":CB "All!Not Installed!Installed" )
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
c=${#fti[@]} # c=number of packages, items in array fti

for (( item=0; item<=$c; item++ )); do
echo "fti[$item] = ${fti[$item]}"
pd+=("${fti[$item]}")
done

#echo 'Array pd'
#for (( citem=1; citem<=$c; citem++ )); do
#echo "pd[$citem]= ${pd[$citem]}"
#done
#exit

aptshow=$(apt show ${pd[@]})
pddescription=$(grep "Description:" <<< $aptshow)
pdsizeDown=$(grep "Download-Size:" <<< $aptshow)
pdsizeInst=$(grep "Installed-Size:" <<< $aptshow)
pdpolicy=$(apt policy ${pd[@]} |grep -e "Installed:" -e "Candidate:" )

#pddescription=$(apt show ${pd[@]} |grep "Description:")
#pdsizeDown=$(apt show ${pd[@]} |grep "Download-Size:")
#pdsizeInst=$(apt show ${pd[@]} |grep "Installed-Size:")

pdss=($(printf "%s\n" ${pddescription[@]} |cut -f2 -d ":"))
pdpi=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Installed:" |cut -f4 -d " "))
pdpc=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Candidate:" |cut -f4 -d " "))
pdszd=($(printf "%s\n" ${pdsizeDown[@]} |cut -f2 -d ":"))
pdszi=($(printf "%s\n" ${pdsizeInst[@]} |cut -f2 -d ":"))

for (( pitem=1; pitem<=$c; pitem++ )); do
#Build the list for yad with double quotes and space.
list+=( "FALSE" "${fti[pitem]}" "${pdss[pitem]}" "${pdpi[pitem]}" "${pdpc[pitem]}" "${pdszd[pitem]}" "${pdszi[pitem]}" )
#echo " list[$pitem] = ${list[$pitem]}"
done
#exit

toinstall=($(yad --list --title="Files Browser" --no-markup --width=800 --height=600 --center --checklist \
--print-column=2 --separator="\n" \
--button="gtk-ok":0 --button="gtk-cancel":1 --button="Info":5 \
--column="Install":CHK --column="File" \
--column="Description" --column="Installed" --column="Candidate" --column="Download Size" --column="Installed Size" "${list[@]}"))
#the --checklist option is required by yad in order to print all entries with value of "true". If you ommit this option, only the last entry is printed.
#alternativelly with option --print-all you can print ALL the list including true - false selection of rows

echo "Button Pressed:" $?
printf "%s\n" ${toinstall[@]} #this prints the list correctly.

aptinstall #call the aptinstall function to install selected packages.

unset IFS
exit

#To be done:
# You can assign a button to see upgradeble pkgs , you can list them, display them and user to select which pkgs want to upgrade.
# Command apt install --upgrade pkgname works , but pkgname* gets all pkgs (both installed and not installed)
# nice trick:
# the following command runs as one line in terminal:
# root@debi64:/home/gv/Desktop# read -p "give package name: " pkg;readarray pkgs< <(apt list --upgradable |egrep "^$pkg" |cut -f1 -d'/');echo ${pkgs[@]};for i in ${pkgs[@]};do read -p "press any key to install next package = $i or press s to skip: " ans;if [[ $ans != 's' ]];then apt install -y --upgrade $i;fi;done
