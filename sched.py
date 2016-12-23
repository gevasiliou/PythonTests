'''
import threading
import schedule
import time
import datetime
import sys
import multiprocessing

from datetime import *

'''
'''
# This one has worked ok based on multiprocessing library of Python , which provides terminate() method.
def foo(n):
    for i in range(10000 * n):
        print "Tick"
        time.sleep(1)
        print "Tack"

p = multiprocessing.Process(target=foo, name="Foo", args=(10,))
p.start()
time.sleep(10)
p.terminate()
p.join()
'''

'''
# This also works ok due to that functions are called in series. One function does the job, second functions exits.
def test():
    print('{} This is a test'.format(datetime.datetime.now())) #this works ok
	#If you apply a loop here like while true, then exit() is not called since Python and Schedule work in series.
	#Meaning that if a job is running the next job does not start if previous job is not finished.
	
def exit():
    print('{} Now the system will exit '.format(datetime.datetime.now())) #this works ok
    sys.exit()

schedule.every().day.at("09:57").do(test)
schedule.every().day.at('09:58').do(exit)

while True:
    schedule.run_pending()
    time.sleep(1)
'''

'''
# This one use schedule and threads to automatically start a job at time X and stop it at time Y
# http://stackoverflow.com/questions/41289947/how-to-start-stop-python-function-from-10-am-to-1230pm

def doit(stop_event, arg):
    while not stop_event.wait(1): 
		#By wait(1) you repeat the loop every 1 sec. 
		#Applying wait(0) , loops run immediatelly until to be stopped by  stop_event
		#By removing the .wait section the while loop is immediatelly terminated.
        print ("working on %s" % arg)
    print("Stopping as you wish.")


def startit():
	global pill2kill
	global t
	pill2kill = threading.Event()
	t = threading.Thread(target=doit, args=(pill2kill, "task"))
	t.start()

def stopit():
	global pill2kill
	global t
	pill2kill.set()
	t.join()

#startit() #Manual call for Testing 
#time.sleep(5) #Wait 5 seconds
#stopit() #Manual call or Testing

schedule.every().day.at("12:48").do(startit)
schedule.every().day.at('12:49').do(stopit)

#schedule.every().day.at("12:50").do(startit) #Uncomment this to recall it for testing
#schedule.every().day.at('12:51').do(stopit) #Unocmment this to recall it for testing

while 1:
    schedule.run_pending()
    time.sleep(1)
'''

#------------------- Manual Comparison of datetime ------------------#
# http://stackoverflow.com/questions/8142364/how-to-compare-two-dates
# http://stackoverflow.com/questions/373335/how-do-i-get-a-cron-like-scheduler-in-python
# https://docs.python.org/3/library/datetime.html
from datetime import datetime
import time

def test():
	global hasrun
#	while (run==True):
	print('{} This is a test'.format(datetime.now()))
	time.sleep(5)
	hasrun=True

year,month,day,hour,minute=2016,12,23,15,55	

now=datetime.now()
print "Now the time is :", now
jobstart=datetime(year,month,day,hour,minute)
jobstop=datetime(year,month, day,hour,minute+1)
print "Job will run at: ", jobstart
print "Job will finish at: ", jobstop

print datetime.now() - jobstart
hasrun=False
while True:
	while ((datetime.now() > jobstart) and (datetime.now() < jobstop )): 
		run=True
		test()
	else:
		print('{} Please Wait...'.format(datetime.now()))
		run=False
		if hasrun:
#			day=day+1
			minute=minute+2
			jobstart=datetime(year,month,day,hour,minute)
			jobstop=datetime(year,month, day,hour,minute+1)
			print "the job will run again ", jobstart
			print "and will finish at ", jobstop
			hasrun=False
		time.sleep(10)
		
#date1 = "31/12/2015"
#date2 = "01/01/2016"
#newdate1 = time.strptime(date1, "%d/%m/%Y")
#newdate2 = time.strptime(date2, "%d/%m/%Y")
#newdate1 > newdate2 will return False
#newdate1 < newdate2 will return True
