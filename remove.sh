#!/bin/bash
yad --text="Hello from script to remove"
qterminal -e apt install mate-utils-common && read -p "Press any key to exit"
# or use xterm -e
exit
