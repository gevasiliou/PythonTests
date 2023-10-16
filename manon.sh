#!/bin/bash
# Copy this file to /usr/bin or /bin or to any of the paths provided by $PATH.
# When you copy , you can skip the .sh extension i.e : cp ./manon.sh /usr/bin/manon 
# Ensure executable rights for all users and then you can then call it directly using $manon instead of ./manon.sh
# 14/10/2023 : Just keep in mind that debian-utilities has some binaries that do most of the man job:
# dman - read man pages from manpages.debian.org
# debman - read man pages from uninstalled packages
# debmany  -  select  manpages  or documentation files from installed packages, packages from the repository or .deb-files for viewing using
#       "man", "sensible-pager" or an alternative viewer.

helpme() {
	    cat <<EOF
Usage: ./manon.sh --manpage [packagename] [option1] [option2]
Update 15-10-2023: Due to script changes, --apt, --debian --debianlist --ubuntu , --ubuntulist and bsd switches work ok.
The rest switches like --online, are not fully tested.

Option1:
    --help          This help screen.

    --online        Use online services to retrieve requested man page (die.net, mankier.com and man.he.net).
                    Option2:
                           --mankier     Skip die.net look at mankier.com
                           --manhenet    Skip die.net and mankier.com and look directly in man.he.net
                           * If option2 is ommited , default is die.net service

    --apt           Debian Specific. Extract and display the man page from the deb package without downloading it. 
                    Option 2:
                             --full    : man pages but also examples,change logs, readme,docs and info pages
                             --noman   : Exclude man pages and return changelog entries,examples, etc

    --aptmulti      Experimental - Debian Specific. Extract and display the man page from many packages at once(i.e kodi*), without downloading it. 
                    Option 2:
                             --full    : man pages but also examples,change logs, readme,docs and info pages
                             --noman   : Exclude man pages and return changelog entries,examples, etc
                             
    --down          Debian Specific. Download the deb package (apt-get -d pkg), extract man page and then delete deb package.
                    Option 2:
                             --nodelete     When used with --down the deb package will not be deleted.

    --debian        Search particulary in debian manpages online platform (i.e https://manpages.debian.org/testing/grep). 
                    Your current release is detected  and man pages for your release are provided.
                    If manpage is not found, then a second attempt to --debiansuite is made before abandoning the script (i.e deb debian-goodies)
                    Option 2: --manpage programm 
                    
    --debianlist    Display a list of available man pages (various releases) at i.e http://manpages.debian.org/grep (i.e jessie,stretch,testing, unstable, posix etc). 
                    Does not work with suites of tools (i.e debian-goodies) except if the suite has it's own man page (i.e devscripts).
                    If --debianlist does not work ok with man & curl, use --debianlisthtml for the old html based man page viewing (html man page dumped to terminal)
                        
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

Just keep in mind that debian-utilities has some binaries that do most of the man job:
dman - read man pages online from manpages.debian.org
debman - read man pages from uninstalled packages (not working very well at 2023)
debmany  - more modern than debman - works well - used to select  manpages  or documentation files from installed packages, packages from the repository or .deb-files for viewing using
"man", "sensible-pager" or an alternative viewer.

More interesting pkgs about manpages:
pkg: txt2man            : transforms an ASCII txt file to man page
pkg: help2man           : Program to create simple man pages from the --help and --version output of other programs.
pkg: info2man           : Convert GNU info files to POD (Plain Old Documentation) or man pages (info to pod to man in one step)    
pkg: manpages-el        : GNU Manpages Collection in Greek Language
pkg: mandoc             : BSD Manpage compiler toolset
pkg: freebsd-manpages   : Free BSD Manpages collection
pkg: debiman            : debiman makes (Debian) manpages accessible in a web browser.
fn: debcat              : In .bash_aliases we have a function that by default extracts contents of deb file in screen
                          without downloading the pkg in HDD and you can select which file you want to see

fn: viman               : A function that allows you to view man pages in vim -> viman () { man "$@" >/dev/null 2>&1 && man "$@" | vim -R +":set ft=man" - ; }
pkg: ps2pdf             : Converter man page to pdf -> man -t bash | ps2pdf - bash.pdf

TODO & BUGS Dated 15.10.2023: 

a. Find a way to ensure that script will exit if --manpage <pkg> is not provided.

b. Buggy usage: manon --manpage --apt --> Fails since --apt will be considered as argument for --manpage.
   Can be resolved by further validating \$2 field when --manpage is processed.
   As for now we do a basic validation to \$2 field of --manpage to avoid \$2=<pkg> not beeing provided / beeing empty.
   
c. Buggy usage: manon --apt --manpage help2man 
   This will fail since --apt will be parsed first (apt function will be called) before --manpage <pkg> is parsed.  
   This can be resolved by first parsing all arguments, and then make the corresponding function calls.

EOF

#Don't use tabs to add entries in above help. Always use spaces, since spaces are interprated the same from all shells (while tabs not)
}	

function apt {
	validmode=1
	loop=1
	full_mode=0
	noman_mode=0
	echo "function apt  - args received : $* / number of args = $#"
	while [[ $# -gt 0 ]]; do
	  echo "function apt - processing arg $1"
	  case "$1" in
		--full) full_mode=1;shift;; 
		--noman) noman_mode=1;shift;;
#		--pkg) echo "--pkg found";if [ -n "$2" ]; then pkg="$2";echo "pkg name=$2";shift 2; else echo "Option --pkg requires a value." >&2;exit 1;fi;;
		*) restparam+=$1;shift;;
	  esac
	done
    pkg="$manpage"
	echo "function apt - package requested: $pkg"
	
#141023	pkg="$1"
    [[ "$pkg" =~ "*" ]] && echo "wildmark not accepted; try --aptmulti" && return

	#Nov17: apt list does not work with pkg/experimental or pkg/repo in general. An if added to handle differently packages including / like pkg/experimental
	#Nov17: BTW echo "${pkg%%/*}" will return xfce4-power-manager if $1 is xfce4-power-manager/experimental

#    if [[ $1 =~ "/" ]];then
         aptresp=$(apt-get --print-uris download $pkg 2>&1) 
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
		echo "Error. Either wrong package name or other error. Raw output of apt-get --print-uris download $pkg:"
#		apt-get --print-uris download $aptpkg
		apt-get --print-uris download $pkg
		exit 1
	fi
    aptpkg="${pkg%%/*}"
	deb=$(grep "/$aptpkg" <<<"$aptresp" |cut -d" " -f1 |sed s/\'//g)
	echo "deb file : $deb"
	if [[ $full_mode -eq 1 ]]; then
	  echo "--full mode selected-returning man pages,changelogs,readme,info,examples & docs"
      pkgmanpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep -v -e '^l' |grep -e "man/man" -e "changelog" -e "README" -e '/info/' -e '/examples/' -e '/doc/' |grep -vE "\/$" |awk '{print $NF}')) #Nov17: added grep -v '^l' to exclude sym links
    elif [[ $noman_mode -eq 1 ]]; then
   	  echo "--noman mode selected: only changelogs,readme,info,examples & docs. man pages excluded"
      pkgmanpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep -v -e '^l' |grep -e "changelog" -e "README" -e '/info/' -e '/examples/' -e '/doc/' |grep -vE "\/$" |awk '{print $NF}')) #Nov17: added grep -v '^l' to exclude sym links
    else
      #man pages only-default selection
      pkgmanpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep -v -e '^l' |grep -e "man/man" |grep -vE "\/$" |awk '{print $NF}')) #Nov17: added grep -v '^l' to exclude sym links
	fi
	while [[ $loop -eq 1 ]]; do
		if [[ -z $pkgmanpage ]];then
			echo "No man pages found in deb package - These are the contents of the $deb:"
			curl -sL -o- $deb |dpkg -c /dev/stdin
			exit 1
		else
			echo "man page found: ${#pkgmanpage[@]}"
			declare -p pkgmanpage |sed 's/declare -a pkgmanpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
		
		if [[ ${#pkgmanpage[@]} -eq 1 ]]; then
			echo "One man page found - Display "
			curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO $pkgmanpage |man /dev/stdin
			loop=0
		else
			read -p "Select man pages to display by id or press a for all  - q to quit : " ms
			if [[ $ms == "a" ]]; then 
				echo "Display all"
				curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${pkgmanpage[@]} |man /dev/stdin				
			elif [[ $ms == "q" ]]; then
				echo "exiting"
				loop=0
			elif [[ $ms -le $((${#pkgmanpage[@]}-1)) ]]; then
				echo "Display ${manpage[$ms]}"
				#curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${manpage[$ms]} |man /dev/stdin
                if [[ ${pkgmanpage[$ms]} =~ "man/man" ]]; then #Nov17: Different handling of various file types
				   curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${pkgmanpage[$ms]} |man /dev/stdin #|yad --text-info --center --width=800 --height=600 --no-markup
				elif [[ ${pkgmanpage[$ms]: -3} == ".gz" ]]; then
				   curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${pkgmanpage[$ms]} |gunzip -c |less -S
				else 
				   curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${pkgmanpage[$ms]} |less -S
				fi
			elif [[ $ms -gt $((${#pkgmanpage[@]}-1)) ]]; then
				echo "out of range - try again"
			else
				echo "Invalid Selection - Try Again"
			fi
		fi
	done
}

function aptmulti {
	validmode=1
	loop=1
	full_mode=0
	#pkg="$1"
	pkg="$manpage" #global variable, defined in main program body
	echo "package requested: $pkg"
    resp=( $(apt-get --print-uris download "$1" 2>&1) )
    aptresp=( $(printf '%s\n' ${resp[@]} |grep 'http' |sed 's/\x27//g') )
    echo "apt response"
    printf '%s\n' "${aptresp[@]}"
#   declare -p aptresp
#   exit
    [[ -z "${aptresp[@]}" ]] && echo "nothing found" && return
    declare -A debs
    for ((i=0;i<=${#aptresp[@]};i++));do
      if [[ $full_mode -eq 1 ]];then
        pkgmanpage+=($(curl -sL -o- ${aptresp[$i]} |dpkg -c /dev/stdin |grep -v -e '^l' |grep -e "man/man" -e "changelog" -e "README" -e '/info/' -e '/examples/' -e '/doc/' |grep -vE "\/$" |awk '{print $NF}')) 
      else
        #man pages only - default selection
        pkgmanpage+=($(curl -sL -o- ${aptresp[$i]} |dpkg -c /dev/stdin |grep -v -e '^l' |grep -e "man/man" |grep -vE "\/$" |awk '{print $NF}')) 
      fi

      #script for association between man pages of each deb file (1 deb / many manpages)
      for k in "${!pkgmanpage[@]}";do
          [[ -z "${debs[${pkgmanpage[$k]}]}" ]] && debs["${pkgmanpage[$k]}"]="${aptresp[$i]}"
      done

    done
    
#TODO: include in the man pages the control file (apt show info) from deb using dpkg-deb --ctrl-tarfile     

	while [[ $loop -eq 1 ]]; do
		if [[ -z $pkgmanpage ]];then
			echo "No man pages found in deb package"
			exit 1
		else
			echo "man page found: ${#pkgmanpage[@]}"
			declare -p pkgmanpage |sed 's/declare -a pkgmanpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
#		exit
		read -p "Select man pages to display by id or press q to quit : " ms
		if [[ $ms == "q" ]]; then
			echo "exiting"
			loop=0
        elif [[ $ms -le $((${#pkgmanpage[@]}-1)) ]]; then
            deb="${debs[${pkgmanpage[$ms]}]}"
            echo "Display ${pkgmanpage[$ms]} from $deb"
            #curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${manpage[$ms]} |man /dev/stdin
            if [[ ${pkgmanpage[$ms]} =~ "man/man" ]]; then #Nov17: Different handling of various file types
                curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${pkgmanpage[$ms]} |man /dev/stdin #|yad --text-info --center --width=800 --height=600 --no-markup
            elif [[ ${pkgmanpage[$ms]: -3} == ".gz" ]]; then
                curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${pkgmanpage[$ms]} |gunzip -c |less -S
            else 
			   curl -sL -o- $deb |dpkg-deb --fsys-tarfile /dev/stdin |tar -xO ${pkgmanpage[$ms]} |less -S
			fi
        elif [[ $ms -gt $((${#pkgmanpage[@]}-1)) ]]; then
            echo "out of range - try again"
        else
            echo "Invalid Selection - Try Again"
        fi
	done
}

function down {
	validmode=1
	loop=1
	rawpkg="$1"
	echo "rawpkg requested: $rawpkg"
         aptresp=$(apt-get --print-uris download $rawpkg 2>&1)


	if [[ "$aptresp" == *"Unable to locate package"* ]];then
		echo "Error. Either wrong package name or other error. Raw output of apt:"
		apt-get --print-uris download $rawpkg
		exit 1
	fi

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
			elif [[ $ms == "q" ]]; then
				echo "exiting"
				loop=0
			elif [[ $ms -le $((${#manpage[@]}-1)) ]]; then
				echo "Display ${manpage[$ms]}"
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
#  bsdpage="$1"
  bsdpage="$manpage"
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
  #manpage="$1"
  echo "function openbsd - args received: $*"
  echo "function openbsd - proceed with manpage: $manpage to url: https://man.openbsd.org/$manpage"
  manpagecap="${manpage^^}" #Capitalize the man page title
  mandata="$(links -dump https://man.openbsd.org/$manpage |awk "/$manpagecap/,0")"
  [[ -z "$mandata" ]] && echo "No man page found at \"https://man.openbsd.org/$manpage\"" && exit 1

  if [[ "$mode" == "--openbsd" && $3 == "--browser" ]]; then
     gksu -u "$normaluser" xdg-open "https://man.openbsd.org/$manpage" 2>/dev/null &
  else
     echo "$mandata" |sed "1i https://man.openbsd.org/$manpage" |less -S
  fi  
#fi
}

function netbsd {
#old: http://netbsd.gw.com/cgi-bin/man-cgi?grep++NetBSD-current
#https://man.netbsd.org/${manpage}
  validmode=1  
  #manpage="$1"
  echo "Function netbsd - manpage received: $manpage"
  manpagecap="${manpage^^}" #Capitalize the man page title
  mandata="$(links -dump https://man.netbsd.org/${manpage} |awk "/$manpagecap/,0")"
  [[ -z "$mandata" ]] && echo "No man page found at \"https://man.netbsd.org/${manpage}\"" && exit 1

  if [[ "$mode" == "--netbsd" && $3 == "--browser" ]]; then
     gksu -u "$normaluser" xdg-open "https://man.netbsd.org/${manpage}" 2>/dev/null &
  else
     #echo "$mandata" |sed "1i https://man.netbsd.org/${manpage}" |less -S
     echo "$mandata" |man /dev/stdin
  fi  
}

function debiansuite {
  validmode=1  
  
    	echo "function debiansuite  - args received : $* / number of args = $#"
	while [[ $# -gt 0 ]]; do
	  echo "function debiansuite - processing arg $1"
	  case "$1" in
		--manpage) echo "--manpage found";if [ -n "$2" ]; then manpage="$2";shift 2; else echo "Option --manpage requires a value." >&2;exit 1;fi;;
		*) restparam+=$1;shift;;
	  esac
	done

	echo "manpage requested: $manpage"
  
  ##manpage="$1"
  loop=1
  release="$(lsb_release -c -s)" #yields to codename release i.e bullseye (instead of release number i.e 11)- codename required at 2022
  manpagesuite+=( $(curl -s -L -o- "http://manpages.debian.org/$release/$manpage" |grep -v 'index.html' |grep -Po ".* href=\"\K.*/$release/$manpage/.*[.]html" |perl -pe 's/html/gz/g') )
	while [[ $loop -eq 1 ]]; do
		if [[ -z $manpagesuite ]];then
			echo "No results. "
			links -dump "http://manpages.debian.org/$release/$manpage"
			exit 1
		else
			clear
			echo "man page found: ${#manpagesuite[@]}"
			declare -p manpagesuite |sed 's/declare -a manpagesuite=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
    	read -p "Select man pages to display by id or q to quit : " ms
        if [[ $ms == "q" ]]; then
			echo "exiting" && loop=0
		elif [[ $ms -le $((${#manpagesuite[@]}-1)) ]]; then
			echo "Display ${manpagesuite[$ms]/,/}" #list is given in "link,version" format. ${var/,*/} removes the version at the end (removes comma and everything after comma)
    #        links -dump http://manpages.debian.org"${manpagesuite[$ms]/,*/}" |less -S #works ok 28.03.2022
            man <(curl -s -L -o- "https://manpages.debian.org/${manpagesuite[$ms]}")

		else
			echo "Invalid Selection - Try Again"
		fi
	done
}

function debian {
  validmode=1
  
  echo "function debian  - args received : $* / number of args = $#"
  argsreceived=$*
  echo "manpage requested: $manpage"

  
    
  ##141023: manpage="$1"
  #release="$(lsb_release -r -s)" #yields to numerical release i.e 11 - not working at 2022
  release="$(lsb_release -c -s)" #yields to codename release i.e bullseye - required at 2022
  manpagecap="${manpage^^}" #Capitalize the man page title
  mandata="$(links -dump https://manpages.debian.org/$release/$manpage |awk "/$manpagecap/,0")" #works ok 28.03.2022
    #hardcoding .gz at the end , forces manpages.debian to bring the man raw file
  #[[ ! -z "$mandata" ]] && echo "$mandata" |sed "1i https://manpages.debian.org/$release/$manpage" |less -S #works ok 28.03.2022
  [[ ! -z "$mandata" ]] && mandataraw="$(curl -s -L -o - https://manpages.debian.org/$release/$manpage.gz)" && man <(echo "$mandataraw")
  if [[ -z "$mandata" ]];then
    echo "No man page found at \"https://manpages.debian.org/$release/$manpage\""
    echo "let's check if this is a debian suite"
    read -p "press any key to continue" pp
    debiansuite $argsreceived #calling another function, in this script.
  fi

}

function debianlisthtml {
#This is the old - legacy version of --debianlist , working with html files. The new version (just bellow) uses man and online stored gz raw data available in manpages.debian.org
  validmode=1
  page="$1"
  pagecap="${1^^}"
  loop=1
	manpage+=( $(curl -s -L -o- "http://manpages.debian.org/$page" |grep -Po ".* href=\"\K.*/$page.*pkgversion.*title.*$" |perl -pe 's/">.*title="/,/g' |perl -pe 's/">.*$//g' ) )

	while [[ $loop -eq 1 ]]; do
		if [[ -z $manpage ]];then
			echo "No results. If you entered the name of a suite (i.e debian-goodies) try to use --debian switch"
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

function debianlist {
#if [[ "$mode" == "--debianlist" ]]; then
  validmode=1
  
   	echo "function debianlist  - args received : $* / number of args = $#"
    echo "function debianlist - processing arg $1"
    page="$manpage"
	echo "manpage requested: $page"
  
  #page="$1"
  pagecap="${1^^}"
  loop=1
	pkgmanpage+=( $(curl -s -L -o- "http://manpages.debian.org/$page" |grep -Po ".* href=\"\K.*/$page.*pkgversion.*title.*$" |perl -pe 's/">.*title="/,/g' |perl -pe 's/">.*$//g' ) )

	while [[ $loop -eq 1 ]]; do
		if [[ -z $pkgmanpage ]];then
			echo "No results. If you entered the name of a suite (i.e debian-goodies) try to use --debian switch"
			links -dump "http://manpages.debian.org/$page"
			exit 1
		else
			#clear
			echo "man page found: ${#manpage[@]}"
			declare -p pkgmanpage |sed 's/declare -a pkgmanpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
    	read -p "Select man pages to display by id or q to quit : " ms
        if [[ $ms == "q" ]]; then
			echo "exiting" && loop=0
		elif [[ $ms -le $((${#pkgmanpage[@]}-1)) ]]; then
			echo "Display ${pkgmanpage[$ms]/,/}" 
			#list is given in "link,version" format. ${var/,*/} removes the version at the end (removes comma and everything after comma)
            u=$(echo "${pkgmanpage[$ms]/,*/}" |perl -pe 's/html/gz/g') #&& echo "$u" && read -p "any key..." 
            uu="https://manpages.debian.org${pkgmanpage[$ms]}" && export uu; 
            #export required in order perl to be able to read the bash variable uu
            man <(curl -s -L -o- "https://manpages.debian.org/$u" |perl -pe 's/SYNOPSIS/SYNOPSIS ($ENV{uu})/') 
            #Replacing Synopsis header in man page including url & version of the pkg 
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
# Quick jump : http://manpages.ubuntu.com/grep . 
# Includes jscript redirection and thus works on browser but not on terminal (links or curl -L)
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
## 2023: Ubuntu keeps a separate server for manpages in gz format .
## a gz manpage can be read directly by man using this command:
## man <(curl -s -L -o- https://manpages.ubuntu.com/manpages.gz/focal/man1/gawk.1.gz)

  validmode=1
  page=$manpage # $manpage has been set by main body , global variable
  address="$(curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$page |perl -pe 's/>/>\n/g' |grep -o -m1 '/manpages/.*html')"
##  address="$(curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$page |perl -pe 's/>/>\n/g' |grep -o -m1 '/manpages.gz/.*gz')"
  [[ -z "$address" ]] && echo "no man pages returned : curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$page" && 
  links -dump "http://manpages.ubuntu.com/cgi-bin/search.py?q=$page" && exit
  
  address=$(echo "$address" | perl -pe 's/manpages/manpages.gz/g; s/html/gz/g')
  address="https://manpages.ubuntu.com$address"; #export address
  read -p "address=$address - press any key to continue"
  if [[ "$mode" == "--ubuntu" && $3 == "--browser" ]]; then
     gksu -u "$normaluser" xdg-open "http://manpages.ubuntu.com$address" 2>/dev/null &
  else 
  #   links -dump http://manpages.ubuntu.com$address |sed "1i http://manpages.ubuntu.com$address" | less -S #works ok 15.10.23
  export address;man <(curl -s -L -o- "$address" |gzip -d |perl -pe 's/SYNOPSIS/SYNOPSIS ($ENV{address})/')  #trying to catch the gz file instead of the html file
  #use of gzip -d is not necessary - man can open .gz files firectly. 
  # Using gzip -d we can further proccess (i.e text replacement) the man page raw data.
  fi

}

function ubuntulist {
  validmode=1
  echo "function ubuntulist : args received : $* / number of args = $#"
  echo "function ubuntulist : manpage requested: $manpage"
  
  #page="$1"
  loop=1
	pkgmanpage+=($(curl -s -L -o- http://manpages.ubuntu.com/cgi-bin/search.py?q=$manpage |perl -pe 's/>/>\n/g' |grep -o '/manpages/.*man.*html') ) 
	while [[ $loop -eq 1 ]]; do
		if [[ -z $pkgmanpage ]];then
			echo "No results. "
			links -dump "http://manpages.ubuntu.com/cgi-bin/search.py?q=$manpage" && exit 1
		else
			##clear
			echo "man page found at http://manpages.ubuntu.com/cgi-bin/search.py?q=$manpage : ${#pkgmanpage[@]}"
			declare -p pkgmanpage |sed 's/declare -a pkgmanpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
		fi
    	read -p "Select man pages to display by id or q to quit : " ms
        if [[ $ms == "q" ]]; then
			echo "exiting" && loop=0
		elif [[ $ms -le $((${#pkgmanpage[@]}-1)) ]]; then
			echo "Display ${pkgmanpage[$ms]}"
			if [[ "$mode" == "--ubuntulist" && $3 == "--browser" ]]; then
               gksu -u "$normaluser" xdg-open "http://manpages.ubuntu.com${pkgmanpage[$ms]}" 2>/dev/null &
			else
			   #links -dump http://manpages.ubuntu.com"${pkgmanpage[$ms]}" |sed "1i http://manpages.ubuntu.com${pkgmanpage[$ms]}" |less -S
			   #old implmenentation before 151023, relying on the html man page
  		       address=$(echo "${pkgmanpage[$ms]}" | perl -pe 's/manpages/manpages.gz/g; s/html/gz/g')
  		       #making use of the nice ubuntu gz man places, i.e : https://manpages.ubuntu.com/manpages.gz/focal/man1/gawk.1.gz
  		       #instead of the default html man page that is available at https://manpages.ubuntu.com/manpages/focal/en/man1/gawk.1.html
  		       address="https://manpages.ubuntu.com$address"
  		       #read -p "press a key to proceed with address= $address"
  		       ## man <(curl -s -L -o- "$address")  #trying to catch the gz file instead of the html file to make use of man nice coloring
  		       export address;man <(curl -s -L -o- "$address" |gzip -d |perl -pe 's/SYNOPSIS/SYNOPSIS ($ENV{address})/')  #trying to catch the gz file instead of the html file
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
	#title=$1
	title=$manpage;pkg=$manpage
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
		#unset manpage aptresp aptpkg
		#pkg="$1"
		pkg="$manpage"
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
			pkgmanpage+=($(curl -sL -o- $deb |dpkg -c /dev/stdin |grep "man/man" |grep -vE "\/$" |awk '{print $NF}'))
			if [[ -z $pkgmanpage ]];then
				echo "No man pages found in deb package for $pkg. These are the contents of the $deb:"
				curl -sL -o- $deb |dpkg -c /dev/stdin
			else
				echo "man page found: ${pkgmanpage[@]}"
				declare -p pkgmanpage |sed 's/declare -a pkgmanpage=(//g' |tr ' ' '\n' |sed 's/)$//g'
			fi
		fi
#fi
}

#------------------------MAIN PROGRAMM-----------------------------------------------------------------------------------------#
function main { return; }
{
    oldargs=$*
    echo "Number of Parameters Given: $#"
    if [[ $# -eq 0 ]];then helpme;exit 1;fi #show help and exit if no args are provided at all

    echo "Old Args = $oldargs"
	#[[ -z $1 ]] || [[ "$1" == "--help" ]] || [[ "$2" == "--help" ]] && helpme && exit 1 #if no man page is requested print help and exit
	#[[ -z $2 ]] && mode="--apt" || mode="$2" #if no particular mode is given, the apt mode is used by default
	#echo "mode selected:  $mode"
	normaluser="$(awk -F':' '/1000:1000/{print $1;exit}' /etc/passwd)" 
	#Detect the system normal user. Could be buggy if more than one normal user exists

	while [[ $# -gt 0 ]]; do
	  case "$1" in

	#case $mode in
	"--manpage") echo "--manpage found";if [ -n "$2" ]; then manpage="$2";echo "manpage name=$2";shift 2; else echo "Option --manpage requires a value." >&2;exit 1;fi;;
	#"--pkg") echo "--pkg found";if [ -n "$2" ]; then pkg="$2";echo "pkg name=$2";shift 2; else echo "Option --pkg requires a value." >&2;exit 1;fi;;
	"--apt" )echo "mode selected=$1";apt $oldargs;shift;; ## Mind the absence of double quotes. If you pass oldargs using double quotes will be passed as ONE parameter and we don't want that.
	"--aptmulti" )echo "mode selected=$1";aptmulti $oldargs;shift;; ##	"--aptmulti")aptmulti "$@";;
	"--aptcheck" )echo "mode selected=$1";aptcheck $oldargs;shift;;
	"--down" )echo "mode selected=$1";down $oldargs;shift;;
	"--bsd" )echo "mode selected=$1";bsd $oldargs;shift;;
	"--openbsd" )echo "mode selected=$1";openbsd $oldargs;shift;;
	"--netbsd" )echo "mode selected=$1";netbsd $oldargs;shift;;
	"--debian" )echo "mode selected=$1";debian $oldargs;shift;;
#	"--debiansuite" )echo "mode selected=$1";debiansuite $oldargs;shift;;
	"--debianlist" )echo "mode selected=$1";debianlist $oldargs;shift;;
	"--debianlisthtml" )echo "mode selected=$1";debianlisthtml $oldargs;shift;;
	"--ubuntu" )echo "mode selected=$1";ubuntu $oldargs;shift;;
	"--ubuntulist" )echo "mode selected=$1";ubuntulist $oldargs;shift;;
	"--online" )echo "mode selected=$1";online $oldargs;shift;;
	"--help" ) helpme; exit 1; shift ;;
	*) restparam+=$1;shift;;
	# TODO 15.10.2023: 
	# Find a way to ensure that script will exit if --manpage <pkg> is not provided.
	# Also keep in mind that this usage will fail: manon --manpage --apt because --apt will be considered as argument for --manpage.
	# Another buggy usage: manon --apt --manpage help2man -> This will fail since --apt will be found firts and apt function will be called
	# before --manpage <pkg> is examined.
	esac
    done
	[[ $validmode -eq 1 ]] && echo "Succesfull exit" && exit 0
	echo "invalid options - exit with code 1" && exit 1
	exit 1
}




# compare man pages:
# http://unix.stackexchange.com/questions/337884/how-to-view-differences-between-the-man-pages-for-different-versions-of-the-same
# diff -y -bw -W 150 <(links -dump "https://www.mankier.com/?q=grep" |less -S |fold -s -w 70) <(man grep |less -S |fold -s -w 70)
# diff_man() { diff -y <(man --manpath="/old/path/to/man" "$1") <(man "$1"); }
# Using process substitution = each process get a named fifo and it is treated as a file. 

:<<manpagealert
script to display all binaries missing man pages (script included in devscripts debian pkg)
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
