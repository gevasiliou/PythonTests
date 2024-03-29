#!/bin/bash
# https://github.com/julienw/config-files/blob/master/yoga/rotate-screen.sh
# October 2016 - Tested and worked on Toshiba Radius 11 Convertible Laptop with Debian 8.5 Sid and XFCE 4.12 
# This is a bash script to make screen autorotation possible based on device orientation.
# All you need for this script to run  iio-sensor-proxy and inotify ($sudo apt install iio-sensor-proxy inotify-tools)
# Nowdays, iio-sensor-proxy usually is included in any Linux Distro.
# For inotify source : https://github.com/rvoicilas/inotify-tools
# PS: Gnome has a built in implementation of auto screen rotation based on iio-sensor-proxy. 
#
# Source Code: https://linuxappfinder.com/blog/auto_screen_rotation_in_ubuntu
#
# Receives input from monitor-sensor (part of iio-sensor-proxy package). You can run monitor-sensor first in command line to verify correct working.
# This script could be added to startup applications for the user.
#scr=$(xrandr |grep connected)
#echo $scr
#pos=$(expr index "${scr}" connected)
#echo 'position:' $pos
#screen=$(expr substr "${scr}" 1 $(($pos-2))) #pos has the value of "c" from connected. -1 has a space , -2 has the screen name
#echo 'Auto Recognized Screen:' $screen
function Tablet { 
    [[ $1 == "off" ]] && action="enable"
    [[ $1 == "on" ]] && action="disable"
    while read i; do
       #echo "enabling $(xinput list --name-only $i)"
       xinput $action $i;
    done <<< "$(xinput list |grep -e 'AT.*keyboard' -e 'Synaptics' |grep -Po 'id=\K[0-9]+')";
}


screen2=$(xrandr | grep 'connected' |grep -v 'disconnected' | grep -oE '[a-zA-Z]+[\-]+[^ ]') #this seems also to work and print the VGA-1 / eDP-1
echo 'Auto Recognize screen {alt}:' $screen2
> sensor.log # Clear sensor log to keep the size small.
monitor-sensor >> sensor.log 2>&1 & # Launch monitor-sensor - store output in a variable to be parsed by rest script

# Parse output or monitor sensor to get the new orientation whenever the log file is updated
# Possibles are: normal, bottom-up, right-up, left-up. Light data will be ignored
while inotifywait -e modify sensor.log; do  #switch -e = event.  modify = event to watch. sensor.log = file to watch.
	ORIENTATION=$(tail -n 1 sensor.log | grep 'orientation' | grep -oE '[^ ]+$')  # Read the last line that was added to the file and get the orientation
	case "$ORIENTATION" in # Set the actions to be taken for each possible orientation
	normal)
		   xrandr --output $screen2 --rotate normal
		   xinput set-prop "ELAN Touchscreen" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1 
		   Tablet off;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Left ;;
	bottom-up)
			xrandr --output $screen2 --rotate inverted
			xinput set-prop "ELAN Touchscreen" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1 
			Tablet on ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Left ;;
	right-up)
			xrandr --output $screen2 --rotate right
			xinput set-prop "ELAN Touchscreen" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1 
			Tablet on ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Bottom ;;
	left-up)
			xrandr --output $screen2 --rotate left
			xinput set-prop "ELAN Touchscreen" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1 
			Tablet on ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Bottom ;;
	esac
done
exit #exit may not required. added by me.

# IF the screen to be rotated is not correctly grabbed, run xrandr from terminal.
# inotifywait seems that is not terminated when the script is terminated.
# To kill the inotifywait : kill -- -$$ (https://bbs.archlinux.org/viewtopic.php?id=186989) or kill $(pgrep inotifywait)
# or try even kill -9 -f inotifywait
# inotifywatch manual: http://man7.org/linux/man-pages/man1/inotifywatch.1.html
# grep manual / operators / options : http://man7.org/linux/man-pages/man1/grep.1.html
# grep & Unix Expressions: http://www.robelle.com/smugbook/regexpr.html
# grep -oE '[^ ]+$'
#   -o = only match
#   [patern] = match anything like patern (i.e a-z, 0-9, A-Z)
#   [^patern] = NOT operation of brackets = do not match anything that includes the patern.
# grep examples by http://www.robelle.com/smugbook/regexpr.html:
# grep '[a-zA-Z]'	{any line with at least one letter}
# grep '[^a-zA-Z0-9]	{anything not a letter or number}

## Here there is an extension of the above script using a kind of rotation lock feature:
## https://linuxappfinder.com/blog/add_an_auto_rotation_lock
## Instead of the lock/unlock using a hidden file (see blog above), we could use zenity inside bash script to lock/unlock:
## answer = $(zenity --list --text='test' --radiolist --column="Action" --column="-" TRUE "Unlock" FALSE "Locked" FALSE "Exit")
## You only need to handle the value of $answer within an "If" condition. 
## $answer can get values Unlock, Locked, Exit , and Null/nothing if the user presses cancel.
## Moreover, using yad instead of zenity (or combining yad and zenity) you can provide a tray icon (!!) and can call a custom shell command 
## upon user click on icon.... 
## yad example: $yad --notification --command='zenity --notification --text=hello world' --image='/home/gv/Desktop/abp.png'
## The whole story could be split in three scripts:
## First script will just call the yad , calling the second script.
## Second script will be just an if - then condition based on the user answer:
## answer=$(zenity --list --text='test' --radiolist --column="Action" --column="-" TRUE "Unlock" FALSE "Locked" FALSE "Exit")
## If answer = exit or answer = locked then kill all
## If answer = unlocked then call third script for automatic rotation else kill all (case of exit and unlocked)
## Third script will be the script presented above.

## Tricks:
## yad --notification --command='zenity --list --text='test' --radiolist --column="Action" --column="-" TRUE "Unlock" FALSE "Locked" FALSE "Exit"' --image='/home/gv/Desktop/abp.png'
## This works ok. Icon goes to tray and upon click it calls the zenity list.
## 
## For script probably could be used like this:
## ans=$(yad --notification --command='zenity --list --text='test' --radiolist --column="Action" --column="-" TRUE "Unlock" FALSE "Locked" FALSE "Exit"' --image='/home/gv/Desktop/abp.png')
## However this one when combined with ;echo $ans in the end, prints nothing....
