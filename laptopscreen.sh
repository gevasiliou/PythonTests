#this was created at 2022 to be called by /usr/bin/hdmisound.sh but all (and even more) functions are provided by twoscreens.sh script
#so now hdmisound.sh calls twoscreens.sh instead of this script using command line options.

synclient TapButton1=1 #Non relevant command - just enable touchpad click if necessary.
if [[ -z $1 ]]; then
echo "provide option off to switch off your laptop screen and enable HDMI";
echo "provide option on to switch on your laptop screen and disable HDMI";
echo "provide option mirror to mirror your laptop screen to HDMI";
soundsetup="$(gksu -u gv pacmd list 2>&1 |grep 'active profile')";
echo "sound: $soundsetup";
screensetup="$(xrandr --listmonitors)" && echo "$screensetup"
exit 1;
fi

if [[ $1 == "off" ]]; then 
echo "off/$1";
xrandr --output eDP-1 --off --output HDMI-2 --mode 1920x1080 --scale 1x1;
gksu -u gv pacmd set-card-profile 0 output:hdmi-stereo;
soundsetup="$(gksu -u gv pacmd list 2>&1 |grep 'active profile')" && echo "sound: $soundsetup";
screensetup="$(xrandr --listmonitors)" && echo "$screensetup"
fi

if [[ $1 == "on" ]]; then 
echo "on/$1";
xrandr --output eDP-1 --mode 1366x768 --scale 1x1 --output HDMI-2 --off;
gksu -u gv pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo;
soundsetup="$(gksu -u gv pacmd list 2>&1 |grep 'active profile')" && echo "$soundsetup";
screensetup="$(xrandr --listmonitors)" && echo "$screensetup"
fi


if [[ $1 == "mirror" ]]; then 
echo "mirror/$1";
xrandr --output eDP-1 --mode 1366x768 --scale 1x1 --output HDMI-2 --same-as eDP-1 --mode 1920x1080 --scale 1x1;#--scale 0.711x0.711
gksu -u gv pacmd set-card-profile 0 output:hdmi-stereo;
soundsetup="$(gksu -u gv pacmd list 2>&1 |grep 'active profile')" && echo "$soundsetup";
screensetup="$(xrandr --listmonitors)" && echo "$screensetup"
fi


#xrandr --output eDP-1 --mode 1366x768 --scale 1x1 --output HDMI-2 --same-as eDP-1 --mode 1920x1080 --scale 1x1 2>>/var/log/hdmi.log
