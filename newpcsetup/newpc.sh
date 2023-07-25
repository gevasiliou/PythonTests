#On a debian fresh installation
#To open a root terminal , open a user terminal and type 'su' or go to tty1 (ctrl+alt+f1) and login as root
set +f #treat * as glob star. Use set -f to disable globbing and treat * literally as an *
[[ "$(whoami)" != "root" ]] && echo "you need to be root to run this script" && exit 1
echo "proceeding as root"
synclient TapButton1=1 #enable touchpad click if necessary.

function essentials {
read -p "esseential pkgs installation - press any key to proceed or s to skip this section" s && [[ "$s" == "s" ]] && return

if grep '.bash_aliases' /root/.bashrc >&/dev/null
then 
  echo "/root/.bashrc already imports /root/.bash_aliases"
else
  echo "if [ -f ~/.bash_aliases ];then . ~/.bash_aliases;fi needs to be appended to the end of /root/.bashrc" 
  read -p 'Press enter to modify /root/.bashrc or s to skip' answer
  if [[ "$answer" != "s" ]];then
    echo "if [ -f ~/.bash_aliases ];then . ~/.bash_aliases;fi" >>/root/.bashrc
  else
    echo "modification of /root/.bashrc is skipped" 
  fi
fi

ess=( "geany" "git" "git-all" "nano" "gksu" "sudo" "hwinfo" "net-tools" "wget" "curl" "aptitude" "desktop-file-utils" )
ess+=( "linux-headers-$(uname -r)" "kbuild" "module-assistant" "build-essential" "dkms")
ess+=( "kmod" "sysfsutils" ) #kmod=kernel modules handling (lsmod,modprobe,insmod,modinfo,,etc)
ess+=( "firmware-linux" "build-essential" "libpcap-dev" "autoconf" "intltool" "libtool" "automake" "systemd-ui" "x11-xserver-utils" )
# apt-get install geany-plugin-addons geany-plugin-py #fails on Debian 9 2018
# gksu will provide a gui su, will create gksu.desktop = root terminal = Exec=gksu /usr/bin/x-terminal-emulator and also Icon=gksu-root-terminal
# sudo is not installed by default in Debian
# kmod will provide lsmod, insmod, modprobe,modinfo, etc. 
# sysfsutils provide systool -a -v -m rtl8192se

for i in "${ess[@]}";do
printf '%s ' "=========> Installing pkg $i"
if ! dpkg-query -s "$i" >&/dev/null ;then 
  read -p "========> Want to install $i [y/n] ? :" an
  [[ $an == "y" ]] && apt-get --yes install "$i" || echo "===========> skipping installation of $i <============"
else 
  printf '%s\n' " <========= already installed ";
fi

#dpkg-query -l pkg returns 0 if pkg is installed
done

esscmds=( "m-a prepare" ) #m-a prepare : module assistant : prepare kernel to build extra modules
esscmds+=( "wget -O - http://download.videolan.org/pub/debian/videolan-apt.asc | sudo apt-key add" )  #add the usually missing videolan public key

for k in "${esscmds[@]}";do
  read -p "========> running command \"$k\" (or press s to skip) " cm
  [[ $cm != "s" ]] && eval "$k" || echo "===========> skipping execution of command $k <============"
done
}

function utils {
read -p "Utilities Installation. press any key to proceed or s to skip this section" s && [[ "$s" == "s" ]] && return
unset toinst
toinst=( "perl" "python" "gawk" "sed" "grep" "original-awk" "ntp")
toinst+=( "mpv" "youtube-dl" "links" "lynx" "yad" "xxd" "xdotool" "vlc" "agrep" "moreutils" "debian-goodies" )
toinst+=( "transmission" "hexchat" "htop" "lshw" "unrar" "vobcopy" "browser-plugin-freshplayer-pepperflash" ) 
toinst+=( "flashplugin-nonfree" "flashplugin-nonfree-extrasound" "pepperflashplugin-nonfree" )
toinst+=( "cpufrequtils" "debianutils" )
toinst+=( "firmware-linux-free" "firmware-realtek" )
toinst+=( "xfce4-terminal" "xfce4-appfinder" "xfce4-notes" "xfce4-notes-plugin" "xfce4-screenshooter" "xfce4-screenshooter-plugin" )
toinst+=( "eog" "shutter" "info" "pinfo" "okular" "catfish" )
toinst+=( "iio-sensor-proxy" "inotify-tools" )
toinst+=( "cmake" "qt5-default" "libssl-dev" "qtscript5-dev" "libnm-gtk-dev" "qttools5-dev" "qttools5-dev-tools" )

#okular is a perfect pdf reader from kde with touch support (scroll & zoom) providing also text highlight tools
#pinfo is an info pages reader like links browser
#debian-goodies provide debman which downloads a deb package in a tmp directory (using debget script from the same bunch of scripts), and then extracts man pages out of this deb package.

for i in "${toinst[@]}";do
printf '%s ' "=========> Installing pkg $i"
if ! dpkg-query -l "$i" >&/dev/null ;then 
  read -p "========> Want to install $i [y/n/h] ? :" an
  [[ $an == "h" ]] && apt show "$i" && read -p "========> Want to install $i [y/n] ? :" an
  [[ $an == "y" ]] && apt-get --yes install "$i" || echo "===========> skipping installation of $i <============"
else 
  printf '%s\n' " <========= already installed ";
fi
#dpkg-query -l pkg returns 0 if pkg is installed
done
}

function tweakwifi {
#https://www.insomnia.gr/forums/topic/621254-%CF%87%CE%B1%CE%BC%CE%B7%CE%BB%CF%8C-%CF%83%CE%AE%CE%BC%CE%B1-%CF%83%CE%B5-wifi-%CE%BA%CE%AC%CF%81%CF%84%CE%B1-realtek-rtl8723be-%CE%BB%CF%8D%CF%83%CE%B7/
read -p 'tweaking wlan0 adapter (press s to skip section)' tw && [[ "$tw" == "s" ]] && return

essentials
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

#to disable power saving you can also use iw command: iw wlan0 set power_save off
#iw gives great options for wireless card management
#
#if  egrep 'parm:[ ]+disable_watchdog' <(modinfo "$module");then 
#https://www.insomnia.gr/forums/topic/621254-%CF%87%CE%B1%CE%BC%CE%B7%CE%BB%CF%8C-%CF%83%CE%AE%CE%BC%CE%B1-%CF%83%CE%B5-wifi-%CE%BA%CE%AC%CF%81%CF%84%CE%B1-realtek-rtl8723be-%CE%BB%CF%8D%CF%83%CE%B7/
}

function gitclone {
echo "This will run the following commands:"
echo "apt install git-all"
echo "git clone https://github.com/gevasiliou/PythonTests.git /home/gv/Desktop/ && chown -R gv:gv /home/gv/Desktop/PythonTests"
echo "git config credential.helper store #this will store the username/password on the next push."
echo "git config --global credential.helper manager-core"
read -p "press any key to proceed or s to skip this section" s && [[ "$s" == "s" ]] && return

mkdir /home/gv/Desktop/PythonTests && git clone https://github.com/gevasiliou/PythonTests.git /home/gv/Desktop/PythonTests
chown -R gv:gv /home/gv/Desktop/PythonTests
git config credential.helper store #this will store the username/password on the next push.
git config --global credential.helper manager-core #this will do the same job, working 2022 with tokens
git config --global credential.helper manager #this should work for git 2023 , git version 2.39+
#especially for git 2.39+ you need to manually install (dpkg -i) the latest Git Credential Manager deb package found here:
#https://github.com/git-ecosystem/git-credential-manager/releases
#Then make sure that .git-config file in your home directory includes this line:
#[credential]
#	helper = manager
#	credentialStore = cache
#
# The credentialStore = cache is actually a workaround. The main idea is that you need to define a credential store . 

git config --global user.email ge.vasiliou@gmail.com
}

function sysupgrade {
echo "this will copy .bash_aliases and mancolor to /home/gv and /root"
echo "moreover, apt sources.list will be tweaked and then update and upgrade will be done"
read -p "press any key to proceed or s to skip this section" s && [[ "$s" == "s" ]] && return

for i in /home/gv /root;do
echo "copy .bash_aliases to $i" && cp -iv /home/gv/Desktop/PythonTests/.bash_aliases "$i"
echo "copy mancolor to $i" && cp -iv /home/gv/Desktop/PythonTests/mancolor "$i" 
done

echo "make backup of /etc/apt/sources.list" && cp -iv /etc/apt/sources.list /etc/apt/sources.list.backup
echo "copy sources.list to /etc/apt" && cp -iv /home/gv/Desktop/PythonTests/sources.list /etc/apt/
echo "copy apt preferences to /etc/apt/" && cp -iv /home/gv/Desktop/PythonTests/preferences /etc/apt/
echo "Updating the system (update && upgrade && dist-upgrade)"
#we don't need an explicit user confirmation prompt for above cp commamds since cp -i will ask for user confirmation by default. 
#Option -v in cp stands for verbose = report what you do.

wget -O - http://download.videolan.org/pub/debian/videolan-apt.asc | sudo apt-key add -
apt-get update && apt-get upgrade --allow-unauthenticated && apt-get dist-upgrade --allow-unauthenticated 
#Tip: when repos are changed by owners (i.e google INC changed to google LLC) apt-get update will fail. You need to use 'apt upgrade' instead of 'apt-get'.
} 

function vboxinstall {
echo "Installing virtualbox guest addition cd, but test if essential packages are installed before that. Also better to make a system update first"
echo "at the end make sure that virtualbox-guest-x11 is installed"
read -p "press any key to proceed or s to skip this section" s && [[ "$s" == "s" ]] && return

essentials

apt-get install virtual* #this will install all virtualbox packages, including the additions cd and virtualbox itself
apt list virtualbox-guest-x11 #just to verify that this utlil is installed
}



function desktopfiles {
# all those files usually are not required since pkgs install them during pkg installation
read -p "desktopfiles installation - press any key to proceed or s to skip this section" s && [[ "$s" == "s" ]] && return
[[ ! -f /usr/share/applications/gksu.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/gksu.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xce4-appfinder.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-appfinder.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xce4-terminal.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-terminal.desktop /usr/share/applications/
[[ ! -f /etc/xdg/autostart/xce4-notes-autostart.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-notes-autostart.desktop /etc/xdg/autostart/
[[ ! -f /usr/share/applications/xfce4-notes.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-notes.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xfce4-screenshooter.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-screenshooter.desktop /usr/share/applications/
}

function chromeinstall {
echo "ready to install google-chrome-stable from repos"
read -p "press any key to proceed or s to skip this section" s && [[ "$s" == "s" ]] && return

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

function hdmisound {
read -p "hdmisound installation services - press any key to proceed or s to skip this section" s && [[ "$s" == "s" ]] && return
if [[ ! -f /lib/udev/rules.d/78-hdmi.rules ]];then
cat <<EOF >/lib/udev/rules.d/78-hdmi.rules
KERNEL=="card0", SUBSYSTEM=="drm", ACTION=="change", RUN+="/bin/systemctl start hdmi-sound.service"
EOF
  chmod 644 /lib/udev/rules.d/78-hdmi.rules
  ls -allh /lib/udev/rules.d/78-hdmi.rules
else
  echo "udev hdmi rules file exists:"
  ls -allh /lib/udev/rules.d/78-hdmi.rules
fi

if [[ ! -f /etc/systemd/system/hdmi-sound.service ]];then
cat <<EOF >/etc/systemd/system/hdmi-sound.service
[Unit]
Description=hdmi sound hotplug

[Service]
Type=simple
RemainAfterExit=no
ExecStart=/usr/bin/hdmisound.sh

[Install]
WantedBy=multi-user.target

EOF

chmod 777 /etc/systemd/system/hdmi-sound.service
ls -allh /etc/systemd/system/hdmi-sound.service

else 
  echo "systemd hdmi sound service exists:"
  ls -allh /etc/systemd/system/hdmi-sound.service
fi

if [[ ! -f /usr/bin/hdmisound.sh ]];then 
  cp -iv /home/gv/Desktop/PythonTests/newpcsetup/hdmisound.sh /usr/bin
  chmod 755 /usr/bin/hdmisound.sh
  ls -allh /usr/bin/hdmisound.sh
else
  echo "hdmisound.sh exists:"
  ls -allh /usr/bin/hdmisound.sh
fi

udevadm control --reload-rules

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
"--hdmisound")hdmisound;;
*)echo "action missing. Usage --utils --sysupgrade --vboxinstall --desktopfiles --chromeinstall --tweakwifi --gitclone --essentials";;
esac
