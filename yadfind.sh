fname=""
#filepath=$(yad --entry --entry-text="$PWD")
resp=$(yad --width=400 --title="" --text="Please enter your details:" --form --field="Path":MDIR "$PWD" --field="Search for" "*.sh")
#Respons (resp) of yad is /home/gv/Desktop/PythonTests | *.sh | (field values separated by yad default saparator |)
filepath=$(echo "$resp" | awk '{print $1}' FS='|')
namemask=$(echo "$resp" | awk '{print $2}' FS='|')

while :
do
filetoopen=$(find "$filepath" -name "$namemask" | yad --list --title "Search Results" --separator="" --width=800 --height=600 --text "Finding all header files.." --column "Files" --button='Exit':20 --button='Open':30 --button='Run':40)


case $? in
10) echo "gtk-save selected"
    ;;
20) echo "Exit selected"
    break
    ;;
30) echo "Open Button Pressed"
    while :
    do
		resp=$(yad --title="$filetoopen" --text-info --filename="$filetoopen" --editable --wrap --width=800 --height=600 --center --button="Save":100 --button="Return":1)
		case $? in 
		100) echo "$resp" > "$filetoopen";;
		1) break;;
		esac
	done 
    #fnametoopen=$(yad --file --center --title='Open Notes File' 2>/dev/null)
    #[[ ! -z "$fnametoopen" ]] && fname="$fnametoopen"  #if file name to open is NOT empty then assign it to fname
    ;;
40) bash -c "$filetoopen"
    ;;
esac
done
