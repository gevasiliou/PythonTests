#! /bin/bash
#--button="Enter" --button="unlock" --button="exit" \
#https://sourceforge.net/p/yad-dialog/wiki/Examples/

function gv()
{

echo 'locked parameter value:' $1 #function parameters have their own numbering/naming system....
echo 'program running value:' $2 
screen2=$(xrandr | grep 'connected' |grep -v 'disconnected' | grep -oE '[a-zA-Z]+[\-]+[^ ]') 
echo 'Auto Recognize screen {alt}:' $screen2

if [ $2 -eq 0 ]; then
echo 'program not running...strting now'
> sensor.log 
monitor-sensor >> sensor.log 2>&1 & 
while inotifywait -e modify sensor.log; 
do 
	ORIENTATION=$(tail -n 1 sensor.log | grep 'orientation' | grep -oE '[^ ]+$') 
	if [[ $1 -eq 0 ]]; then
		echo 'since not locked,lets roll'	
		case "$ORIENTATION" in
		normal)
		xrandr --output $screen2 --rotate normal ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Left ;;
		bottom-up)
		xrandr --output $screen2 --rotate inverted ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position 	Left ;;
		right-up)
		xrandr --output $screen2 --rotate right ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Bottom ;;
		left-up)
		xrandr --output $screen2 --rotate left ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Bottom ;;
		esac
#	exit 0
	fi
done
#exit 0
fi
#exit #exit may not required. added by me.

}

function byebye
{
echo 'Bye Bye'
pidof monitor-sensor | xargs kill -9
pidof inotifywait | xargs kill -9
pidof yad | xargs kill -9
#pidof autorotate.sh | xargs kill -9
#exit
}

# The main program
action=$(yad --width 300 --entry --title "AutoRotate" \
    --image=gnome-shutdown \
    --button="gtk-ok:0" --button="gtk-cancel:1" \
    --text "Choose action:" \
    --entry-text "UnLock" "Lock" "Exit" )

case $action in
    UnLock*) locked=0 ;;
    Lock*) locked=1 ;;
    Exit*) byebye  ;;
    *) exit 1 ;;    
esac
pof=$(pidof monitor-sensor)
echo 'pof=' $pof
if [$pof -eq ""]; then 
running=0
fi
echo 'one step to call gv. running value is ' $running

gv $locked $running #call function with parameters

#ret=$?
#
#[[ $ret -eq 1 ]] && exit 0
#
#if [[ $ret -eq 2 ]]; then
#    gdmflexiserver --startnew &
#    exit 0
#fi


#This works fine
#case $action in
#    Lock*) cmd="echo 'Lock pressed'" ;;
#    Unlock*) cmd="echo 'unlock pressed'" ;;
#    Exit*) cmd="echo 'exit pressed'" ;;
#    *) exit 1 ;;    
#esac
#eval exec $cmd #executes the previously selected command in case
