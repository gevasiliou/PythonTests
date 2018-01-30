#! /bin/bash
#--button="Enter" --button="unlock" --button="exit" \
#https://sourceforge.net/p/yad-dialog/wiki/Examples/
# Source: https://linuxappfinder.com/blog/auto_screen_rotation_in_ubuntu
# Tweaks: https://gist.github.com/mildmojo/48e9025070a2ba40795c

#TOUCHSCREEN='ELAN Touchscreen' #as reported by evtest
TOUCHSCREEN="$(xinput list --name-only |grep -i -e 'touchscreen' -e 'touch[- ]screen')"
TRANSFORM='Coordinate Transformation Matrix'

function gv {
> sensor.log 
monitor-sensor >> sensor.log 2>&1 & 

exec >> autorotate.log 2>&1
#TOUCHSCREEN='ELAN Touchscreen' #as reported by evtest
TOUCHSCREEN="$(xinput list --name-only |grep -i -e 'touchscreen' -e 'touch[- ]screen')"
TRANSFORM='Coordinate Transformation Matrix'

printf '%s ' $(date) && echo 'Start of Function gv. Parameters Received:' $1 $2 $3 #Parameters inside function get a different number / name.
 
screen=$(xrandr | grep 'connected' |grep -v 'disconnected' | grep -oE '[a-zA-Z]+[\-]+[^ ]') 
printf '%s ' $(date) && echo 'Auto Recognize screen {alt}:' $screen

while inotifywait -e modify sensor.log 2>&1 |ts; 
#ts is a utility of pkg moreutils and automatically time stamps output of any command. Using 2>&1 stderr is also time stamped
do 
	ORIENTATION=$(tail -n 1 sensor.log | grep 'orientation' | grep -oE '[^ ]+$') 
		case "$ORIENTATION" in
		normal)
		printf '%s ' $(date) && echo 'xrandr rotate normal'
		xrandr --output $screen --rotate normal
		xinput set-prop "$TOUCHSCREEN" "$TRANSFORM" 1 0 0 0 1 0 0 0 1
		#gsettings set com.canonical.Unity.Launcher launcher-position Left
		;;		
		bottom-up)
		printf '%s ' $(date) && echo 'xrandr rotate bottom-up'
		xrandr --output $screen --rotate inverted
		xinput set-prop "$TOUCHSCREEN" "$TRANSFORM" -1 0 1 0 -1 1 0 0 1 
		#gsettings set com.canonical.Unity.Launcher launcher-position Left
		;;		
		right-up)
		printf '%s ' $(date) && echo 'xrandr rotate right-up'
		xrandr --output $screen --rotate right
		xinput set-prop "$TOUCHSCREEN" "$TRANSFORM" 0 1 0 -1 0 1 0 0 1
		#gsettings set com.canonical.Unity.Launcher launcher-position Bottom
		;;		
		left-up)
		printf '%s ' $(date) && echo 'xrandr rotate left-up'
		xrandr --output $screen --rotate left
		xinput set-prop "$TOUCHSCREEN" "$TRANSFORM" 0 -1 1 1 0 0 0 0 1
		#gsettings set com.canonical.Unity.Launcher launcher-position Bottom
		;;
		esac
done
printf '%s ' $(date) && echo 'End of Function gv' 
exit 1
}
export -f gv

function notifystop {
exec >> autorotate.log 2>&1
printf '%s ' $(date) && echo 'Notify Stop'
#exec 2> /dev/null
#pidof monitor-sensor | xargs kill -9
#pidof inotifywait | xargs kill -9
pkill -f "monitor-sensor" 2>&1
pkill -f "monitor-sensor >> sensor.log 2>&1"  2>&1
pkill -f "inotifywait -e modify sensor.log"  2>&1
exit
}
export -f notifystop

function byebye {
exec >> autorotate.log 2>&1
#exec 2> /dev/null
printf '%s ' $(date) && echo 'Bye Bye to all!'
#pidof monitor-sensor | xargs kill -9
#pidof inotifywait | xargs kill -9
#pidof yad | xargs kill -9
pkill -f "monitor-sensor"  2>&1
pkill -f "monitor-sensor >> sensor.log 2>&1"  2>&1
pkill -f "inotifywait -e modify sensor.log"  2>&1
pkill -f "autorot.sh"  2>&1
pkill -f "yad --notification --command=bash -c autorot >>autorotate.log 2>&1"  2>&1
#rm -f sensor.log autorotate.log
exit
}
export -f byebye

function autorot {
exec >> autorotate.log 2>&1
# ------------------------------------------------------- The main function ----------------------------- #
printf '%s ' $(date) && echo 'Main Programm Starting'
action=$(yad --width 300 --entry --title "AutoRotate" \
    --image=gnome-shutdown \
    --button="gtk-ok:0" --button="gtk-cancel:1" \
    --text "Choose action:" \
    --entry-text "UnLock" "Lock" "Exit" )

pof=$(pidof monitor-sensor) && printf '%s ' $(date) && echo 'monitor-sensor pid =' $pof

if [[ $pof -eq "" ]]; then 
	running="notrunning"
else
	running="running"
fi

case $action in
    UnLock*) 
		printf '%s ' $(date) && echo 'Unlock Selected'
#		gv $locked $running
		#Check if monitor-sensor and inotify is already running to avoid creating a new instance.		
		if [[ $pof -eq "" ]]; then 
			printf '%s ' $(date) && echo "notrunning - starting now"
			gv
		else
			printf '%s ' $(date) && echo "already running , skipping command"
		fi
		;;
    Lock*) 
		printf '%s ' $(date) && echo 'Locked Selected'
		notifystop;;
    Exit*)
		printf '%s ' $(date) && echo 'Exit Selected' 
		byebye;;
	    *) exit 0;;    
esac
printf '%s ' $(date) && echo 'Main Programm End'
exit 0
}
export -f autorot

yad --notification --command="bash -c autorot >>autorotate.log 2>&1" >>autorotate.log 2>&1
#yad --notification --image=gtk-help --command="bash -c autorot >>autorotate.log 2>&1" >>autorotate.log 2>&1
exit
# I tried to use a kind of flags passing to the functions in order to avoid pkill for lock feature.
# But is seems that once inotifywait runs once, will be always running as process.
# As a result if you try to "skip" the inotify section with some "already running" logic checks, they do not work.
# It seems that the most easy way when you want to lock the autorotation is just to kill the inotify and monitor-sensor.
# To verify if the process is killed : #ps aux |grep inotify or grep monitor-sensor
# To simulate the monitor-write, open a second terminal and # echo "    Accelerometer orientation changed: bottom-up" >>sensor.log
# It has been observed with ps aux that the monitor sensor process some times appear just as "monitor-sensor" and some times with full comannd line.
