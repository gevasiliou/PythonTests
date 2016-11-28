#!/bin/bash

{ #Declarations
export TMPFILE=/tmp/yadvalues
#Declarations 
}

function pkgselect { 
#yad --center --text="Selected: $2"
#echo "Args Received =" $0 " , " $1 " , " $2 " , " $3 " , " $4 " , " $5
#echo -e "FILEID=\"$1\"\nFILENAME=\"$4\"\nFILECOMMAND=\"$5\"" > $TMPFILE
echo -e "PKGDIS=\"$2\"" > $TMPFILE

}
export -f pkgselect

function pkgdisplay { 
source $TMPFILE
#filetodisplay="$FILENAME"
#descr=$(apt show "$PKGDIS" |sed -n '/Description:/,$p')
descr=$( apt show "$PKGDIS" )
yad --title="Package Display-$PKGDIS" --no-markup --center --text="$descr" --width=800 --height=200 --button="Go Back":0
}
export -f pkgdisplay

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
		--field="Show installed":CB "All!Not Installed!Installed!Experimental" )
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
"Experimental")
#here the things are a bit different
readarray -t fti < <(apt list --all-versions $pattern |grep "experimental" |cut -f1 -d " ");;
esac

IFS=$'\n' 
c=${#fti[@]} # c=number of packages, items in array fti

for (( item=0; item<=$c; item++ )); do
echo "fti[$item] = ${fti[$item]}"
pd+=("${fti[$item]}")
#echo "fti[$item] = ${fti[$item]}"
done

aptshow=$(apt show ${pd[@]})
pddescription=$(grep "Description:" <<< $aptshow)
pdsizeDown=$(grep "Download-Size:" <<< $aptshow)
pdsizeInst=$(grep "Installed-Size:" <<< $aptshow)

pdss=($(printf "%s\n" ${pddescription[@]} |cut -f2 -d ":"))
pdszd=($(printf "%s\n" ${pdsizeDown[@]} |cut -f2 -d ":"))
pdszi=($(printf "%s\n" ${pdsizeInst[@]} |cut -f2 -d ":"))

if [[ $installed == "Experimental" ]]; then
echo "grab versions differently in experimental packages"
pdpolicy=$(grep "Version:" <<< $aptshow)
pdpc=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Version:" |cut -f2 -d ":")) #candidate

fti2=($(printf "%s\n" ${pd[@]} |cut -f1 -d'/'))
pdpolicy2=$(apt policy ${fti2[@]} |grep -e "Installed:") #apt policy doesnot accept pkg/experimental
pdpi=($(printf "%s\n" ${pdpolicy2[@]} |grep -e "Installed:" |cut -f4 -d " "))

else
echo "Classic version grab"
pdpolicy=$(apt policy ${pd[@]} |grep -e "Installed:" -e "Candidate:" )
pdpi=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Installed:" |cut -f4 -d " "))
pdpc=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Candidate:" |cut -f4 -d " "))
fi


#echo "${pdss[@]}"
#exit

for (( pitem=0; pitem<=$c; pitem++ )); do
#Build the list for yad with double quotes and space.
list+=( "FALSE" "${fti[pitem]}" "${pdss[pitem]}" "${pdpi[pitem]}" "${pdpc[pitem]}" "${pdszd[pitem]}" "${pdszi[pitem]}" )
done
#exit

toinstall=($(yad --list --title="Files Browser" --no-markup --width=1200 --height=600 --center --checklist \
--select-action 'bash -c "pkgselect %s "' \
--print-column=2 --separator="\n" \
--button="Display":'bash -c "pkgdisplay"' --button="gtk-ok":0 --button="gtk-cancel":1 --button="Info":5 \
--column="Install":CHK --column="File" \
--column="Description" --column="Installed" --column="Candidate" --column="Download Size" --column="Installed Size" "${list[@]}" ))
#the --checklist option is required by yad in order to print all entries with value of "true". If you ommit this option, only the last entry is printed.
#alternativelly with option --print-all you can print ALL the list including true - false selection of rows

echo "Button Pressed:" $?
echo "Package list to be installed"
printf "%s\n" ${toinstall[@]} #this prints the list correctly.

#aptinstall #call the aptinstall function to install selected packages.

unset IFS
exit

#To be done:
# You can assign a button to see upgradeble pkgs , you can list them, display them and user to select which pkgs want to upgrade.
# Command apt install --upgrade pkgname works , but pkgname* gets all pkgs (both installed and not installed)
# 
# Trick1: the following command asks for a package name , load all pkgs found in a array, and prompts you to install them.
# It also runs as one line in terminal:
# root@debi64:/home/gv/Desktop# read -p "give package name: " pkg;readarray pkgs< <(apt list --upgradable |egrep "^$pkg" |cut -f1 -d'/');echo ${pkgs[@]};for i in ${pkgs[@]};do read -p "press any key to install next package = $i or press s to skip: " ans;if [[ $ans != 's' ]];then apt install -y --upgrade $i;fi;done
# 
# Trick2: The following command gives info about all versions of pkgs, including experimental repo:
# root@debi64:/home/gv/Desktop/PythonTests# apt list --all-versions xfce4* |cut -f1 -d" "
# you can combine with grep experimental to see only pkgs available in experimental repo.
# You then can install a package of a specific varsion using apt install pkg/experimental or apt -t experimental install pkg 
# apt list --all-versions  |grep -v "installed" |grep experimental -> list all not installed files from experimental repo
# apt list --installed --all-versions  |grep experimental -> Find and list experimental versions of all installed files
# apt list --all-versions  |grep experimental -> list experimental versions of all the pkgs (both installed and not installed)
# You can limit the listing like apt list --installed --all-versions xfce* |grep experimental

#
#Trick3: By Running just apt list (no arguments) or apt list --all-versions will give you huge lists of ALL packages (installed and not installed) available in repos.
# You can combine with grep "installed" (or even --installed switch) to see only the installed packages.

# Trick4: You can also see the installed packages using dpkg-query --list instead of apt.

# You can install the package apt-show-versions and locate all available versions of a package (or more packages)
# For example this : apt-show-versions -a -r |grep -v "No experimental" |grep experimenta
# use the -r option which enables regex to be used (useless in this case but usefull if you combine -r xfce*)
# the -a options lists all versions, including experimental.
