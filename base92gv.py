#!/usr/bin/env python
# Base92 encode/decode for Python 2 (pip install base92)
# https://github.com/thenoviceoof/base92
#THE BEERWARE LICENSE (Revision 42):

# @thenoviceoof wrote the base92 file. As long as you retain this notice you can do whatever you want with this stuff. 
# If you meet @thenoviceoof some day, and you think his stuff is worth it, you can buy him a beer in return
# Nathan Hwang (thenoviceoof)
#
# GV Script Sep 2020 to work with stdin

from __future__ import print_function #to take advantage of Python3 print function with customized end of line
import sys
import base92

if len(sys.argv) > 1:
    #print sys.argv[1]
    if sys.argv[1]=="--help":
        print('This script can be used only with pipe. echo "hello" |base92gv.py or echo "hello" |base92gv.py --decode', end="\n")
    if sys.argv[1]=="--decode": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            #print line
            d=base92.decode(line)
            print(d, end="") #end of line="" instead of new line. Decode of base92.py can not handle \n
    exit() 

for line in sys.stdin:
    e=base92.encode(line)
    print(e, end="")
