exec 3>&2 2>log 4<log 

set -vx
"$@" >&2
set +vx 
cat <&4 >&1  |tail -n +2 |head -n -2 #this prints out the whole logfile. If this is missing you see nothing on screen / command line
