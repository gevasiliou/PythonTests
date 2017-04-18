# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly (~/.bashrc).
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
#if [ -f ~/.bash_aliases ]; then
#    . ~/.bash_aliases
#fi
#Remark: .bashrc of user has already above check condition but root .bashrc not.
#Install it using cp .bash_aliases /home/gv/ and cp .bash_aliases /root/ or cp .bash_aliases $HOME/ (under root terminal)
# You can import the recent aliases on the fly by running root@debi64:# . ./.bash_aliases

alias cd..='cd ..'
alias cls='clear'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias nocrap='grep -i -v -e .page -e .png -e .svg -e .jpg -e messages -e usr/share/man -e changelog -e log -e localle -e locale -e "/doc/"'
alias yadit='yad --text-info --center --width=800 --height=600 --no-markup --wrap'
#alias lsdir='ls -l -d */'
alias dirsize='du -b -h -d1'   #Combine with * or ./* to display also files. Use */ for subdirs
alias gitsend='git add . && git commit -m "update" && git push && git show --name-only'
alias bashaliascp='cp -i .bash_aliases /home/gv/ && cp -i .bash_aliases /root/'
alias update='apt-get update && apt-get upgrade && apt-get dist-upgrade'
alias printfunctions='set |grep -A2 -e "()"'
#alias weather='links -dump "http://www.meteorologos.gr/" |grep -A7 -m1 -e "Αθήνα"'
#lynx -dump "http://www.meteorologos.gr/" |awk '/Αθήνα/{a=1;next}a==1{print gensub(/(...)(..)(.*)/,"\\2 βαθμοί",1,$0);exit}' |espeak -vel+f2 -s130

alias weather='curl wttr.in/Μαρούσι'
alias hexit='od -w32 -An -t x1c -v'
alias man="LESS='+Gg' man"
#alias asciit='od -An -tuC'
#alias esc_single_quotes='sed "s|\x27|\x5c\x5c\x27|g"' #\x27 = hex code for single quote. \x5c = hex code for \
#alias esc_double_quotes=$'sed \'s|"|\\\\"|g\''

# ascii_table() { echo -en "$(echo '\'0{0..3}{0..7}{0..7} | tr -d " ")"; }
# Uses octal to build the whole ascii table

function teee { a="$(</dev/stdin)";echo -e "pipe in\n$a\npipe out\n" >/dev/stderr; echo "$a"; }

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
[[ -z "$1" ]] && local d="$PWD" || local d="$1"
[[ "${d: -1}" != "/" ]] && d="${d}/" #if last char is not a dash, add a dash
ls -all "$d" |grep '^d' 
#alternative : find "$d" -maxdepth 1 -type d |column
}

function dpkgnum { dpkg -L "$1" |nl;}  #prints info about a package with numbering of the entries.

function printarray () { 
echo "printarray: Prints indexed array $1 as stored in bash environment "
# ab=( "one" "two" "fi ve" );printarray --> please provide a var
# printarray ab
# [0]="one
# [1]="two
# [2]="fi ve" #works even with space in array values
[[ -z $1 ]] && echo "Provide an array variable to display" && return
#declare -p $1 |sed "s/declare -a $1=(//g; s/)$//g; s/\" \[/\n\[/g" #Only valid in GNU Sed
declare -p $1 | perl -pe "s/declare -a $1=\(//g; s/\)$//g; s/\" \[/\n\[/g" #Valid even in BSD
}

function mandiff { 
echo "mandiff: Compare installed man pages $1 vs the online man page at maniker.com"
[[ -z $1 ]] && echo "manpage missing " && return
[[ $(man -w "$1" 2>/dev/null) == "" ]] && echo "no valid manpage found for $1" && return
#mandiff = compare with diff an installed man page with online one by mankier.com
diff -y -bw -W 150 <(links -dump "https://www.mankier.com/?q=$1" |less |fold -s -w 70) <(man $1 |less |fold -s -w 70)
}

function lsdeb () { 
echo "lsdeb: Displays contents of the .deb file corresponding to an apt-get install package $1"
[[ -z $1 ]] && echo "apt pkg file missing " && return
local tmpdeb=$(apt-get --print-uris download $1 2>&1 |cut -d" " -f1)
tmpdeb=$(echo "${tmpdeb: 1:-1}")
dpkg -c <(curl -sL -o- $tmpdeb)
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

function dcat() { 
echo "dcat: directory cat - cat files within directory $1, excluding subdirs unless --full is given"
[[ -z $1 ]] && echo "Pass me a directory to cat files" && return
local d="$1"
[[ ! -d $d ]] && echo "$d   is not a directory - for regular file just use less" && return

[[ "${d: -1}" != "/" ]] && d="${d}/" #if last char is not a dash, add a dash
echo "directory to scan and print= $d"

if [[ "$2" == "--full" ]];then 
  echo "Will go inside subdirs! Maybe gonna be long time to finish this..." 
  local depth=""
elif [[ "$2" == "--two" ]];then 
  echo "Will go inside subdirs level2! Maybe gonna be long time to finish this..." 
  local depth=" -maxdepth 2"
else
  echo "Will not go inside subdirs" 
  local depth=" -maxdepth 1"
fi

	#for f in /sys/class/power_supply/BAT0/*;do echo "$f";cat "$f";done #this works but it does not go inside sub dirs
	#find "$d" -type f -exec bash -c 'echo "File: $0";cat "$0"' {} \; #this one worked somehow ok
	echo -e ".ce 2\n#-!#dcat file contents of directory $d\n\n\n-" >/tmp/.__tmpcont
	find "$d" $depth -type f -exec bash -c '[[ "$0" != "/proc/kmsg" && "$0" != /proc/kpage* && "$0" != *pagemap* ]] \
	    && [[ $(file $0) == *"ASCII"* || $(file $0) == *"empty"* ]] && \
	    echo "$0" && echo -e "#-!#File: $0\n$(cat "$0")" >>/tmp/.__tmpcont ' {} \;
	#make sure that file found is an ASCII file to avoid perform cat on binaries and pics 
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
	man --nj --nh <(h=".TH man 1 2017 1.0 $1-cheats";sed "s/^${1^^}:/.SH ${1^^}:/g; s/^$/\.LP/g; s/^##/\.SS /g;G" cheatsheets/${1,,}*gv.txt |sed 's/^$/\.br/g; s/\\/\\e/g;' |sed "1i $h");
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
