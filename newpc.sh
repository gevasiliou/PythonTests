On a debian fresh installation
To open a root terminal , open a user terminal and type 'su' or go to tty1 (ctrl+alt+f1) and login as root

# Essentials
cd /home/gv/Desktop
apt-get install git nano
git clone https://github.com/gevasiliou/PythonTests.git && chown -R gv:gv /home/gv/Desktop/PythonTests
cp -i /home/gv/Desktop/PythonTests/.bash_aliases /home/gv/ 
cp -i /home/gv/Desktop/PythonTests/.bash_aliases /root/
cp -i /etc/apt/sources.list /etc/apt/sources.list.backup
cp -i /home/gv/Desktop/PythonTests/sources.list /etc/apt/
apt-get update && apt-get upgrade --allow-unauthenticated && apt-get dist-upgrade --allow-unauthenticated 
apt-get install gksu sudo

#. /home/gv/Desktop/PythonTests/.bash_aliases

# Installing virtualbox guest addition cd
# make sure that virtualbox-guest-x11 is installed
apt-get install linux-headers-$(uname -r)
apt-get install build-essential module-assistant && m-a prepare
apt-get install virtual* #this will install all virtualbox packages, including the additions cd and virtualbox itself

# Finetunning - Utilities
apt install perl gawk sed grep
apt install mpv youtube-dl links lynx yad xxd xdotool wget vlc agrep aptitude transmission geany hexchat htop hwinfo lshw unrar vobcopy
apt install browser-plugin-freshplayer-pepperflash
apt install debianutils firmware-linux-free firmware-realtek flashplugin-nonfree flashplugin-nonfree-extrasound pepperflashplugin-nonfree
#apt install network-manager sensible-utils tor
cp /home/gv/Desktop/PythonTests/newpcsetup/apps/
