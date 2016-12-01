from evdev import UInput, AbsInfo
#from evdev import ecodes as e
from evdev import InputDevice, categorize, ecodes, resolve_ecodes, resolve_ecodes_dict, AbsEvent, InputEvent
import time
from datetime import datetime
from pymouse import PyMouse
from pykeyboard import PyKeyboard
from threading import Timer

def stamp():
	stamp=datetime.now().time()
	return stamp;

def rightclick():
	print "Right Click Timer Function Starting. Pressed=", pressed
	time.sleep(1)
	timeup=time.time()
	x1,y1 = m.position()
	endx=x1
	endy=y1
	deltatime=timeup - timedown
	print 'Timer Finish. Pressed:',pressed,'Deltatime=',deltatime, ' Delta X:', abs(endx-startx), ' Delta Y:',abs(endy-starty)
#	m.click(x1, y1, 1)
	m.release(x1, y1, 1)
	m.press(x1, y1, 2)
	m.release(x1, y1, 2)

#	if pressed==True and (abs(endx-startx) < 20) and (abs(endy-starty) < 20): 
#		dev.grab()
#		m.click(x, y, 2)
#		k.tap_key(273) #does not work, either as 273 or as BTN_RIGHT

dev = InputDevice('/dev/input/event7') #Run evtest to verify the correct event number. 
print(dev)
m = PyMouse()
#m2 = PyMouse()

k=PyKeyboard()
'''
for event in dev.read_loop():
	x,y = m.position()  # gets mouse current position coordinates
	print categorize(event),'-->','Event TimeStamp:', event.timestamp(), 'Event Code: ', event.code, ' Event Type: ',event.type, ' Event Value: ',event.value
	if event.type == 1 and event.code == 330 and event.value == 1: #BTN_TOUCH down event
		#timedown=event.timestamp #this did not work
		timedown=time.time()
		startx=x
		starty=y
	if event.type == 1 and event.code == 330 and event.value == 0: #BTN_TOUCH up event
		#timeup=event.timestamp
		timeup=time.time()
		endx=x
		endy=y
		deltatime=timeup - timedown
		print 'Deltatime=',deltatime, ' Delta X:', abs(endx-startx), ' Delta Y:',abs(endy-starty)
		if (deltatime > 0.7) and (abs(endx-startx) < 20) and (abs(endy-starty) < 20):
			m.click(x, y, 2)


'''
pressed=False
for event in dev.read_loop():
	x,y = m.position()  # gets mouse current position coordinates
#	print categorize(event),'-->','Event TimeStamp:', event.timestamp(), 'Event Code: ', event.code, ' Event Type: ',event.type, ' Event Value: ',event.value
	if event.type == 1 and event.code == 330 and event.value == 1:
		pressed=True
		timedown=time.time()
		startx=x
		starty=y
		rightclick()
#		t = Timer(1.0, rightclick)
#		t.start()
#		timeup=time.time()
#		endx=x
#		endy=y
#		deltatime=timeup - timedown
#		m.click(x, y, 2)
#		print 'Pressed:',pressed,'Deltatime=',deltatime, ' Delta X:', abs(endx-startx), ' Delta Y:',abs(endy-starty)
#	if event.type == 1 and event.code == 330 and event.value == 0:
#		print "Finger removed - cancelling..."
#		pressed=False
#		t.cancel()
##		try:
##			dev.ungrab()
##		except (OSError,IOError):  # capture case where grab was never initiated
##			pass
