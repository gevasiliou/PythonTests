#!/bin/bash
# Copy this file to /usr/bin or /bin or to any of the paths provided by $PATH. Ensure executable rights for all users and then you can then call it directly avoiding the ./manon syntax
helpme() {
	    cat <<EOF
This script search online man pages in various ways.
Usage: manon [packagename] [option1] [option2]
Option1:
    --help          This usage screen.

    --online        Use online services to retrieve requested man page (die.net, mankier.com and man.he.net).
                    Option2:
                           --mankier     Skip die.net look at mankier.com
                           --manhenet    Skip die.net and mankier.com and look directly in man.he.net
                           * If option2 is ommited , default is die.net service

    --apt           Debian Specific. Extract and display the man page from the deb package without downloading it. 
                    All man pages and examples,change logs, info pages, are returned by default
                    Option 2:
                             --manonly : Return only manpages, and exclude logs,exapmples,etc.
                             --noman   : Exclude man pages and return changelog entries,examples, etc
                             
    --down          Debian Specific. Download the deb package (apt-get -d pkg), extract man page and then delete deb package.
                    Option 2:
                             --nodelete     When used with --down the deb package will not be deleted.

    --debian        Search particulary in debian manpages online platform (i.e https://manpages.debian.org/testing/grep). 
                    Your current release is detected (lsb_release -r -s) and man pages for your release are provided.
                    Combine with --browser to display man page at browser

    --debianlist    Display a list of available man pages (various releases) at i.e http://manpages.debian.org/grep (i.e jessie,stretch,testing, unstable, posix etc). 
                    Combine with --browser to display man page at browser
                        
    --bsd           Display the FreeBSD man pages (i.e https://man.freebsd.org/grep). 
                    Combine with --browser to display man page at browser
    
    --openbsd       Display OpenBSD man pages (i.e https://man.openbsd.org/grep). 
                    Combine with --browser to display man page at browser

    --netbsd        Display NetBSD man pages (i.e http://netbsd.gw.com/cgi-bin/man-cgi?grep++NetBSD-current). 
                    Combine with --browser to display man page at browser    

    --ubuntu        Display the man page from Ubuntu (i.e http://manpages.ubuntu.com/grep). 
                    Combine with --browser to display man page at browser 
    
    --ubuntulist    Display a list of available man pages (various released) at http://manpages.ubuntu.com (i.e posix man, plan9, regular man pages, etc). 
                    Combine with --browser to display man page at browser
    
EOF
#Don't use tabs to add entries in above help. Always use spaces, since spaces are interprated the same from all shells (while tab not)
}	

function apt {
	validmode=1
	loop=1
	pkg="$1"
	echo "package requested: $pkg"

	#Nov17: apt list does not work with pkg/experimental or pkg/repo in general. An if added to handle differently packages including / like pkg/experimental
	#Nov17: BTW echo "${pkg%%/*}" will return xfce4-power-manager if $1 is xfce4-power-manager/experimental

#    if [[ $1 =~ "/" ]];then 
         aptresp=$(apt-get --print-uris download $1 2>&1) 
         # apt-get --print-uris download is better than install. install will return the uris of all the dependencies;download will return just the uri of the package.
         # Moreover apt-get download works fine with package/repo synthax.
         echo "apt response=$aptresp"
#    else
#		pkg="$1"
#		aptpkg=$(apt list $pkg 2>/dev/null |grep $1 |cut -d" " -f1 |cut -d"," -f1)
#		echo "Package: $aptpkg"
#		aptresp=$(apt-get --print-uris download $aptpkg 2>&1)
		#initially i did it with '--print-uris install' but in case of pkg 'yade', there are three deb files returned. 
		#This seems to be valid for any package that needs to install an additional deb in order to work .
		#on the other hand , using '--print-uris download' only the required package is returned without it's dependencies (more deb packages)
#	fi
	if [[ "$aptresp" == *"Unable to locate package"* ]];then
		echo "Error. Either wrong package name or other error. Raw output of apt:"
#		apt-get --print-uris download $aptpkg
		apt-get --print-uris download $pkg
		exit 1
	fi
    aptpkg="${pkg%%/*}"
	deb=$(grep "/$aptpkg" <<<"$aptresp" |cut -d" " -f1 |sed s/\'//g)
	echo "deb file : $deb"
	if [[ $3 == "--manonly" ]]; then
	manpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep -v -e '^l' |grep -e "man/man" |grep -vE "\/$" |awk '{print $NF}')) #Nov17: added grep -v '^l' to exclude sym links
    elif [[ $3 == "--noman" ]]; then
    manpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep -v -e '^l' |grep -e "changelog" -e "README" -e '/info/' -e '/examples/' -e '/doc/' |grep -vE "\/$" |awk '{print $NF}')) #Nov17: added grep -v '^l' to exclude sym links
    else
    manpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep -v -e '^l' |grep -e "man/man" -e "changelog" -e "README" -e '/info/' -e '/examples/' -e '/doc/' |grep -vE "\/$" |awk '{print $NF}')) #Nov17: added grep -v '^l' to exclude sym links
	fi
	while [[ $loop -eq 1 ]]; do
		if [[ -z $manpage ]];then
			echo "No man pages found in deb package - These are the contents of the $deb:"
			curl -sL -o- $deb |dpkg -c /dev/stdin
			exit 1
		else
			echo "man page found: ${#manpage[@]}"
			declare -p manpage |sed 's/declare -a manpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
		
		if [[ ${#manpage[@]} -eq 1 ]]; then
			echo "One man page found - Display "
			curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO $manpage |man /dev/stdin
			loop=0
		else
			read -p "Select man pages to display by id or press a for all  - q to quit : " ms
			if [[ $ms == "a" ]]; then 
				echo "Display all"
				curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${manpage[@]} |man /dev/stdin				
			elif [[ $ms == "q" ]]; then
				echo "exiting"
				loop=0
			elif [[ $ms -le $((${#manpage[@]}-1)) ]]; then
				echo "Display ${manpage[$ms]}"
				#curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${manpage[$ms]} |man /dev/stdin
                if [[ ${manpage[$ms]} =~ "man/man" ]]; then #Nov17: Different handling of various file types
				   curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${manpage[$ms]} |man /dev/stdin #|yad --text-info --center --width=800 --height=600 --no-markup
				elif [[ ${manpage[$ms]: -3} == ".gz" ]]; then
				   curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${manpage[$ms]} |gunzip -c |less -S
				else 
				   curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${manpage[$ms]} |less -S
				fi
			elif [[ $ms -gt $((${#manpage[@]}-1)) ]]; then
				echo "out of range - try again"
			else
				echo "Invalid Selection - Try Again"
			fi
		fi
	done
}

function down {
#if [[ "$mode" == "--down" ]]; then
	validmode=1
	loop=1
	rawpkg="$1"
	echo "rawpkg requested: $rawpkg"
#    if [[ $rawpkg =~ "/" ]];then 
         aptresp=$(apt-get --print-uris download $rawpkg 2>&1)
#        echo "apt response=$aptresp"
#    else
#		aptpkg=$(apt list $pkg 2>/dev/null |grep $rawpkg |cut -d" " -f1 |cut -d"," -f1)
#		echo "AptPackage: $aptpkg"
#		aptresp=$(apt-get --print-uris download $aptpkg 2>&1)
#		#initially i did it with '--print-uris install' but in case of pkg 'yade', there are three deb files returned. This seems to be valid for any package that needs to install an additional deb in order to work .
#		#on the other hand , using '--print-uris download' only the required package is returned without it's dependencies (more deb packages)
#	fi

	if [[ "$aptresp" == *"Unable to locate package"* ]];then
		echo "Error. Either wrong package name or other error. Raw output of apt:"
#		apt-get --print-uris download $aptpkg
		apt-get --print-uris download $rawpkg
		exit 1
#	else
#	    aptpkg=$1
	fi

##	aptpkg=$(apt list $pkg 2>/dev/null |grep $pkg |cut -d" " -f1 |cut -d"," -f1) #Prior to Nov17
##	[[ $aptpkg == "" ]] && echo "No valid package found" && exit 1 || echo "Package: $aptpkg" #prior to Nov17
#	apt-get download "$aptpkg" 2>/dev/null
	apt-get download "$rawpkg"   
	
	pkg="${rawpkg%%/*}" #Nov17: remove the /repository i.e /experimental if exists
	debname=$(find . -maxdepth 1 -name "$pkg*.deb")
	echo "Deb Name = $debname"
	datatar=$(ar t "$debname" |grep "data.tar")
	echo "data.tar = $datatar"

#it seems that recent versions of dpkg can list the contents of deb just by using dpkg -c debfile
#but bellow we follow the old fashioned way

	if [[ ${datatar##*.} == "gz" ]];then 
		options="z"   #Case of package agrep
	elif [[ ${datatar##*.} == "xz" ]];then
		options="J"  # the most common case for data.tar
	else
		echo "data.tar is not a gz or xz archive. Exiting"
		exit 1
	fi
	#manpage+=($(ar p $debname $datatar | tar t"$options" |grep -v -e '^l' |grep -e "man/man" -e "changelog" |grep -vE "\/$" |awk '{print $NF}')) #Nov17: Changelog option added
	manpage+=($(dpkg -c $debname |grep -v -e '^l' |grep -e "man/man" -e "changelog" -e "README" -e '/info/' -e '/examples/' -e '/doc/' |grep -vE "\/$" |awk '{print $NF}')) 
	#Nov17: Changelog option added and deb contents listing changed from 'ar -p' to 'dpkg -c' since the latest one seems more reliable and robust and also provides an ls similar output thus grep -v '^l' works fine = skip sym links	
	while [[ $loop -eq 1 ]]; do
		if [[ -z $manpage ]];then
			echo "No man pages found in deb package - These are the contents of the $debname:"
			ar p "$debname" "$datatar" | tar t"$options"
			rm -fv $debname
			exit 1
		else
			echo "man page found: ${#manpage[@]}"
			declare -p manpage |sed 's/declare -a manpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
	
		if [[ ${#manpage[@]} -eq 1 ]]; then
			echo "One man page found - Display "
			ar p "$debname" "$datatar" | tar xO"$options" $manpage |man /dev/stdin #works ok
			loop=0
		else
			read -p "Select man pages to display by id or press a for all  - q to quit : " ms
			if [[ $ms == "a" ]]; then 
				echo "Display all"
				ar p "$debname" "$datatar" | tar xO"$options" ${manpage[@]} |man /dev/stdin #works ok
	#			loop=0
			elif [[ $ms == "q" ]]; then
				echo "exiting"
				loop=0
			elif [[ $ms -le $((${#manpage[@]}-1)) ]]; then
				echo "Display ${manpage[$ms]}"
				#ar p "$debname" "$datatar" | tar xO"$options" ${manpage[$ms]} |man /dev/stdin #works ok
				if [[ ${manpage[$ms]} =~ "man/man" ]]; then #Nov17: Different handling for various file types
				   ar p "$debname" "$datatar" | tar xO"$options" ${manpage[$ms]} |man /dev/stdin  
                elif [[ ${manpage[$ms]: -3} == ".gz" ]]; then
                   ar p "$debname" "$datatar" | tar xO"$options" ${manpage[$ms]} |gunzip -c |less -S 
				else 
				   ar p "$debname" "$datatar" | tar xO"$options" ${manpage[$ms]} |less -S
				fi
	#			loop=0
			elif [[ $ms -gt $((${#manpage[@]}-1)) ]]; then
				echo "out of range - try again"
			else
				echo "Invalid Selection - Try Again"
			fi
		fi
	done
	[[ $3 != "--nodelete" ]] &&  rm -vf $debname || echo -e "$debname preserved :\n $(ls -all $debname)"
#fi
}

function bsd {
#if [[ "$mode" == "--bsd" ]]; then
  validmode=1
  bsdpage="$1"
  bsddata="$(links -dump https://man.freebsd.org/$bsdpage |sed '1,/home | help/d' )"
  [[ "$bsddata" =~ "Sorry, no data found" ]] && echo "No man page found at \"https://man.freebsd.org/$bsdpage\"" && exit 1
  
  if [[ "$mode" == "--bsd" && $3 == "--browser" ]]; then
     gksu -u "$normaluser" xdg-open "https://man.freebsd.org/$bsdpage" 2>/dev/null &
  else
     echo "$bsddata" |sed "1i https://man.freebsd.org/$bsdpage" |less -S
  fi  
# In Debian you can also download /view the pkg freebsd-manpages which has almost all freebsd man pages (bug: grep is missing)
#fi
#---------------------------------------------------------------------------------------------------------------------------------------
#links -dump https://man.openbsd.org/grep |sed '1,/GREP/d' |less
}

function openbsd {
#if [[ "$mode" == "--openbsd" ]]; then
  validmode=1  
  bsdpage="$1"
  bsdpagecap="${bsdpage^^}" #Capitalize the man page title
  bsddata="$(links -dump https://man.openbsd.org/$bsdpage |awk "/$bsdpagecap/,0")"
  [[ -z "$bsddata" ]] && echo "No man page found at \"https://man.openbsd.org/$bsdpage\"" && exit 1

  if [[ "$mode" == "--openbsd" && $3 == "--browser" ]]; then
     gksu -u "$normaluser" xdg-open "https://man.openbsd.org/$bsdpage" 2>/dev/null &
  else
     echo "$bsddata" |sed "1i https://man.openbsd.org/$bsdpage" |less -S
  fi  
#fi
}

function netbsd {
#http://netbsd.gw.com/cgi-bin/man-cgi?grep++NetBSD-current
  validmode=1  
  netbsdpage="$1"
  bsdpagecap="${bsdpage^^}" #Capitalize the man page title
  netbsddata="$(links -dump http://netbsd.gw.com/cgi-bin/man-cgi?${netbsdpage}++NetBSD-current |awk "/$netbsdpagecap/,0")"
  [[ -z "$netbsddata" ]] && echo "No man page found at \"http://netbsd.gw.com/cgi-bin/man-cgi?${netbsdpage}++NetBSD-current\"" && exit 1

  if [[ "$mode" == "--netbsd" && $3 == "--browser" ]]; then
     gksu -u "$normaluser" xdg-open "http://netbsd.gw.com/cgi-bin/man-cgi?${netbsdpage}++NetBSD-current" 2>/dev/null &
  else
     echo "$netbsddata" |sed "1i http://netbsd.gw.com/cgi-bin/man-cgi?${netbsdpage}++NetBSD-current" |less -S
  fi  
}

function debian {
#if [[ "$mode" == "--debian" ]]; then
  validmode=1  
  manpage="$1"
  release="$(lsb_release -r -s)"
  manpagecap="${manpage^^}" #Capitalize the man page title
  mandata="$(links -dump https://manpages.debian.org/$release/$manpage |awk "/$manpagecap/,0")"
  [[ -z "$mandata" ]] && echo "No man page found at \"https://manpages.debian.org/$release/$manpage\"" && exit 1

  if [[ "$mode" == "--debian" && $3 == "--browser" ]]; then
     gksu -u "$normaluser" xdg-open "https://manpages.debian.org/$release/$manpage" 2>/dev/null &
  else
     echo "$mandata" |sed "1i https://manpages.debian.org/$release/$manpage" |less -S
  fi  
#fi
}

function debianlist {
#if [[ "$mode" == "--debianlist" ]]; then
  validmode=1
  page="$1"
  pagecap="${1^^}"
  loop=1
	manpage+=( $(curl -s -L -o- "http://manpages.debian.org/$page" |grep -Po ".* href=\"\K.*/$page.*pkgversion.*title.*$" |perl -pe 's/">.*title="/,/g' |perl -pe 's/">.*$//g' ) )

	while [[ $loop -eq 1 ]]; do
		if [[ -z $manpage ]];then
			echo "No results. "
			links -dump "http://manpages.debian.org/$page"
			exit 1
		else
			clear
			echo "man page found: ${#manpage[@]}"
			declare -p manpage |sed 's/declare -a manpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
    	read -p "Select man pages to display by id or q to quit : " ms
        if [[ $ms == "q" ]]; then
			echo "exiting" && loop=0
		elif [[ $ms -le $((${#manpage[@]}-1)) ]]; then
			echo "Display ${manpage[$ms]/,/}" #list is given in "link,version" format. ${var/,*/} removes the version at the end (removes comma and everything after comma)
			if [[ "$mode" == "--debianlist" && $3 == "--browser" ]]; then
               gksu -u "$normaluser" xdg-open "http://manpages.debian.org${manpage[$ms]/,*/}" 2>/dev/null &
			else
			   links -dump http://manpages.debian.org"${manpage[$ms]/,*/}" |awk "/Scroll to navigation/,0" |sed "1i http://manpages.debian.org${manpage[$ms]/,*/}" |less -S
			fi
		else
			echo "Invalid Selection - Try Again"
		fi
	done
#fi
}

function ubuntu {
#---------------------------------------------------------------------------------------------------------------------------------------
# Ubuntu Online Man pages
# Global Address : http://manpages.ubuntu.com
# Quick jump : http://manpages.ubuntu.com/grep . Includes jscript redirection and thus works on browser but not on terminal (links or curl -L)
# Work around: http://manpages.ubuntu.com/cgi-bin/search.py?q=grep  --> provides a list will all man pages / various releases
# Using curl you can get this list in terminal: 
# curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=dman |perl -pe 's/>/>\n/g' |grep -o '/manpages.*man.*html'
# /manpages/artful/en/man1/dman.1.html
# /manpages/precise/en/man1/dman.1.html
# /manpages/trusty/en/man1/dman.1.html
# /manpages/xenial/en/man1/dman.1.html
# /manpages/zesty/en/man1/dman.1.html
# You can keep the most recent one (zesty) - this is also the auto-forwarding man pages if you use http://manpages.ubuntu.com/grep
# or you can provide an indexed array to select the man page you want
# To use zesty you just need to dump http://manpages.ubuntu.com/manpages/zesty/en/man1/dman.1.html

#if [[ "$mode" == "--ubuntu" ]]; then
  validmode=1
  page="$1"
  address="$(curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$page |perl -pe 's/>/>\n/g' |grep -v -e 'posix' -e 'plan9' |grep -o -m1 '/manpages/zesty/.*man.*html' )"
  [[ -z "$address" ]] &&  address="$(curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$page |perl -pe 's/>/>\n/g' |grep -v -e 'posix' |grep -o -m1 '/manpages/zesty/.*man.*html' )"
  [[ -z "$address" ]] &&  address="$(curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$page |perl -pe 's/>/>\n/g' |grep -o -m1 '/manpages/zesty/.*man.*html' )"
  [[ -z "$address" ]] && echo "no man pages returned : curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$page" && links -dump "http://manpages.ubuntu.com/cgi-bin/search.py?q=$page" && exit
  read -p "$address - press any key to continue"
  if [[ "$mode" == "--ubuntu" && $3 == "--browser" ]]; then
     gksu -u "$normaluser" xdg-open "http://manpages.ubuntu.com$address" 2>/dev/null &
  else 
     links -dump http://manpages.ubuntu.com$address |sed "1i http://manpages.ubuntu.com$address" |less -S
  fi
#fi
}

function ubuntulist {
#if [[ "$mode" == "--ubuntulist" ]]; then
  validmode=1
  page="$1"
  loop=1
	manpage+=($(curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$page |perl -pe 's/>/>\n/g' |grep -o '/manpages/.*man.*html') ) 
	while [[ $loop -eq 1 ]]; do
		if [[ -z $manpage ]];then
			echo "No results. "
			links -dump "http://manpages.ubuntu.com/cgi-bin/search.py?q=$page" && exit 1
		else
			clear
			echo "man page found at http://manpages.ubuntu.com/cgi-bin/search.py?q=$page : ${#manpage[@]}"
			declare -p manpage |sed 's/declare -a manpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
    	read -p "Select man pages to display by id or q to quit : " ms
        if [[ $ms == "q" ]]; then
			echo "exiting" && loop=0
		elif [[ $ms -le $((${#manpage[@]}-1)) ]]; then
			echo "Display ${manpage[$ms]}"
			if [[ "$mode" == "--ubuntulist" && $3 == "--browser" ]]; then
               gksu -u "$normaluser" xdg-open "http://manpages.ubuntu.com${manpage[$ms]}" 2>/dev/null &
			else
			   links -dump http://manpages.ubuntu.com"${manpage[$ms]}" |sed "1i http://manpages.ubuntu.com${manpage[$ms]}" |less -S
			fi
		else
			echo "Invalid Selection - Try Again"
		fi
	done
#fi
}

function online {
#if [[ "$mode" == "--online" || "$mode" == "--online-gui" ]]; then
	validmode=1
	title=$1
	unset dt0 dt data mson loopon
	loopon=1
	if [[ -z $3 ]]; then
		echo "Trying at die.net"
		#dt=$(links -dump https://linux.die.net/man/1/$1)
		pkg=${1:0:1} #get the first char
		dt0+=($(links -dump "https://linux.die.net/man/$pkg.html" |grep -E "^( )*+$1+\([0-9]\)")) #search die.net alphabetical pages
		#declare -p dt0 && exit
		if [[ ${#dt0[@]} -gt 1 ]];then
			while [[ $loopon -eq 1 ]]; do
				#declare -p dt0 |sed 's/declare -a dt0=//g' |tr -d '()' |tr ' ' '\n'
				declare -p dt0 |sed 's/declare -a dt0=(//g' |tr ' ' '\n' |sed 's/)$//g'
				read -p "Select man pages to display by id or q to quit : " mson #case of wait : gives three different man pages (wait(1) wait(2) wait(3))
				echo "You selected: $mson"
				if [[ $mson == "q" ]]; then
					echo "exiting"
					loopon=0
					exit 1
				elif [[ $mson -le $((${#dt0[@]}-1)) ]]; then
					echo "Display ${dt0[$mson]}" 	#for some reason pressing any letter assigns dt0[0] , obviously else goes into here instead of the last else
					loopon=0
					dt=${dt0[$mson]}
				elif [[ $mson -gt $((${#dt0[@]}-1)) ]]; then
					echo "out of range - try again"
				else
					echo "Invalid Selection - Try Again"
				fi
			done
		else
			dt=$dt0
		fi

		if [[ -z $dt ]]; then 
			echo "$1 not available in die.net"
			data="Man page Not Found in die.net"
		else
			manname=$(awk -F"\(" '{print $1}'<<<$dt |tr -d " ")
			section=$(awk -F"\(" '{print $2}'<<<$dt |cut -d")" -f1 |tr -d " ")
			echo "$dt - $manname - $section"
			data=$(links -dump https://linux.die.net/man/$section/$manname)
			tit="/die.net online"
		fi
	fi
	
	if [[ $data == *"Not Found"* || $3 == "--mankier" ]]; then
		echo "die.net skipped. Trying mankier.com"
		unset dt data
		data=$(links -dump  "https://www.mankier.com/?q=$1") 
		#Mind the fantastic redirection of mankier. If package is foung, then you are automatically redirected to man page and you don't have to worry about man section (1..8)'
		tit="/mankier online"
	fi

	if [[ $data == *"No results"* || $3 == "--manhenet" ]]; then #mankier return No results in search form if package is not found.
		echo "die.net and mankier.com skpped . Trying man.he.net"
		unset data
		data=$(links -dump  "http://man.he.net/?topic=$1&section=all") #Mind that man.he.net supports section=all and thus you don't need to specify 1..8'
		tit="/man.he.net online"
	fi

	if [[ $data == *"No matches"* ]]; then #man.he.net returns no matches for package if the package does not exist
		echo "No manual found either at die.net, mankier.com or man.he.net. Exiting"
		exit
	fi
#	if [[ "$3" == "--gui" ]];then
#		yad --text-info<<<"$data" --height=500 --width=800 --center --title="$title$tit Manual " --wrap --show-uri --no-markup &	
#	else
		echo "$data" |less -S 
#	fi
#fi
# You can also try the official man pages project:
# https://www.kernel.org/doc/man-pages/
# http://man7.org/linux/man-pages/index.html
# http://man7.org/linux/man-pages/man1/grep.1.html
# http://man7.org/linux/man-pages/dir_all_alphabetic.html
# curl --silent http://man7.org/linux/man-pages/dir_all_alphabetic.html |grep -w 'ln' |grep -o '"[^"]*"'
# "./man1/ln.1.html"
# "./man1/ln.1p.html"
}

function debianold {
#if [[ "$mode" == "--debianold" ]]; then
	validmode=1
	echo "grab man page by https://manpages.debian.org/cgi-bin/man.cgi and perform similar operation to dman ubuntu utility."
	pkg="$1"
	manpage=$(links -dump "https://manpages.debian.org/cgi-bin/man.cgi?query=$pkg&apropos=0&sektion=0&manpath=Debian+8+jessie&format=html&locale=en")
	found="Debian+8+jessie"
	if [[ $manpage == *"no data found"* ]];then
		unset manpage
		echo "stable failed"
		manpage=$(links -dump "https://manpages.debian.org/cgi-bin/man.cgi?query=$pkg&apropos=0&sektion=0&manpath=Debian+testing+stretch&format=html&locale=en")
		found="Debian+testing+stretch"
		if [[ $manpage == *"no data found"* ]];then
			unset manpage
			echo "testing failed"
			manpage=$(links -dump "https://manpages.debian.org/cgi-bin/man.cgi?query=$pkg&apropos=0&sektion=0&manpath=Debian+unstable+sid&format=html&locale=en")
			found="Debian+unstable+sid"
			if [[ $manpage == *"no data found"* ]];then
				echo "unstable failed"
				echo "no man page available in debian online for package $pkg"
				found=""
				exit 1
			fi
		fi
	fi
# As of January 2017 you can use the global page https://manpages.debian.org/jump?q=$1 which will jump you directly to corect section
# combine with awk to remove the first lines : 
# links -dump https://manpages.debian.org/jump?q=ngrep |awk "/Scroll to navigation/,0"
# See alias functions.
# Also you can use the similar to bsd command: 
# links -dump https://manpages.debian.org/grep 
# You just need to delete the first lines.

	if [[ "$mode" == "--debianold" && $3 == "--browser" ]]; then
		gksu -u "$normaluser" xdg-open "https://manpages.debian.org/cgi-bin/man.cgi?query=$pkg&apropos=0&sektion=0&manpath=$found&format=html&locale=en" 2>/dev/null &
	else
		#awk "/home | help | more information/,0" <<<"$manpage" |tail -n +2 |less -S
		awk "/Scroll to navigation/,0" <<<"$manpage"|less -S
	fi
# Also check http://manpages.ubuntu.com/manpages/xenial/en/man1/dman.1.html
# Also mind that debian manpages seems to fail in some pkgs, like netcat (either as pkg search or apropos search)
# Another great tool to investigate seems to be python debmans: https://pypi.python.org/pypi/debmans/1.0.0 
# https://debmans.readthedocs.io/en/latest/usage.html
#fi
}

function debcheck {
# Bellow Options have been made for testing only. Not working correctly, especially with new debian man pages web site.
#if [[ "$mode" == "--debcheck" ]]; then
	validmode=1
	echo "This is debian online manpages checker"
	unset pk
	unset pk1
	#pk+=($(apt list "$1" |cut -d" " -f1 |cut -d"/" -f1))
	pk1+=($(apt list "$1" |cut -d" " -f1 ))
	for i in ${pk1[@]};do
		if [[ $(cut -d"/" -f2<<<"$i") == "experimental" ]];then
			echo "Package $i is experimental - test skipped since debian man pages online does not hold experimental man pages"
		else
			pk+=($(cut -d"/" -f1 <<<"$i"))
		fi
	done
	declare -p pk |sed 's/declare -a pk=(//g' |tr ' ' '\n' |sed 's/)$//g'
	#sleep 5 && exit
	for pkg in ${pk[@]};do
	manpage=$(links -dump "https://manpages.debian.org/cgi-bin/man.cgi?query=$pkg&apropos=0&sektion=0&manpath=Debian+8+jessie&format=html&locale=en")
	if [[ $manpage == *"no data found"* ]];then
		unset manpage
	#	echo "stable failed"
		manpage=$(links -dump "https://manpages.debian.org/cgi-bin/man.cgi?query=$pkg&apropos=0&sektion=0&manpath=Debian+testing+stretch&format=html&locale=en")
		if [[ $manpage == *"no data found"* ]];then
			unset manpage
	#		echo "testing failed"
			manpage=$(links -dump "https://manpages.debian.org/cgi-bin/man.cgi?query=$pkg&apropos=0&sektion=0&manpath=Debian+unstable+sid&format=html&locale=en")
			if [[ $manpage == *"no data found"* ]];then
	#			echo "unstable failed"
				echo "no man page available in debian online for package $pkg" | tee -a debmanonline.log
	#			exit 1
			fi
		fi
	fi
	done

#fi
}

function aptvsdeb {
#Bellow is also for testing 
#if [[ "$mode" == "--aptvsdeb" ]]; then
	validmode=1
	while IFS=" " read -r _ _ _ _ _ _ _ _ _ pkg;do
		unset manpage
		unset aptresp aptpkg
		echo "Package in log: $pkg"
	#	pkg="$1"
		aptpkg=$(apt list $pkg 2>/dev/null |grep $pkg |cut -d" " -f1 |cut -d"," -f1)
		echo "Package in apt: $aptpkg"
		aptresp=$(apt-get --print-uris download $aptpkg 2>&1)
		echo "Apt Response: $aptresp"
		if [ "$aptresp" == *"Unable to locate package"* -o "$aptresp" == *"Handler silently"* ];then
			echo "Error. Either wrong package name or other error for $pkg. Raw output of apt:"
	#		apt-get --print-uris install $aptpkg
	#		exit 1
	#	fi
		else
			deb=$(grep "/$pkg" <<<"$aptresp" |cut -d" " -f1 |sed s/\'//g)
			echo "deb file : $deb"
			manpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep "man/man" |grep -vE "\/$" |awk '{print $NF}'))
			if [[ -z $manpage ]];then
				echo "No man pages found in deb package for $pkg. These are the contents of the $deb:"
		#		curl -sL -o- $deb |dpkg -c /dev/stdin
			else
				echo "man page found: ${manpage[@]}"
#				declare -p manpage |sed s/"declare -a "//g
				echo "Package=$aptpkg, debmanpages=${manpage[@]}" >> debvsapt.log
			fi
		fi
	done <debmanonline.log
#fi
#---------------------------------------------------------------------------------------------------------------------------------------
}

function aptcheck {
#Bellow is also for testing 
#if [[ "$mode" == "--aptcheck" ]]; then
		validmode=1
		unset manpage aptresp aptpkg
		pkg="$1"
		aptpkg=$(apt list $pkg 2>/dev/null |grep $pkg |cut -d" " -f1 |cut -d"," -f1)
		echo "Package in apt: $aptpkg"
		aptresp=$(apt-get --print-uris download $aptpkg 2>&1)
		echo "Apt Response: $aptresp"
		if [ "$aptresp" == *"Unable to locate package"* -o "$aptresp" == *"Handler silently"* ];then
			echo "Error. Either wrong package name or other error for $pkg. Raw output of apt:"
			apt-get --print-uris install $aptpkg
			exit 1
	#	fi
		else
			deb=$(grep "/$pkg" <<<"$aptresp" |cut -d" " -f1 |sed s/\'//g)
			echo "deb file : $deb"
			manpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep "man/man" |grep -vE "\/$" |awk '{print $NF}'))
			if [[ -z $manpage ]];then
				echo "No man pages found in deb package for $pkg. These are the contents of the $deb:"
				curl -sL -o- $deb |dpkg -c /dev/stdin
			else
				echo "man page found: ${manpage[@]}"
				declare -p manpage |sed 's/declare -a manpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
			fi
		fi
#fi
}

#------------------------MAIN PROGRAMM-----------------------------------------------------------------------------------------#
{
[[ -z $1 ]] || [[ "$1" == "--help" ]] || [[ "$2" == "--help" ]] && helpme && exit 1 #if no man page is requested print help and exit
[[ -z $2 ]] && mode="--apt" || mode="$2" #if no particular mode is given, the apt mode is used by default
echo "mode selected:  $mode"
normaluser="$(awk -F':' '/1000:1000/{print $1;exit}' /etc/passwd)" #Could be buggy if more than one normal user exists
case $mode in
"--apt")apt "$@";;
"--down")down "$@";;
"--bsd")bsd "$@";;
"--openbsd")openbsd "$@";;
"--netbsd")netbsd "$@";;
"--debian")debian "$@";;
"--debianlist")debianlist "$@";;
"--ubuntu")ubuntu "$@";;
"--ubuntulist")ubuntulist "$@";;
"--online")online "$@";;
esac

[[ $validmode -eq 1 ]] && echo "Succesfull exit" && exit 0
echo "invalid options - exit with code 1" && helpme && exit 1
exit 1
}

# compare man pages:
# http://unix.stackexchange.com/questions/337884/how-to-view-differences-between-the-man-pages-for-different-versions-of-the-same
# diff -y -bw -W 150 <(links -dump "https://www.mankier.com/?q=grep" |less -S |fold -s -w 70) <(man grep |less -S |fold -s -w 70)
# diff_man() { diff -y <(man --manpath="/old/path/to/man" "$1") <(man "$1"); }
# Using process substitution = each process get a named fifo and it is treated as a file. 

:<<manpagealert
script to display all binaries missing man pages

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

F=( "/bin/*" "/sbin/*" "/usr/bin/*" "/usr/sbin/*" "/usr/games/*" )
for f in ${F[@]};do 
  for ff in $f;do
    if ! mp=$(man -w -S 1:8:6 "${ff##*/}" 2>&1 >/dev/null);then 
       echo "$mp" |grep -v "man 7 undocumented" #man 7 undocumented is printed in a separate line.
    fi
  done
done

Oneliner:
F=( "/bin/*" "/sbin/*" "/usr/bin/*" "/usr/sbin/*" "/usr/games/*" );for f in ${F[@]};do for ff in $f;do if ! mp=$(man -w -S 1:6:8 "${ff##*/}" 2>&1 >/dev/null);then echo "$mp" |grep -v "man 7 undocumented";fi;done;done

manpagealert

# ManPage Differences
# In the new Debian Manpages as soon as you give the pkg name you are redirected to the man page directly of Jessie.
# Works even with links , lynx and curl by CLI using "https://dyn.manpages.debian.org/jump?q=pkgname"
# If you need to compare two different versions of the same pkg you can run :
# diff -w -y <(links -dump "https://manpages.debian.org/jessie/xserver-xorg-input-synaptics/synclient.1.en.html") \
# <(links -dump "https://manpages.debian.org/unstable/xserver-xorg-input-synaptics/synclient.1.en.html")

# 1. Curl Deb File and read the man page without downloading deb: 
# curl -sL -o- "http://httpredir.debian.org/debian/pool/main/a/avis/avis_1.2.2-4_all.deb" |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ./usr/share/man/man8/avisd.8.gz |man /dev/stdin
# mind that tar does not need -z or -J !
# curl -s=silent, -L = Locate link if moved , and -o- is -o = output to file, and dash indicates output to stdout 
# tar -x = xtract , -O = display extracted files on stdout instead of saving to file, -t = list files
# For testing , bellow commands display deb contents inside data archive of deb: 
# curl -sL -o- "http://httpredir.debian.org/debian/pool/main/a/avis/avis_1.2.2-4_all.deb" |dpkg-deb -c (/dev/stdin is not necessary)
# curl -sL -o- "http://httpredir.debian.org/debian/pool/main/a/avis/avis_1.2.2-4_all.deb" |dpkg-deb --fsys-tarfile /dev/stdin |tar -t
# dpkg -c <(curl -sL "http://httpredir.debian.org/debian/pool/main/a/avis/avis_1.2.2-4_all.deb") #also works ok
# Another complete example
# curl -sL -o- "http://httpredir.debian.org/debian/pool/main/a/axel/axel_2.11-1.1_amd64.deb" |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ./usr/share/man/man1/axel.1.gz |man /dev/stdin
# locate full deb address using apt --print-uris install axel |grep axel (to keep out all the dependency debs)
# even better to use apt --print-uris download axel. This will return the right package. install can return more debs (i.e try yade pkg)

# 2. Working example with deb downloading
# curl -sLO "http://httpredir.debian.org/debian/pool/main/a/avis/avis_1.2.2-4_all.deb" # curl -O saves the file in CWD
# ls -> avis_1.2.2-4_all.deb
# ar p avis_1.2.2-4_all.deb data.tar.xz | tar -xJO ./usr/share/man/man8/avisd.8.gz |man /dev/stdin #works ok
# tar -x = extract, -J = xz archive , -O output extracted file to stdout
# Tips: 
# This also works ok : ar -p `ls *.deb` data.tar.xz |unxz |tar -t . You can use unxz and gunzip to unzip xz and gz archives 
# tar -t is used just for listing . unxz -l claims that does not support stdin (?!)

# Also this works ok for manpages inside deb:
# dpkg-deb --fsys-tarfile $(ls *.deb) |tar -xO ./usr/share/man/man1/agrep.1.gz |man /dev/stdin -->display the man page correctly on screen


# 3. Extract any compressed text file from downloaded deb:
# apt-get download netcat
# ar -p `ls *.deb` data.tar.xz |tar -Jt  #list files 
# ar -p `ls *.deb` data.tar.xz |tar -xJO ./usr/share/doc/netcat/changelog.Debian.gz |gunzip |cat (or less or whatever)
# or
# ar -p `ls *.deb` data.tar.xz |tar -xJO ./usr/share/doc/netcat/changelog.Debian.gz |man /dev/stdin
# man can operate as gunzip and cat on the same time, even if the file is a typical text file and not a man page.
#
# for some reason tar fails to unzip the last gz file (but gunzip works ok):
# ar -p `ls *.deb` data.tar.xz |tar -xJO ./usr/share/doc/netcat/changelog.Debian.gz |tar -xzO |cat
# if the file is not compressed you can just run tar -O (output to stdout = screen)
# ar -p `ls *.deb` data.tar.xz |tar -xJO ./usr/share/doc/netcat/copyright



# 4. Display contents of an not installed package without downloading
# apt-get --print-uris download apt-spy 2>&1 |cut -d" " -f1 |sed s/\'//g #this will isolate the full deb link
# dpkg -c <(curl -sL -o- $(apt-get --print-uris download apt-spy 2>&1 |cut -d" " -f1 |sed s/\'//g)) #this does the job
# though this fails to be registered an a alias due to the sed that tries to remove ' character from start/end.
# 
# Alternative ${var: 1:-1} removes first and last char and now it works!
# alias lsaptonline='function __aso (){ tmpdeb=$(apt-get --print-uris download $1 2>&1 |cut -d" " -f1); tmpdeb=$(echo "${tmpdeb: 1:-1}");dpkg -c <(curl -sL -o- $tmpdeb); } ;__aso'
#
# curl -sL -o- "http://ftp.gnu.org/gnu/tar/tar-latest.tar.gz" |tar -tz --wildcards --no-anchored '*.h'   #archive file listing with wildcards - avoiding grep
# curl -sL -o- "http://ftp.gnu.org/gnu/tar/tar-latest.tar.gz" |tar -zt |grep '/src/.*\.h$'               #classic tar archive file listing
# curl -sL -o- "http://ftp.gnu.org/gnu/tar/tar-latest.tar.gz" |tar -xzO --wildcards --no-anchored '*.h'    #extract and dump contents on screen
# curl -sL -o- "http://ftp.gnu.org/gnu/tar/tar-latest.tar.gz" |tar -xzf - --wildcards --no-anchored '*.h'  #extract and save files locally in a new directory tar-1.29 (goes into CWD)
#
# curl -sL -o- http://ftp.gr.debian.org/debian/pool/non-free/a/agrep/agrep_4.17-9_amd64.deb |dpkg-deb --fsys-tarfile /dev/stdin|tar -t # Displays files in deb archive, identical to dpkg -c
#

# 5. Resources:
# http://www.howtogeek.com/howto/uncategorized/linux-quicktip-downloading-and-un-tarring-in-one-step/
# http://man.cx/<pkghere>
# http://askubuntu.com/questions/92328/how-do-i-uncompress-a-tarball-that-uses-xz
# http://superuser.com/questions/82923/how-to-list-files-of-a-debian-package-without-install
#! https://www.g-loaded.eu/2008/01/28/how-to-extract-rpm-or-deb-packages/
# https://www.gnu.org/software/tar/manual/html_node/Writing-to-an-External-Program.html#SEC87
# https://www.cyberciti.biz/faq/howto-read-file-as-manpage-with-man-command/
# http://linux-tips.com/t/how-to-extract-deb-package/169
# http://unix.stackexchange.com/questions/61461/how-to-extract-specific-files-from-tar-gz
# https://blog.packagecloud.io/eng/2015/10/13/inspect-extract-contents-debian-packages/

# 5. Tips and Bugs
# apt --print-uris source (or download) agrep 
# Get file list of deb archive by web (debian package system / file tree)
# function deb_list () { curl -s $(lsb_release -si | sed -e 's Ubuntu http://packages.ubuntu.com/ ' -e 's Debian https://packages.debian.org/ ')/$(lsb_release -sc)/all/$1/filelist | sed -n -e '/<pre>/,/<\/pre>/p' | sed -e 's/<[^>]\+>//g' -e '/^$/d'; }
# man pages extension is .1 , .7, .8 depending on the man classification. 
# in deb files man page is xxxx.1.gz but man can handle it / decompress it directly without neet to tar -xz or gunzip /unxz first
# The --down or --apt solution (extract man from deb file) fails to detect / follow / display manpages that are in realiry symbolic links to other man pages inside the deb file.
# Reason of failure is that symlink points to something like ./usr/share/man/man1/correctmanpage.1.gz which will be only available if you fully extract the deb package.
# Instead of apt-get --print-uris download i also tried --print-uris install. But with install a lot of deb packages will be returned since a normal install operation will also install dependencies.
# As a result --print-uris download will return the one and only correct deb file for the package you provided.
# You can read any compressed page in your local system easily by using any of the following commands:
# man /usr/share/doc/bash/README.commands.gz #make use of the man capability to decompress and display man or even regular files
# zmore /usr/share/doc/bash/README.commands.gz |less #zmore is a default gz reader
# cat /usr/share/doc/bash/README.commands.gz |gunzip |less #again for some reason the tar -xzO is not working to display the file


# 6. See any sources tar file
# apt-get --print-uris source pkg
# find the orig or debian xz or gz archive - copy full http source link
# curl -sL -o- "source link" |tar -Jt (for xz) or -zt (for gz) -> You get a list of all files in archive. Copy the full path of the file you want
# curl -sL -o- "source link" |tar -xJO (for xz) or -xzO (for gz) file_path_inside_archive -> should print to stdout the file
# if the file you want is tar, then you need to further tar -x(z or J) or to unxz or to gunzip and then cut.
# curl -s = silent, -L = follow moved pages (case of httpredir) -o- = force output to stdout (-o = output , last - = stdout)
# tar -x = extract, -t=list files, -z=gz compressed, -J-xz compressed, -O force output to stdout.

# 7. Read man from sources 
# apt --print-uris source yaboot
# Usually returns orig.tar and debian.tar
# Locate the man page using tar -tz or -tJ (-t = list files of archive)
# curl -sL "http://httpredir.debian.org/debian/pool/non-free/a/agrep/agrep_4.17.orig.tar.gz" |tar -zt |egrep "agrep.[0-9]+$"
# >agrep-4.17/agrep.1
# curl -sL "http://debian.noc.ntua.gr/debian/pool/main/y/yaboot/yaboot_1.3.17.orig.tar.gz" |tar -xzO yaboot-1.3.17/man/yaboot.8 |man /dev/stdin
# -x = extract
# -z = gz archive. if tz archive, use -J
# -O = print to stdout
# man /dev/stdin : read man page from stdin

# Complete Job: 
# f=$(curl -sL "http://httpredir.debian.org/debian/pool/non-free/a/agrep/agrep_4.17.orig.tar.gz" |tar -zt |egrep "agrep.[0-9]+$")
# curl -sL "http://httpredir.debian.org/debian/pool/non-free/a/agrep/agrep_4.17.orig.tar.gz" |tar -xzO $f |man /dev/stdin

# Script based on source tar archives:
# script fails often (i.e bzr) since man pages was not found neither in original tar nor debian tar.

# In case you want to look in sources instead of the deb files, you could use  apt --print-uris source $pkg 2>&1 |grep "orig" |cut -d" " -f1 |sed s/\'//g) #isolate the link, remove ' in front/end of http add
# Sources often include a file with name orig (=original) or with name debian = debian specific, that can be catched with s wapt --print-uris source $pkg 2>&1 |grep "debian.tar" |cut -d" " -f1 |sed s/\'//g)
# This worked before to switch to deb file analysis:
	#if [[ ${origsrc##*.} == "gz" ]];then #check last chars after the last dot
		#f=$(curl -sL "$src" |tar -zt |grep -P "$pkg\.[0-9]$") #list archive files, find the man page
		#if [[ -z $f ]];then #if man page not found in original source
			#if [[ ${debsrc##*.} == "xz" ]];then #check debian extension
				#echo "this is a xz archive"
				#echo "Debian source is : $srcdeb"
				#fdeb=$(curl -sL "$srcdeb" |tar -Jt |grep -P "$pkg.\.[0-9]$") #look for manual in debian source
				#echo "Manual Found on debian.tar: $fdeb"
			#fi
		#else
			#echo "Manual Found on original source: $f"
		#fi

	#read -p "press any key to read man"
	
		#if [[ -z $f ]];then
			#curl -sL "$srcdeb" |tar -xJO $fdeb |man /dev/stdin
		#else
			#curl -sL "$src" |tar -xzO $f |man /dev/stdin
		#fi
