# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them directly το ~/.bashrc.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
#if [ -f ~/.bash_aliases ]; then
#    . ~/.bash_aliases
#fi
#
#Remark: .bashrc of user has already above check condition but root .bashrc not.
# Install it using cp .bash_aliases /home/gv/ and cp .bash_aliases /root/ or cp .bash_aliases $HOME/ (under root terminal)
# You can import the recent aliases on the fly by running root@debi64:# . ./.bash_aliases

#alias words='/usr/share/dict/words'

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/usr/local/sbin:/sbin:/usr/sbin
export MOZ_USE_XINPUT2=1 #firefox with touch events enabled: env MOZ_USE_XINPUT2=1 firefox &

#source mancolor
export LESS_TERMCAP_mb=$'\e[1;35m'
export LESS_TERMCAP_md=$'\e[1;35m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'
export MANPAGER='less -s -M +Gg'

alias bashalias-version="echo This is .bash_aliases version 2.2 , Last Updated 10.03.2024"

alias calculator='xcalc &'
alias mountandroid="sudo mount -t davfs http://192.168.2.6:8080 /home/gv/Desktop/andro"
alias gksu="pkexec --keep-cwd env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY" #gksu pkg that we used old days is obsolete by 2019.
alias grtranslate="trans :el" #you need to have apt install translate-shell 
alias lanip="ifconfig |grep 'inet[^6]'"
alias hdmisound="pacmd set-card-profile 0 output:analog-stereo && pacmd set-card-profile 0 output:hdmi-stereo+input:analog-stereo && pacmd list 2>&1 |grep 'active profile'"
alias laptopsound="pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo && pacmd list 2>&1 |grep 'active profile'"
alias ping="ping -c3"
alias winpid="echo -ne 'select window  to get pid...  ' && xprop _NET_WM_PID WM_CLASS | cut -d' ' -f3 |sed -z -e 's/\n/ - /1' -e 's/[\x22,]//g'"
##

alias screenreset='xrandr --output eDP-1 --off && sleep 20 && xrandr --output eDP-1 --auto && xrandr --output HDMI-2 --mode 1920x1080 --scale 1x1 --output eDP-1 --mode 1366x768 --scale 1x1 --left-of HDMI-2'
alias screenreset2='xrandr --output eDP-1 --scale 1.5x1.5 && sleep 5 && xrandr --output eDP-1 --scale 1x1'
alias scplegacy='scp -O -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa'
alias sshlegacy='ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa'
alias converttopng='convert -verbose -coalesce'
alias vpn='openfortivpn'
alias default="mimeopen -d" #usage : mimeopen -d file.pdf --> Will provide a menu to select & register default application for handling pdfs.
alias ipchicken="links -dump www.ipchicken.com |egrep -o '[0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}'"
alias cd..='cd ..'
alias cd..2='cd .. && cd ..'
alias cd-='cd $OLDPWD'
alias nano='nano -lmS' #-l enables line numbers | -m enables mouse support | -S smooth scroll (line by line)
alias less='less -N' #-N enables line number. Can be used also directly inside less to toggle line numbers on and off
alias cls='clear'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias nocrap='grep -i -v -e .page -e .png -e .svg -e .jpg -e messages -e usr/share/man -e changelog -e log -e localle -e locale -e "/doc/"'
alias maxpower='cpufreq-set -c 0 --min 2000000 --max 9000000 && cpufreq-set -c 1 --min 2000000 --max 9000000'
alias yadit='yad --text-info --center --width=800 --height=600 --no-markup &' #--wrap &'
#alias yadit='yad --text="$(</dev/stdin)" --center --wrap --no-markup --width=800 & disown'  #alternative: yad --text="$(cat -)"  # yadit alternative but without scroll bars and buttons
#alias lsdir='ls -l -d */'

alias gitsend='git add . && git commit -m "update" && git push && git show --name-only'
alias gitcancel='read -p "are you sure? [y/n]: " p;case "$p" in "y") git reset --hard HEAD~;;esac' #cancels the last local commit. You can also cancel 2 commits at once: git reset --hard HEAD~2
alias bashaliascp='cp -i .bash_aliases /home/gv/ && cp -i .bash_aliases /root/ && chown --verbose gv:gv /home/gv/.bash_aliases'
alias aptsourcescp='cp -i /etc/apt/sources.list /etc/apt/sources.backup && cp -i /home/gv/Desktop/PythonTests/sources.list /etc/apt/'
alias update='apt-get update && apt-get upgrade && apt-get dist-upgrade '
alias printfunctions='set |grep -A2 -e "()"'
alias wfr='( nmcli radio wifi off && sleep 10 && nmcli radio wifi on & )' #WiFiReset. Alternative: modprobe -r rtl8723be && sleep 10 && modprobe rtl8723be
#alias weather='links -dump "http://www.meteorologos.gr/" |grep -A7 -m1 -e "Αθήνα"'
#lynx -dump "http://www.meteorologos.gr/" |awk '/Αθήνα/{a=1;next}a==1{print gensub(/(...)(..)(.*)/,"\\2 βαθμοί",1,$0);exit}' |espeak -vel+f2 -s130

alias lsm='ls -l $@ && cd' #ls and move. Strange, but cd keeps the $@ and it works.
#Trick : ls -l /dir && cd $_ does the same job


alias weather="curl wttr.in/'Νέα Ερυθραία'" #/Μαρούσι
alias hexit='od -w40 -An -t x1c -v'
#alias man="LESS='+Gg' man" #This one goes to end of man page and then back to beginning , forcing less to count the man page lines
#alias man replaced by export MANPAGE in the beginning of this document 22.10.23

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

#alias dirsize='df -h / && du -b -h -d1 |sort -rh'   #Combine with * or ./* to display also files. Use */ for subdirs or even */*/ for subdirs

alias changelog='apt-get changelog'

function md2man {
	[[ -z "$1" ]] || [[ $1 == "--help" ]] && echo "usage: md2man <md-file>, which runs \"man -l <(pandoc -s -f markdown -t man \$1)\"" && return 1 
	man -l <(pandoc -s -f markdown -t man "$1") 
}

function note {
fname="$1"
while :
do
title="YadNotes - $fname"
txttosave=$(yad --title="$title" --text-info --filename="$fname" --editable --wrap --width=500 --height=500 --center --button=gtk-save:10 --button='Exit':20 --button='Open':30 2>/dev/null)

case $? in
10) #echo "gtk-save selected"
    fnametosave=$(yad --file --filename="$fname" --save --center --title='Select File To Save your notes' 2>/dev/null)
    [[ $? -eq 1 ]] && continue ##If cancel was pressed on file save dialogue
    [[ "$fname" == "$fnametosave" ]] && yad --text="This file exists. Overwrite?" --button=gtk-ok --button=gtk-cancel
    case $? in
    1) continue;;
    0) [[ ! -z "$fnametosave" ]] && echo "$txttosave" > "$fnametosave" || yad --text="No Filename - No Save"
    [[ ! -z "$fnametosave" ]] && fname="$fnametosave"
    ;;
    esac  
    #if file name to save is NOT empty then assign it to fname. 
    #If fnametosave is empty then no action - the previous fname (if set i.e by fnametoopen) will be preserved.

    #break
    ;;
20) #echo "Exit selected"
    break
    ;;
30) #echo "Open Button Pressed"
    fnametoopen=$(yad --file --center --title='Open Notes File' 2>/dev/null)
    [[ ! -z "$fnametoopen" ]] && fname="$fnametoopen"  #if file name to open is NOT empty then assign it to fname
    ;;
esac
done

}
alias notes='note &'

function aptlog {
l=$(awk '/Log started/{a=NR}END{print a}' /var/log/apt/term.log);awk -v l=$l 'NR==l || (NR>l && /^Unpacking/&& NF)' /var/log/apt/term.log |less
}

#alias networkreset="sudo systemctl restart NetworkManager.service && ifconfig" #for some reason this switches on and off the network, but IP is not changing!
#also you can try this: "systemctl restart networking.service" 

function networkreset {
read -p "Restarting network interfaces... press 'n' to skip, 'y' to proceed: " an
#[[ "$an" == "n" ]] && return 1  
    if [[ "$an" == "y" || "$an" == "Y" ]];then
        # Populate the array
        mapfile -t ifce <<<"$(ifconfig | grep 'RUNNING' | grep -v 'lo[:]' | awk -F':' '{print $1}')"
        # alternative : ifce+=( $(ifconfig | grep 'RUNNING' | grep -v 'lo[:]' | awk -F':' '{print $1}') )
        # alternative is not suggested due to that splitting will take place using IFS value (space, tab, newline) meaning that if the command output has spaces it will mess up the array.
        # on the otherhand , mapfile with -t switch will only use newline as delimiter and not IFS value.
        # Iterate through the array elements
        for interface in "${ifce[@]}"; do
            echo "Processing interface: $interface"
            sudo ifconfig "$interface" down
            sleep 5
            echo "Interface $interface stopped"
        done
        sleep 5
        echo "Restarting Interfaces"
        for interface in "${ifce[@]}"; do
            echo "Processing interface: $interface"
            sudo ifconfig "$interface" up
            sleep 5
            echo "Interface $interface started"
            ifconfig "$interface" |grep 'inet'
        done
    fi
read -p "Restarting squid proxy... press 'n' to skip, 'y' to proceed: " q
#[[ "$q" == "n" ]] && exit
    if [[ "$q" == "y" || "$q" == "Y" ]];then
        echo "Restarting Squid Proxy...please wait"
        sudo systemctl stop squid
        sleep 3
        sudo systemctl start squid
        sudo systemctl status squid
    fi
}


function asciifrom {
#https://gchq.github.io/CyberChef
#https://tools.ietf.org/html/rfc4648
#https://en.wikipedia.org/wiki/Base32
#https://unix.stackexchange.com/questions/98948/ascii-to-binary-and-binary-to-ascii-conversion-tools
#https://www.linuxnix.com/convert-binaryhex-oct-decimal-linuxunix/
#https://www.dcode.fr/ascii-85-encoding 
#echo $((base#number)) : https://phoxis.org/2012/07/12/builtin-bash-any-base-to-decimal-conversion/
#TODO : 
# bacon , https://mothereff.in/bacon
# base62, https://base62.io/
# base36 , https://www.dcode.fr/base-36-cipher
# z-base32, 
# Commercial Enigma : https://cryptii.com/pipes/commercial-enigma
# https://pypi.org/project/enigmamachine/
#Enigma and rest of ciphers described in pycipher : https://pycipher.readthedocs.io/en/master/
#Anybase inlcuding base36 online (text to anybase): https://onlineutf8tools.com/convert-utf8-to-arbitrary-base
#MD5, SHA-1 , SHA-256, etc : https://cryptii.com/pipes/md5-hash
#substitution cipher: http://practicalcryptography.com/ciphers/simple-substitution-cipher/
[[ -z "$1" ]] || [[ $1 == "--help" ]] && echo "usage: asciifrom hex / slashedhex / bin / longbin / octal / base64 / base91 / base92 / rot 1 to 25 / rot47 / base32 / base32hex / base85nd [NoDelimiter] / base85 / ascii85 / base58 / base26-1 [start from 1] / base26-0 [start from 0]"
[[ $1 == "bin" ]] && perl -lape '$_=pack"(B8)*",@F';     #breaks if spaces are not present. Binary should be 8 digits.
#asciifrom bin returns the ascii letters corresponding to the binary input.
#actually binary number is converted to hex number and hex number is converted to corresponding ascii letter 
[[ $1 == "longbin" ]] && perl -lpe '$_=pack"B*",$_';     #breaks if spaces are present.Binary should be dividable by 8 i guess.
[[ $1 == "hex" ]] && xxd -r -p && echo                          #input in format with 2digit hex, no space between, like 4648....
#Remark: xxd -r -p returns the ascii text from the given hex valuer.
#for example echo "3635" |xxd -r -p  --> 65 = ascii char 6 (hex 0x36) and ascii char 5 (hex 0x35) and not the number 65.
#this is why we call it asciifrom hex. If you try to convert the number 65 (decimal) to hex , then it's hex value is 41. 
#or for hex number 41, the decimal number is 65. This is done with dec2hex and hex2dec functions which treats input as numbers.
[[ $1 == "slashedhex" ]] && sed 's/\\x//g; s/\\u//g' |xxd -r -p && echo   #input in format \x46\x68 ... Tip: Such an input can be viewed directly in bash using echo -e 'input'
#Tip: When input text is like \u48 this is equal to \x48
[[ $1 == "octal" ]] && sed 's/^/\\0/g; s/ /\\0/g' |echo -e $(</dev/stdin)
[[ $1 == "dec" ]] && perl -pe 's/ /\n/g' |while read -r line;do printf \\$(printf "%o\n" $line);echo;done |perl -pe 's/\n/ /g'
[[ $1 == "base32" ]] && base32 -id            #included in coreutils and basez pkg
[[ $1 == "base32hex" ]] && base32hex -g -d      #part of basez package. -g : ignore garbage in input
[[ $1 == "base64" ]] && base64 -id 
[[ $1 == "base85nd" ]] && base85 -ind         #you need the executable produced by this c program: https://raw.githubusercontent.com/roukaour/ascii85/master/ascii85.c
[[ $1 == "base85" ]] && base85 -id     #with delimiter . String starts with <~ and finishes with ~> (required by most ascii85
[[ $1 == "base58" ]] && base58 -d && echo #apt install base58
#base85 using perl (requires apt install libconvert-ascii85-perl
# echo ..... |perl -mConvert::Ascii85 -lpe '$_ = Convert::Ascii85::decode($_);'
# echo ..... |perl -mConvert::Ascii85 -lpe '$_ = Convert::Ascii85::encode($_);'

[[ $1 == "ascii85" ]] && sed 's/^/\<\~/g; s/$/\~\>/g' |ascii85 -d   #apt install ruby-ascii85. Runs with just ascii85. Sed adds <~ to the start, ~> in the end
[[ $1 == "base91" ]] && base91.py --decode   #make sure that base91.py exists in /usr/bin or in any other directory in the $PATH
[[ $1 == "base92" ]] && base92gv.py --decode   #make sure that base92gv.py exists in /usr/bin or in any other directory in the $PATH
#[[ $1 == "rot13" ]] && rot13.py --decode  #make sure that rot13.py exists in /usr/bin or in any other directory in the $PATH
[[ $1 == "base26-1" ]] && sed 's/10/j/g; s/11/k/g; s/12/l/g; s/13/m/g; s/14/n/g; s/15/o/g; s/16/p/g; s/17/q/g; s/18/r/g; s/19/s/g; s/20/t/g; s/21/u/g; s/22/v/g; s/23/w/g; s/24/x/g; s/25/y/g; s/26/z/g;' | sed 's/1/a/g; s/2/b/g; s/3/c/g; s/4/d/g; s/5/e/g; s/6/f/g; s/7/g/g; s/8/h/g; s/9/i/g'
[[ $1 == "base26-0" ]] && sed 's/9/j/g; s/10/k/g; s/11/l/g; s/12/m/g; s/13/n/g; s/14/o/g; s/15/p/g; s/16/q/g; s/17/r/g; s/18/s/g; s/19/t/g; s/20/u/g; s/21/v/g; s/22/w/g; s/23/x/g; s/24/y/g; s/25/z/g;' | sed 's/0/a/g; s/1/b/g; s/2/c/g; s/3/d/g; s/4/e/g; s/5/f/g; s/6/g/g; s/7/h/g; s/8/i/g'

if [[ $1 == "combo" ]];then
        g="$(</dev/stdin)";
        echo "base64 -id"; 
        echo "$g" |base64 -id;
        echo "base64 -id | base64 -id"; 
        echo "$g" |base64 -id |base64 -id;
        read -p 'next';
        echo "base64 -id| base32 -id";
        echo "$g" |base64 -id |base32 -id;
        read -p 'next';
        echo "base64 -id| base85 -id";
        echo "$g" |base64 -id |base85 -ind;
        read -p 'next';
        echo "base32 -id";
        echo "$g" |base32 -id;
        echo "base32 -id| base64 -id";
        echo "$g" |base32 -id |base64 -id;
        read -p 'next';
        echo "base32 -id| base32 -id";
        echo "$g" |base32 -id |base32 -id;
        read -p 'next';
        echo "base32 -id| base85 -ind";
        echo "$g" |base32 -id |base85 -ind;
        read -p 'next';
        echo "base85 -ind";
        echo "$g" |base85 -ind;
        echo "base85 -ind| base64 -id";
        echo "$g" |base85 -ind |base64 -id;
        read -p 'next';
        echo "base85 -ind| base32 -id";
        echo "$g" |base85 -ind |base32 -id;
        read -p 'next';
        echo "base85 -ind| base85 -ind";
        echo "$g" |base85 -ind |base85 -ind;
        read -p 'next';
fi

case $1 in 
#"rot13") rot13.py --decode;;
"rot1") tr 'b-za-aB-ZA-A' 'a-zA-Z';; #Rotates by -1 = 1 letter back => a becomes z. Equivalent to 25 letters in front.
"rot2") tr 'c-za-bC-ZA-B' 'a-zA-Z';; #-2 letters back (or +24 letters)
"rot3") tr 'd-za-cD-ZA-C' 'a-zA-Z';; #Ceasar Cipher
"rot4") tr 'e-za-dE-ZA-D' 'a-zA-Z';;
"rot5") tr 'f-za-eF-ZA-E' 'a-zA-Z';;
"rot6") tr 'g-za-fG-ZA-F' 'a-zA-Z';;
"rot7") tr 'h-za-gH-ZA-G' 'a-zA-Z';;
"rot8") tr 'i-za-hI-ZA-H' 'a-zA-Z';;
"rot9") tr 'j-za-iJ-ZA-I' 'a-zA-Z';;
"rot10") tr 'k-za-jK-ZA-J' 'a-zA-Z';;
"rot11") tr 'l-za-kL-ZA-K' 'a-zA-Z';;
"rot12") tr 'm-za-lM-ZA-L' 'a-zA-Z';;
"rot13") tr 'n-za-mN-ZA-M' 'a-zA-Z';;
"rot14") tr 'o-za-nO-ZA-N' 'a-zA-Z';;
"rot15") tr 'p-za-oP-ZA-O' 'a-zA-Z';;
"rot16") tr 'q-za-pQ-ZA-P' 'a-zA-Z';;
"rot17") tr 'r-za-qR-ZA-Q' 'a-zA-Z';;
"rot18") tr 's-za-rS-ZA-R' 'a-zA-Z';;
"rot19") tr 't-za-sT-ZA-S' 'a-zA-Z';;
"rot20") tr 'u-za-tU-ZA-T' 'a-zA-Z';;
"rot21") tr 'v-za-uV-ZA-U' 'a-zA-Z';;
"rot22") tr 'w-za-vW-ZA-V' 'a-zA-Z';;
"rot23") tr 'x-za-wX-ZA-W' 'a-zA-Z';;
"rot24") tr 'y-za-xY-ZA-X' 'a-zA-Z';;
"rot25") tr 'z-za-yZ-ZA-Y' 'a-zA-Z';;
"rot47") tr 'P-~\!-O' '\!-~' ;;
esac

#Jolanda Challenges:
#for a string a="VjVLSjZNT1pSTzRKNjVXTlpTSlQyMzNHQkREVVYyUVNCV0ZGNFZWWFZTM0pYNDNDQUlGRjRZRU5PV1JUWDRHU1JPNEo2NVdOQU9ES1pNV05aUkRUTDJZQkFaRFRaNEdDQUhEUlYzM0hCNUZKUDJNQlJOU1JUMzNEQ1JEVVYyUVdCWkRVTjJZUUJFMktSTVdOWlNLVFZWUURCSTJQTjJZSFJPSEo0VlFIQU9GRk5MM0NBSUpKWDNHSEJaS05IRFlCWkREVUYzM0lST0hUUDVHU1JPTUo2M1FKWklGUE41UVZBU01GTkwzVlpTSlRMTVlCWjVGRk5CRUFWREROSDJRSEJFTFVUQkVDUzVGVDY1UUtaSURKSllHUUE1SkY2NTNEU0lFSjYzR0haSUtVVlkzSUJPSlQ2TFlSQlpLSjJMWUhaSU1URkxZWkJaS0pCTVlIQkVISjRNTUFCQTJUUDRHSFpJRlAyNTNXQkVIUDI0M1ZBNUZUUDNFQVpJNEpYWVlIQTVLSkxZV0hTTUxUNE1MPQ=="
#decoded message is here: echo "$a" |base64 -d |rot13.py |base32 -d
#
#https://www.facebook.com/groups/Ethical.Hacking.Cyber.Secure/permalink/435511390415317/
#echo "$a" |asciifrom bin |base32 -d |rev |base85 -n -d
#
#https://www.facebook.com/groups/Ethical.Hacking.Cyber.Secure/permalink/430777217555401/
#echo "$a" |asciifrom bin |sed 's/[U+]//g' |asciifrom hex |asciifrom base32 |asciifrom base85nd

#https://www.facebook.com/groups/Ethical.Hacking.Cyber.Secure/permalink/440351073264682/
#1): 00110100 00110011 00110011 00110011 
#2): 43330263430213231302631313025303 (asciifrom bin of input)
#3): 36352033322031303420393720393920 (rev of step2)
#4): 65 32 104 97 99 107 101 114 32 (ascii chars from hex - treat step3 as hex number)
#5): Output (decimals of step4 to ascii)
#echo "$a" |asciifrom bin |rev |sed 's/../& /g' |hex2dec |dec2ascii |perl -pe 's/\n//g' |dec2ascii |perl -pe 's/\n//g'

#https://www.facebook.com/groups/Ethical.Hacking.Cyber.Secure/permalink/444441176189005/
#1.) 00111000 00110010 00111000 00111000 00110100 00110101
#2.) 828845884 844575810 593174889 1131292774 1126903354
#3.) 1g/<2W4B#[!iCn(fC+.:VE+AaqE+q'QOBJgI#HuT]
#4.) ;flS`@;^!rEa`p#Gp$gB+EV:.+CT;4+E(j7BPD!kDJ(RE8TZ(bDf0
#5.) Solution ..
#echo "$a" |asciifrom bin |dec2hex |asciifrom hex |rev |base85 -nd
}

function asciito {
[[ -z "$1" ]] || [[ $1 == "--help" ]] && echo "usage: asciito hex / slashedhex / bin / longbin / octal / base64 / base91 / base92 /rot 1 to 25 / rot47 / base32 / base32hex / base85 / base85nd [NoDelimiter] / base58 / base26-1"
[[ $1 == "hex" ]] && xxd -p                            ##returns one big string with 2digit hex like 4648....
[[ $1 == "slashedhex" ]] && xxd -p |sed 's/../\\x&/g'  ##returns entries like \x46\x68 ...

[[ $1 == "bin" ]] && perl -lpe '$_=join " ", unpack"(B8)*"'
#bin alternative xxd -b |awk '{NF--;$1="";print}' |perl -pe 's/\n/ /g; s/^ //g' && echo #default: bin blocks of 8 bits . 
[[ $1 == "longbin" ]] && xxd -b |awk '{NF--;$1="";print}' |perl -pe 's/\n//g; s/^ //g; s/ //g' && echo #one big string without spaces. Alternative: perl -lpe '$_=unpack"B*"'
[[ $1 == "octal" ]] && od -b |awk '{$1="";print}' |sed 's/^ //g'
[[ $1 == "dec" ]] && perl -lpe '$_=join " ", unpack"(B8)*"' | perl -pe 's/ /\n/g' |while read -r line;do echo "obase=10; ibase=2; $line" |bc;done |perl -pe 's/\n/ /g' && echo #asciito bin|bin2dec
[[ $1 == "base32" ]] && base32         #included in coreutils and basez pkg
[[ $1 == "base32hex" ]] && base32hex   #part of basez package
[[ $1 == "base64" ]] && base64
[[ $1 == "base85" ]] && base85   #using base85.c executable. Equivalent to ruby ascii85 command from pkg ruby-ascii85
[[ $1 == "base85" ]] && base85 -n  #using base85.c executable. Without <~ in the start and without ~> in the end.
[[ $1 == "base58" ]] && base58  && echo
[[ $1 == "base91" ]] && base91.py   #make sure that base91.py exists in /usr/bin or in any other directory in the $PATH
[[ $1 == "base92" ]] && base92gv.py   #make sure that base92gv.py exists in /usr/bin or in any other directory in the $PATH
[[ $1 == "base26-1" ]] && sed 's/./& /g' |sed -r 's/j|J/10/g; s/k|K/11/g; s/l|L/12/g; s/m|M/13/g; s/n|N/14/g; s/o|O/15/g; s/p|P/16/g; s/q|Q/17/g; s/r|R/18/g; s/s|S/19/g; s/t|T/20/g; s/u|U/21/g; s/v|V/22/g; s/w|W/23/g; s/x|X/24/g; s/y|Y/25/g; s/z|Z/26/g;' | sed -r 's/a|A/1/g; s/b|B/2/g; s/c|C/3/g; s/d|D/4/g; s/e|E/5/g; s/f|F/6/g; s/g|G/7/g; s/h|H/8/g; s/i|I/9/g'
[[ $1 == "base26-0" ]] && sed 's/./& /g' |sed -r 's/j|J/9/g; s/k|K/10/g; s/l|L/11/g; s/m|M/12/g; s/n|N/13/g; s/o|O/14/g; s/p|P/15/g; s/q|Q/16/g; s/r|R/17/g; s/s|S/18/g; s/t|T/19/g; s/u|U/20/g; s/v|V/21/g; s/w|W/22/g; s/x|X/23/g; s/y|Y/24/g; s/z|Z/25/g;' | sed -r 's/a|A/0/g; s/b|B/1/g; s/c|C/2/g; s/d|D/3/g; s/e|E/4/g; s/f|F/5/g; s/g|G/6/g; s/h|H/7/g; s/i|I/8/g'
##[[ $1 == "rot13" ]] && rot13.py   #make sure that rot13.py exists in /usr/bin or in any other directory in the $PATH
case $1 in 
#"rot13") rot13.py;;
"rot1") tr 'a-zA-Z' 'b-za-aB-ZA-A';; #Rotates by +1 , go to next letter (a becomes b) or rotate -25 (25 letters back)
"rot2") tr 'a-zA-Z' 'c-za-bC-ZA-B';; #Rotates by +2 , go to next 2 letters (a becomes c)
"rot3") tr 'a-zA-Z' 'd-za-cD-ZA-C';; #Ceasar Cipher - rotate by 3
"rot4") tr 'a-zA-Z' 'e-za-dE-ZA-D';;
"rot5") tr 'a-zA-Z' 'f-za-eF-ZA-E';;
"rot6") tr 'a-zA-Z' 'g-za-fG-ZA-F';;
"rot7") tr 'a-zA-Z' 'h-za-gH-ZA-G';;
"rot8") tr 'a-zA-Z' 'i-za-hI-ZA-H';;
"rot9") tr 'a-zA-Z' 'j-za-iJ-ZA-I';;
"rot10") tr 'a-zA-Z' 'k-za-jK-ZA-J';;
"rot11") tr 'a-zA-Z' 'l-za-kL-ZA-K';;
"rot12") tr 'a-zA-Z' 'm-za-lM-ZA-L';;
"rot13") tr 'a-zA-Z' 'n-za-mN-ZA-M';;
"rot14") tr 'a-zA-Z' 'o-za-nO-ZA-N';;
"rot15") tr 'a-zA-Z' 'p-za-oP-ZA-O';;
"rot16") tr 'a-zA-Z' 'q-za-pQ-ZA-P';;
"rot17") tr 'a-zA-Z' 'r-za-qR-ZA-Q';;
"rot18") tr 'a-zA-Z' 's-za-rS-ZA-R';;
"rot19") tr 'a-zA-Z' 't-za-sT-ZA-S';;
"rot20") tr 'a-zA-Z' 'u-za-tU-ZA-T';;
"rot21") tr 'a-zA-Z' 'v-za-uV-ZA-U';;
"rot22") tr 'a-zA-Z' 'w-za-vW-ZA-V';;
"rot23") tr 'a-zA-Z' 'x-za-wX-ZA-W';;
"rot24") tr 'a-zA-Z' 'y-za-xY-ZA-X';;
"rot25") tr 'a-zA-Z' 'z-za-yZ-ZA-Y';;
"rot47") tr '\!-~' 'P-~\!-O' ;;
esac
}

function asciirotby {
case $1 in 
"1" | "+1" | "-25") tr 'a-zA-Z' 'b-za-aB-ZA-A';; #Rotates by +1 , go to next letter (a becomes b) or rotate -25 (25 letters back)
"2" | "+2" | "-24") tr 'a-zA-Z' 'c-za-bC-ZA-B';; #Rotates by +2 , go to next 2 letters (a becomes c)
"3" | "+3" | "-23") tr 'a-zA-Z' 'd-za-cD-ZA-C';; #Ceasar Cipher - rotate by 3
"4" | "+4" | "-22") tr 'a-zA-Z' 'e-za-dE-ZA-D';;
"5" | "+5" | "-21") tr 'a-zA-Z' 'f-za-eF-ZA-E';;
"6" | "+6" | "-20") tr 'a-zA-Z' 'g-za-fG-ZA-F';;
"7" | "+7" | "-19") tr 'a-zA-Z' 'h-za-gH-ZA-G';;
"8" | "+8" | "-18") tr 'a-zA-Z' 'i-za-hI-ZA-H';;
"9" | "+9" | "-17") tr 'a-zA-Z' 'j-za-iJ-ZA-I';;
"10" | "+10" | "-16") tr 'a-zA-Z' 'k-za-jK-ZA-J';;
"11" | "+11" | "-15") tr 'a-zA-Z' 'l-za-kL-ZA-K';;
"12" | "+12" | "-14") tr 'a-zA-Z' 'm-za-lM-ZA-L';;
"13" | "+13" | "-13") tr 'a-zA-Z' 'n-za-mN-ZA-M';;
"14" | "+14" | "-12") tr 'a-zA-Z' 'o-za-nO-ZA-N';;
"15" | "+15" | "-11") tr 'a-zA-Z' 'p-za-oP-ZA-O';;
"16" | "+16" | "-10") tr 'a-zA-Z' 'q-za-pQ-ZA-P';;
"17" | "+17" | "-9") tr 'a-zA-Z' 'r-za-qR-ZA-Q';;
"18" | "+18" | "-8") tr 'a-zA-Z' 's-za-rS-ZA-R';;
"19" | "+19" | "-7") tr 'a-zA-Z' 't-za-sT-ZA-S';;
"20" | "+20" | "-6") tr 'a-zA-Z' 'u-za-tU-ZA-T';;
"21" | "+21" | "-5") tr 'a-zA-Z' 'v-za-uV-ZA-U';;
"22" | "+22" | "-4") tr 'a-zA-Z' 'w-za-vW-ZA-V';;
"23" | "+23" | "-3") tr 'a-zA-Z' 'x-za-wX-ZA-W';;
"24" | "+24" | "-2") tr 'a-zA-Z' 'y-za-xY-ZA-X';;
"25" | "+25" | "-1") tr 'a-zA-Z' 'z-za-yZ-ZA-Y';;
esac
}

function binnegate { 
	sed 's/0/A/g; s/1/0/g; s/A/1/g'  #for a binary format of 01010101 returns 10101010
}

function bin2dec {
#this converts a number expressed in binary format to decimal number and not to it's ascii equivalent.
#different from bin2ascii (asciifrom bin) which converts binary to hex and then hex to ascii
#example:
#echo "00110110 00110011" |asciifrom bin  ---> 63        = the corresponding ascii letters 6 and 3
#echo "00110110 00110011" |bin2hex        ---> 36 33     = bin numbers converted to hex numbers. In any case 0x36 equals to ascii letter 6 and 0x35 equals to ascii letter 5
#echo "00110110 00110011" |bin2dec        ---> 54 51     = bin numbers converted to decimal numbers. In any case decimal number 54 corresponds to ascii letter 6 
#echo "54 51" |dec2hex                    ---> 36 33     = dec number 54 equals to hex number 36 and dec 51 equals to hex 33


perl -pe 's/ /\n/g' |while read -r line;do echo "obase=10; ibase=2; $line" |bc;done |perl -pe 's/\n/ /g'
echo
}

function dec2bin {
perl -pe 's/ /\n/g' |while read -r line;do echo "obase=2; ibase=10; $line" |bc;done	|perl -pe 's/\n/ /g'
echo
}
#--------------------------------------------------------------------------
function bin2hex {
#number converting , not bin to ascii but bin number to hex number.
perl -pe 's/ /\n/g' |while read -r line;do echo "obase=16; ibase=2; $line" |bc;done	|perl -pe 's/\n/ /g'
echo
}

function hex2bin {
tr 'a-z' 'A-Z' |perl -pe 's/ /\n/g' |while read -r line;do echo "obase=2; ibase=16; $line" |bc;done	|perl -pe 's/\n/ /g'
# .... | sed -r 's/.{8}/& /g' #every 8 chars insert a space
echo
}
#--------------------------------------------------------------------------
function dec2ascii {
#no direct method available- you go from dec number to octal number and then from octal number to ascii letter
#echo "54 51" |dec2ascii   --->  6 3    =  ascii letter 6 and ascii letter 3. Not the number 63. echo 54 51 |dec2hex returns hex number 36 33 

perl -pe 's/ /\n/g' |while read -r line;do printf \\$(printf "%o\n" $line);echo;done |perl -pe 's/\n/ /g'
echo
}

function ascii2dec {
asciito bin|bin2dec
}
#--------------------------------------------------------------------------

function dec2hex {
perl -pe 's/ /\n/g' |while read -r line;do echo "obase=16; ibase=10; $line" |bc;done	|perl -pe 's/\n/ /g'	
}

function hex2dec {
#bc can not handle lower case chars.
#also 
tr 'a-z' 'A-Z' |perl -pe 's/ /\n/g' |while read -r line;do echo "obase=10; ibase=16; $line" |bc;done	|perl -pe 's/\n/ /g'	
}
#--------------------------------------------------------------------------

function ascii2hex {
	hexit |awk '(!(NR%2 == 0))'
}

function killit {
[[ -z "$1" ]] && echo "no name given" && return
echo "those processes will be killed:"
ps -aux |grep -e "$1" |grep -v 'grep' 
read -p 'press any key to proceed or press q to quit: ' q
[[ $q != "q" ]] && kill -9 $(ps -aux |grep -e "$1" |grep -v "grep" |awk '{print $2}') || echo "cancelled"
}

function dirsize {
[[ -z "$1" ]] && d=$PWD || d="$1"	
echo "Disk Status:"
df -h /
echo
echo "Listing Directory Size of $d : "
du -b -h -d1 "$d" |sort -rh
}

function cinema {
echo "A youtube-dl automation script. Downloads from url, and open mpv to watch the video."
echo "Options:"
echo "  --url=<url> direct video link"
echo "  --openloadurl=<url> urls with hidden openload video link"
echo "  --nosave : do not keep local copy of the video in current working directory (default is to save the file)"
echo "  --getsubs: try to find openload vtt subs file"
echo "  --vlc: use vlc instead of default mpv. Combine with --buffer=XXX (in MB) to change the default buffer size (100MB)"
echo
unset videotowatch subflag movietitle videotowatch suburl subs

if ! which youtube-dl >/dev/null;then echo "you need to install youtube-dl";return 1;fi	
#if ! which mpv >/dev/null;then echo "you need to install mpv";return 1;fi	
if ! which curl >/dev/null;then echo "you need to install curl";return 1;fi	

#[[ -z $1 ]] && echo "no video url given.... exiting now. " && return 1

if printf '%s\n' "$@" |fgrep -- '--url=' >/dev/null;then
    videotowatch=$(printf "%s\n" "$@" |grep -- '--url=' |sed 's/--url=//')
else 
    if printf '%s\n' "$@" |fgrep -- '--openloadurl=' >/dev/null;then
      openloadlink=$(printf "%s\n" "$@" |grep -- '--openloadurl=' |sed 's/--openloadurl=//') #just remove --openload to get the url sent to function
      echo "openload link=$openloadlink"
      videotowatch=$(curl -s $openloadlink |tr ',>' '\n' |egrep -m1 -o 'http.*openload.[^ ]*' |sed 's/[\"]//g')
	  if [[ -z $videotowatch ]];then
		echo "[!!]First try to cath video url FAILED. Proceeding to second try to catch video url...."
		echo "[!!]First try was:"
		echo "[!!]curl -s $openloadlink |tr ',>' '\n' |egrep -m1 -o 'http.*openload.[^ ]*' |sed 's/[\"]//g"
		link2=$(curl -s $openloadlink |egrep -m1 'openload' |tr ' ' '\n' |egrep "http" |tr -d '\042\047()' ) ##&& echo "link2=$link2"
		videotowatch=$(curl -Ls "$link2" |tr ' ' '\n' |egrep -o 'http.*openload.*' |sed 's/[\"]//g')
	  fi
	fi
fi

echo && echo "video to watch=$videotowatch"
[[ -z $videotowatch ]] && echo "no valid video url/openload url given.... exiting now. " && return 1

#if [[ $2 == "--getsubs" ]];then
if printf '%s\n' "$@" |fgrep -- '--subs=' >/dev/null
then 
	suburl=$(printf "%s\n" "$@" |grep -- '--subs=' |sed 's/--subs=//')
	suburl=$(set +f && ls $suburl && set -f)
	echo "--subs option given... Trying to read subtitles file $suburl..." && echo
	subs="--sub-file=$suburl"
	#example: cinema --openloadurl=https://openload.co/f/NyTst2m1ELw --subs=$(ls /home/gv/*.srt)
else
	if printf '%s\n' "$@" |fgrep -- '--getsubs' >/dev/null;then 
	  echo "--getsubs option given... Trying to get subtitles..." && echo && subflag=1
	  suburl=$(getsubsurl "$videotowatch")
	  if [[ "$suburl" == "no vtt subs found" ]]; then 
		echo "no vtt subs found"
		return 1
	  else
		subs="--sub-file=$suburl"
	  fi
	fi
fi
# cinema --openloadurl=https://onlinemoviestar.xyz/seires/206209-law-and-order-special-victims-unit/seasons/14/episodes/1 --getsubs 
# gksu -u gv xdg-open https://www.watch-online.cc/tv-shows/tt0203259/law-and-order-special-victims-unit/season/14/episode/2/


#if printf '%s\n' "$@" |fgrep -- '--nosave' >/dev/null;then 
#  movietitle=""
#else
  movietitle="$videotowatch"
  movietitle="${movietitle##*/}" #from url https://openload.co/f/m6ZrSptAZ-E/Drkst.mp4 returns only last part=Drkst.mp4
  printf "%s\n" "Local file will be named $movietitle"
  [[ $subflag -eq 1 ]] && moviename="${movietitle%%.*}" && wget --quiet "$suburl" -O "${moviename}.vtt" && printf "%s" " and subs will be named ${moviename}.vtt" 
  #saving vtt subs. Play locally using mpv L* (video and subs start by letter L)
#fi
echo

if printf '%s\n' "$@" |fgrep -- '--vlc' >/dev/null;then
    if printf '%s\n' "$@" |fgrep -- '--buffer' >/dev/null;then 
      buffsize=$(printf "%s\n" "$@" |grep -- '--buffer=' |sed 's/--buffer=//')
      buffsize=$((buffsize*1000000))
    else
      buffsize=100000000 #100Mbyte default buffer size
    fi
    echo "vlc option is given. Buffer Size = $buffsize. Movie Title=$movietitle"
    read -p "press any key to start or press ctrl+c to exit"
    youtube-dl -q -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4' "$videotowatch" -o- |tee $movietitle |cat >/dev/null &
    sleep 30
    while [ $(find ./"$movietitle" -printf '%s\n') -lt $buffsize ]; do 
      printf '%s\r' "buffering $(ls -l "$movietitle" |cut -d' ' -f5) out of $buffsize" >/dev/tty;
      sleep 10;
    done
    vlc ./"$movietitle" 2>/dev/null &
    fg %1
    
else
  echo && echo "command to be executed:"
  echo "youtube-dl -v -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4' $videotowatch -o- |tee $movietitle |mpv $subs --force-seekable=yes -"
  read -p "press any key to start or press ctrl+c to exit"
  youtube-dl -v -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4' "$videotowatch" -o- |tee $movietitle |mpv $subs --force-seekable=yes -
fi
#alternative with vlc: 
#youtube-dl -v -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4' https://1fhjlub.oloadcdn.net/dl/l/iwiyD3ZGlPz7rf_a/lcCbgM8aHTM/Frozen.2013.BluRay.x264.Greek.mp4 -o- |vlc /dev/stdin
#or |vlc -
#vlc opens immediattely but this is not a problem. As soon as data arrive they are played on open vlc.

#if --save is not given , $movietitle is empty "" and actually piping to tee "" does nothing.

#youtube-dl -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4' "http://openload.co/embed/1AfWyTzfRcg/LwndrdrSVS1-1.avi" -o- |mpv --sub-file="https://thumb.oloadcdn.net/subtitle/1AfWyTzfRcg/sCt2OvM6F8Q.vtt" -
#[[ -z $(curl -s "http://openload.co/embed/1AfWyTzfRcg") ]] && echo problem || echo all good -->> returns problem, while https returns all good

#in most cases openload embed link is found on the main page:
#c=$(curl -s https://onlinemoviestar.xyz/seires/206209-law-and-order-special-victims-unit/seasons/13/episodes/18 |tr ',>' '\n' |egrep -o 'http.*openload.*' |sed 's/[\"]//g') && echo "$c"
#http://openload.co/embed/ZJr47lNfSCs/LwdrSVS1318.mp4
#cinema "$c" --getsubs

#in some other cases not
#c=$(curl -s https://onlinemoviestar.xyz/seires/206209-law-and-order-special-victims-unit/seasons/13/episodes/20 |tr ',>' '\n' |egrep -o 'http.*openload.*' |sed 's/[\"]//g') && echo "$c"
#<empty>

#in such cases you can grap the next moviestar page associated with openload button:
#c=$(curl -s https://onlinemoviestar.xyz/seires/206209-law-and-order-special-victims-unit/seasons/13/episodes/20 |egrep 'openload' |tr ',>' '\n' |egrep -o 'http.*onlinemoviestar.*/play[^\")]*' |sed 's/\x27//g') && echo "$c"
#https://onlinemoviestar.xyz/play/series/206209/13/20/aHR0cDovL29wZW5sb2FkLmNvL2VtYmVkLzJrNmZQNjBHdkRZL0x3ZHJTVlMxMzIwLm1wNA%2C%2C

#or
#c=$(curl -s https://onlinemoviestar.xyz/seires/206209-law-and-order-special-victims-unit/seasons/13/episodes/20 |egrep 'openload' |tr ' ' '\n' |egrep "http" |tr -d '\042\047()' ) && echo "$c"
#https://onlinemoviestar.xyz/play/series/206209/13/20/aHR0cDovL29wZW5sb2FkLmNvL2VtYmVkLzJrNmZQNjBHdkRZL0x3ZHJTVlMxMzIwLm1wNA%2C%2C

#d=$(curl -Ls "$c" |tr ' ' '\n' |egrep -o 'http.*openload.*' |sed 's/[\"]//g') && echo "$d"
#http://openload.co/embed/2k6fP60GvDY/LwdrSVS1320.mp4
#cinema "$d" --getsubs
}

function getsubsurl {
echo "[getsubsurl function]: returns openload vtt subs url hidden in embeded openload links" >/dev/tty
[[ -z $1 ]] && echo "[getsubsurl function]: no video url given.... exiting now. " >/dev/tty && return 1

if ! which youtube-dl >/dev/null;then echo "[getsubsurl function]: you need to install youtube-dl" >/dev/tty;return 1;fi	
if ! which curl >/dev/null;then echo "[getsubsurl function]: you need to install curl" >/dev/tty;return 1;fi	

ur="$1"
[[ -z $(curl -s "$ur") ]] && echo "[getsubsurl function]: $ur returns no data - switching to https" >/dev/tty && ur=$(sed 's/^http/https/' <<<"$ur")

subs=$(curl -s "$ur" |grep -m1 'vtt' |grep -Po 'src=\"\K.*vtt')
if [[ -z "$subs" ]];then 
	echo "no vtt subs found" 
else
	echo "[getsubsurl function]: vtt subs found - $subs" >/dev/tty
	echo "$subs"
fi
}

function tablet {
[[ -z $1 ]] && echo "tablet function invoked but no option was given. Send me 'on' or 'off'" && return 1

if [[ $1 == "off" ]];then
while read i;do echo "enabling $(xinput list --name-only $i)" && xinput enable $i;done <<<"$(xinput list |grep -e 'AT.*keyboard' -e 'Synaptics' |grep -Po 'id=\K[0-9]+')"
fi

if [[ $1 == "on" ]];then
while read i;do echo "disabling $(xinput list --name-only $i)" && xinput disable $i;done <<<"$(xinput list |grep -e 'AT.*keyboard' -e 'Synaptics' |grep -Po 'id=\K[0-9]+')"
fi
}

function aptless {
[[ -z $1 ]] && echo "no patteern given" && return 1
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
	echo '---------------- pipe entry-------------' >/dev/tty;
	i=1;
	while read -r l;do 
	  echo "$i>$l" >/dev/tty;
	  let i++;
	done <<<"$v";
	echo '---------------- pipe exit-------------' >/dev/tty; #disabled - for some reason prints the result of the last command
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

function lsdir () { 
# List only directories
# TBD: Make it work with globs like tmp*
local d="$PWD";
local helpme="This is help about lsdir function.
Under the hood this command is run:
ls -allh \x22$d\x22 |grep '^d' 
There are also alternative ways to achieve this :
alternative1 : find <dir> -maxdepth 1 -type d |column
alternative2 : for d in */; do ..... done";

[[ "$1" == "--help" ]] && echo -e "$helpme" && return;
[[ -z "$1" ]] && local d="$PWD" || local d="$1"
[[ "${d: -1}" != "/" ]] && d="${d}/" #if last char is not a dash, add a dash
ls -allh "$d" |grep '^d'  #-h: show size in human format 
#alternative1 : find "$d" -maxdepth 1 -type d |column
#alternative2 : a=1;for d in */; do echo -e "${a} --> \x22${d:0:-1}\x22";let a=a+1; done
#1 --> "appsfiles"
#2 --> "cheat sheets"
#<etc>

}

function dpkginfo { dpkg -L "$1" |nl;}  #prints files installed by a package with numbering of the entries.

function printarray () { 
#set -x
# ab=( "one" "two" "fi ve" );printarray --> please provide a var
# printarray ab
# [0]="one
# [1]="two
# [2]="fi ve" #works even with space in array values
[[ -z $1 ]] && echo "Provide an array name (without \$) to display " && return
#declare -p $1 |sed "s/declare -a $1=(//g; s/)$//g; s/\" \[/\"\n\[/g" #Only valid in GNU Sed -not working in BSD
#declare -p $1 | perl -pe "s/declare -[aA] $1=\(//g; s/\)$//g; s/\" \[/\"\n\[/g" #works even in BSD
echo "printarray: Prints array $1 as stored in bash environment "

declare -p $1 | perl -pe 's/\[/\n[/g'
#This works because when array is defined in main bash shell , the array is also accessible by the functions
# Above perl -pe fails in logic if the array you  want to print contains data [...] i.e _xspecs array set by system
# Try printarray _xspecs and you will see the failure.

#Tip: 
#Shell quick printing: for key in "${!array[@]}";do echo "array[$key]=${array[$key]}";done
#using ${!array[@]} syntax we can loop over array KEYS/INDEX

# Those are not working inside a shell script - problem how to pass and parse a dynamic array into a script
#arr=( "$@" ) OR #arr="$1[@]"
#for key in "${!arr[@]}";do echo "$arr[$key]=${arr[$key]}";done

# This Alternative approach seems to work due to eval usage:
#function printarray { for k in $(eval echo "\${!$1[@]}");do printf '%s' "$1[${k}]="; eval echo "\${$1[$k]}";done; }


}

function mandiff { 
echo "mandiff: Compare installed man pages $1 vs the online man page at maniker.com"
[[ -z $1 ]] && echo "manpage missing " && return 1
[[ $(man -w "$1" 2>/dev/null) == "" ]] && echo "no valid manpage found for $1" && return
#mandiff = compare with diff an installed man page with online one by mankier.com
diff -y -bw -W 150 <(links -dump "https://www.mankier.com/?q=$1" |less |fold -s -w 70) <(man $1 |less |fold -s -w 70)
}

function debls () { 
	echo "debls: Displays contents of the .deb file (without downloading in local hdd) corresponding to an apt-get install $1" 
	echo "Use --down to download deb file to local hdd (cwd), list contents and then remove deb file"
	echo "Without --down, curl will be used to list the contents of the pkg , in a format equivallent to ls -all"
	[[ -z $1 ]] && echo "apt pkg file missing,exiting " && return 1

	if [[ $2 == "--down" ]];then
		echo "--down selected"
		apt-get download $1 && ls -l $1*.deb && dpkg -c $1*.deb && rm -f $1*.deb
	    #dpkg -c <(curl -sL -o- $tmpdeb) |grep -v '^d' #--nd excludes directories from listing
	else
		echo "no deb downloading is selected. curl will be used"
        echo "apt-get --print-uris download $1 2>&1"
		local tmpdeb=$(apt-get --print-uris download $1 2>&1 |cut -d" " -f1)
		tmpdeb=$(echo "${tmpdeb: 1:-1}")
		echo "deb file to list contents: $tmpdeb"
	    #dpkg -c <(curl -sL -o- $tmpdeb)
        echo "executing command: curl -sL -o- $tmpdeb |dpkg -c /dev/stdin"
	    curl -sL -o- $tmpdeb |dpkg -c /dev/stdin
	fi
#Alternatives
#curl -sL -o- 'http://ftp.gr.debian.org/debian/pool/main/k/kodi/kodi-eventclients-wiiremote_17.6+dfsg1-4+b1_amd64.deb' |dpkg-deb --fsys-tarfile /dev/stdin |tar -t
#tar -t : list contents
#dpkg-deb --ctrl-tarfile : extract the control information of a deb pkg.
#dpkg -c by default equals to dpkg-deb --fsys-tarfile
}

function humanreadable() {
# humanreadable is used to translate a number corresponding to file size to human readable format like Kbyte, Mbyte, Gbyte, Tbyte, etc
#usage 1 : echo "1024567" |humanreadable 
#usage 2 : humanreadable 123123123

#v="$(</dev/stdin)"; #necessary for this function to accept input by pipe
#echo "$v" |awk ....
#Though using just cat , prints the stdin to stdout and works fine
# cat |awk .....

#if [[ -z "$1" ]];then v="$(</dev/stdin)";else v=$1;fi

if test -n "$1"; then
   v="$1"
   #echo "Read from positional argument $1";
elif test ! -t 0; then
   v="$(</dev/stdin)"
   #echo "Read from stdin if file descriptor /dev/stdin is open"
   #cat > file4.txt
else
   echo "humanreadable is used to translate a number corresponding to file size to human readable format like Kbyte, Mbyte, Gbyte, Tbyte, etc"
   echo "Use humanreadable function either with an argument or pipe data into it".
   return 1
   #echo "No standard input."
fi


echo "$v" |awk 'function human(x) {
         s=" B   KiB MiB GiB TiB EiB PiB YiB ZiB"
         while (x>=1024 && length(s)>1) 
               {x/=1024; s=substr(s,5)}
         s=substr(s,1,4)
         xf=(s==" B  ")?"%5d   ":"%8.2f"
         return sprintf( xf"%s\n", x, s)
      }
      {gsub(/^[0-9]+/, human($1)); print}'
}



function debcat () {
	echo "Function debcat: Extracts and displays a specific file from a .deb package (without downloading in local hdd) corresponding to an apt-get install $1." 
	echo "Usage: debcat <pkg> [option1] "
	echo "<pkg>: pkg name in apt format"
	echo "[option1]:"
	echo "   --list:                    simple deb listing of all files including links and directorier and exit" #or --listnd to force listing excluding directories"
	echo "   --ind or blank (default):  creates an index of all files excluding directories,links, and binary files (.so, .mo, .ko, /bin/"
	echo "   --all:                     force index to include all files excluding directory listing and links"
    echo 
	[[ -z $1 ]] && echo "apt pkg file missing, exiting.... " && return 1

	local tmpdeb=$(apt-get --print-uris download $1 2>&1 |cut -d" " -f1)
    local downsize=$(apt-get --print-uris download $1 2>&1 |grep -Eo '\b[0-9]{4,}\b' |humanreadable)  #grep -Eo '\b[56789][0-9]{6,}\b'
    #humanreadable is a function declared here and converts size in bytes to human readable size in KiB, MiB, etc
    tmpdeb=$(echo "${tmpdeb: 1:-1}") #remove the first and last char which are a single quote '
    echo "<pkg>: $tmpdeb"
	echo "[Option1]: $2 " && echo
	[[ -z $2 ]] && secondarg="" || secondarg="$2"  #echo "file to display is missing for pkg $1" && return 1
	[[ $2 == "--list" ]] && echo "--list selected - perform deb listing - all other options ignored" && debls "$1" && return 0
	#[[ $2 == "--listnd" ]] && echo "--listnd selected - perform nd listing - all other options ignored" && debls "$1" "--nd" && return 0
    #clear
    
    if [[ -z "$tmpdeb" ]];then 
       echo "No deb file could be found for $1. Results of 'apt-get --printu-uris download $1'" 
       apt-get --print-uris download "$1" 2>&1 
       return 1
    else
       echo "Command executed: apt-get --printu-uris download $1"
       echo "Deb Address to curl: $tmpdeb / Size: $downsize"
    fi
     
	if [[ $2 == "--ind" || $secondarg == "" ]];then
	    unset flist ms loop key
        loop=1
	    #if [[ "$3" == "--all" ]];then
		flist+=($(curl -sL -o- $tmpdeb |dpkg -c /dev/stdin |egrep -v -e '^l' -e '^d' -e '.mo' -e '.so' -e '.ko' -e '/bin/' -e '\/$' |awk '{print $NF}'))  #-e '\/bin\/' 
	    declare -p flist |sed 's/declare -a flist=(//g' |tr ' ' '\n' |sed 's/)$//g'
    fi
	
	if [[ $2 == "--all" || $2 == "-all" ]];then
		unset flist ms loop key
        loop=1
    	flist+=($(curl -sL -o- $tmpdeb |dpkg -c /dev/stdin |grep -v -e '^l' -e '^d' |grep -vE "\/$" |awk '{print $NF}'))
	    declare -p flist |sed 's/declare -a flist=(//g' |tr ' ' '\n' |sed 's/)$//g'
	fi


	while [[ $loop -eq 1 ]]; do
			read -p "Select file to display by id or  q to quit : " ms
			[[ "$ms" == "q" ]] && echo "exiting...." && return 1
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
				elif [[ ${flist[$ms]: -4} == ".png" ]]; then
				   pto="$(xdg-mime query default image/png)";ptopure="${pto%%.*}";echo "openning $ptopure"
				   curl -L -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${flist[$ms]} | cat - >/tmp/test.png; "$ptopure" /tmp/test.png;rm -f /tmp/test.png
				elif [[ ${flist[$ms]: -4} == ".jpg" ]]; then
				   pto="$(xdg-mime query default image/jpg)";
				   [[ -z "$pto" ]] && pto="$(xdg-mime query default image/jpeg)"; #some systems they don't have a jpg handler but they do have jpeg.
				   if [[ -z "$pto" ]];then
				     echo "No handler found for jpg/gpeg images - skipping" 
				   else
  				     ptopure="${pto%%.*}";echo "openning $ptopure"
				     curl -sL -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${flist[$ms]} | cat - >/tmp/test.jpg; "$ptopure" /tmp/test.jpg;rm -f /tmp/test.jpg
				   fi  
				else 
				   curl -sL -o- $tmpdeb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${flist[$ms]} |sed "1i ${flist[$ms]}" |less
				fi
			fi
		done
        return
	#fi	

: << COMMENT
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
COMMENT
echo "bye!"
}

function aptshowlight() { 
echo "aptshowlight: It is apt show $1 but in light version , giving only Package name and short description"
[[ -z $1 ]] && echo "Package missing " && return 1
#aptshowlight : runs apt show on given arg $1 , and prints only package name, section and Description. Combine with yadit.
#notice that if you specify to -A (after context) more lines than really available the results are not correct.
apt show $1 2>/dev/null |grep -A2 -e "Package:" -e "Description:" |grep -v -e "Version\|Priority\|Maintainer\|Installed-"
}

function aptshowsmart() { 
echo "aptshowsmart: apt show $1 in a smart way , using less pager"
[[ -z $1 ]] && echo "Package missing " && return 1
local ass+=$(apt list $1 2>/dev/null |grep -v "Listing" |sed "s#\\n# #g" |cut -d/ -f1)
apt show $ass |less
}

function debmanonline { 
echo "Function debmanonline: usage debmanonline <manpage>"
echo "Display debian man pages online from https://manpages.debian.org for package $1"
echo "Tip1: man page name might be different than package name"
echo "Tip2: Some packages like mesa-utils include more than one man page"
[[ -z $1 ]] && echo "Pass me a man page name to query https://manpages.debian.org" && return 1
echo "running command links -dump https://manpages.debian.org/jump?q=$1 to detect if there is a valid man page or if man page is not found"
if [[ $(links -dump https://manpages.debian.org/jump?q=$1) == *"Manpage not found"* ]];then 
echo "man page not found for $1 in online debian manpages. Maybe $1 is a package with a lot of man pages. Try to use debls $1 or debcat $1";return 1;
fi 

#debman uses the 2017 new web page with jump option

#links -dump https://manpages.debian.org/jump?q=$1 |awk "/Scroll to navigation/,0" |less  #disabled 20.10.24

# |less works better than |man /dev/stdin - less has a better formatting of the dumped web page.
#avoid to use name "debman" for this function since there is a programm debman inside pkg debian-goodies
#alternative synthax : links -dump https://dyn.manpages.debian.org/gawk

#bellow added 20.10.24 - instead of dumping the online manpage, search for the raw man page link, and parse this gz man page with man
onlinemanraw="$(curl -sL -o- https://dyn.manpages.debian.org/"$1" |grep -E -o '[/].*en.gz')"
echo "running command: curl -sL -o- https://dyn.manpages.debian.org/$1 |grep -E -o '[/].*en.gz'  ---->  $onlinemanraw"
read -p "press enter to open https://manpages.debian.org$onlinemanraw" an
curl -sL -o- "https://manpages.debian.org$(curl -sL -o- https://dyn.manpages.debian.org/$1 |grep -E -o '[/].*en.gz')" |man /dev/stdin
# Explanation
# curl -sL -o- https://dyn.manpages.debian.org/gawk |grep -E -o '[/].*gz' --> /bookworm/gawk/gawk.1.en.gz
#
}


function wiki() { 
echo "wiki: Returns wikipedia $@ entries in terminal"
[[ -z $1 ]] && echo "Pass me a page to search WikiPedia " && return 1
#dig +short txt $1.wp.dg.cx #This uses dig (apt install dnsutils) and does not work.
local q="$@"
links -dump "https://en.wikipedia.org/w/index.php?search=$q" |less
# better to use $@ that parses all args together ; Otherwise the arg red hat is passed as $1=red and $2=hat (or it has to be quoted)
}

function dircat() { 
echo "dircat: directory cat - cat files within directory $1, excluding subdirs. Use --two for entering second level or --full "
[[ -z $1 ]] && echo "Pass me a directory to cat files" && return 1
#printf '%s\n' "$@"  #works ok in cases like dircat /etc/w*

##[[ -d $1 ]] && local d="$1" || local d=( "$@" ) #If files provided , store them in a array

#[[ ! -d $d ]] && echo "$d   is not a directory - for regular file just use less" && return #disabled 24 Sep evening to allow single files
unset d; d=( "$@" ); 
echo "we are going to cat:"
ls -ld "${d[@]}"
#printf '%s\n' "${d[@]}"
read -p "press enter to continue"
#return

##[[ -d $d ]] && [[ "${d: -1}" != "/" ]] && d="${d}/" #if a directory was given and if last char is not a dash then add a trailing dash
##[[ -d $d ]] && echo "directory to scan and print= $d"

##if [[ -d $d ]] && 
if [[ "$2" == "--full" ]];then 
  echo "Will go inside subdirs! Maybe gonna be long time to finish this..." 
  local depth=""
##elif [[ -d $d ]] && [[ "$2" == "--two" ]];then 
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
	find "${d[@]}" $depth -type f -exec bash -c '[[ "$0" != "/proc/kmsg" && "$0" != /proc/kpage* && "$0" != *pagemap* ]] \
	                                          && [[ $(file "$0") == *"ASCII"* || $(file "$0") == *"empty"* ]] \
	                                          && echo "$0 --> /tmp/.__tmpcont" && echo -e "#-!#File: $0\n$(cat "$0")" >>/tmp/.__tmpcont ' {} \;
#	                                          && echo "$0 --> /tmp/.__tmpcont" && echo -e "#-!#File: $0\n$(cat "$0")" >>/tmp/.__tmpcont ' {} \;
	#make sure that file found is an ASCII file to avoid perform cat on binaries and pics
	# using find ${d[@]} will work with globbing like file* and also with one entry like a simple directory
	man --nj --nh <(local h=".TH man gv 2017 1.0 dcat";sed "s/^$/\.LP/g; s/^#-!#/\.SH /g;G" /tmp/.__tmpcont |sed 's/^$/\.br/g; s/\\/\\e/g;' |sed "1i $h")
	rm -f /tmp/.__tmpcont && echo "/tmp/.__tmpcont removed successfully" || echo "/tmp/.__tmpcont failed to remove"
	#Call the man as pager to display files contents. Man formatting is necessary: 
	#File must be double spaced and empty lines to be replaced with .BR. 
	#Existed line breaks will be substitued by .LP = new paragraph 
	#Lines starting with #-!# will be Headers (.SH)
	#man header to be inserted in the beginning of the file = before first line
	#backslashes must be man escaped : \ becomes \e (also \\ works for man)

}

function findexec {
echo "findexec: find executable files under directories of /. Double quotes on file name is MANDATORY"
[[ -z $1 ]] && echo "Pass me a file name to look for executable files under / dir" && return 1
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
echo "mancheat: explore GV cheat sheets using man page viewer"
if [[ -z $1 ]]; then 
echo "Pass me a cheat file name to display from /cheatsheets/gvcheats directory."
echo "combine with '--edit' or '--gedit' to edit the cheat file"
echo "combine with --chapters to list available chapters of a particular cheatsheet (i.e mancheat java --chapters"
echo "use mancheat without any argument to get a list of available cheatsheets."
echo "ls -all /home/gv/Desktop/PythonTests/cheatsheets/gvcheats";
find /home/gv/Desktop/PythonTests/cheatsheets/gvcheats -type f -printf '%f\n' |awk -F"-" '{print $1}';
return 1;
fi

if 	[[ $2 == "--edit" ]]; then
	nano /home/gv/Desktop/PythonTests/cheatsheets/gvcheats/${1,,}*gv.txt;
	return 0
fi

if 	[[ $2 == "--gedit" ]]; then
    if dpkg-query -s geany >&/dev/null ; 
    # Check if geany is installed - dpkg -s or dpkg-query -s 
    # If pkg is installed , return code is 0 (=all ok) and info about pkg are displayed in user's std ouput
    # if pkg is not installed, return code is 1 (=error) and error messages are display in user's error output (usually the same as std output)
    # Wigh >&/dev/null we redirect both std output and error output to /dev/null, because what we need is just the error code.
    # We don't count on the numerical error code 1 or 0 , we count on it's logical value (true or false)
    # and in this case it is known that a return code 0 means all good = true
    then geany /home/gv/Desktop/PythonTests/cheatsheets/gvcheats/${1,,}*gv.txt
	else nano /home/gv/Desktop/PythonTests/cheatsheets/gvcheats/${1,,}*gv.txt;
	fi
	return 0
fi

if 	[[ $2 == "--chapters" ]]; then
	grep "^##" /home/gv/Desktop/PythonTests/cheatsheets/gvcheats/${1,,}*gv.txt;
	return 0
fi


man --nj --nh <(h=".TH man 1 2017 1.0 $1-cheats-by-GV";sed "s/^${1^^}:/.SH ${1^^}:/g; s/^$/\.LP/g; s/^##/\.SS /g;G" /home/gv/Desktop/PythonTests/cheatsheets/gvcheats/${1,,}*gv.txt |sed 's/^$/\.br/g; s/\\/\\e/g;' |sed "1i $h");

#This works directly in cli:
#man --nj <(h=".TH man 1 "2017" "1.0" cheats page";sed "1i $h" cheatsheets/utils*gv.txt |sed 's/^UTILS:/.SH UTILS:/g; s/^$/\.LP/g; s/^##/\.SS /g; s/\\/\\\\/g;G' |sed 's/^$/\.br/g')

}

function datetoepoch {
#2022
#echo "converts regular date to epoch. Send a date or pipe me a date in format 14/Feb/2017:11:31:20" >&2
# The help message is printed on stderr (&2). In command line run will be printed on screen. 
# On script run mode $(..) or in pipe run mode only the returned converted date result is stored without the help message, since scripts hold by default only stdout , unless 2>&1 is provided
#buggy method:
#[[ -z $1 ]] && local dt=$(</dev/stdin) || local dt="$1" #if $1 is empty, use dev/stdin = work like a pipe. Otherwise use $1

    if [ -p /dev/stdin ]; then  # Check to see if a pipe exists on stdin.
    local dt=$(</dev/stdin);    # store the pipe data in variable
    else
    [[ -z $1 ]] && local dt="$(date)" || local dt="$(echo $1 | sed -e 's,/,-,g' -e 's,:, ,')" #if not a pipe and no args given then keep current - now - date
    fi

echo "[datetoepoch]: Date to be converted to epoch = $dt" >&2

#date -d "$(echo $dt | sed -e 's,/,-,g' -e 's,:, ,')" +"%s"
date -d "$dt" +"%s"
}

function epochtodate { 
    #echo "[epochtodate]: convert epoch date to normal date" >&2; 
    #[[ -z $1 ]] && local dt=$(</dev/stdin) || local dt="$1" #if $1 is empty, use dev/stdin = works like a pipe. Otherwise use $1 if provided - This is buggy. If not piped and no arguments are given then terminal hangs expecting user input.
    if [ -p /dev/stdin ]; then # Check to see if a pipe exists on stdin.
    local dt=$(</dev/stdin);
    else
    [[ -z $1 ]] && local dt="$(date +%s)" || local dt="$1" #if no argument is given, the keep the current - now - date in epoch format , else keep $1
    fi
    
    echo "[epochtodate]: Date to be converted from epoch to normal date format = $dt" >&2; 
    ###date -d@"$dt"; #legacy - works ok 30.03.2022
    
    #to be done: This function fails when used as pipe and stdin contains more than one line
    #tail -2 /var/log/squid/access.log |awk '{print $1}' |epochtodate
    #[epochtodate-n]: Date to be converted from epoch to normal date format = 1648597316.787
    #1648597351.857
    #date: invalid date ‘@1648597316.787\n1648597351.857’
    # For multilines you have to workaround with bash , but i am sure we can fix this inside this function
    # tail -3 /var/log/squid/access.log |awk '{print $1}' |while read -r a;do echo $a|epochtodate;done  #this works ok in cmd line.
    # bellow seems to handle correct multiline input ether by pipe, or by cli i.e pipe from awk or echo. Also works as standalone or with just one input line
    echo "$dt" |while read -r tm;do date -d@"$tm";done  #trial 30.03.2022 - method to handle multiline input
}


function dategr {
	#2022 
    if [ -p /dev/stdin ]; then # Check to see if a pipe exists on stdin.
    local dt=$(</dev/stdin);
    #echo "pipe contains : $dt" >&2; #debugging
    else 
    [[ -z $1 ]] && local dt="$(date)" || local dt="$1"
    fi

    echo "[dategr]: Date to be converted in GR format (24H)) = $dt" >&2;
    date --date="$dt" +%d/%m/%Y" "%H:%M:%S; #dt can get either pipe data , or "now" if is called without pipe and without arguments or $1 argument.
    #testing: echo "1648583844.667" |epochtodate |dategr

}

function rebootat {
	helpme="Usage: rebootat 0 -> will use the very first entry of grub boot menu - numbering starts from zero"
	[[ -z $1 ]] && echo "$helpme" >&2 && return;
	[[ $1 == "-h" ]] && echo "$helpme" >&2 && return;
	[[ $1 == "--help" ]] && echo "$helpme" >&2 && return;
	read -p "Parameter $1 provided - press any key to continue"
	grub-reboot "$1"
	read -p "grub-reboot set to $1 - press any key to reboot now..."
	grub-editenv list;
	local an;
	read -p "are you sure you want to reboot ? All your unsaved work will be lost.Type 'yes-rebootnow' to confirm  :" an
	[[ "$an" == "yes-rebootnow" ]] && sleep 10 && reboot || echo "aborting... $an selected" 
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
	[[ "$rep" =~ ^[nN] ]] && return 1
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
echo "Use -d for directories only , -f for full depth"

local p d f
#echo "$@"
[[ $1 == "-d" ]] && d="-type d" && shift || d=""     #if type is not defined, all types are returned
[[ $1 == "-f" ]] && f="" && shift || f="-maxdepth 0" #when maxdepth is not defined, full depth is considered by find
[[ -z $1 ]] && p="./" || p=( "$@" ) #dry run as lsadv defines ./ as find path
#echo "${p[@]}"
echo -e "Permissions\t| Links\t| user\t\t| group\t\t| size\t| Change Time\t\t\t| Name"
printf '%.s-' {1..130} 
echo
find "${p[@]}" $f $d -printf '%M(%m) | %n\t| %u(%U)\t| %g(%G)\t| %s\t| %Cb %Cd %CY %Cr\t| %p\n' | LC_ALL=C sort -t '|' -k1.1,1.2r -k6.1
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
