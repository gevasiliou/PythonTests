#!/bin/bash
function sersoft {
yad --text "Server Prerequesites Will be installed now"
}
export -f sersoft

function clientsoft {
yad --text "Client Prerequesites Will be installed now"
}
export -f clientsoft

function install_ser_soft {
yad --text "Server SOFTWARE to be installed now"
}

function install_client_soft {
yad --text "Client SOFTWARE to be installed now"
}


	MSP="Install Prerequesites for Server"
    MCP="Install Prerequesites for Client"
    MSP1="Software for Server"
    MCP1="Software for Client"

    yad --plug=12346 --tabnum=1 --form --image="abp.png" --separator='\n' &\
    yad --plug=12346 --tabnum=2 --form --separator='\n' --text="Please install softwares" --text-align=center \
    --field="$MSP!gtk-yes:2:FBTN" "bash -c sersoft" --align=center --field="$MCP!gtk-yes:3:FBTN" "bash -c clientsoft" \
    --align=center &\
    action=$(yad --plug=12346 --tabnum=3 --form --seperator=' ' --field="Select:CBE" "\--Install\--!$MSP1!$MCP1" &\
    yad --center --notebook --key=12346 --tab="Welcome Tab" --tab="Prerequesites" --tab="Install" --title="Software Setup Wizard" --image="abp.png" --button="OK:0" --button="Exit:1" --height=560 --width=665 --image-on-top --text="Software version 3")
	ret=$?
	echo "output=" $ret
	echo "answer=" $action
	case $action in
	$MSP1*) install_ser_soft ;;
	$MCP1*) install_client_soft ;;
	*) yad --center --text="error";;
	esac		


    #yad --plug=$KEY --tabnum=1 --form --image="$banner" --separator='\n' --quoted-output \
             #> $res4 &

    #yad --plug=$KEY --tabnum=2 --form --separator='\n' --text="\n\nPlease install the required softwares needed to configure Monosek software. \n\nClick any one of the options.\n\n" --text-align=center --quoted-output \
            #--field="$MSP!gtk-yes:2":FBTN --align=center \
            #--field="$MCP!gtk-yes:3":FBTN --align=center  > $res1 &

    #action=$(yad --plug=$KEY --tabnum=3 --form --seperator='\n' --quoted-output \
            #--field="Select:CBE" "\--Install\--!$MSP1!$MCP1") > $res2 &

    #yad --center --fixed --notebook --key=$KEY --tab-pos=left --tab="Welcome Tab" --tab="Prerequesites" --tab="Install" \
    #--title="Software Setup Wizard" --image="$icon" \
    #--button="OK:0" \
    #--button="Exit:1" \
    #--height=560 --width=665 --image-on-top --text="  Software version $VERSION"
#case $action in
#$MSP1*) TAB2=install_ser_soft ;;
#$MCP1*) TAB3=instal_client_soft ;;
#*) yad --center --text="error";;
#esac


