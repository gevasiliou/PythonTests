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
alias lsdir='ls -all |grep -E "^d"'
alias dirsize='du -h'
alias gitsend='git add . && git commit -m "update" && git push'
alias bashaliascp='cp -i .bash_aliases /home/gv/ && cp -i .bash_aliases /root/'

function dpkgnum { dpkg -L "$1" |nl;} #prints info about a package with numbering of the entries.

function printarray () { 
# ab=( "one" "two" "fi ve" );printarray --> please provide a var
# printarray ab
# [0]="one
# [1]="two
# [2]="fi ve" #works even with space in array values
if [ -z $1 ];then 
	echo "please provide a var"
else 
	declare -p $1 |sed "s/declare -a $1=(//g; s/)$//g; s/\" \[/\n\[/g"
fi
}

function mandiff { 
#mandiff = compare with diff an installed man page with online one by mankier.com
diff -y -bw -W 150 <(links -dump "https://www.mankier.com/?q=$1" |less |fold -s -w 70) <(man $1 |less |fold -s -w 70)
}

function lsdeb () { 
local tmpdeb=$(apt-get --print-uris download $1 2>&1 |cut -d" " -f1)
tmpdeb=$(echo "${tmpdeb: 1:-1}")
dpkg -c <(curl -sL -o- $tmpdeb)
}

function aptshowlight() { 
#aptshowlight : runs apt show on given arg $1 , and prints only package name, section and Description. Combine with yadit.
#notice that if you specify to -A (after context) more lines than really available the results are not correct.
apt show $1 2>/dev/null |grep -A2 -e "Package:" -e "Description:" |grep -v -e "Version\|Priority\|Maintainer\|Installed-"
}

function aptshowsmart() { 
local ass+=$(apt list $1 2>/dev/null |grep -v "Listing" |sed "s#\\n# #g" |cut -d/ -f1)
apt show $ass |less
}

function debman { 
#debman uses the 2017 new web page with jump option
links -dump https://manpages.debian.org/jump?q=$1 |awk "/Scroll to navigation/,0" |less
}


function wiki() { 
# wiki returns wikipedia entrys in terminal. 
#dig +short txt $1.wp.dg.cx #This uses dig (apt install dnsutils) and does not work.
links -dump "https://en.wikipedia.org/w/index.php?search=$@" |less
# better to use $@ that parses all args , otherwise the arg red hat is parsed as red (or must be double quoted)
}

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
