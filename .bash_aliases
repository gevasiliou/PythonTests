# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly (~/.bashrc).
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
#if [ -f ~/.bash_aliases ]; then
#    . ~/.bash_aliases
#fi
#Remark: .bashrc of user has already above check condition but root .bashrc not.
#Install it using cp .bash_aliases /home/gv/ and cp .bash_aliases /root/ or cp .bash_aliases $HOME/ (under root terminal)
#Or you can source it on the fly by command line using #. ./.bash_aliases
alias yadit='yad --text-info --center --width=800 --height=600 --no-markup --wrap'
alias nocrap='grep -i -v -e .page -e .png -e .svg -e .jpg -e messages -e usr/share/man -e changelog -e log'
alias lsdir='ls -all |grep -E '^d''
