#!/bin/bash
# Bellow schemes based on LVDS-1 laptop screen 1366x768 and an LG TV 37'' connected with VGA cable, detected as VGA-1 with native resolution 1920x1080

function mirror {
xrandr --output LVDS-1 --mode 1366x768 --scale 1x1 --output VGA-1 --same-as LVDS-1 --mode 1920x1080 --scale 0.711x0.711
# Above sscale etting in reallity enlarges VGA-1 by reducing the resolution with scale to match 1366x768 , as in LVDS-1
}

function extended {
xrandr --output VGA-1 --mode 1920x1080 --scale 1x1 --output LVDS-1 --mode 1366x768 --scale 1x1 --left-of VGA-1 
}

function vgaonly {
xrandr --output LVDS-1 --off --output VGA-1 --mode 1920x1080 --scale 1x1
}

function laptoponly {
xrandr --output VGA-1 --off --output LVDS-1 --mode 1366x768 --scale 1x1
}

function vgaenlarged {
xrandr --output LVDS-1 --off --output VGA-1 --mode 800x600 --scale 1x1
}

function getactive {
xr=$(xrandr)
mon1=$(echo "$xr" |grep -v disconnected |grep -m1 connected |cut -f1 -d"(") #|grep -Po '^[A-Z-0-9]*')
mon2=$(echo "$xr" |grep -v disconnected |grep -v "$mon1" |grep connected |cut -f1 -d"(") #|grep -Po '^[A-Z-0-9]*')
mode1=$(echo "$xr" |grep -m1 -e '*' |grep  -Po '^[ ]*[0-9x0-9]*') #selected mode is marked with an asterisk
mode2=$(echo "$xr" |grep -v "$mode1" |grep -e '*' |grep  -Po '^[ ]*[0-9x0-9]*') #exclude mode1 and get the next mode
yad --center --text="Screen Setup:\n Monitor 1: \n $mon1 \n mode: $mode1 \n\n\n Monitor 2: \n $mon2 \n mode: $mode2"
#this function is not working well if LVDS-1 monitor is off , since it still appears "connected" and comes first in the row by xrandr
}

#---------------------MAIN PROG------------------------------------------#
synclient TapButton1=1 #Non relevant command - just enable touchpad click if necessary.

if [[ $1 = "" ]]; then
answer=$(yad --center --form --num-output --separator="" --field="Screen Setup":CB "Mirror!Extended Desktop!VGA Only!VGA Enlarged!Laptop Only!Exit")
else
echo "Setting screen schema by command line is not yed defined for option $1"
#we can call a function here to manipulate the $1 value and assign it to $answer , and thus case bellow will work in all cases
#for exampe case $1 in "mirror") answer=1;;
fi

case $answer in
1) mirror;;
2) extended;;
3) vgaonly;;
4) vgaenlarged;;
5) laptoponly;;
6) exit;;
esac
getactive #After finishing the set up, read and display the values from xrandr , as a kind of gui verification.
exit
