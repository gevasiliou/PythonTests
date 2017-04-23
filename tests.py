#!/usr/bin/python
import os

#os.system("sh .webgps.sh > coordinates.text")

file = "./file7"
with open(file) as f:
  (lat, long) = f.read().splitlines()  #If the file has more than two lines, an error is given by Python (too many arguments)

print(lat)
cmd="echo "+lat+"|sed 's/line/\U&/g'"
os.system(cmd)
#os.system('echo %(lat)s' % locals())
#| sudo gammu-smsd-inject TEXT 07xxxxxxxxx")
