#!/bin/bash
# place this file under /usr/bin , and chmod +x this file in order to be able to call it 
# You can call it from every folder , without extension . Just run "mang command"
# For info pages (more advanced than man) you can install and use the tkinfo package (available in repos)
# Tip: Using whatis command (i.e whatis cat) gives you a single line description. You can apply this to whole dir like whatis /usr/bin/*
# Either tkinfo and man have options to looks inside directories or to display directory of man / info page been displayed.
function printhelp {
echo "  mangui - man with GUI - Usage: mangui <manpage> OR mangui --install / --help"
echo "  Place this file under /usr/bin , and chmod +x this file in order to be able to call it from anywhere. " 
echo "  Use --install to install at /usr/bin automatically"
echo "  You can call it from every folder , without extension . Just run mang command "
echo "  This prog does not work with info pages. For GUI at info pages you can install and use the tkinfo package (available in repos) "
echo " This prog works with man pages present in your system from installed packages."
}
#echo $0
#mkfifo ${fifo=$(mktemp -u)}
#exec {fd}<>${fifo}
#info cat >>$fifo
#yad --text-info <$fifo
#exit

if [[ -z $1 ]];then
	printhelp
else
	if [ "$1" = "--help" ];then 
		printhelp
	elif [ "$1" = "--install" ];then
		cp -v -i $0 /usr/bin
		sleep 1
		chmod +x /usr/bin/mangui
	else
		tit=$(echo ${1^^}) #Capitalize all letters
		manual=$(man $1 2>&1) #2>&1 is necessary since if no man available the error goes to stderr (&2) and manual will get no value since nothing is printed in stdout (&1)
		if [[ "$manual" == "No manual"* ]]
		then 
			echo "$manual" && exit
		else
			if [ -e /usr/bin/yad ];then
				man $1 |yad --text-info --height=500 --width=800 --center --title="$tit Manual " --wrap --show-uri --no-markup &	
			elif [ -e /usr/bin/zenity ];then
				echo "yad is missing , using zenity"
				man $1 |zenity --text-info --height=500 --width=800 --title="$tit Manual " &
			else
				echo "yad and zenity missing - starting classic bash man..."
				sleep 1
				man $1
			fi
		fi
	fi
fi

exit

# To be Done
# Search previous - next. Yad provides basic search with control + s which finds only the first occurence of the pattern
# Recall mang with a different file
# Provide a list of all the commands under /usr/bin , using also whatis to get single line description, select file and then man this file
# Optimize operation for info pages. Ideally be a GUI info browswer.
# About info : If you info a command with a lot of chapters all of the are send to yad.
# If you info part ot a package (i.e info cat , which is part of coreutils) only the cat pages will be send to yad but if you info coreutils you get everything (and here is where i miss the advanced search)
# Alternative script : Make a script "yadit" that will be called like "yadit whatever command" and automatically create a GUI for the command given (man,cat,ls,find,etc)

:<<man_differences
Display differences between manpages (http://unix.stackexchange.com/questions/337884/how-to-view-differences-between-the-man-pages-for-different-versions-of-the-samehttp://unix.stackexchange.com/questions/337884/how-to-view-differences-between-the-man-pages-for-different-versions-of-the-same)
diff_man() { diff -u <(man "$1") <(man --manpath="/old/path/to/man" "$1"); } - works better with diff -y (side by side comparison)
diff -w -y <(man grep) <(man agrep) (-w ignores all the whitespace and compares just real text lines)
man_differences

:<<noman
Search for files who miss manpages
http://unix.stackexchange.com/questions/337619/is-there-a-way-to-find-installed-binary-packages-which-dont-have-manpages/337761#337761
Based on the source code of manpage_alert script, part of devscripts package, this solution works fine:
F=( "/bin/*" "/sbin/*" "/usr/bin/*" "/usr/sbin/*" "/usr/games/*" );for f in ${F[@]};do for ff in $f;do if ! mp=$(man -w -S 1:6:8 "${ff##*/}" 2>&1 >/dev/null);then echo "$mp" |grep -v "man 7 undocumented";fi;done;done

Actually each binary in folders bin,sbin,usr/bin and usr/sbin is called by man recursivelly.
-w switch prints man page location and -S defines particular section of man pages.
Redirections of 2>&1 and >/dev/null makes the man command to print nothing if there is a valid man page location.
If the command man complains about missing man page, then this message is printed.
actually even if you run man -w grep >/dev/null nothing will be printed but if you run man -w getweb >/dev/null then bellow error message is printed:
No manual entry for getweb - See 'man 7 undocumented' for help when manual pages are not available.

Error message is printed on stderr instead of stdout. As usuall error messages printed can not be stored in vars, unless you redirect stderr to stdout (2>&1)
Mind that even this command will print the err message, though that var $a is not echoed:
root@debi:# a=$(man -w getweb >/dev/null)
Which means that stderr will be printed to your screen no matter what, and $a will be a blanc var.

