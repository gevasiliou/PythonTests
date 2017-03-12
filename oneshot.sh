#!/bin/bash
echo "Just an echo - nothing more to be done here"

echo "You run this script as USER=$USER"
echo "Your HOME dir is $HOME"
echo "Your PATH is $PATH"
echo "Parameter received="$#
[[ -z $1 ]] && echo "parameter 1 is emty"

read -p "Enter a value" 
echo "you entered $REPLY"

#dpkgnum agrep

#read -p "press any key to try to load agrep manual from debian.manpages web site"
#debman agrep

#read -p "now will try to call an debman alias by the BASH_ALIASES variable"
#echo ${BASH_ALIASES[@]}
#bash -c 'echo ${BASH_ALIASES[@]}'
#eval echo ${BASH_ALIASES[@]}
##none of above worked. 

#read -p "press a key to try to execute justatest function sourced from .bash_aliases with process substitution"
#source <(sed -n '/function justatest/,/\}/p' .bash_aliases) && justatest 

## bellow also works fine
##read -p "another way to source the code is directly EVAL the code"
##eval "$(sed -n '/function justatest/,/\}/p' .bash_aliases)" && justatest

#read -p "lets try to source debman alias"
#shopt -s expand_aliases &&  source <(sed -n "/alias debman/p" .bash_aliases) && debman agrep
##OR 
## to strip the alias , get rid of shopt and use just the function:
## sed -n "/alias debman/p" .bash_aliases |awk -F="'|}" '{print $2"}"}'

exit
