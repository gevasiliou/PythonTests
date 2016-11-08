#!/bin/bash

function printarray {
arr=("${@}")
ind=0
#IFS=$'\n'
#IFS=$'\n'
	echo "Start of array "	
	echo "Items in Array:" ${#arr[@]}
	echo -e "Array[@]=" "${arr[@]}"
#	printf IFS= "Array[@]=" "${arr[@]}"
	for e in "${arr[@]}"; do
		#echo "Array[$ind]=" "$e"
		printf '%s\n' "Array[$ind]=$e"
		ind=$(($ind+1))
	done

 	printf "End of Array \n\n"
#unset IFS 
unset arr
}

function test1 {
for i in $( ls /usr/share/applications/*.desktop); do
	executable=$(grep -m 1 -Po '(?<=^Exec=)[ --0-9A-Za-z/:space:]*' $i )
	comment=$(grep -m 1 -Po '(?<=^Comment=)[ --0-9A-Za-z/:space:]*' $i )
	comment2=$(grep -m 1 -Po '(?<=^Generic Name=)[ --0-9A-Za-z/:space:]*' $i)
	mname=$(grep -m 1 -Po '(?<=^Name=)[ --0-9A-Za-z/:space:]*' $i)
	icon=$(grep -m 1 -Po '(?<=^Icon=)[ --0-9A-Za-z/:space:]*' $i)

	if [[ $comment = "" ]]; then
		comment=$comment2
	fi
	
	list+=( "$fileindex" "${icon[0]}" "${mname[0]}" "$i" "${executable[0]}" "${comment[0]}" ) #this sets double quotes in each variable.
	fileindex=$(($fileindex+1))
	
done
}

function test8 {
i=/usr/share/applications/g*.desktop
	readarray -t fi < <(printf '%s\n' $i)
	IFS=$'\n' printarray ${fi[@]}
#	unset IFS
	readarray -t executable < <(grep  -m 1 '^Exec=' $i)
	executable+=("$(grep -L '^Exec=' $i)"":Exec=None")
	IFS=$'\n' sortexecutable=($(sort <<<"${executable[*]}"))
	trimexecutable=($(grep  -Po '(?<=Exec=)[ --0-9A-Za-z/]*' <<<"${sortexecutable[*]}"))
	printarray ${trimexecutable[@]}
#	unset IFS
#	yad --text "next"
#---------------------------------------------------------------------------------------#
	readarray -t comment < <(grep -m 1 "^Comment=" $i )
	readarray -t nocomment < <(grep -L "^Comment=" $i )	
	IFS=$'\n'
	for items in ${nocomment[@]}; do
		comment+=($(echo "$items"":Comment=None"))
	done
	IFS=$'\n' sortcomment=($(sort <<<"${comment[*]}"))
	trimcomment=($(grep -Po '(?<=Comment=)[ --0-9A-Za-z/]*' <<<"${sortcomment[*]}"))
	printarray ${trimcomment[@]}
	unset IFS
#---------------------------------------------------------------------------------------#
	
	ae=0
	for aeitem in ${fi[@]};do
		list+=( "$fileindex" "${trimicon[$ae]}" "${trimmname[$ae]}" "${fi[$ae]}" "${trimexecutable[$ae]}" "${trimcomment[$ae]}" ) #this sets double quotes in each variable.
		fileindex=$(($fileindex+1))
		ae=$(($ae+1))
	done
}

function test9 {
IFS=$'\n'
i=/usr/share/applications/*.desktop
#readarray -t ag< <(grep -m1 -e "^Exec=" -e "^Name=" -e "^Icon=" -e "^Comment=" -e "^GenericName=" $i)
#ag=($(grep -e "^Exec=" -e "^Name=" -e "^Icon=" -e "^Comment=" -e "^GenericName=" $i))
#printarray ${ag[@]}
#results=/home/gv/Desktop/PythonTests/grepres.log
#printf '%s\n' ${ag[@]} > $results

fn=($(ls $i))

#printarray ${fn[@]}
fileindex=1
for f in ${fn[@]}; do
#	echo $f
#	values=($(grep "$f" $results))
	values=($(grep -e "^Exec=" -e "^Name=" -e "^Icon=" -e "^Comment=" -e "^GenericName=" $f))
	echo ${values[@]} 2>&1 &
#	echo "trimexec" $f "-" $trimexecutable
#	trimcomment=$(grep "$f" $results |grep -Po '(?<=Comment=)[ --0-9A-Za-z/]*')
#	trimcomment2=$(grep "$f" $results |grep -Po '(?<=GenericName=)[ --0-9A-Za-z/]*')
#	trimmname=$(grep "$f" $results |grep -Po '(?<=Name=)[ --0-9A-Za-z/]*')
#	trimicon=$(grep "$f" $results |grep -Po '(?<=Icon=)[ --0-9A-Za-z/]*')
	#echo "$fileindex" "$trimicon" "$trimmname" "$f" "$trimexecutable" "$trimcomment"
	#list+=( "$fileindex" "$trimicon" "$trimmname" "$f" "$trimexecutable" "$trimcomment" ) 
#	fileindex=$(($fileindex+1))
done

}


TimeStarted=$(date +%s.%N)
#echo "Time Started=" $TimeStarted
#test1
#test8
test9
TimeFinished=$(date +%s.%N)
TimeDiff=$(echo "$TimeFinished - $TimeStarted" | bc -l)
#echo "Time Finished=" $TimeFinished
echo "Run Time= " $TimeDiff
