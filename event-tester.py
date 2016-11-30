from evdev import UInput, AbsInfo
#from evdev import ecodes as e
from evdev import InputDevice, categorize, ecodes, resolve_ecodes, resolve_ecodes_dict, AbsEvent, InputEvent
import time
from datetime import datetime
from pymouse import PyMouse
from pykeyboard import PyKeyboard

def stamp():
	stamp=datetime.now().time()
	return stamp;

rep=1

dev = InputDevice('/dev/input/event7') #Run evtest to verify the correct event number. 
print(dev)

for event in dev.read_loop():
#	if event.type == ecodes.EV_ABS: #With this IF you can limit what to be printed. Remove it to print everything.
#		print(categorize(event))
	print categorize(event),'-->','Event TimeStamp:', event.timestamp(), 'Event Code: ', event.code, ' Event Type: ',event.type, ' Event Value: ',event.value
#		print AbsEvent(event)
