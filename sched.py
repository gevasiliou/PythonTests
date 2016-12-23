import threading
import schedule
import time
import datetime
import sys
#global run

def greet(run):
	print ('Function Greet')
#	global run
	while (run == 1):
		print('{} This is a test'.format(datetime.datetime.now()))
		time.sleep(5)
		#print('Hello Again')
	
def clearjob(jobc):
#	schedule.clear(jobc)
	#schedule.cancel_job(jobc)
	global run
	print ('Clear Job called')
	run=0

#run=1
#schedule.every(5).seconds.do(greet, 'George').tag('daily-tasks', 'friend')
schedule.every().day.at("03:00").do(greet,1).tag('daily-tasks', 'friend')    
#print schedule.every().day.at("02:06").do(greet).tag('daily-tasks', 'friend')
#time.sleep(10)
#schedule.every().day.at("01:43").do(clearjob,'daily-tasks')

schedule.every().day.at("03:01").do(greet,0)
#schedule.clear('daily-tasks')
#schedule.cancel_job(greet)
#schedule.every().day.at("00:24").do(greet, 'Andrea').tag('daily-tasks', 'friend')

while True:
    schedule.run_pending()
    time.sleep(1)
'''

def test():
    print('{} This is a test'.format(datetime.datetime.now()))


def exit():
    sys.exit()

schedule.every(5).seconds.do(test)
schedule.every().day.at('01:34').do(exit)

while True:
    schedule.run_pending()
    time.sleep(1)
'''
