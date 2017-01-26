# Function from : https://github.com/aureliojargas/txt2regex/blob/master/txt2regex.sh
ColorOnOff(){
	# The colors: Normal, Prompt, Bold, Important
	[ "$f_color" != 1 ] && return
	if [ "$cN" ]
	then
		unset cN cP cB cI cR
	elif [ "$f_whitebg" != 1 ]
	then
		cN=$(echo -ne "\033[m")      # normal
		cP=$(echo -ne "\033[1;31m")  # red
		cB=$(echo -ne "\033[1;37m")  # white
		cI=$(echo -ne "\033[1;33m")  # yellow
		cR=$(echo -ne "\033[7m")     # reverse
	else
		cN=$(echo -ne "\033[m")      # normal
		cP=$(echo -ne "\033[31m")    # red
		cB=$(echo -ne "\033[32m")    # green
		cI=$(echo -ne "\033[34m")    # blue
		cR=$(echo -ne "\033[7m")     # reverse
	fi
# \033[ = ASCII for ESC

}
