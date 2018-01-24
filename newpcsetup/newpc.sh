#On a debian fresh installation
#To open a root terminal , open a user terminal and type 'su' or go to tty1 (ctrl+alt+f1) and login as root

# Essentials
[[ "$(whoami)" != "root" ]] && echo "you need to be root to run this script" && exit 1
echo "proceeding"

set +f #treat * as glob star. Use set -f to disable globbing and treat * literally as an *
#cd /home/gv/Desktop

cat <<EOF >>/root/.bashrc
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF
#. /home/gv/Desktop/PythonTests/.bash_aliases

apt-get install git nano
git clone https://github.com/gevasiliou/PythonTests.git /home/gv/Desktop/ && chown -R gv:gv /home/gv/Desktop/PythonTests
cp -iv /home/gv/Desktop/PythonTests/.bash_aliases /home/gv/ 
cp -iv /home/gv/Desktop/PythonTests/.bash_aliases /root/
cp -iv /etc/apt/sources.list /etc/apt/sources.list.backup
cp -iv /home/gv/Desktop/PythonTests/sources.list /etc/apt/
apt-get update && apt-get upgrade --allow-unauthenticated && apt-get dist-upgrade --allow-unauthenticated 
apt-get install gksu sudo


# Installing virtualbox guest addition cd
# make sure that virtualbox-guest-x11 is installed
apt-get install linux-headers-$(uname -r)
apt-get install build-essential module-assistant && m-a prepare
apt-get install virtual* #this will install all virtualbox packages, including the additions cd and virtualbox itself

# Finetunning - Utilities
apt install perl gawk sed grep
apt install mpv youtube-dl links lynx yad xxd xdotool 
apt install wget vlc agrep aptitude transmission 
apt install geany hexchat htop hwinfo lshw unrar vobcopy
apt install browser-plugin-freshplayer-pepperflash
apt install flashplugin-nonfree flashplugin-nonfree-extrasound pepperflashplugin-nonfree
apt install debianutils firmware-linux-free firmware-realtek 
apt install xfce4-terminal xfce4-appfinder xfce4-notes xfce4-notes-plugin xfce4-screenshooter xfce4-screenshooter-plugin

#apt install network-manager sensible-utils tor
[[ ! -f /usr/share/applications/gksu.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/gksu.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xce4-appfinder.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-appfinder.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xce4-terminal.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-terminal.desktop /usr/share/applications/
[[ ! -f /etc/xdg/autostart/xce4-notes-autostart.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-notes-autostart.desktop /etc/xdg/autostart/
[[ ! -f /usr/share/applications/xfce4-notes.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-notes.desktop /usr/share/applications/
[[ ! -f /usr/share/applications/xfce4-screenshooter.desktop ]] && cp -iv /home/gv/Desktop/PythonTests/newpcsetup/xfce4-screenshooter.desktop /usr/share/applications/
update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper #setting xfce terminal as default terminal
update-alternatives --config x-terminal-emulator #display the list for manual confirmation

# Installing chrome
apt-get install desktop-file-utils
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp
dpkg -i /tmp/google-chrome-stable_current_amd64.deb && update-alternatives --set x-www-browser /usr/bin/google-chrome-stable
update-alternatives --config x-www-browser
rm -iv /tmp/google-chrome-stable_current_amd64.deb

# Various update-alternatives
# * 0            /usr/lib/browser-plugin-freshplayer-pepperflash/libfreshwrapper-flashplayer.so   70        auto mode
# There are 2 choices for the alternative gnome-www-browser (providing /usr/bin/gnome-www-browser).
#
#  Selection    Path                           Priority   Status
#------------------------------------------------------------
#* 0            /usr/bin/google-chrome-stable   200       auto mode
#There are 3 choices for the alternative x-session-manager (providing /usr/bin/x-session-manager).
#
#  Selection    Path                    Priority   Status
#------------------------------------------------------------
#* 0            /usr/bin/startxfce4      50        auto mode
#  1            /usr/bin/startlxqt       50        manual mode
#There are 4 choices for the alternative x-www-browser (providing /usr/bin/x-www-browser).
#
#  Selection    Path                           Priority   Status
#------------------------------------------------------------
#* 0            /usr/bin/google-chrome-stable   200       auto mode
#  1            /usr/bin/firefox                70        manual mode

