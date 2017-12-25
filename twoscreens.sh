#!/bin/bash
# Bellow schemes based on LVDS-1 laptop screen 1366x768 and an LG TV 37'' connected with VGA cable, detected as VGA-1 with native resolution 1920x1080

function mirror {
#xrandr --output LVDS-1 --mode 1366x768 --scale 1x1 --output VGA-1 --same-as LVDS-1 --mode 1920x1080 --scale 0.711x0.711
# Above sscale etting in reallity enlarges VGA-1 by reducing the resolution with scale to match 1366x768 , as in LVDS-1
xrandr --output $1 --mode 1366x768 --scale 1x1 --output $2 --same-as $1 --mode 1920x1080 --scale 0.711x0.711
}

function extended {
#xrandr --output VGA-1 --mode 1920x1080 --scale 1x1 --output LVDS-1 --mode 1366x768 --scale 1x1 --left-of VGA-1 
xrandr --output $2 --mode 1920x1080 --scale 1x1 --output $1 --mode 1366x768 --scale 1x1 --left-of $2 
}

function vgaonly {
#xrandr --output LVDS-1 --off --output VGA-1 --mode 1920x1080 --scale 1x1
xrandr --output $1 --off --output $2 --mode 1920x1080 --scale 1x1
}

function vgaenlarged {
#xrandr --output LVDS-1 --off --output VGA-1 --mode 800x600 --scale 1x1
xrandr --output $1 --off --output $2 --mode 800x600 --scale 1x1
}

function laptoponly {
#xrandr --output VGA-1 --off --output LVDS-1 --mode 1366x768 --scale 1x1
xrandr --output $2 --off --output $1 --mode 1366x768 --scale 1x1
}

function getactive {
#xr=$(xrandr)
#mon1=$(echo "$xr" |grep -v disconnected |grep -m1 connected |cut -f1 -d"(") #|grep -Po '^[A-Z-0-9]*')
#mon2=$(echo "$xr" |grep -v disconnected |grep -v "$mon1" |grep connected |cut -f1 -d"(") #|grep -Po '^[A-Z-0-9]*')
#mode1=$(echo "$xr" |grep -m1 -e '*' |grep  -Po '^[ ]*[0-9x0-9]*') #selected mode is marked with an asterisk
#mode2=$(echo "$xr" |grep -v "$mode1" |grep -e '*' |grep  -Po '^[ ]*[0-9x0-9]*') #exclude mode1 and get the next mode
#yad --center --text="Screen Setup:\n Monitor 1: \n $mon1 \n mode: $mode1 \n\n\n Monitor 2: \n $mon2 \n mode: $mode2"
m=$(xrandr --listmonitors);yad --center --text="$m" #displays always the active -not just connected- monitors 
}

#---------------------MAIN PROG------------------------------------------#
synclient TapButton1=1 #Non relevant command - just enable touchpad click if necessary.
#detect primary and secondary monitors. Fortunatelly xrandr reports as connected monitors that might have been disabled with --off
sec=$(xrandr |grep ' connected' |grep -e 'HDMI' -e 'VGA' |awk '{print $1}') #hardcoding - for me hdmi and vga monitors are always secondary
prim=$(xrandr |grep ' connected' |grep -v "$sec" |awk '{print $1}') #this one should be the laptop monitor = primary (LVDS-1, eDP-1,etc)
[[ -z "$sec" ]] && m=$(xrandr --listmonitors) && yad --center --text="No second monitor connected \n $m" && exit 1
##echo "primary is $prim and secondary is $sec" && exit
# You can verify if an HDMI monnitor is connected using also cat /sys/class/drm/card0/*HDMI*/status
# in my Toshiba returns two lines; one card disconnected - the next one connected if hdmi is used
# Especially for hdmi you need to enable output on pulse audio.
# Using gui: run  pavucontrol, go to the most right tab = configuration and selet an hdmi output (either std or 5.1)
# using script: https://wiki.archlinux.org/index.php/PulseAudio/Examples
# Remember that pactl and pacmd commands must runn as user and not as root
# Those commands should work for easy switching to hdmi audio:
#pacmd set-card-profile 0 output:hdmi-stereo-extra1
#pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo

if [[ -z $1 ]]; then
answer=$(yad --center --form --num-output --separator="" --field="Screen Setup":CB "Mirror!Extended Desktop!VGA Only!VGA Enlarged!Laptop Only!Exit")
else
echo "Setting screen schema by command line is not yed defined for option $1"
#we can call a function here to manipulate the $1 value and assign it to $answer , and thus case bellow will work in all cases
#for exampe case $1 in "mirror") answer=1;;
fi

case $answer in
1) mirror "$prim" "$sec";;
2) extended "$prim" "$sec";;
3) vgaonly "$prim" "$sec";;
4) vgaenlarged "$prim" "$sec";;
5) laptoponly "$prim" "$sec";;
6) exit;;
esac
getactive #After finishing the set up, read and display the values from xrandr , as a kind of gui verification.
exit
