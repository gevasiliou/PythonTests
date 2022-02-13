#!/bin/bash
# Bellow schemes based on LVDS-1 laptop screen 1366x768 and an LG TV 37'' connected with VGA/HDMI cable, detected as VGA-1 /HDMI-1 with native resolution 1920x1080
# pacmd can not work as root. even calling with su gv does not work. only gksu gv works.

function soundsetup {
	[[ $1 == "--hdmi" ]] && sset=1
	[[ $1 == "--laptop" ]] && sset=2
	[[ -z $1 ]] && sset=$(yad --center --form --title="Sound Setup" --item-separator="-" --separator='' --num-output --field="Enable HDMI Sound":CB "HDMI-PC-Exit")

	if [[ $sset -eq 1 ]];then
	   if grep '^connected$' /sys/class/drm/card0/*HDMI*/status >/dev/null 2>&1;then 
	      gksu -u gv pacmd set-card-profile 0 output:hdmi-stereo;
          sleep 1;
	   else
	      sset=2
	   fi
	fi

	if [[ $sset -eq 2 ]];then
	   gksu -u gv pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo;
       sleep 1;
	fi
	
	#yad --center --no-markup --title="Active Sound Setting" --text="$(gksu -u gv pacmd list 2>&1 |grep 'active profile')" 
	#16.04.2018 : yad --center --no-markup --title="Active Sound Setting" --text="$(pacmd list |grep 'active profile')" 
}


function lapmirror {
#xrandr --output LVDS-1 --mode 1366x768 --scale 1x1 --output VGA-1 --same-as LVDS-1 --mode 1920x1080 --scale 0.711x0.711
# Above sscale etting in reallity enlarges VGA-1 by reducing the resolution with scale to match 1366x768 , as in LVDS-1

xrandr --output $1 --mode 1366x768 --scale 1x1 --output $2 --same-as $1 --mode 1920x1080 --scale 0.711x0.711
soundsetup --hdmi
}

function natmirror {
xrandr --output $1 --mode 1366x768 --scale 1x1 --output $2 --same-as $1 --mode 1920x1080 --scale 1x1
soundsetup --hdmi
}

function extended {
#xrandr --output VGA-1 --mode 1920x1080 --scale 1x1 --output LVDS-1 --mode 1366x768 --scale 1x1 --left-of VGA-1 
xrandr --output $2 --mode 1920x1080 --scale 1x1 --output $1 --mode 1366x768 --scale 1x1 --left-of $2 
soundsetup --hdmi
}

function vgaonly {
#xrandr --output LVDS-1 --off --output VGA-1 --mode 1920x1080 --scale 1x1
xrandr --output $1 --off --output $2 --mode 1920x1080 --scale 1x1
soundsetup --hdmi
}

function vgaenlarged {
#xrandr --output LVDS-1 --off --output VGA-1 --mode 800x600 --scale 1x1
xrandr --output $1 --off --output $2 --mode 800x600 --scale 1x1
soundsetup --hdmi
}

function laptoponly {
#xrandr --output VGA-1 --off --output LVDS-1 --mode 1366x768 --scale 1x1
xrandr --output $2 --off --output $1 --mode 1366x768 --scale 1x1
soundsetup --laptop
}

function helppeople {
h=$(cat <<EOF
You can provide using command line those options:
--lapmirror           (mirror laptop to HDMI keeping the laptop resolution also in hdmi screen)
--natmirror           (mirror laptop to HDMI with natural resolution in each screen)
--extended            (extend laptop screen to hdmi)   
--vgaonly             (disables laptop screen and enables hdmi) 
--vgaenlarged         (disables laptop screen and enables hdmi with 800x600 resolution)
--laptoponly          (disables hdmi and enables laptop screen)
--soundsetup-hdmi
--soundsetup-laptop
--status              (prints current screen and sound setup)
--help
EOF)
echo -e "$h"
}

function getactive {
#xr=$(xrandr)
#mon1=$(echo "$xr" |grep -v disconnected |grep -m1 connected |cut -f1 -d"(") #|grep -Po '^[A-Z-0-9]*')
#mon2=$(echo "$xr" |grep -v disconnected |grep -v "$mon1" |grep connected |cut -f1 -d"(") #|grep -Po '^[A-Z-0-9]*')
#mode1=$(echo "$xr" |grep -m1 -e '*' |grep  -Po '^[ ]*[0-9x0-9]*') #selected mode is marked with an asterisk
#mode2=$(echo "$xr" |grep -v "$mode1" |grep -e '*' |grep  -Po '^[ ]*[0-9x0-9]*') #exclude mode1 and get the next mode
#yad --center --text="Screen Setup:\n Monitor 1: \n $mon1 \n mode: $mode1 \n\n\n Monitor 2: \n $mon2 \n mode: $mode2"
soundsetup="$(gksu -u gv pacmd list 2>&1 |grep 'active profile')"
screensetup="$(xrandr --listmonitors)"
#Apr2018: yad --center --no-markup --title="Monitors Active" --text="$(xrandr --listmonitors)" 
if [[ $1 -eq 0 ]]; then
yad --center --no-markup --title="Active Setup" --text="Screen Setup\n$screensetup\n\n\nSound Setup\n$soundsetup" 
fi

if [[ $1 -eq 1 ]]; then
#if $1=1 => command line run (clirun) =1
echo -e "Active Screen Setup\n$screensetup\n\n\nActive Sound Setup\n$soundsetup" 
fi

#displays always the active -not just connected- monitors 
}
#

#---------------------MAIN PROG------------------------------------------#
synclient TapButton1=1 #Non relevant command - just enable touchpad click if necessary.
#detect primary and secondary monitors. Fortunatelly xrandr reports as connected monitors that might have been disabled with --off

sec=$(xrandr |grep ' connected' |grep -e 'HDMI' -e 'VGA' |awk '{print $1}') #hardcoding - for me hdmi and vga monitors are always secondary
#alternative: xrandr |grep '[^dis]connected'

prim=$(xrandr |grep ' connected' |grep -v "$sec" |awk '{print $1}') #this one should be the laptop monitor = primary (LVDS-1, eDP-1,etc)

#2022 commented out: [[ -z "$sec" ]] && m=$(xrandr --listmonitors) && yad --center --text="No second monitor connected \n $m" #&& exit 1

##echo "primary is $prim and secondary is $sec" && exit
# You can verify if an HDMI monnitor is connected using also cat /sys/class/drm/card0/*HDMI*/status
# in my Toshiba returns two lines; one card disconnected - the next one connected if hdmi is used
# Especially for hdmi you need to enable output on pulse audio.
# Using gui: run  pavucontrol, go to the most right tab = configuration and selet an hdmi output (either std or 5.1)
# using script: https://wiki.archlinux.org/index.php/PulseAudio/Examples
# Remember that pactl and pacmd commands must runn as user and not as root
#
# Those commands work for easy switching to hdmi audio:
# pacmd set-card-profile 0 output:hdmi-stereo #or output:hdmi-surround
# pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo
# In most computers with one soundcard , this card gets id 0, so set-card-profile 0 should work everywhere

# You can also adjust volume by terminal using pacmd set-sink-volume 6 10000.
# Get the sink number:
# $ pacmd list |awk '/active profile/{getline;getline;print;exit}'
#		alsa_output.pci-0000_00_1b.0.analog-stereo/#6: Built-in Audio Analog Stereo
# $ pacmd list |awk '/active profile/{getline;getline;print;exit}' |grep -Po '(?<=#)\d+(?=:)' 
# 6
# Alternative: amixer sset 'Master' 50% (runs also as root , without the need of su or gksu)

#if grep '^connected$' /sys/class/drm/card0/*HDMI*/status >/dev/null 2>&1;then soundsetup 1; fi


if [[ -z $1 ]]; then
clirun=0
[[ -z "$sec" ]] && m=$(xrandr --listmonitors) && yad --center --text="No second monitor connected \n $m" #&& exit 1
answer=$(yad --center --form --num-output --title="Monitors Setup" --separator="" --field="Screen Setup":CB "Laptop Mirror!Native Mirror!Extended Desktop!VGA Only!VGA Enlarged!Laptop Only!Sound Setup!Exit")
else
clirun=1
echo "Setting screen schema by command line : You have provided option : $1" #&& exit 1
[[ -z "$sec" ]] && echo -e "No second monitor connected" #&& m=$(xrandr --listmonitors) 
#echo -e "We detected those monitors/outputs:\n $m" #&& exit 1
#we can call a function here to manipulate the $1 value and assign it to $answer , and thus case bellow will work in all cases
#for exampe 
case $1 in 
"--lapmirror") answer=1;;
"--natmirror") answer=2;;
"--extended") answer=3;;
"--vgaonly") answer=4;;
"--vgaenlarged") answer=5;;
"--laptoponly") answer=6;;
"--soundsetup-hdmi") soundsetup --hdmi;;
"--soundsetup-laptop") soundsetup --laptop;;
"--status") getactive "$clirun" && answer=8;;
"--help") helppeople;;
*) echo "not recognized option $1, exiting..." && answer=8;;
esac
fi

case $answer in
1) lapmirror "$prim" "$sec";;
2) natmirror "$prim" "$sec";;
3) extended "$prim" "$sec";;
4) vgaonly "$prim" "$sec";;
5) vgaenlarged "$prim" "$sec";;
6) laptoponly "$prim" "$sec";;
7) soundsetup;;
8) exit;;
esac
getactive "$clirun" #After finishing the set up, read and display the values from xrandr , as a kind of gui verification.
exit
#xrandr --output HDMI-1 --off --output HDMI-2 --off --output eDP-1 --mode 1366x768 --scale 2x2 
#This will adjust the laptop screen to 2732x1536. 
#xrandr --output HDMI-1 --off --output HDMI-2 --off --output eDP-1 --mode 1366x768 --scale 1.4x1.4 
#This will adjust/force the laptop screen to 1920x1080, like VGA/HDMI. Usefull to restore lost windows when hdmi is disconnected 
