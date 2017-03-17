#! /bin/bash -i
exec 3>&2 2>log 4<log 

set -vx
"$@" >&2
set +vx 
cat <&4 >&1 # |tail -n +2 |head -n -2 #this prints out the whole logfile. If this is missing you see nothing on screen / command line

#Alternative:
#http://stackoverflow.com/questions/42841662/command-redirection/42847799#42847799
# Make a function in your current shell / bash aliases
#
# $ function logme { a="$@"; echo $a >log ; "$@" >>log 2>&1;cat log;return; }
# $ logme pwd  
# > pwd
# > /home/gv/Desktop/PythonTests
