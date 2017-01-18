#!/bin/bash
echo "Just an echo - nothing more to be done here"
echo "Parameter received="$#
[[ -z $1 ]] && echo "parameter 1 is emty"
exit 0
