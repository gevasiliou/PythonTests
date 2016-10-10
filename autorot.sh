#!/bin/sh
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

> sensor.log # Clear sensor log to keep the size small.
monitor-sensor >> sensor.log 2>&1 & # Launch monitor-sensor - store output in a variable to be parsed by rest script

# Parse output or monitor sensor to get the new orientation whenever the log file is updated
# Possibles are: normal, bottom-up, right-up, left-up. Light data will be ignored
while inotifywait -e modify sensor.log; do
ORIENTATION=$(tail -n 1 sensor.log | grep 'orientation' | grep -oE '[^ ]+$') # Read the last line that was added to the file and get the orientation

# Set the actions to be taken for each possible orientation
case "$ORIENTATION" in
normal)
xrandr --output eDP1 --rotate normal ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Left ;;
bottom-up)
xrandr --output eDP1 --rotate inverted ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Left ;;
right-up)
xrandr --output eDP1 --rotate right ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Bottom ;;
left-up)
xrandr --output eDP1 --rotate left ;; ##&& gsettings set com.canonical.Unity.Launcher launcher-position Bottom ;;
esac
done
exit
# You need to supply to xrandr the correct output (eDP1 in my case). Just run xrandr from any terminal.
# Or we can modify the script to get the output name using grep. 
# inotifywait seems that is not terminated when the script is terminated.
# To kill the inotifywait : kill -- -$$ (https://bbs.archlinux.org/viewtopic.php?id=186989) or kill $(pgrep inotifywait)
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
