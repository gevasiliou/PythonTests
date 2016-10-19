#!/bin/bash
#answer=$(zenity --list --text='test' --radiolist --column="Action" --column="-" TRUE "Unlock" FALSE "Locked" FALSE "Exit")
echo "starting..."

yad --notification --command="zenity --list --text='test' --radiolist --column='Action' --column='-' TRUE 'Unlock' FALSE 'Locked' FALSE 'Exit'"

#arg="zenity --list --text='test' --radiolist --column='Action' --column="-" TRUE 'Unlock' FALSE 'Locked' FALSE 'Exit'"
#echo 'you choose:' $arg

#yad --notification --command=$arg


echo "you selected:" 
echo $ans
#ans=$(yad --notification --command="zenity --list --text='test' --radiolist --column='Action' --column='-' TRUE 'Unlock' FALSE 'Locked' FALSE 'Exit'") --> this does NOT work.

