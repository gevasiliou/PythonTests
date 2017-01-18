#!/bin/bash
echo "Just an echo - nothing more to be done here"
echo "Parameter received="$#
[[ -n $1 ]] && echo "parameter 1 is emty"
exit 0
