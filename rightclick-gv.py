from evdev import InputDevice
import time
from pymouse import PyMouse
from threading import Timer
import subprocess


def rightclick():
    print "Right Click Timer Starting. Pressed Flag=", pressed
    timestop = time.time()
    x1, y1 = m.position()  # Get the coordinates after time has elapsed
    endx = x1
    endy = y1
    deltatime = timestop - timestart
    print 'Timer Finished. Pressed Flag:', pressed, 'Deltatime=', deltatime, ' Delta X:', abs(
        endx - startx), ' Delta Y:', abs(endy - starty)
    if pressed == True and (abs(endx - startx) < 20) and (abs(endy - starty) < 20):
        subprocess.check_call(['xinput', '--disable', 'ELAN Touchscreen'])
        m.press(x1, y1, 2)
        m.release(x1, y1, 2)
        subprocess.check_call(['xinput', '--enable', 'ELAN Touchscreen'])
#       Bug: You can not have right click context menu on multiple sellected items inside Nautilus
#       Workaround: For multiple selected items in Nautilus you can bring context menu with two finger tap

dev = InputDevice('/dev/input/event10')  # Run evtest to verify the correct ELAN event number.
print(dev)  # Print the dev information
m = PyMouse()

# -------- Right Click Injection without finger relase (Code Begin)

pressed = False
for event in dev.read_loop():
    #	print categorize(event),'-->','Event TimeStamp:', event.timestamp(), 'Event Code: ', event.code, ' Event Type: ',event.type, ' Event Value: ',event.value
    if event.type == 1 and event.code == 330 and event.value == 1:
        x, y = m.position()  # gets mouse current position coordinates
        pressed = True
        timestart = time.time()
        startx = x
        starty = y
        t = Timer(1.0, rightclick)
        t.start()

    # Bellow i detect the finger relase (BTN_TOUCH Value becomes 0). If code bellow is enabled, cancels the right click injection.
    if event.type == 1 and event.code == 330 and event.value == 0:
        print "Finger removed - cancelling..."
        pressed = False
        t.cancel()

    if event.type == 3 and event.code == 47 and event.value == 1: #ABS_MT_SLOT EVENT. VALUE 1 = 2 FINGERS
        print "Two Finger tap..."
        x2, y2 = m.position()  # Get the pointer coordinates
        m.click(x2, y2, 2)
        print "Two Finger tap Right Click Injected..."

# --------  Right Click Injection without finger relase (Code End)

