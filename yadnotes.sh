fname=""
while :
do
title="YadNotes - $fname"
txttosave=$(yad --title="$title" --text-info --filename="$fname" --editable --wrap --width=500 --height=500 --center --button=gtk-save:10 --button='Exit':20 --button='Open':30 2>/dev/null)

case $? in
10) #echo "gtk-save selected"
    fnametosave=$(yad --file --filename="$fname" --save --center --title='Select File To Save your notes' 2>/dev/null)
    [[ $? -eq 1 ]] && continue
    [[ "$fname" == "$fnametosave" ]] && yad --text="This file exists. Overwrite?" --button=gtk-ok --button=gtk-cancel
    case $? in
    1) continue;;
    0) [[ ! -z "$fnametosave" ]] && echo "$txttosave" > "$fnametosave" || yad --text="No Filename - No Save"
    [[ ! -z "$fnametosave" ]] && fname="$fnametosave"
    ;;
    esac  
    #if file name to save is NOT empty then assign it to fname. 
    #If fnametosave is empty then no action - the previous fname (if set i.e by fnametoopen) will be preserved.

    #break
    ;;
20) #echo "Exit selected"
    break
    ;;
30) #echo "Open Button Pressed"
    fnametoopen=$(yad --file --center --title='Open Notes File' 2>/dev/null)
    [[ ! -z "$fnametoopen" ]] && fname="$fnametoopen"  #if file name to open is NOT empty then assign it to fname
    ;;
esac
done
