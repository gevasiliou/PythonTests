#time awk 'FNR==NR{a[$1]=$2;next}{for(i in a){match($0,i);val=substr($0,RSTART,RLENGTH);if(val){sub(val,a[i]);print;next}};}1' patterns.txt  <(head -n 1000 contents.txt) >newcontents.txt &
#sleep 1
#time awk 'FNR==NR{a[$1]=$2;next}{for(i in a){match($0,i);val=substr($0,RSTART,RLENGTH);if(val){sub(val,a[i]);print;next}};}1' patterns.txt  <(tail -n 1000 contents.txt) >newcontents2.txt &
date
s=$SECONDS
sed -f <(printf 's/%s/%s/g\n' $(<patterns.txt)) <(head -3000 contents.txt) >newcontents1.txt &
sed -f <(printf 's/%s/%s/g\n' $(<patterns.txt)) <(tail +3001 contents.txt |head -3000) >newcontents2.txt &
sed -f <(printf 's/%s/%s/g\n' $(<patterns.txt)) <(tail +6001 contents.txt |head -3000) >newcontents3.txt &
wait
cat newcontents1.txt newcontents2.txt newcontents3.txt >newcontents.txt && rm -f newcontents[123].txt
echo "seconds elapsed: $(($SECONDS-$s))"
date
