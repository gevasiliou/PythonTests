from evdev import UInput, AbsInfo
from evdev import ecodes as e 
import time
from datetime import datetime
from pymouse import PyMouse
from pykeyboard import PyKeyboard

def stamp():
	stamp=datetime.now().time()
	return stamp;

rep=1
while rep == 1 :
	print stamp(), ' Lets start this shit'
	time.sleep(2)
	print 'You have 5 seconds to move your mouse pointer smowhere'
	time.sleep(5) 

	m = PyMouse()
	x,y = m.position()  # gets mouse current position coordinates
	m.click(x, y, 2)  # the third argument represents the mouse button (1 left click,2 right click,3 middle click)

	print stamp(), 'right click injected at ', m.position()
