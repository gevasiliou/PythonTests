#!/usr/bin/python
import os
import logging
import sys

def systemcmd():
  file = "./file7"
  with open(file) as f:
    (lat, long) = f.read().splitlines()  #If the file has more than two lines, an error is given by Python (too many arguments)

  print(lat)
  cmd="echo "+lat+"|sed 's/line/\U&/g'"
  os.system(cmd)
  #os.system('echo %(lat)s' % locals())
  #| sudo gammu-smsd-inject TEXT 07xxxxxxxxx")
  return

LEVELS = {'debug': logging.DEBUG,
          'info': logging.INFO,
          'warning': logging.WARNING,
          'error': logging.ERROR,
          'critical': logging.CRITICAL}

if len(sys.argv) > 1:
    level_name = sys.argv[1]
    level = LEVELS.get(level_name, logging.NOTSET)
    logging.basicConfig(level=level)  
    #logging.basicConfig(filename='loggs.log', format='%(asctime)s - %(levelname)s - %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p',level=level)
print(level_name)
logging.debug('This is a debug message')
logging.info('This is an info message')
logging.warning('This is a warning message')
logging.error('This is an error message')
logging.critical('This is a critical error message')
