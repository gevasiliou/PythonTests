#!/bin/bash
#Written by smokey01
#04 May 2016

function help 
{
yad --window-icon="gtk-find" --center --title="Look4 Help" --text="
This is a simple little GUI made with
YAD to help drive the find command.

All fields must be populated or the GUI
will not return any results.

If you believe you should have received
results but didn't, try widening the
date and or size parameters.

Double click on results to open the file.

Requires YAD-0.36.2 or later.

Enjoy. smokey01
"
}
export -f help

function look  
{
loc=${1}
name=${2}
#startdate=${3}
#enddate=${4}
#startsize=${5}
#endsize=${6}

#find $loc -name "$name" -newermt "$startdate" ! -newermt "$enddate" -size +$startsize"k" ! -size +$endsize"k" | yad --width=600 --height=400 --separator=" " --window-icon="gtk-find" --title "Search Results" --center --column "Files" --list --dclick-action="rox"
find $loc -name "$name" | yad --width=600 --height=400 --separator=" " --window-icon="gtk-find" --title "Search Results" --center --column "Files" --list --dclick-action="rox"

}
export -f look

yad --window-icon="gtk-find" --title="Look4 Files" --center --form --separator=" " --date-format="%Y-%m-%d" \
--field="Location:":MDIR "$PWD" \
--field="Filename:" "*.sh" \
--field="Start Date:":DT "2000-01-01" \
--field="End Date:":DT "2016-12-31" \
--field="Start Size KB:":NUM "0" \
--field="End Size KB:":NUM "1024" \
--field="Find!gtk-find:BTN" 'bash -c "look %1 %2 %3 %4 %5 %6"' \
--button=gtk-help:'bash -c help' \
--button=gtk-quit:0

#yad --window-icon="gtk-find" --title="Look4 Files" --center --form --columns=2 --separator=" " --date-format="%Y-%m-%d" \
--field="Location:":MDIR "/" --field="Filename:" "*" --field="Directories Only":CHK --field="Executables Only":CHK \
--button=gtk-help:'bash -c help' --button=gtk-find:0 --button=gtk-quit:1
