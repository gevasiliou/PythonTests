#On a debian fresh installation
#To open a root terminal , open a user terminal and type 'su' or go to tty1 (ctrl+alt+f1) and login as root
set +f #treat * as glob star. Use set -f to disable globbing and treat * literally as an *
[[ "$(whoami)" != "root" ]] && echo "you need to be root to run this script" && exit 1
echo "proceeding as root"
synclient TapButton1=1 #enable touchpad click if necessary.

function essentials {
if grep '.bash_aliases' /root/.bashrc >&/dev/null
then 
  echo "/root/.bashrc already imports /root/.bash_aliases"
else
  read -p 'Press enter to modify /root/.bashrc to load external aliases file .bash_aliases or s to skip' answer
  if [[ "$answer" != "s" ]];then
    echo "if [ -f ~/.bash_aliases ];then . ~/.bash_aliases;fi" >>/root/.bashrc
  else
    echo "skipped" 
  fi
fi

ess=( "geany" "git" "nano" "gksu" "sudo" )
ess+=( "linux-headers-$(uname -r)" "kbuild" "module-assistant" )
ess+=( "kmod" "sysfsutils" )
ess+=( "build-essential" "libpcap-dev" "autoconf" "intltool" "libtool" "automake" )
# apt-get install geany-plugin-addons geany-plugin-py #fails on Debian 9 2018
# gksu will provide a gui su, will create gksu.desktop = root terminal = Exec=gksu /usr/bin/x-terminal-emulator and also Icon=gksu-root-terminal
# sudo is not installed by default in Debian
# kmod will provide lsmod, insmod, modprobe,modinfo, etc. 
# sysfsutils provide systool -a -v -m rtl8192se

for i in "${ess[@]}";do
printf '%s ' "=========> Installing pkg $i"
if ! dpkg-query -l "$i" >&/dev/null ;then printf "\n" && apt-get install "$i";else printf '%s\n' " <========= already installed";fi
#dpkg-query -l pkg returns 0 if pkg is installed
done
m-a prepare #module assistant : prepare kernel to build extra modules

}

function utils {
# Finetunning - Utilities
unset toinst
toinst=( "perl" "gawk" "sed" "grep" "original-awk" )
toinst+=( "mpv" "youtube-dl" "links" "lynx" "yad" "xxd" "xdotool" "wget" "vlc" "agrep" "aptitude" "moreutils" )
toinst+=( "transmission" "hexchat" "htop" "hwinfo" "lshw" "unrar" "vobcopy" "browser-plugin-freshplayer-pepperflash" ) 
toinst+=( "flashplugin-nonfree" "flashplugin-nonfree-extrasound" "pepperflashplugin-nonfree" )
toinst+=( "cpufrequtils" "debianutils" )
toinst+=( "firmware-linux-free" "firmware-realtek" )
toinst+=( "xfce4-terminal" "xfce4-appfinder" "xfce4-notes" "catfish" "xfce4-notes-plugin" "xfce4-screenshooter" "xfce4-screenshooter-plugin" )
toinst+=( "eog" "shutter" "info" "pinfo" "okular" )
toinst+=( "iio-sensor-proxy" "inotify-tools" "debian-goodies")
#okular is a perfect pdf reader from kde with touch support and text highlight tools
#pinfo is an links browser info pages reader
#debian-goodies provide debman which downloads a deb package in a tmp directory (using debget script from the same bunch of scripts), and then extracts man pages out of this deb package.

for i in "${toinst[@]}";do
printf '%s ' "=========> Installing pkg $i"
if ! dpkg-query -l "$i" >&/dev/null ;then printf "\n" && apt-get install "$i";else printf '%s\n' " <========= already installed";fi
#dpkg-query -l pkg returns 0 if pkg is installed
done
}

function tweakwifi {
#https://www.insomnia.gr/forums/topic/621254-%CF%87%CE%B1%CE%BC%CE%B7%CE%BB%CF%8C-%CF%83%CE%AE%CE%BC%CE%B1-%CF%83%CE%B5-wifi-%CE%BA%CE%AC%CF%81%CF%84%CE%B1-realtek-rtl8723be-%CE%BB%CF%8D%CF%83%CE%B7/
essentials

echo 'tweaking wlan0 adapter'
module="$(lsmod |egrep -o -m1 'rtl[0-9]+[^ ]*')" &&\
echo "Current Parameters:" &&\
param="$(systool -a -v -m $module |sed -nr '/Parameters/,/^$/p')" && echo "$param"
# Tip: You can get an explanation of all parameters by running $ modinfo rtl8723be
read -p 'Press enter to proceed'
echo "options $module fwlps=0 ips=0 swlps=0 disable_watchdog=1 ant_sel=2" >/etc/modprobe.d/"$module".conf
echo "conf file created:"
ls -all /etc/modprobe.d/"$module".conf
cat /etc/modprobe.d/"$module".conf

echo "List all .conf files"
ls -all /etc/modprobe.d/*

echo && read -p "press enter to test the file by disabling and re-enabling wifi..."
modprobe -r "$module" && sleep 5 && modprobe "$module" &&\
echo "Modified Parameters:" &&\
param="$(systool -a -v -m $module |sed -nr '/Parameters/,/^$/p')" && echo "$param"


#if  egrep 'parm:[ ]+disable_watchdog' <(modinfo "$module");then 
#https://www.insomnia.gr/forums/topic/621254-%CF%87%CE%B1%CE%BC%CE%B7%CE%BB%CF%8C-%CF%83%CE%AE%CE%BC%CE%B1-%CF%83%CE%B5-wifi-%CE%BA%CE%AC%CF%81%CF%84%CE%B1-realtek-rtl8723be-%CE%BB%CF%8D%CF%83%CE%B7/
}

function gitclone {
git clone https://github.com/gevasiliou/PythonTests.git /home/gv/Desktop/ && chown -R gv:gv /home/gv/Desktop/PythonTests
git config credential.helper store #this will store the username/password on the next push.
}

function sysupgrade {
echo "copy .bash_aliases to /home/gv" && cp -iv /home/gv/Desktop/PythonTests/.bash_aliases /home/gv/ 
echo "copy .bash_aliases to /root" && cp -iv /home/gv/Desktop/PythonTests/.bash_aliases /root/
echo "make backup of /etc/apt/sources.list" && cp -iv /etc/apt/sources.list /etc/apt/sources.list.backup
echo "copy sources.list to /etc/apt" && cp -iv /home/gv/Desktop/PythonTests/sources.list /etc/apt/
echo "copy apt preferences to /etc/apt/" && cp -iv /home/gv/Desktop/PythonTests/preferences /etc/apt/
echo "Updating the system (update && upgrade && dist-upgrade)"
apt-get update && apt-get upgrade --allow-unauthenticated && apt-get dist-upgrade --allow-unauthenticated 
} 

function vboxinstall {
echo "Installing virtualbox guest addition cd"
echo "at the end make sure that virtualbox-guest-x11 is installed"

essentials

apt-get install virtual* #this will install all virtualbox packages, including the additions cd and virtualbox itself
apt-list virtualbox-guest-x11
}



function desktopfiles {
# all those files usually are not required since pkgs install them during pkg installation
[[ ! -f /usr/share/applications/gksu.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/gksu.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xce4-appfinder.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-appfinder.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xce4-terminal.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-terminal.desktop /usr/share/applications/
[[ ! -f /etc/xdg/autostart/xce4-notes-autostart.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-notes-autostart.desktop /etc/xdg/autostart/
[[ ! -f /usr/share/applications/xfce4-notes.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-notes.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xfce4-screenshooter.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-screenshooter.desktop /usr/share/applications/
}

function chromeinstall {
echo "ready to install google-chrome-stable from repos"
apt-get install google-chrome-stable
resp=$? #returns 0 on success , 100 in error
if [[ "$resp" -ne 0 ]];then
#if apt install from repos fails then go directly to google for downloading
echo "Installing chrome from https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb. Deb file will be saved to /tmp"
apt-get install desktop-file-utils
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp
dpkg -i /tmp/google-chrome-stable_current_amd64.deb #on new systems may break but is fixed with apt-get install --fix-broken
ret=$?; 
[[ $ret -ne 0 ]] && apt-get install -f && dpkg -i /tmp/google-chrome-stable_current_amd64.deb  
update-alternatives --config x-www-browser #as a confirmation - alternatives updated by chrome installer automatically
rm -iv /tmp/google-chrome-stable_current_amd64.deb
fi

}

function xfcepanels {
echo "TODO: copying xfce4 panel data for bottom panel"
}

function firmware-install {
echo "TODO: install the missing debian firmware..."
	}

# Various update-alternatives
# update-alternatives --set x-www-browser /usr/bin/google-chrome-stable #chrome installation takes care of this
# update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper #setting xfce terminal as default terminal
# update-alternatives --config x-terminal-emulator #display the list for manual confirmation
# * 0            /usr/lib/browser-plugin-freshplayer-pepperflash/libfreshwrapper-flashplayer.so   70        auto mode
# There are 2 choices for the alternative gnome-www-browser (providing /usr/bin/gnome-www-browser).
#
#  Selection    Path                           Priority   Status
#------------------------------------------------------------
#* 0            /usr/bin/google-chrome-stable   200       auto mode
# There are 3 choices for the alternative x-session-manager (providing /usr/bin/x-session-manager).
#
#  Selection    Path                    Priority   Status
#------------------------------------------------------------
#* 0            /usr/bin/startxfce4      50        auto mode
#  1            /usr/bin/startlxqt       50        manual mode
# There are 4 choices for the alternative x-www-browser (providing /usr/bin/x-www-browser).
#
#  Selection    Path                           Priority   Status
#------------------------------------------------------------
#* 0            /usr/bin/google-chrome-stable   200       auto mode
#  1            /usr/bin/firefox                70        manual mode

# ----------------------MAIN PROGRAMM ------------------#
case $1 in
"--utils")utils;;
"--sysupgrade")sysupgrade;;
"--vboxinstall")vboxinstall;;
"--desktopfiles")desktopfiles;;
"--chromeinstall")chromeinstall;;
"--gitclone")gitclone;;
"--essentials")essentials;;
"--tweakwifi")tweakwifi;;
*)echo "action missing. Usage --utils --sysupgrade --vboxinstall --desktopfiles --chromeinstall --tweakwifi --gitclone --essentials";;
esac
