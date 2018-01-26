#!/bin/bash
# Adjust CPU performance
# With intel_pstate enabled (default) you can have only "powersave" (default) or performance
# Both provide a variable CPU speed, although "performance" works better = higher.
# if you disable intel_pstate at boot time (kernel parameter intel_pstate=disable, just before ro quiet)
# you will be able to select more governors like conservative and ondemand, or even to stick your own CPU GHz.
# To see current available governors just run $cpufreq-info
# to set dynamically a new governor: $cpufreq-set -c 0 -g performance (repeat with -c 1 or as many cpus you have)
# to stick a fixed cpu frequency use $cpufreq-set -c 0 -f 1600000 (in case 1,6 GHz is your max)
# Use  fixed frequncy requires intel_pstate to be disabled . userspace governor is used automatically
# the whole story works only if cpufrequtils are installed (check with apt policy - usually installed by default)
# to verify the capabilities of your cpu : cat /proc/cpuinfo
# http://unix.stackexchange.com/questions/121410/setting-cpu-governor-to-on-demand-or-conservative
# https://wiki.debian.org/HowTo/CpuFrequencyScaling
# https://www.computerhope.com/unix/modprobe.htm

if [[ $1 = "" ]]; then

#echo "Supply a govenor like performace, powersave, etc"
#echo "1. Performance"
#echo "2. Powersave"
#echo "3. Exit"
#echo -e "Enter your selection:"; read answer
answer=$(yad --form --num-output --separator="" --field="Governor":CB "Performance!PowerSave!Exit")
#echo $answer
#exit
else
echo "Setting governor:" $1
gksu -g "cpufreq-set -c 0 -g $1"
gksu -g "cpufreq-set -c 1 -g $1"
gov0=$(cpufreq-info -c 0 |grep "may decide which" |cut -f 2 -d '"')
gov1=$(cpufreq-info -c 1 |grep "may decide which" |cut -f 2 -d '"')
yad --center --text="Govervor used :\n CPU0: $gov0 \n CPU1: $gov1"
exit
fi

case $answer in
1) 
#echo "Setting performance"
gksu -g "cpufreq-set -c 0 -g performance"
gksu -g "cpufreq-set -c 1 -g performance"
gov0=$(cpufreq-info -c 0 |grep "may decide which" |cut -f 2 -d '"')
gov1=$(cpufreq-info -c 1 |grep "may decide which" |cut -f 2 -d '"')
yad --center --text="Govervor used :\n CPU0: $gov0 \n CPU1: $gov1"
;;
2)
#echo "Setting powersave"
gksu -g "cpufreq-set -c 0 -g powersave"
gksu -g "cpufreq-set -c 1 -g powersave"
gov0=$(cpufreq-info -c 0 |grep "may decide which" |cut -f 2 -d '"')
gov1=$(cpufreq-info -c 1 |grep "may decide which" |cut -f 2 -d '"')
yad --center --text="Govervor used :\n CPU0: $gov0 \n CPU1: $gov1"
;;
3) 
gov0=$(cpufreq-info -c 0 |grep "may decide which" |cut -f 2 -d '"')
gov1=$(cpufreq-info -c 1 |grep "may decide which" |cut -f 2 -d '"')
yad --center --text="Govervor used :\n CPU0: $gov0 \n CPU1: $gov1"
exit
;;
esac

exit
#cpufreq-set -c 0 -f 1600000
#cpufreq-set -c 1 -f 1600000
#cpufreq-set -c 0 -g performance --min 2000000 --max 3000000 #real max will be the hw limit 2160000
# modprobe cpufreq_userspace 
#cpufreq-info

:help <<OOO
depmod — Generate a list of kernel module dependences and associated map files.
insmod — Insert a module into the Linux kernel.
lsmod — Show the status of Linux kernel modules.
modinfo — Show information about a Linux kernel module.
rmmod — Remove a module from the Linux kernel.
uname — Print information about the current system.
$ i=1;while ((i<100));do cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq;printf '\n';sleep 0.5;i=$i+1;done
$ for f in /sys/devices/system/cpu/cpu*/cpufreq/*;do echo "------->> $f <<-----------";cat "$f";printf '\n';done
$ realpath /sys/devices/system/cpu/cpu1/cpufreq
/sys/devices/system/cpu/cpufreq/policy1
$ find /sys/devices/system/cpu/** -type f -print -exec cat {} \; |less
$ for f in /sys/devices/system/cpu/intel_pstate/**;do ls -all "$f";cat "$f";done #ls -all is prefered to see what file is writable


OOO
##grep "cpu MHz" /proc/cpuinfo
