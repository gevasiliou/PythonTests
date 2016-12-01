from evdev import UInput, AbsInfo, InputDevice, categorize, ecodes, resolve_ecodes, resolve_ecodes_dict, AbsEvent, InputEvent
import time
from datetime import datetime
from pymouse import PyMouse
from pykeyboard import PyKeyboard
from threading import Timer

def stamp():
	stamp=datetime.now().time()
	return stamp;


def rightclick():
	print "Right Click Timer Starting. Pressed Flag=", pressed
	time.sleep(1)
	timestop=time.time()
	x1,y1 = m.position() #Get the coordinates after time has elapsed
	endx=x1
	endy=y1
	deltatime=timestop - timestart
	print 'Timer Finished. Pressed Flag:',pressed,'Deltatime=',deltatime, ' Delta X:', abs(endx-startx), ' Delta Y:',abs(endy-starty)
#	m.click(x1, y1, 1) # Injecting a left click before right click - This modifies the Nautilus behavior.
#	m.release(x1, y1, 1) # I also tried to inject a left click release prior to right click injection.
#	dev.grab() # Device grab / ungrap has not a serious effect in Nautilus. In XFCE Desktop , right click is kept even without grabbing the device.
	m.press(x1, y1, 2)
	m.release(x1, y1, 2)
#	m2.click(x1, y1, 2) # I just thought to inject the right click with a different PyMouse Object - No success = Same Nautilus Behavior
#	dev.ungrab()

#	if pressed==True and (abs(endx-startx) < 20) and (abs(endy-starty) < 20): 
#		dev.grab()
#		m.click(x, y, 2)
#		dev.ungrab()

dev = InputDevice('/dev/input/event7') #Run evtest to verify the correct ELAN event number. 
print(dev) #Print the dev information
m = PyMouse()
#m2 = PyMouse() #Let's see what will happen if we register a seperate PyMouse object and inject right click with this.

# -------- Right Click Injection without finger relase (Code Begin)

pressed=False
for event in dev.read_loop():
#	print categorize(event),'-->','Event TimeStamp:', event.timestamp(), 'Event Code: ', event.code, ' Event Type: ',event.type, ' Event Value: ',event.value
	if event.type == 1 and event.code == 330 and event.value == 1:
		x,y = m.position()  # gets mouse current position coordinates
		pressed=True
		timestart=time.time()
		startx=x
		starty=y
#		t = Timer(1.0, rightclick)
#		t.start()
		rightclick() # I got suspicious about the Timer call so i just called the rightclick function directly.

# Bellow i detect the finger relase (BTN_TOUCH Value becomes 0). If code bellow is enabled, cancels the right click injection.
#	if event.type == 1 and event.code == 330 and event.value == 0:
#		print "Finger removed - cancelling..."
#		pressed=False
#		t.cancel()
##		try:
##			dev.ungrab()
##		except (OSError,IOError):  # capture case where grab was never initiated
##			pass
# --------  Right Click Injection without finger relase (Code End)


'''
#  -------- Right Click Injection upon finger relase (Code Begin)
# This Code works upon finger removal. Works OK even with Nautilus.

for event in dev.read_loop():
#	print categorize(event),'-->','Event TimeStamp:', event.timestamp(), 'Event Code: ', event.code, ' Event Type: ',event.type, ' Event Value: ',event.value
	if event.type == 1 and event.code == 330 and event.value == 1: # Code 330-BTN_TOUCH down event , value =1 
		x,y = m.position()  # gets mouse current position coordinates
		#timestart=event.timestamp #this did not work - switching to time.time()
		timestart=time.time()
		startx=x
		starty=y
	if event.type == 1 and event.code == 330 and event.value == 0: #Code 330-BTN_TOUCH up(release) event value = 0 
		x1,y1 = m.position()  # gets mouse current position coordinates
		#timestop=event.timestamp #this didn't worked - switching to time.time()
		timestop=time.time()
		endx=x1
		endy=y1
		deltatime=timestop - timestart
		print 'Deltatime=',deltatime, ' Delta X:', abs(endx-startx), ' Delta Y:',abs(endy-starty)
		if (deltatime > 0.7) and (abs(endx-startx) < 20) and (abs(endy-starty) < 20): # If time elapsed > treshold, and movement in X-Y less than tresholds then fire a right click event.
			m.click(x, y, 2)
# This worked OK even inside Nautilus userspace and files/folders
#  -------- Right Click Injection upon finger relase (Code End)
'''

'''
How To test:
a. tap in Desktop space: After one second the desktop context menu appears.
b. tap in a desktop item: After a second item's context menu appears
c. tap a Nautilus item: After a second item's context menu appears
d. tap at Nautilus space : After a second item's context menu appears correctly.
e. Repeat a,b,c,d with long press - no finger release: In all cases context menu will pop up except case d (nautilus space).

Next Actions:
We can try more Window Managers (i.e Caja, Nemo) to verify if the bug is also there
The method of injecting a left click prior to right click proved to be problematic, since Nautilus seems to "break" and Nautilus functionallity is not restored even after terminating the script.
Maybe worth to try mouse injections with PyGTK3 :
http://stackoverflow.com/questions/4542152/keyboard-mouse-events-on-desktop-root-window-with-pygtk-gtk-gdk-on-linux
https://digitaloctave.co.uk/pages/gtk3/tutorial14.htm
