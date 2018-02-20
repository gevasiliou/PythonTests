#!/bin/bash
#while inotifywait -e modify /sys/class/drm/card0/card0-HDMI-A-2/status #/sys/class/drm/card0/*HDMI*/status; 
#inotify does not work on /sys/files since they are special files like ram, updated by kernel
#do
sleep 0.5
	if grep '^connected$' /sys/class/drm/card0/card0-HDMI*/status ;then #/sys/class/drm/card0/*HDMI*/status >/dev/null 2>&1;then 
	    sleep 2
            echo "$(date) --- HDMI connected" >> /var/log/hdmi.log #full path required
	    su gv -c 'pacmd set-card-profile 0 output:hdmi-surround'
            active=$(su gv -c 'pacmd list |grep "active profile"')
            echo "$(date) --- $active" >> /var/log/hdmi.log #full path required
            amixer sset 'Master' 120%  >> /var/log/hdmi.log 2>&1

	else
	    sleep 2
	    echo "$(date) --- HDMI disconnected" >> /var/log/hdmi.log #full path required
	    su gv -c 'pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo' #pacmd does not run as root
            active=$(su gv -c 'pacmd list |grep "active profile"')
            echo "$(date) --- $active" >> /var/log/hdmi.log #full path required
            amixer sset 'Master' 120% >> /var/log/hdmi.log 2>&1
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


EOF

