# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them directly το ~/.bashrc.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
#if [ -f ~/.bash_aliases ]; then
#    . ~/.bash_aliases
#fi
#Remark: .bashrc of user has already above check condition but root .bashrc not.
#Install it using cp .bash_aliases /home/gv/ and cp .bash_aliases /root/ or cp .bash_aliases $HOME/ (under root terminal)
# You can import the recent aliases on the fly by running root@debi64:# . ./.bash_aliases

#alias words='/usr/share/dict/words'
function aptlog {
l=$(awk '/Log started/{a=NR}END{print a}' /var/log/apt/term.log);awk -v l=$l 'NR==l || (NR>l && /^Unpacking/&& NF)' /var/log/apt/term.log |less
}

alias cd..='cd ..'
alias cd..2='cd .. && cd ..'
alias cd-='cd $OLDPWD'
alias nano='nano -lmS' #-l enables line numbers | -m enables mouse support | -S smooth scroll (line by line)
alias cls='clear'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias nocrap='grep -i -v -e .page -e .png -e .svg -e .jpg -e messages -e usr/share/man -e changelog -e log -e localle -e locale -e "/doc/"'
alias maxpower='cpufreq-set -c 0 --min 2000000 --max 9000000 && cpufreq-set -c 1 --min 2000000 --max 9000000'


alias yadit='yad --text-info --center --width=800 --height=600 --no-markup &' #--wrap &'
#alias yadit='yad --text="$(</dev/stdin)" --center --wrap --no-markup --width=800 & disown'  #alternative: yad --text="$(cat -)"  # yadit alternative but without scroll bars and buttons
#alias lsdir='ls -l -d */'



alias dirsize='df -h / && du -b -h -d1'   #Combine with * or ./* to display also files. Use */ for subdirs or even */*/ for subdirs
alias gitsend='git add . && git commit -m "update" && git push && git show --name-only'
alias bashaliascp='cp -i .bash_aliases /home/gv/ && cp -i .bash_aliases /root/'
alias aptsourcescp='cp -i /etc/apt/sources.list /etc/apt/sources.backup && cp -i /home/gv/Desktop/PythonTests/sources.list /etc/apt/'
alias update='apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y'
alias printfunctions='set |grep -A2 -e "()"'
alias wfr='( nmcli radio wifi off && sleep 10 && nmcli radio wifi on & )' #alternative modprobe -r rtl8723be && sleep 10 && modprobe rtl8723be
#alias weather='links -dump "http://www.meteorologos.gr/" |grep -A7 -m1 -e "Αθήνα"'
#lynx -dump "http://www.meteorologos.gr/" |awk '/Αθήνα/{a=1;next}a==1{print gensub(/(...)(..)(.*)/,"\\2 βαθμοί",1,$0);exit}' |espeak -vel+f2 -s130

alias lsm='ls -l $@ && cd' #Strange, but cd keeps the $@ and it works.
#Trick : ls -l /dir && cd $_ does the same job


alias weather="curl wttr.in/'Νέα Ερυθραία'" #/Μαρούσι
alias hexit='od -w40 -An -t x1c -v'
alias man="LESS='+Gg' man" #This one goes to end of man page and then back to beginning , forcing less to count the man page lines
#alias asciit='od -An -tuC'
#alias esc_single_quotes='sed "s|\x27|\x5c\x5c\x27|g"' #\x27 = hex code for single quote. \x5c = hex code for \
#alias esc_double_quotes=$'sed \'s|"|\\\\"|g\''

# ascii_table() { echo -en "$(echo '\'0{0..3}{0..7}{0..7} | tr -d " ")"; }
# Uses octal to build the whole ascii table

alias tabit="perl -pe 's/\x20{1,4}/\t/g'"  #alternative : sed -r or sed -E - extended regex for {1,4} to work

#alias battery="upower -i $(upower -e |grep -e 'BAT') |grep -e 'state' -e 'percentage' -e 'time to' -e 'native-path' |sed -r 's/^\s+//g'"

alias catd="awk 'FNR==1{print \"==========>\",FILENAME,\"<===========\"}{printf FNR \":  \" }1'" #cat with details
#alternative: for f in ./*;do echo "========>> $f <<========";cat "$f";done

alias stopwlan0monitor='ifconfig wlan0 down && sleep 1 && iwconfig wlan0 mode managed && sleep 1 && ifconfig wlan0 up && sleep 1 && NetworkManager'
alias startwlan0monitor='airmon-ng check kill && ifconfig wlan0 down && iwconfig wlan0 mode monitor && ifconfig wlan0 up && aireplay-ng -9 wlan0 && airodump-ng wlan0'



function aptless {
[[ -z $1 ]] && echo "no patteern given" && exit 1
apt list "$@" |grep --color=always '^.[^/]*' |less -r
}

function power {
echo "AC Power" && upower -i "$(upower -e |grep 'line_power')" |grep -e 'native-path' -e 'online' |sed -r 's/^\s+//g'
echo && echo "Battery" && upower -i "$(upower -e |grep -e 'BAT')" |grep -e 'state' -e 'percentage' -e 'time to' -e 'native-path' |sed -r 's/^\s+//g'
}

function teee { 
#This can be used between pipes toprint on screen what is coming in from the left command and flows to the next command

#function teee { a="$(</dev/stdin)";echo -e "pipe in\n$a\npipe out\n" >/dev/stderr; echo "$a"; }
	v="$(</dev/stdin)"; 
	echo '---------------- pipe -------------' >/dev/tty;
	i=1;
	while read -r l;do 
	  echo "$i>$l" >/dev/tty;
	  let i++;
	done <<<"$v";
	echo '---------------- pipe -------------^' >/dev/tty; #disabled - for some reason prints the result of the last command
	echo "$v"; ##echo to pipe buffer - necessary to keep the data flow to the next command if any or to screen
	
#Usage example:
#$ cat file1.txt |teee |grep 'WNA' |grep '621'
#---------------- pipe -------------
#1>denovo23    HNS.2_9729  HNS.2_20867
#2>denovo28    HNS.6_14948 HNS.6_148211    HNS.11_327521
#3>denovo62    HNS.7_468475    HNS.7_631780
#4>denovo897   WNA.2_58410 WNA.1_175071
#5>denovo621   WNA.2_20180 WNA.2_294219
#6>denovo622   CES.1_24310 HNS.6_26786
#---------------- pipe -------------
#denovo621   WNA.2_20180 WNA.2_294219

	}

deepest () { 
#This one goes to the deepest directory starting from current directory - cwd
cd "$(find $PWD -type d -printf '%d:%p\0' |sort -z -t: -r |awk -F: -v RS='\0' -v ORS='\n' 'NR==1{print $2}')"; 
# You can print the top 3 of deepest dirs using something like
# find $PWD -type d -printf '%d:%p\0' |sort -z -t: -r |awk -F: -v RS='\0' -v ORS='\n' 'NR<=3' 
# %d represents the depth of each dir found (starting from pwd)
# %p prints the name of the result
# You can go back to cwd using cd $OLDPWD
	}


function lsnum { 
echo "lsnum: Counts the files in the location provided ($1)" >&2
[[ -z $1 ]] && local d=$PWD || local d=$1
local filesfound=$(find $d -maxdepth 1 -type f |wc -l)
local linksfound=$(find $d -maxdepth 1 -type l |wc -l)
local dirsfound=$(find $d -maxdepth 1 -type d |wc -l)
echo "Folder: $(readlink -f $d)" #resolves the literal sent ./directory or just directory to full dir path
echo "Files: $filesfound" 
echo "SymLinks: $linksfound"
echo "Dirs: $(($dirsfound-1))" #Find reports (and wc count) also the directory send to be searched 
#find is preferred over ls for various reasons:
# in dirs, ls fails to catch the hidden ones.
# in files, ls might fail to catch filenames with strange chars in name (spaces,tabs,newlines,etc)
}

function lsdir { 
# List only directories
# TBD: Make it work with globs like tmp*
[[ -z "$1" ]] && local d="$PWD" || local d="$1"
[[ "${d: -1}" != "/" ]] && d="${d}/" #if last char is not a dash, add a dash
ls -allh "$d" |grep '^d' 
#-h: show size in human format 
#alternative : find "$d" -maxdepth 1 -type d |column
}

function dpkginfo { dpkg -L "$1" |nl;}  #prints files installed by a package with numbering of the entries.

function printarray () { 
echo "printarray: Prints array $1 as stored in bash environment "
# ab=( "one" "two" "fi ve" );printarray --> please provide a var
# printarray ab
# [0]="one
# [1]="two
# [2]="fi ve" #works even with space in array values
[[ -z $1 ]] && echo "Provide an array name (without \$) to display " && return
#declare -p $1 |sed "s/declare -a $1=(//g; s/)$//g; s/\" \[/\"\n\[/g" #Only valid in GNU Sed -not working in BSD
declare -p $1 | perl -pe "s/declare -[aA] $1=\(//g; s/\)$//g; s/\" \[/\"\n\[/g" #works even in BSD
#This works because when array is defined in main bash shell , the array is also accessible by the functions


#Alternative:
#function printarray { for k in $(eval echo "\${!$1[@]}");do printf '%s' "$1[${k}]="; eval echo "\${$1[$k]}";done; }

#Tip: 
#Shell quick printing: for key in "${!array[@]}";do echo "array[$key]=${array[$key]}";done
#using ${!array[@]} syntax we can loop over array KEYS/INDEX
}

function mandiff { 
echo "mandiff: Compare installed man pages $1 vs the online man page at maniker.com"
[[ -z $1 ]] && echo "manpage missing " && return
[[ $(man -w "$1" 2>/dev/null) == "" ]] && echo "no valid manpage found for $1" && return
#mandiff = compare with diff an installed man page with online one by mankier.com
diff -y -bw -W 150 <(links -dump "https://www.mankier.com/?q=$1" |less |fold -s -w 70) <(man $1 |less |fold -s -w 70)
}

function lsdeb () { 
	echo "lsdeb: Displays contents of the .deb file (without downloading in local hdd) corresponding to an apt-get install $1 . Use --nd to exclude directories"
	[[ -z $1 ]] && echo "apt pkg file missing " && return
	local tmpdeb=$(apt-get --print-uris download $1 2>&1 |cut -d" " -f1)
	tmpdeb=$(echo "${tmpdeb: 1:-1}")
	echo "$tmpdeb"
	if [[ $2 == "--nd" ]];then
	    dpkg -c <(curl -sL -o- $tmpdeb) |grep -v '^d' #--nd excludes directories from listing
	else
	    dpkg -c <(curl -sL -o- $tmpdeb)
	fi


}

function debcat () {
	echo "debcat: Extracts and displays a specific file from a .deb package (without downloading in local hdd) corresponding to an apt-get install $1." 
	echo "Use --list switch to force a deb listing of all files or --listnd to force listing excluding directories"
	echo "Use --ind switch to be prompted will all files found excluding directories and links"
	echo "Combine --all after --ind to force index to include binary files like .so,.mo,.ko,etc -excluded by default"
    echo 
	[[ -z $1 ]] && echo "apt pkg file missing " && return
	[[ -z $2 ]] && echo "file to display is missing for pkg $1" && return
	[[ $2 == "--list" ]] && echo "--list selected - perform deb listing - all other options ignored" && lsdeb "$1" && return 0
	[[ $2 == "--listnd" ]] && echo "--listnd selected - perform nd listing - all other options ignored" && lsdeb "$1" "--nd" && return 0
	echo "$2 selected" && echo
	local tmpdeb=$(apt-get --print-uris download $1 2>&1 |cut -d" " -f1)
    tmpdeb=$(echo "${tmpdeb: 1:-1}") #remove the first and last char which are a single quote '
    #clear
    echo "deb package: $tmpdeb"


	if [[ $2 == "--ind" ]];then
	    unset flist ms loop key
        loop=1
	    if [[ "$3" == "--all" ]];then
			flist+=($(curl -sL -o- $tmpdeb |dpkg -c /dev/stdin |grep -v -e '^l' -e '^d' |grep -vE "\/$" |awk '{print $NF}'))
	    else
			flist+=($(curl -sL -o- $tmpdeb |dpkg -c /dev/stdin |egrep -v -e '^l' -e '^d' -e '.mo' -e '.so' -e '.ko' -e '\/$' |awk '{print $NF}'))  #-e '\/bin\/' 
	    fi
	    declare -p flist |sed 's/declare -a flist=(//g' |tr ' ' '\n' |sed 's/)$//g'
	    while [[ $loop -eq 1 ]]; do
			read -p "Select file to display by id or  q to quit : " ms
			[[ "$ms" == "q" ]] && echo "exiting...." && return
			if [[ ${flist[$ms]: -3} == ".so" ]] || [[ ${flist[$ms]: -3} == ".mo" ]] || [[ ${flist[$ms]: -3} == ".ko" ]];then #|| [[ ${flist[$ms]} =~ "/bin/" ]]
				echo "We Cannot Display ${flist[$ms]} since it is a binary file"
			elif [[ $ms -gt $((${#flist[@]}-1)) ]]; then
				echo "out of range - try again"
			else
				#read -n1 -p "Display ${flist[$ms]} - Press any key to continue or q to return...   " key && echo
				echo "proceeding with ${flist[$ms]} "
				if [[ ${flist[$ms]} =~ "man/man" ]]; then 
				   curl -sL -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${flist[$ms]} |man /dev/stdin 
				elif [[ ${flist[$ms]: -3} == ".gz" ]]; then
				   curl -sL -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${flist[$ms]} |gunzip -c |sed "1i ${flist[$ms]}" |less
				else 
				   curl -sL -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${flist[$ms]} |sed "1i ${flist[$ms]}" |less
				fi
			fi
		done
        return
	fi	


	local debfile="$2"
    echo "deb file to display:  $debfile"
    if [[ "$debfile" =~ "man/man" ]];then
	    curl -sL -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO "$debfile" |man /dev/stdin
	elif [[ "${debfile: -3}" == ".gz" ]];then #last three chars
	    curl -sL -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO "$debfile" |gunzip -c |sed "1i $2" |less
	elif [[ ${debfile: -3} == ".so" ]] || [[ ${debfile: -3} == ".mo" ]];then #|| [[ ${debfile} =~ "/bin/" ]];then 
		echo "We Cannot Display ${debfile} since it is a binary file"
	else
	    curl -sL -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO "$debfile" |sed "1i $2" |less
	fi

}

function aptshowlight() { 
echo "aptshowlight: It is apt show $1 but in light version , giving only Package name and short description"
[[ -z $1 ]] && echo "Package missing " && return
#aptshowlight : runs apt show on given arg $1 , and prints only package name, section and Description. Combine with yadit.
#notice that if you specify to -A (after context) more lines than really available the results are not correct.
apt show $1 2>/dev/null |grep -A2 -e "Package:" -e "Description:" |grep -v -e "Version\|Priority\|Maintainer\|Installed-"
}

function aptshowsmart() { 
echo "aptshowsmart: apt show $1 in a smart way , using less pager"
[[ -z $1 ]] && echo "Package missing " && return
local ass+=$(apt list $1 2>/dev/null |grep -v "Listing" |sed "s#\\n# #g" |cut -d/ -f1)
apt show $ass |less
}

function debman { 
echo "debman: debian man pages online of package $1"
[[ -z $1 ]] && echo "Pass me a package to query debian manpages" && return
#debman uses the 2017 new web page with jump option
links -dump https://manpages.debian.org/jump?q=$1 |awk "/Scroll to navigation/,0" |less
}


function wiki() { 
echo "wiki: Returns wikipedia $@ entries in terminal"
[[ -z $1 ]] && echo "Pass me a page to search WikiPedia " && return
#dig +short txt $1.wp.dg.cx #This uses dig (apt install dnsutils) and does not work.
local q="$@"
links -dump "https://en.wikipedia.org/w/index.php?search=$q" |less
# better to use $@ that parses all args together ; Otherwise the arg red hat is passed as $1=red and $2=hat (or it has to be quoted)
}

function dircat() { 
echo "dircat: directory cat - cat files within directory $1, excluding subdirs unless --full is given"
[[ -z $1 ]] && echo "Pass me a directory to cat files" && return
[[ -d $d ]] && local d="$1" || local d=( "$@" ) #If files provided , store them in a array
#[[ ! -d $d ]] && echo "$d   is not a directory - for regular file just use less" && return #disabled 24 Sep evening to allow single files
echo "${d[@]}"
[[ -d $d ]] && [[ "${d: -1}" != "/" ]] && d="${d}/" #if a directory was given and if last char is not a dash then add a trailing dash
[[ -d $d ]] && echo "directory to scan and print= $d"

if [[ -d $d ]] && [[ "$2" == "--full" ]];then 
  echo "Will go inside subdirs! Maybe gonna be long time to finish this..." 
  local depth=""
elif [[ -d $d ]] && [[ "$2" == "--two" ]];then 
  echo "Will go inside subdirs level2! Maybe gonna be long time to finish this..." 
  local depth=" -maxdepth 2"
else
  echo "Will not go inside subdirs" 
  local depth=" -maxdepth 1"
fi

	#for f in /sys/class/power_supply/BAT0/*;do echo "$f";cat "$f";done #this works but it does not go inside sub dirs
	#find "$d" -type f -exec bash -c 'echo "File: $0";cat "$0"' {} \; #this one worked somehow ok
	echo -e ".ce 2\n#-!#dcat file contents of directory $d\n\n\n-" >/tmp/.__tmpcont
	find "${d[@]}" $depth -type f -exec bash -c '[[ "$0" != "/proc/kmsg" && "$0" != /proc/kpage* && "$0" != *pagemap* ]] \
	                                          && [[ $(file "$0") == *"ASCII"* || $(file "$0") == *"empty"* ]] \
	                                          && echo "$0 --> /tmp/.__tmpconf" && echo -e "#-!#File: $0\n$(cat "$0")" >>/tmp/.__tmpcont ' {} \;
	#make sure that file found is an ASCII file to avoid perform cat on binaries and pics
	# using find ${d[@]} will work with globbing like file* and also with one entry like a simple directory
	man --nj --nh <(local h=".TH man gv 2017 1.0 dcat";sed "s/^$/\.LP/g; s/^#-!#/\.SH /g;G" /tmp/.__tmpcont |sed 's/^$/\.br/g; s/\\/\\e/g;' |sed "1i $h")
	rm -f /tmp/.__tmpcont
	#Call the man as pager to display files contents. Man formatting is necessary: 
	#File must be double spaced and empty lines to be replaced with .BR. 
	#Existed line breaks will be substitued by .LP = new paragraph 
	#Lines starting with #-!# will be Headers (.SH)
	#man header to be inserted in the beginning of the file = before first line
	#backslashes must be man escaped : \ becomes \e (also \\ works for man)

}

function findexec {
echo "findexec: find executable files under directories of /. Double quotes on file name is MANDATORY"
[[ -z $1 ]] && echo "Pass me a file name to look for executable files under / dir" && return
local fname=("$1")
echo "arg=$fname"
#for $1=*grep* search for all combinations: *grep* , grep*,*grep,grep
#[[ "${fname:0:1}" == "*" ]] && fname+=("${fname:1}") #if starts with * remove it and add it as a saparate search term
#[[ "${fname: -1}" == "*" ]] && fname+=("${fname:0:-1}") #if ends with * remove it and add it to array
#[[ "${fname:0:1}" == "*" ]] && [[ "${fname: -1}" == "*" ]] && fname+=("${fname:1:-1}") #if first and last char is * remove them
#for f in "${fname[@]}";do find / -type f -executable -name "$f";done 
find / -type f -executable -name "$fname"
}

function mancheat { 
echo "mancheat: explore the cheat sheets using man page viewer"
[[ -z $1 ]] && echo "Pass me a cheat file name to display from ./cheatsheets/ directory" && return
	man --nj --nh <(h=".TH man 1 2017 1.0 $1-cheats";sed "s/^${1^^}:/.SH ${1^^}:/g; s/^$/\.LP/g; s/^##/\.SS /g;G" /home/gv/Desktop/PythonTests/cheatsheets/${1,,}*gv.txt |sed 's/^$/\.br/g; s/\\/\\e/g;' |sed "1i $h");
#This works directly in cli:
#man --nj <(h=".TH man 1 "2017" "1.0" cheats page";sed "1i $h" cheatsheets/utils*gv.txt |sed 's/^UTILS:/.SH UTILS:/g; s/^$/\.LP/g; s/^##/\.SS /g; s/\\/\\\\/g;G' |sed 's/^$/\.br/g')
}

function dtoe {
echo "dtoe: convert date to epoch. Send a date or pipe me a date in format 14/Feb/2017:11:31:20" >&2
# The help message is printed on stderr (&2). In command line run will be printed on screen. 
# On script run $(..) mode only the returned converted date result is stored in $(..), not the help message, since scripts hold only stdout , unless they include 2>&1
[[ -z $1 ]] && local dt=$(</dev/stdin) || local dt="$1" #if $1 is empty, use dev/stdin = work like a pipe. Otherwise use $1
echo "Date to be converted = $dt" >&2
date -d "$(echo $dt | sed -e 's,/,-,g' -e 's,:, ,')" +"%s"
}

function toascii {
[[ -z $1 ]] && local st=$(</dev/stdin) || local st="$1" #if $1 is empty, use dev/stdin = work like a pipe. Otherwise use $1
#Not tested alternatives:
#FILE=$1;if [ ! -z "$FILE" ]; then exec 0< "$FILE";fi
#file="${1}";if [ "${file}" = "-" ] ; then file=/dev/stdin;fi # "toascii -" to read from terminal OR "cmd | toascii -" for pipe or "toascii file" 
echo "Warning : Possible null chars have been removed by bash. Pipe to od -tx1c instead"
echo -e "Var:\c";echo "$st" | od -w40 -An -tc
echo -e "Dec:\c";echo "$st" | od -w40 -An -tu1 
echo -e "Oct:\c";echo "$st" | od -w40 -An -to1 
echo -e "Hex:\c";echo "$st" | od -w40 -An -tx1c |sed -n '1p'
#Also this works: od -An -t uC
}


function dupes {
echo "dupes: Find duplicate files under cwd , including subdirectories. Pipe to grep to limit the results returned" >&2
#Limit results with grep : $ dupes |grep '\.txt' # escape dot to be treated literally as dot instead of regex
[[ -z $1 ]] && echo "Current Working Directory ($PWD) will be used." && local dn="$PWD" || local dn="$1"
if [[ "$dn" == "/" ]];then
	read -p "Are you sure you want to search all directories under / ?" rep
	[[ "$rep" =~ ^[nN] ]] && return
fi	

echo "Directory to Examine=$dn"
while IFS= read -r -d '' res;do local fn+=( "$res" );done < <(find "$dn" -print0)
dupes=$(LC_ALL=C sort <(printf '\<%s\>$\n' "${fn[@]##*/}") |uniq -d)
grep -e "$dupes" <(printf '%s\n' "${fn[@]}")  |awk -F/ '{print $NF,"==>",$0}' |LC_ALL=C sort

#In bash 4.4 You can also use IFS= readarray -t -d '' fn< <(find . -print0)
#Before bash 4.4 , readarray does not accept -d (delimiter) option
#You can also allow a $2 for filename pattern , and thus convert fine to find "$dn" -name $2 -print0

#awk alternative:
# find $PWD -name '*.txt' -printf '%f %h\n' |awk '{d[$1]++;f[$1]=f[$1] "--" $2}d[$1]>=2{print $1,":",f[$1]}'
# a.txt : --/home/gv/Desktop/PythonTests/tmp--/home/gv/Desktop/PythonTests/tmp2
# b.txt : --/home/gv/Desktop/PythonTests/tmp--/home/gv/Desktop/PythonTests/tmp2
# file1.txt : --/home/gv/Desktop/PythonTests--/home/gv/Desktop/PythonTests/tmp2
}

function lsadv {
set -f
echo "lsadv = ls advanced using find - similar output to ls -all. Includes octal file permissions." 
echo "Use -d for directories , -f for full depth"

local p d f
#echo "$@"
[[ $1 == "-d" ]] && d="-type d" && shift || d=""
[[ $1 == "-f" ]] && f="" && shift || f="-maxdepth 1"
[[ -z $1 ]] && p="./" || p=( "$@" )
#echo "${p[@]}"
echo -e "Permissions\t| group\t| user\t| size\t| Change Time\t\t\t| Name"
printf '%.s-' {1..130} 
echo
find "${p[@]}" $d $f -printf '%M (%m) | %g\t| %u\t| %s\t| %Cb %Cd %CY %Cr\t| %p\n' | LC_ALL=C sort -t '|' -k1.1,1.2r -k6.1
#sort k1.1,1.2r : sort at first char of first field in reverse order ==> links first, directories then, files last
#sort k6 : then sort by last column = filename
set +f
}



#TODO
# make a function manit to work as pipe : contents=$(</dev/stdin) && man <(contents after man formatting) or man /dev/stdin
# You need to apply some defaults though. 
# For example Section Headers by default to be three ### or can be user defined by --sh=# for one #
# insert the header (also can be a switch --header="..")
# double space, line breaks, escape backslashes, preserve existing line breaks of input stream (treat as .LP)
# Potential bugs: If input stream has not ### sections?
# 

# Tips about functions usage as an alias and sourcing them to other scripts
# See all declared functions with 'set' - it will not be available in 'alias' command any more.
# Bash manual claims that is better to use direct functions instead of alias.
# You can declare just functions without alias and you can call those functions by terminal without problem.
# You can also export -f the function/s to be available in all childs/scripts.
# In this case you need to be sure that function names exported will not be redifined again (same name) in your scripts
# To list all the functions loaded by bash use 'declare' or 'set'

# Alternativelly you might source the whole .bash_aliases file into your script and have all function / aliases available in your script.
# In order alias to be available in a shell script it might be required to include 'shopt -s expand_aliases ' option inside your script.
# According to man bash this option is ON by default for interactive shells (also verified by shopt |grep alias)
# But since a script is considered a kind of non-interactive shell , the expand_aliases option has to be set in script to affect the script environment / subshell

# Instead of sourcing the whole file you can source part of the file with command substitution technique:
# Working example: source <(sed -n '/function justatest/,/\}/p' .bash_aliases) && justatest will use justatest in your separate external script.
# Another working example: eval "$(sed -n '/function justatest/,/\}/p' .bash_aliases)" && justatest
# Sed will work correctly if function is written in multi line format. For one liners doesnot work ok. Better to use grep.

# You can also source a particular alias in your scripts using:
# shopt -s expand_aliases &&  source <(sed -n "/function __debman/p" .bash_aliases) && debman agrep
# tested and works fine.
# Alternative that strips the alias part and keeps only the function part:
# sed -n "/alias debman/p" .bash_aliases |awk -F="'|}" '{print $2"}"}'
