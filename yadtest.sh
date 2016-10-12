#!/bin/bash
#answer=$(zenity --list --text='test' --radiolist --column="Action" --column="-" TRUE "Unlock" FALSE "Locked" FALSE "Exit")
echo "starting..."
yad --notification --command="zenity --list --text='test' --radiolist --column="Action" --column="-" TRUE "Unlock" FALSE "Locked" FALSE "Exit""


echo "you selected:" 
echo $answer
