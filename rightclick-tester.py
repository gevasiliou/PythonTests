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

def rightclicktimer():
    print "Right Click Timer Function"
    time.sleep(1)
    if pressed==True and (abs(endx-startx) < 20) and (abs(endy-starty) < 20): 
#		dev.grab()
		m.click(x, y, 2)
#		k.tap_key(273)

dev = InputDevice('/dev/input/event7') #Run evtest to verify the correct event number. 
print(dev)
m = PyMouse()
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
	print categorize(event),'-->','Event TimeStamp:', event.timestamp(), 'Event Code: ', event.code, ' Event Type: ',event.type, ' Event Value: ',event.value
	if event.type == 1 and event.code == 330 and event.value == 1:
		#timedown=event.timestamp #this did not work
		pressed=True
		timedown=time.time()
		startx=x
		starty=y
		t = Timer(1.0, rightclicktimer)
		t.start()
		
		timeup=time.time()
		endx=x
		endy=y
		deltatime=timeup - timedown
		print 'Pressed:',pressed,'Deltatime=',deltatime, ' Delta X:', abs(endx-startx), ' Delta Y:',abs(endy-starty)
	if event.type == 1 and event.code == 330 and event.value == 0:
		print "Finger removed - cancelling..."
		pressed=False
		t.cancel()
#		try:
#			dev.ungrab()
#		except (OSError,IOError):  # capture case where grab was never initiated
#			pass
