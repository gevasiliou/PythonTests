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

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias nocrap='grep -i -v -e .page -e .png -e .svg -e .jpg -e messages -e usr/share/man -e changelog -e log -e localle -e locale -e "/doc/"'
alias yadit='yad --text-info --center --width=800 --height=600 --no-markup --wrap'
alias lsdir='ls -all |grep -E '^d''
alias dirsize='du -h'
alias gitsend='git add . && git commit -m "update" && git push'
alias bashaliascp='cp -i .bash_aliases /home/gv/ && cp -i .bash_aliases /root/'
alias printarray='function _pa (){ if [ -z $1 ];then echo "please provide a var";else declare -p $1 |sed "s/declare -a $1=(//g; s/)$//g; s/\" \[/\n\[/g";fi; };_pa'
alias mandiff='function __mdf { diff -y -bw -W 150 <(links -dump "https://www.mankier.com/?q=$1" |less |fold -s -w 70) <(man $1 |less |fold -s -w 70); };__mdf'
#mandiff = compare with diff an installed man page with online one by mankier.com
alias lsaptonline='function __aso (){ local tmpdeb=$(apt-get --print-uris download $1 2>&1 |cut -d" " -f1); tmpdeb=$(echo "${tmpdeb: 1:-1}");dpkg -c <(curl -sL -o- $tmpdeb); } ;__aso'
alias aptshowlight='function __aptshowlight(){ apt show $1 2>/dev/null |grep -A2 -e "Package:" -e "Description:" |grep -v -e "Version\|Priority\|Maintainer\|Installed-"; };__aptshowlight'
#aptshow : runs apt show on given arg $1 , and prints only package name, section and Description. Combine with yadit.
#notice that if you specify to -A (after context) more lines than really available the results are not correct.
alias aptshowsmart='function __aptshowsmart(){ local ass+=$(apt list $1 2>/dev/null |grep -v "Listing" |sed "s#\\n# #g" |cut -d/ -f1);apt show $ass |less; };__aptshowsmart'
alias wiki='function __wiki() { dig +short txt $1.wp.dg.cx; };__wiki'
#wiki returns wikipedia entrys in terminal. Uses dig (apt install dnsutils)

:<<usage_of_printarray
root@debi64:/home/gv/Desktop/PythonTests# ab=( "one" "two" "fi ve" )
root@debi64:/home/gv/Desktop/PythonTests# printarray
please provide a var
root@debi64:/home/gv/Desktop/PythonTests# printarray ab
[0]="one
[1]="two
[2]="fi ve"

mind that this works even if there is space in the array elements , like "fi ve"
if you supply to printarray with a non valid variable, declare will complain (that is normal)
usage_of_printarray
