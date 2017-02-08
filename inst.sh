#!/bin/bash

{ #Declarations
export TMPFILE=/tmp/yadvalues
mkdir -v tmpdeb
export DEBLIST=./tmpdeb/deblist.log
set -f 
#set -f controls bash behavior for filename expansion. 
#default is +f meaning that when you use "a*" bash expands this to all local files starting with a. 
#That was affecting also apt list behavior since apt list a* expanded a* to local filenames , and thus if in a directory files starting with a exist, apt returns nothing.
#Declarations 
stop=0
initpkg1="$1" #if sent by terminal ; otherwise will remain empty
initpkg2="$2"
exclude1="dev" #default values
exclude2="dbg"
}

function pkgselect { 
#echo "Args Received by caller = $@" |yad --text-info
#$0 " , " $1 " , " $2 " , " $3 " , " $4 " , " $5
#echo -e "FILEID=\"$1\"\nFILENAME=\"$4\"\nFILECOMMAND=\"$5\"" > $TMPFILE
echo -e "PKGDIS=\"$2\"\nPKGVER=\"$4\"\nPKGDEBSIZE=\"$6\"" > $TMPFILE
#cat $TMPFILE |yad --text-info
}
export -f pkgselect

function pkgdisplay { 
source $TMPFILE
#descr=$( apt show "$PKGDIS" )
#yad --title="Package Display-$PKGDIS" --no-markup --center --text="${descr[@]}" --width=800 --height=200 --button="Go Back":0

pkgdis2=$(echo $PKGDIS |cut -f1 -d"/")
descr=$(echo -e "------------------# apt policy $pkgdis2 #---------------------- \n ")
descr+=$( apt policy "$pkgdis2" )
descr+=$(echo -e "\n ------------------# apt show $PKGDIS #----------------------\n ")
descript=$( apt show "$PKGDIS" )
if [[ "$descript" =~ "Description:" ]];then
descr+=$( apt show "$PKGDIS" )
else
descr+=$(echo -e "\n ------------------# No description available #----------------------\n ")
fi
displ=$(yad --title="Package Display-$PKGDIS" --no-markup --text-info<<<"$descr" --center --width 800 --height=400 --editable --wrap --button="Go Back":0)
#If you don't use this method (displ=$(yad....) then the whole yad text-info will be printed in the terminal.
}
export -f pkgdisplay

function savepkglist {
IFS= 
#for some reason the expected IFS=$'\n' is messing things up
printf "%s\n" ${LIST3[@]} >pkglist.dat # this prints the LIST3 correctly at file.

if [[ $? == 0 ]]; then
yad --text="Package List saved to comma separated file pkglist.dat"
fi
unset IFS
}
export -f savepkglist

function aptinstall {
for i in ${toinstall[@]}; do #$toninstall array is global var assigned in the main programm by yad.
	if [[ "$i" =~ "Package:" || "$i" =~ "Deb Name" || "$i" =~ "data.tar" ]]; then continue;fi 
	istrip1=$(echo $i |cut -f1 -d"/")
	istrip2=$(echo $i |cut -f2 -d"/")
	if [ $istrip2 == "experimental" ]; then
	echo "Experimental Package Detected"
	fi
	#exit
	echo "preparing to install :" $i
	read -p "Press any key to continue installing $i or type s/q to skip/exit:" next
	if [[ $next == "q" ]]; then
		exit 1
	elif [[ $next != "s" ]]; then
		if [ $istrip2 == "experimental" ]; then
			echo "Experimental Package Detected"
			apt install -t experimental $i
		else 
			apt install $i
		fi
		#echo "This is just an echo for testing: Command that should run is # apt install $i # " && echo "installation of package #$i# finished"
		# Combining commands with && means that next command is executed only when prev command exited with code 0 = success.
	fi
done
}

function selectpackages {
#if something is sent here, then do it pattern. Otherwise the previous pattern will be kept (is not unsetted).
[[ "$1" != "" ]] && pattern1="$1" 
[[ "$2" != "" ]] && pattern2="$2"

selections=$(yad --title="Select Files" --window-icon="gtk-find" --center --form --buttons-layout=center --columns=2 --align=right --separator="," --date-format="%Y-%m-%d" \
		--field="Pattern1:" "$pattern1" --field="Pattern2:" "$pattern2" --field="Apt Operation:CB" "apt list!apt search" \
		--field="Exclude1:" "$exclude1" --field="Exclude2:" "$exclude2" \
		--field="Show installed":CB "All!Not Installed!Installed!All Unstable!Installed vs Unstable!All Experimental!Installed vs Experimental" )

if [ $? == 1 -o $? == 252 ]; then #1 is for Cancel Button, 252 is for ESC button
echo "Script Exit."
exitright
exit 1
fi

echo $selections
#exit
pattern1=`echo $selections | awk -F',' '{print $1}'`
pattern2=`echo $selections | awk -F',' '{print $2}'`
aptsearch=`echo $selections | awk -F',' '{print $3}'`
#pattern=$(echo -e \"$pattern\")
exclude1=`echo $selections | awk -F',' '{print $4}'`
exclude2=`echo $selections | awk -F',' '{print $5}'`
installed=`echo $selections | awk -F',' '{print $6}'`

[[ $exclude1 == "" && $exclude2 == "" ]] && exclude="-v -e ////\\\\\/////" # I tried exclude="-e \"\"" but grep complains. Will be almost impossible a pkg to have this slash pattern in it's pkgname
[[ $exclude1 != "" && $exclude2 != "" ]] && exclude="-v -e $exclude1 -e $exclude2"
[[ $exclude1 == "" && $exclude2 != "" ]] && exclude="-v -e $exclude2"
[[ $exclude1 != "" && $exclude2 == "" ]] && exclude="-v -e $exclude1"

echo "exclude=$exclude"
#exit
}

function printarray {
arr=("${@}")
ind=0
	echo "Start of Array"	
#	echo "Array[@]=" "${arr[@]}"
	for e in "${arr[@]}"; do
		echo "Array[$ind]=" $e
		ind=$(($ind+1))
	done
 	printf "End of Array\n\n"

}

function listdebapt {
	source $TMPFILE
	pkg="$PKGDIS"
	aptpkg="$PKGDIS"
	aptresp=$(apt-get --print-uris download $aptpkg 2>&1)
	debname=$(grep "/$pkg" <<<"$aptresp" |cut -d" " -f1 |sed s/\'//g)
	debcontents=$(dpkg -c <(curl -sL -o- $debname)) 
	debmancontents=$(grep "man/man" <<<"$debcontents" |grep -v "/$")
	echo -e "${debname:2}\n\nmanpages:\n$debmancontents\n\nDeb Contents Tree\n$debcontents" |yad --text-info --center --height 500 --width 500
}
export -f listdebapt

function listdeb {
	source $TMPFILE
	pkg="$PKGDIS"
	aptpkg="$PKGDIS"
	debname=$(find . -name "$pkg*.deb")
	if [[ "$debname" == "" ]];then
		debsize=$(sed 's/\,//g' <<<"$PKGDEBSIZE") && sizebytes="${debsize:0:-2}" && sizebytes="${sizebytes%.*}" && sizepower="${debsize: -2}"
		[[ $sizepower == " B" ]] && sizebytes=$(( $sizebytes / 1000 ))
		[[ $sizepower == "MB" ]] && sizebytes=$(( $sizebytes * 1000 ))		
		#echo "size power = $sizepower / bytes=$sizebytes" |yad --text-info
		if [[ "$sizebytes" -gt 4000 ]];then 
			yad --text-info<<<"This deb has a download size of $PKGDEBSIZE. Sure you want to get it?" --height 100 --width 600 --center
			sure=$?
		else
			sure=0
		fi

		if [[ sure -eq 0 ]];then
			apt-get download "$aptpkg" 2>/dev/null |yad --progress --pulsate --auto-close --title="Downloading..."
			debname=$(find . -name "$pkg*.deb")
		else
			return 1
		fi
	fi
	#echo "Deb Name = $debname"
	datatar=$(ar t "$debname" |grep "data.tar")
	#echo "data.tar = $datatar"

	if [[ ${datatar##*.} == "gz" ]];then 
		options="z"
	elif [[ ${datatar##*.} == "xz" ]];then
		options="J"
	else
		return 1
	fi
	debcontents=$(ar p "$debname" "$datatar" | tar tv"$options")
	debmancontents=$(ar p "$debname" "$datatar" | tar tv"$options" |grep "man/man" |grep -v "/$")
	echo -e "${debname:2}\n\nmanpages:\n$debmancontents\n\nDeb Contents Tree\n$debcontents" |yad --text-info --center --height 500 --width 1000
	#rm -f $debname
	echo "$PWD/${debname:2}">>$DEBLIST
	#echo "$PWD/${debname:2}" >6&
# Display also other zipped text / changelog files
# ar -p `ls *.deb` data.tar.xz |tar -xJO ./usr/share/doc/xul-ext-password-editor/changelog.Debian.gz |gunzip |less -f /dev/stdin
}
export -f listdeb

function readmanpage {
	source $TMPFILE
	firstcall="yes" #initial state to display local man the very first time
	pkg="$PKGDIS"
	aptpkg="$PKGDIS"
	[[ "$1" == "no" ]] && firstcall="no" #If it is a recall then you are not in local man thus you need to go back to deb contents.
	if [[ "$PKGVER" != "(none)" && "$firstcall" == "yes" ]];then #the first time we wanna display the local man
		man $pkg 2>&1 |yad --text-info --height=700 --width=1100 --center --title="$pkg LOCAL Manual " --wrap --show-uri --no-markup \
		--button="Try Online":10 \
		--button="gtk-ok":0 \
		--button="gtk-cancel":1
		resp=$?
		[[ "$resp" -ne 10 ]] && return 0 #If you select other than "Try Online" then exit (otherwise go on).
	fi
	#echo "Package: $aptpkg"
	debname=$(find . -name "$pkg*.deb")
	if [[ "$debname" == "" ]];then
		debsize=$(sed 's/\,//g' <<<"$PKGDEBSIZE") && sizebytes="${debsize:0:-2}" && sizebytes="${sizebytes%.*}" && sizepower="${debsize: -2}"
		[[ $sizepower == " B" ]] && sizebytes=$(( $sizebytes / 1000 )) #Bytes
		[[ $sizepower == "MB" ]] && sizebytes=$(( $sizebytes * 1000 )) #Mbytes	
		#echo "size power = $sizepower / bytes=$sizebytes" |yad --text-info
		if [[ "$sizebytes" -gt 4000 ]];then #raise a confirmation if size is greater than 4000KB = 4MB
			yad --text-info<<<"This deb has a download size of $PKGDEBSIZE. Sure you want to get it?" --height 100 --width 600 --center
			sure=$?
		else
			sure=0
		fi 
		
		if [[ sure -eq 0 ]];then
			apt-get download "$aptpkg" 2>/dev/null |yad --height 200 --width 200 --progress --pulsate --auto-close --title="Downloading $aptpkg"
			debname=$(find . -name "$pkg*.deb")
		else
			return 1
		fi
	fi
	#echo "Deb Name = $debname"
	datatar=$(ar t "$debname" |grep "data.tar")
	#echo "data.tar = $datatar"

	if [[ ${datatar##*.} == "gz" ]];then 
		options="z"
	elif [[ ${datatar##*.} == "xz" ]];then
		options="J"
	else
		echo "data.tar is not a gz or xz archive. Exiting" |yad --text-info --height 500 --width 500
		return 1
	fi
	unset manpage manpage2
	manpage+=($(ar p $debname $datatar | tar tv"$options" |grep "man/man" |grep -vE "\/$" |grep -v "^l" |awk '{print $NF}'))
	manpage+=($(echo "__________________OTHER_FILES_________________________________"))
	manpage+=($(ar p $debname $datatar | tar tv"$options" |grep -v -e "^l" -e "^d" -e "man/man"|grep -e "doc" -e ".gz" |grep -vE "\/$" |awk '{print $NF}'))
	#declare -p manpage |yad --text-info --wrap
		if [[ -z $manpage ]];then
			debcontents=$(ar p "$debname" "$datatar" | tar tv"$options")
			debmancontents=$(ar p "$debname" "$datatar" | tar tv"$options" |grep "man/man" |grep -v "/$")
			echo -e "No man pages found in deb : ${debname:2}\n\nmanpages listing:\n$debmancontents\n\nDeb Contents Tree\n$debcontents" |yad --text-info --center --height 500 --width 500
			echo "$PWD/${debname:2}">>$DEBLIST
			return 1
		#else
			#echo "man page found: ${#manpage[@]}"
			#declare -p manpage |sed 's/declare -a manpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
	
		if [[ ${#manpage[@]} -eq 1 ]]; then
			#echo "man page found - Display "
			#ar p "$debname" "$datatar" | tar xO"$options" $manpage |man /dev/stdin |yad --text-info --height=500 --width=800 --center --title="$pkg Manual " --wrap --show-uri --no-markup
			mpg=$(man <(ar p "$debname" "$datatar" | tar xO"$options" $manpage))
			tit="$pkg ONLINE Manual"
			echo "$PWD/${debname:2}">>$DEBLIST
		else
			#echo "Display all"
			#ar p "$debname" "$datatar" | tar xO"$options" ${manpage[@]} |man /dev/stdin |yad --text-info --height=500 --width=800 --center --title="$pkg All Manuals " --wrap --show-uri --no-markup
			#echo "${manpage[@]}" |yad --text-info --height=500 --width=800 --wrap
			manpagetodisplay=$(yad --list --title="Deb Browser" --no-markup --width=500 --height=600 --center \
			--print-column=2 \
			--button="Show All":10 \
			--button="gtk-ok":0 \
			--button="gtk-cancel":1 \
			--column="Man Pages:${#manpage[@]}" "${manpage[@]}")
			manyad=$?
			#echo "$manpagetodisplay" |yad --text-info --height=500 --width=800 --wrap
			
			if [[ "$manyad" -eq 0  && "$manpagetodisplay" != *"OTHER_FILES"* ]]; then #OK / Select File to Display
				manpagetodisplay=$(echo "${manpagetodisplay:0:-1}") #there is a bloody | in the end , due to yad
				#echo "manyad=0=display only $manpagetodisplay" |yad --text-info
				mpg=$(man <(ar p "$debname" "$datatar" | tar xO"$options" "$manpagetodisplay"))
				tit="$pkg Man Page $manpagetodisplay"
				echo "$PWD/${debname:2}">>$DEBLIST
			elif [[ "$manyad" -eq 10 ]]; then #Show All
				#echo "manyad=10=display all" |yad --text-info
				for i in ${manpage[@]};do [[ "$i" != *"OTHER_FILES"* ]] && manpage2+=( "$i" );done;
				#echo "${manpage2[@]}" |yad --text-info --wrap
				mpg=$(man <(ar p "$debname" "$datatar" | tar xO"$options" ${manpage2[@]}))
				tit="$pkg - ALL ONLINE Manuals"
				echo "$PWD/${debname:2}">>$DEBLIST
			else 
				#echo "manyad=1 = exit" |yad --text-info
				echo "$PWD/${debname:2}">>$DEBLIST
				return 1
			fi
		fi
	yad --text-info<<<"$mpg" --height=500 --width=800 --center --title="$tit" --wrap --show-uri --no-markup \
	--button="Show Deb":'bash -c "listdeb"' \
	--button="Back":10 \
	--button="Exit":0
	resp1=$?
	[[ "$resp1" -eq 10 && ${#manpage[@]} -gt 1 ]] && unset manpagetodisplay manpage manpage2 debcontents debmancontents && readmanpage no

#	[[ "$resp1" -eq 10 ]] && listdeb 
	echo "$PWD/${debname:2}">>$DEBLIST
#Bug: All the simple echo  instead of screen was going to array aptinstall on the main program. It seems that yad list call method (inside array) was sucking echoes inside. 
}
export -f readmanpage

function search_manipulate {
echo "You are in function search manipulate"
echo "Selections = $selections"

[[ "${pattern1:0:1}" == "*" ]] && pattern1="${pattern1:1}" #if first char is * exclude this char
[[ "${pattern1: -1}" == "$" || "${pattern1: -1}" == "*" ]] && pattern1="${pattern1:0:-1}" #if last char is * exclude him
#In apt search we don't want wildmark (*) in pkg name.
search1=$(apt search $pattern1 |grep "/" |cut -f1 -d "/" |grep -vE '^  ')

if [[ $pattern2 != "" ]];then
	[[ "${pattern2:0:1}" == "*" ]] && pattern2="${pattern2:1}" #if first char is * exclude this char
	[[ "${pattern2: -1}" == "$" || "${pattern2: -1}" == "*" ]] && pattern2="${pattern2:0:-1}"
	search2=$(apt search $pattern2 |grep "/" |cut -f1 -d "/" |grep -vE '^  ')
	pattern="$search1 $search2"
else
	pattern="$search1"
fi
pattern=$(tr '\n' ' ' <<<"$pattern")

echo "Pattern1 for apt search = $pattern1"
echo "Pattern2 for apt search = $pattern2"
read -p "any key" key
echo "Pattern for apt list that comes after = $pattern"

}

function aptlist_manipulate {
#all these lines were before at function selectpackages

if [[ $pattern1 = "*" ]]; then
	pattern1=""  #If user enters an asterisk then apt list blanc will bring all pkgs.
elif [[ "${pattern1: -1}" != "*" && "${pattern1: -1}" != "$" ]]; then
	pattern1=$(echo "$pattern1""*")
elif [[ "${pattern1: -1}" == "$" ]]; then
	pattern1="${pattern1:0:-1}" #If you enter a dollar sign in the end this means do not treat the name as pattern with wildmark but literally.
fi

[[ "$pattern2" == "*" ]] && pattern2=""
if [[ $pattern2 != "" ]];then	
	if [[ "${pattern2: -1}" == "$" ]];then 
		pattern2="${pattern2:0:-1}"
	elif [[ "${pattern2: -1}" != "*" && "${pattern2: -1}" != "$" ]]; then
		pattern2=$(echo "$pattern2""*")
	fi
	pattern="$pattern1 $pattern2"
else
	pattern="$pattern1"
fi

echo "Pattern for apt list = $pattern"
echo "Excluded Value= $exclude"
#sleep 5 && apt list "$pattern" 2>&1 && exit
}

function exitright {
echo -e "Temp Files to remove:"
cat $DEBLIST |sort |uniq
ls tmpdeb/
for f in $(cat tmpdeb/deblist.log |sort |uniq);do rm -fv $f;done
rm -fv tmpdeb/deblist.log
rm -fv *.FAILED
rmdir -v tmpdeb
set +f
}

#------------------------------------------MAIN PROGRAM-----------------------------------------------------#
while [[ $stop -eq 0 ]];do
selectpackages $initpkg1 $initpkg2

if [[ $aptsearch == "apt search" ]];then
echo "apt search selected"
echo "exclude value=$exclude"
search_manipulate
else
echo "apt list selected"
echo "exclude value=$exclude"
aptlist_manipulate
fi
#exit
#while [[ $stop -eq 0 ]];do
echo "Installed=$installed ---- Pattern=$pattern"
case "$installed" in
"Not Installed") 
readarray -t fti < <(apt list $pattern |grep -e "installed" -e "Listing" |cut -f 1 -d "/" |grep $exclude);;
"Installed")
readarray -t fti < <(apt list $pattern |grep -v "Listing" |grep  "installed" |cut -f1 -d "/" |grep $exclude);; 
"All")
#readarray -t fti < <(apt list $pattern |cut -f1 -d "/" |grep -v -e "Listing" |grep -v -e "$exclude1" -e "$exclude2");; 
readarray -t fti < <(apt list $pattern |cut -f1 -d "/" |grep -v -e "Listing" |grep $exclude);; 
# We need cut to be first to isolate pkgname. Some packages that had "dev" in their deb name and not in pkg name (i.e lynx-common) were wrongly exluded by grep -v -e "dev" pattern
"All Experimental")
#here the things are a bit different. Get all exprimental packages (either installed or not) that match the pattern provided
readarray -t fti < <(apt list --all-versions $pattern |grep -v "Listing" |grep "/experimental" |cut -f1 -d " " |cut -f1 -d "," |grep $exclude);;
"Installed vs Experimental")
#here the things are a bit different. Get all experimental pkgs from the --installed list
readarray -t fti < <(apt list --installed --all-versions $pattern 2>&1 |grep -v "Listing" |grep "/experimental" |cut -f1 -d " " |cut -f1 -d"," |grep $exclude);; #we need to cut even for coma to catch the case "experimental,now"
"All Unstable")
readarray -t fti < <(apt list --all-versions $pattern |grep -v "Listing" |grep "unstable" |grep -v "testing" |cut -f1 -d " " |cut -f1 -d"," |grep $exclude);;
"Installed vs Unstable")
readarray -t fti < <(apt list --installed --all-versions $pattern |grep -v "Listing" |grep "unstable" |grep -v "testing" |cut -f1 -d " " |cut -f1 -d"," |grep $exclude);;
esac
#declare -p fti
IFS=$'\n' 
c=${#fti[@]} # c=number of packages, items in array fti
[[ $c -lt 1 ]] && echo "Np packages found matching your pattern" && break
[[ $c -gt 1000 ]] && echo "More than 1000 pkgs found (actually found $c pkgs). Will list only first 1000 pkgs" |yad --text-info && c=1000
for (( item=0; item<=$c; item++ )); do
[[ -z "${fti[$item]}" ]] && continue
echo -e "fti[$item] = \"${fti[$item]}\""
pd+=("${fti[$item]}")
done

aptshow=$(apt show ${pd[@]})
#declare -p aptshow
#echo "$aptshow" |grep "virtual"
#exit
pddescription=$(grep -e "Description:" <<< $aptshow |tr -d '"') #some packages like xtail have "" in their description which breaks the rest code (yad --select function in particular)
#pddescription=$(grep -e "Package:\|Description:\|not a real package" <<< $aptshow)
#declare -p pddescription && set +f && exit
pdsizeDown=$(grep "Download-Size:" <<< $aptshow)
pdsizeInst=$(grep "Installed-Size:" <<< $aptshow)

pdss=($(printf "%s\n" ${pddescription[@]} |cut -f2-3 -d ":"))
pdszd=($(printf "%s\n" ${pdsizeDown[@]} |cut -f2 -d ":"))
pdszi=($(printf "%s\n" ${pdsizeInst[@]} |cut -f2 -d ":"))

# To be noted:
# when using apt show a*, virtual packages were also listed.
# As a result, the apt show of virtual packages returns not a real package as description and this mess things up.
# Example: Package: abiword-gnome - State: not a real package (virtual)
# Hopefully apt list is not displaying virtual packages (!). So if you apt show the packages returned by apt list and not the pattern you will be ok. 
# This can be verified by running 'apt list "abi*" ' (abiword-gnome is missing) and also 'apt list -a abiword-gnome' returns nothing.
# apt show abiword-gnome returns: --> Package: abiword-gnome --> State: not a real package (virtual)
# Depending on apt pinning priorities, apt list / apt show may return some virtual packages (happened when sid had priority <1)
# Another suspicious package to return "virtual package" is apt-spy.


if [ $installed = "All Experimental" -o $installed = "Installed vs Experimental" -o $installed = "All Unstable" -o $installed = "Installed vs Unstable" ]; then
echo "grab versions differently in experimental packages"
pdpolicy=$(grep "^Version:" <<< $aptshow) #get the candidate versions at experimental
#pdpc=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Version:" |awk -F'Version:' '{print $2}')) #candidate
pdpc=($(printf "%s\n" ${pdpolicy[@]} |awk -F'Version:' '{print $2}')) #candidate version stripped

#get installed version
fti2=($(printf "%s\n" ${pd[@]} |cut -f1 -d'/')) #remove the /experimental string from pkg name 
pdpolicy2=$(apt policy ${fti2[@]} |grep -e "Installed:") #apt policy doesnot accept pkg/experimental format
pdpi=($(printf "%s\n" ${pdpolicy2[@]} |grep -e "Installed:" |cut -f4 -d " "))

else
echo "Classic version grab"
pdpolicy=$(apt policy ${pd[@]} |grep -e "Installed:" -e "Candidate:" )
pdpi=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Installed:" |cut -f4 -d " ")) #pdpi=pdpolicy installed
pdpc=($(printf "%s\n" ${pdpolicy[@]} |grep -e "Candidate:" |cut -f4 -d " ")) #pdpc=pdpolicy candidate
fi
#exit

#echo "${pdss[@]}"
#exit
list2=($(echo -e "CHKBOX,Package,PkgDescription,Installed, Candidate,DownSize,Installed Size,\n")) #Header Line

for (( pitem=0; pitem<=$c; pitem++ )); do
[[ -z "${fti[$pitem]}" ]] && continue
#Build the list for yad with double quotes and space.
list+=( "FALSE" "${fti[pitem]}" "${pdss[pitem]}" "${pdpi[pitem]}" "${pdpc[pitem]}" "${pdszd[pitem]}" "${pdszi[pitem]}" ) #to be used by yad only - no new lines (\n) allowed by yad list.

list2+=($(echo -e "FALSE,${fti[pitem]},${pdss[pitem]},${pdpi[pitem]},${pdpc[pitem]},${pdszd[pitem]},${pdszi[pitem]},\n"))
# Format of List2 is different. $list for yad has been built in order to be understood by yad = not \n chars inside.
# We could export list to list2 as it was, but will be saved later infiles as one line without \n. 
# It is though strange that if you printf the $list with IFS=$'\n', you get seperate lines for every field change.

done
#printf "%s\n" ${list2[@]} # this prints the list2 correctly on terminal but not in file even if you export it at line 154
export LIST3=$(printf "%s\n" ${list2[@]})

unset toinstall
toinstall=($(yad --list --title="Files Browser" --no-markup --width=1200 --height=600 --center --checklist \
--select-action 'bash -c "pkgselect %s "' \
--print-column=2 \
--separator="\n" \
--button="Show Deb Pkg":'bash -c "listdeb"' \
--button="Show manual":'bash -c "readmanpage"' \
--button="Save List":'bash -c "savepkglist"' \
--button="Display":'bash -c "pkgdisplay"' \
--button="gtk-ok":0 \
--button="gtk-cancel":1 \
--button="New Selection":10 \
--column="Install":CHK \
--column="File" \
--column="Description" \
--column="Installed" \
--column="Candidate" \
--column="Download Size" \
--column="Installed Size" \
"${list[@]}" ))
#the --checklist option is required by yad in order to print all entries with value of "true". If you ommit this option, only the last entry is printed.
#alternativelly with option --print-all you can print ALL the list including true - false selection of rows

btn=$?
echo "Button Pressed:" $btn
#printarray ${list[@]} && exit
#printarray ${toinstall[@]} && exit
#declare -p toinstall
case $btn in 
0) 	
	echo "Package list to be installed"
	printf "%s\n" ${toinstall[@]} #this prints the list correctly.
	aptinstall #call the aptinstall function to install selected packages.
	unset IFS
	unset c pd aptshow pddescription pdsizeDown pdsizeInst pdss pdszd pdszi pdpolicy pdpc 
	unset fti2 pdpolicy2 pdpi pitem list list2 LIST3 toinstall
	# Reset all variables except variables in selectpackages function (pattern, etc)
	# selectpacakges is not called again - previous selections are used. While loop will poll again all the data and thus list will be refreshed.
	;;
1) #Exit. Setting stop=1 while loop ends - script exits.
	stop=1
	unset IFS
	;;
252) #Exit. Setting stop=1 while loop ends - script exits.
	stop=1
	unset IFS
	;;
10) # New Selection
	unset c pd aptshow pddescription pdsizeDown pdsizeInst pdss pdszd pdszi pdpolicy pdpc 
	unset fti2 pdpolicy2 pdpi pitem list list2 LIST3 toinstall IFS initpkg1 initpkg2
	#selectpackages #by not sending an arg to selectpackages, previously values are used.
	# Just unset all variables, and allow the while loop to be repeated
esac	
unset IFS
done
exitright
exit

# GREP Tips:
# If you are in doubt about the results of a command like an extra grep you can compare results of previous command with new command like this:
# diff -w -y <(apt search manpages |grep "/" |cut -d"/" -f1 |grep -E '^[a-zA-Z0-9]') <(apt search manpages |grep "/" |cut -d"/" -f1)
# Differences will be noted with > symbol and then you can manually verify that the results of the new command (extra grep) is as expected.
# Usefull when you want to verify the performance in commands that produce large output.

#To be done:
# How to provide local man page of apt-get? apt-get is not a package (apt list apt-get returns nothing)
# on the other hand, man apt brings only apt manual , not apt-get even if combined with --all switch
# The apt.deb has inside all manuals, thus at least the "try online" option works and gives you the list of all manuals included in apt.
# 
# Provide option to display description / message /binaries list from local installed files (available at /usr/bin, etc -see PATH) 
# Currently can be done by terminal with :  find /usr/bin -type f -executable |xargs whatis -v 2>&1 |sed 's/ - /:/g' >whatis.log
# mind the use of xargs. Without xargs this does not works. 
#
# Jump to readmanual from listdeb
# Assign a button to see upgradeble pkgs , you can list them, display them and user to select which pkgs want to upgrade.
# Command apt install --upgrade pkgname works , but pkgname* gets all pkgs (both installed and not installed)
#
# Trick: Apt list in a regular var - not array
# ass+=$(apt list $1 2>/dev/null |grep -v "Listing" |sed "s#\\n# #g" |cut -d/ -f1);apt show $ass |less #or use tr '\n' ' ' . The point is to remove new lines and insert a space between pkgnames.
# Since apt list skips the virtual packages , instead of apt show pkg* you can use above command and thus apt show will call only 
# valid packages reported by apt list. I have also an alias for this (aptshowsmart) 
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
#Moreover you can print the packages in a customized show format:
#root@debi64:/home/gv# dpkg-query -W -f='${binary:Package},${Version},${Architecture},${binary:Summary}\n'
#-W = --show , -F = --showformat. See man dpkg-query for more info
#The comma between fields is printed. You can apply your own dilimiter or you can apply \t,\n,etc.

# You can install the package apt-show-versions and locate all available versions of a package (or more packages)
# For example try this : apt-show-versions -a -r |grep -v "No experimental" |grep experimenta
# -r enables regex to be used (useless in this case but usefull if you combine -r xfce*)
# -a options lists all versions, including experimental.

# One line dependency checker for a given package (similar to apt-cache depends pkgname):
#root@debi64:/home/gv/Desktop/PythonTests# read -p "Package= " a;pkgs=$(apt show $a | grep Depends | awk -F'Depends: ' '{print $2}');IFS=', ';for p in $pkgs; do pkg=$(echo $p |grep -v -e '(' -e ')');if [[ $pkg != '' ]] ;then echo -e "$pkg\c";apt-cache -q policy $pkg |grep 'Installed';fi;done

#You can expanded it in a script and provide also the "Candidate:" version field , or grep the version inside () provided by apt show
# Thus you can have three columns: Required - Installed - Candidate. 
# This is just informational. You do not need to install dependencies seperatelly - will be installed by defaul with apt install pkgname.

# Tips: A lot of yad dialogues work well with pipes.
# For example this works perfectly : apt install geany |yad --text-info (it does not work with simple --text)


# apt full-upgrade >fullupgrade.txt
# cp fullupgrade.txt fullupgradenice.txt
# sed -n '/upgraded/,$p' fullupgradenice.txt >fullupgradenice2.txt
# geany fullupgradenice2.txt &
# cat fullupgradenice2.txt |tr "\n" " " >fullupgradenice3.txt
# cat fullupgradenice3.txt |sed -e 's/   / /g' >fullupgradenice4.txt
# pattern=$(cat fullupgradenice4.txt);apt list $pattern >fullupgradepkgs.list #wait for apt list to finish... needs time
# cat fullupgradepkgs.list |grep -v "testing" -> should give you only /stable packages and not unstable.
