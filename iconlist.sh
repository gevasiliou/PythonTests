#!/bin/bash 
# http://www.murga-linux.com/puppy/viewtopic.php?p=903968&sid=fd8024fd4befb81e36e4c6eeb7f563ba
export TMPFILE=/tmp/yadvalues 
function savevalues 
{ 
echo -e "IMGNAME=\"$2\"\nIMGSIZE=$3\nIMGPATH=\"$4\"" > $TMPFILE 
}
export -f savevalues 

function showinfo   
{ 
source $TMPFILE
exiv2   "$IMGPATH" 2>/dev/null | gxmessage -c -fn mono -file -  
}
export -f showinfo 
function showinrox  
{ 
source $TMPFILE
rox -s  "$IMGPATH"
}
export -f showinrox 
function copypath   
{ 
source $TMPFILE
echo -n "$IMGPATH" | xclip -i -selection clipboard  
}
export -f copypath 
SEP=";" 
#FOUND=$(find -L /usr/local/lib/X11/pixmaps -regextype gnu-awk -iregex  ".*\.(png|jpg|gif|xpm)$" -printf "%p${SEP}%f${SEP}%s${SEP}%p${SEP}") 
FOUND=$(find -L /usr/share/icons/Tango -regextype gnu-awk -iregex  ".*\.(png|jpg|gif|xpm)$" -printf "%p${SEP}%f${SEP}%s${SEP}%p${SEP}") 

IFS=$SEP 
yad --list  --geometry=700x500 \ 
--select-action='sh -c "savevalues %s"' \ 
--column=icon:IMG \ 
--column=name \ 
--column=size:NUM \ 
--column=path \ 
--button="Info":'sh -c "showinfo"' \ 
--button="Show Location":'sh -c "showinrox"' \ 
--button="Copy Path":'sh -c "copypath"' \ 
--button="gtk-ok":0 \ 
--button="gtk-cancel":1 \ 
$FOUND
