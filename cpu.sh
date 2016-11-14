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
