#!/bin/bash
#while inotifywait -e modify /sys/class/drm/card0/card0-HDMI-A-2/status #/sys/class/drm/card0/*HDMI*/status; 
#inotify does not work on /sys/files since they are special files like ram, updated by kernel
#do

sleep 1
	if grep '^connected$' /sys/class/drm/card0/card0-HDMI*/status ;then #/sys/class/drm/card0/*HDMI*/status >/dev/null 2>&1;then 
	    sleep 2
        echo "$(date) --- HDMI connected" >> /var/log/hdmi.log #full path required
	    su gv -c 'pacmd set-card-profile 0 output:hdmi-stereo' #hdmi-surround
        active=$(su gv -c 'pacmd list |grep "active profile"')
        echo "$(date) --- $active" >> /var/log/hdmi.log #full path required
        amixer sset 'Master' 120%  >& /dev/null
        #2022
        #xrandr --output eDP-1 --off --output HDMI-2 --mode 1920x1080 --scale 1x1 2>>/var/log/hdmi.log #not working, even with su gv -c
        #su gv -c "DISPLAY=:0.0 bash -x '/usr/bin/xrandr --output eDP-1 --off' " #not working 
        #su gv -c 'DISPLAY=:0.0 bash -x /home/gv/Desktop/PythonTests/laptopscreen.sh off 1>&2 2>>/var/log/hdmi.log' #working
        #
        #13.02.2022 : 
        #su gv -c 'DISPLAY=:0.0 bash /home/gv/Desktop/PythonTests/twoscreens.sh --vgaonly >>/var/log/hdmi.log' #working - keeping this one
        #Above command works ok and laptop screen is automatically disabled keeping only hdmi in native resolution
        # Debian 11: The use of FN + Screen Hot Key (i.e F4) works perfectly allowing correctly to mirror or laptop only or vgaonly
        # so youu don't need a script solution. Just hit FN+F4
        # Bug present 13022022:
        #when tv input is switched to another hdmi or antenna , if you unplug the hdmi cable later , kerner fails to detect
        #that hdmi is disconnected (unless you run xrandr). This has as result to stay with a black laptop screen if "vga only"
        #had been selected before either by this script or by the hot FN key combination. 
        #If you unplug the hdmi cable when the correct hdmi channel is selected on TV then detection of "hdmi disconnected" 
        #works perfectly either by this script or by the display utility called by FN key combination and laptop screen is normally enabled.
        #Bug workaround: 
        #When you will be left with a black laptop screen due to hdmi cable disconnection, just hit FN+Screen Key
        #and everything will be restored (laptop screen will be re-enabled obviously due to the display utility hot key call that invokes xrandr i suppose). 
        
        echo "$(date)  ---- given command : xrandr eDP-1 off HDMI-2 on" >> /var/log/hdmi.log
        #su gv -c 'DISPLAY=:0.0 bash /home/gv/Desktop/PythonTests/twoscreens.sh --status >>/var/log/hdmi.log' #works
        #xr=$(xrandr 2>&1) 
        #echo "$(date) --- xrandr : $xr" >> /var/log/hdmi.log
        #w=$(whoami);echo "$w" >> /var/log/hdmi.log

	else
	    sleep 2
	    echo "$(date) --- HDMI disconnected" >> /var/log/hdmi.log #full path required
	    su gv -c 'pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo' #pacmd does not run as root
            active=$(su gv -c 'pacmd list |grep "active profile"')
            echo "$(date) --- $active" >> /var/log/hdmi.log #full path required
            amixer sset 'Master' 120% >& /dev/null
            #13.02.2022:
            #su gv -c 'DISPLAY=:0.0 bash -x /home/gv/Desktop/PythonTests/laptopscreen.sh on 1>&2 2>>/var/log/hdmi.log' #working
            #su gv -c 'DISPLAY=:0.0 bash /home/gv/Desktop/PythonTests/twoscreens.sh --laptoponly >>/var/log/hdmi.log' #working ok keeping this one
            #echo "$(date)  ---- given command: xrandr eDP-1 ON HDMI-2 OFF" >> /var/log/hdmi.log #works - for troubleshooting only
            #xr=$(xrandr 2>&1) && echo "$(date) --- $xr" >> /var/log/hdmi.log #sucks, xrandr fails - unknown display error
            #su gv -c 'DISPLAY=:0.0 bash /home/gv/Desktop/PythonTests/twoscreens.sh --status >>/var/log/hdmi.log'  #works ok
            #finally disabled since FN key ++ screen key F4 works perfect in Debian 11
	fi
#done
exit 0

<<EOH
Sound auto switching to hdmi
https://wiki.archlinux.org/index.php/PulseAudio/Examples#Automatically_switch_audio_to_HDMI
You need to work with udev , systemd and shell

1. create a  new rule file 
cat <<EOF > /lib/udev/rules.d/78-hdmi.rules
KERNEL=="card0", SUBSYSTEM=="drm", ACTION=="change", RUN+="/bin/systemctl start hdmi-sound.service"
EOF

PS: rule files can not call shell scripts directly
PS: systemctl path may vary. Find it using which systmctl
PS: To avoid permission issues better to copy an existed rule file: cp 78-sound.rule 78-hdmi.rules
    This will ensure that the new file will have the correct permissions. In any case all rules files seems to have 644 permissions.

2. Create a .service file. Service files can call sh scripts without problem.
cat <<EOF > /etc/systemd/system/hdmi-sound.service
[Unit]
Description=hdmi sound hotplug

[Service]
Type=simple
RemainAfterExit=no
ExecStart=/usr/bin/hdmisound.sh

[Install]
WantedBy=multi-user.target

EOF

chmod 777 /etc/systemd/system/hdmi-sound.service

3. Copy the file hdmisound.sh to /usr/bin
cp -iv /home/gv/Desktop/PythonTests/newpcsetup/hdmisound.sh /usr/bin

4. Reload rules and you are ready
udevadm control --reload-rules

5. Verify that udev calls the required service using #journalctl and scroll to the end.
You should see something like this close to the end
Feb 13 02:21:16 debian systemd[1]: Configuration file /etc/systemd/system/hdmi-sound.service is marked executable. Please remove executable permission bits. Proceeding anyway.
Feb 13 02:21:16 debian systemd[1]: Configuration file /etc/systemd/system/hdmi-sound.service is marked world-writable. Please remove world writability permission bits. Proceeding anyway.
Feb 13 02:21:16 debian systemd[1]: Started hdmi sound hotplug.
Feb 13 02:21:16 debian hdmisound.sh[25807]: connected

6. As an additional check you can look at the file /var/log/hdmi.log
Tip: changes in this shell script are applied directly, no need to reload rules with udevadm

EOF
EOH
