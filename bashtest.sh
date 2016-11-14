#!/bin/bash
#    for dir in /home/gv/dir1/*/ ; do
#      echo $dir
#    done
    
#    for dir in /home/gv/dir1/* ; do
#      echo $dir
#    done

#    for dir in $(ls /home/gv/dir1/*/) ; do
#      echo $dir
#     done

function numcheck {
echo "Give a number:" && read var
#var=1

if [ "$var" -eq "$var" ] 2>/dev/null; then #if you ommit the 2>/dev/null then if you enter a worng value, bash will complain in your screen.
  echo number
else
  echo not a number
fi
}

#numcheck

#bc <<< "scale=2;$var1/$var2" or answer=$(bc <<< "scale=2;$var1/$var2")

#!/bin/bash
function finddivider {
groups=$(bc <<< "scale=1;$NoOfLines/$1")
decimals=$(cut -f 2 -d "." <<<$groups)
}

function readlog1 {
readarray -O 1 FileContents < <(cat test.log)
NoOfLines=${#FileContents[@]}
divider=3 # initial setting
finddivider $divider

while [[ $decimals != "0" ]]; do
divider=$(($divider + 1))
finddivider $divider
done

if [[ $divider == $NoOfLines ]]; then
echo "No integer divider found. Default divider of 3 will be used".
divider=3
echo "Divider=" $divider
fi

for ((i=1;i<=$divider;i++)); do
echo $i ${FileContents[$i]} 
done

#readarray tt 
}

# -----Main Prog---- #
#!/bin/bash
result=$(cat test.log | grep -A 2 "Published 1EO's")
IFS=$"\n"
echo $result
line=$(echo -e "Published 1EO's\nSave completed\nTrade saving save successful for trade 56945458|220841|b for MCR: CMDTY from source:ICE Tradecapture API retry count: 0 (From this line we check Company Name – CMDTY)")

#echo $line | grep "\b$result\b"
echo "----------------------------------"
echo $line

unset IFS

if [[ $line = $result ]]; then
 echo "match"
else
 echo "does not match"
fi
