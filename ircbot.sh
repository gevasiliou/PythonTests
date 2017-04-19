#!/bin/bash
# Draft irc bot 
# We need to feed netcat using an intermediate file, since a simple "echo PONG" will print locally this message and will not be sent to the server
# other techniques: group some commands and send them on the beginning or use expect scripts
# Resources:
http://stackoverflow.com/questions/43474851/reply-to-irc-ping-with-pong-in-bash-script/43483425#43483425
https://github.com/Newbrict/bash-irc-bot/blob/master/bot.sh
http://archive.oreilly.com/pub/h/1963 #IRC over TELNET
http://stackoverflow.com/questions/7013137/automating-telnet-session-using-bash-scripts  #TELNET automation with expect script

# Heredoc method
#telnet 10.1.1.1 <<EOF
#remotecommand 1
#remotecommand 2
#EOF

# echo method:
# (echo password; echo "show ip route"; sleep 1; echo "quit" ) | telnet myserver port

# Using /dev/tcp instead of telnet/netcat


# -----------------------SCRIPT START-----------------------------------------------------
#exec 3>&1
#exec 4<.ircbot
#exec >.ircbot

rm .ircbot
touch .ircbot
prmnick="monaxoss"
#tail -f .ircbot |telnet irc.freenode.net 6667 |while read res
tail -f .ircbot |nc irc.seersirc.net 6667 |while read res  #you can use either nc or telnet
do 
echo "==>$res"
#[[ "$res" == *"look up your hostname"* ]] && sleep 0.5 && echo "NICK gvgv" >>.ircbot  #responses from freenode.net
#[[ "$res" == *"No Ident response"* ]] && sleep 0.5 && echo "USER gv 8 * :gv " >>.ircbot;
if [[ "$res" == *"Couldn't resolve your hostname; using your IP address instead"* ]];then  
	sleep 2
	echo "NICK gvgv" >>.ircbot
	tail -n1 .ircbot
elif [[ "$res" == *"PING"* ]]; then
	sleep 2
	echo "$res" |sed 's/PING/PONG/' >>.ircbot
	tail -n1 .ircbot
	sleep 2
	echo "USER gv 8 * :gv " >>.ircbot
	tail -n1 .ircbot
	sleep 2
    echo "PRIVMSG $prmnick : hello from bot" >>.ircbot
	tail -n1 .ircbot
	
fi
done


function devtcpbot {
#!/usr/bin/env bash
# Alternative way instead of using telnet or netcat with temp file
# Open a connection to canternet
exec 3<>/dev/tcp/irc.canternet.org/6667;

# Login and join the channel.
printf "NICK BashBot\r\n" >&3;
printf "USER bashbot 8 * :IRC Bot in Bash\r\n" >&3;
sleep 2;
printf "JOIN #HackingIsMagic\r\n" >&3;

# Main loop
while [ true ]; do
	read msg_in <&3;

	# UGLY ping response.  Sends a PONG whenever PING shows up.
	if  [[ $msg_in =~ "PING" ]] ; then
		printf "PONG %s\n" "${msg_in:5}";
		printf "PONG %s\r\n" "${msg_in:5}" >&3;
	fi

done
}
















