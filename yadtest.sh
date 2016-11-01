#!/bin/bash
#answer=$(zenity --list --text='test' --radiolist --column="Action" --column="-" TRUE "Unlock" FALSE "Locked" FALSE "Exit")
echo "starting..."

#yad --notification --command="zenity --list --text='test' --radiolist --column='Action' --column='-' TRUE 'Unlock' FALSE 'Locked' FALSE 'Exit'"

#arg="zenity --list --text='test' --radiolist --column='Action' --column="-" TRUE 'Unlock' FALSE 'Locked' FALSE 'Exit'"
#echo 'you choose:' $arg

#yad --notification --command=$arg


#echo "you selected:" 
#echo $ans
##ans=$(yad --notification --command="zenity --list --text='test' --radiolist --column='Action' --column='-' TRUE 'Unlock' FALSE 'Locked' FALSE 'Exit'") --> this does NOT work.
function pbardemo {
(
echo "10" ; sleep 1
echo "# Updating mail logs" ; sleep 1
echo "20" ; sleep 1
echo "# Resetting cron jobs" ; sleep 1
echo "50" ; sleep 1
echo "This line will just be ignored" ; sleep 1
echo "75" ; sleep 1
echo "# Rebooting system" ; sleep 1
echo "100" ; sleep 1
) | yad --progress \
  --title="Update System Logs" \
  --text="Scanning mail logs..." \
  --percentage=0
}

function multigrep {
res=$(grep -e 'Exec' -e 'GenericName=' /usr/share/applications/brasero.desktop)
i=1 
#grep -nH -e 'Exec=' -e 'GenericName=' -e 'Comment=' /usr/share/applications/*a.desktop |awk -F":" '{print $3}'
#read -d"\n" foo1 foo2 <(grep -e 'Exec=' -e 'Name=' /usr/share/applications/brasero.desktop)
#echo $foo1

#output=$(curl https://domain.com/file.xml)
readarray foo < <(grep -e '^Exec=' -e '^Name=' -e 'Icon=' /usr/share/applications/gvtest.desktop)
echo ${foo[@]}
echo ${foo[0]}
echo ${foo[1]}
echo ${foo[2]}

#echo $res
}

#-----------------------------------MAIN----------------------------------#
#pbardemo
multigrep


