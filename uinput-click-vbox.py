from evdev import InputDevice, InputEvent, UInput, AbsInfo, categorize, ecodes as e
import evdev
import time
from pprint import pprint
#device = evdev.InputDevice('/dev/input/event2')
device = InputDevice('/dev/input/event2') # adjust the correct event number
pprint(device)
cap = device.capabilities(verbose=True,absinfo=True)
#cap = device.capabilities()
pprint(('Device Capabilities:', cap)) # Prints device capabilities in format Type : Values

# Tutorial: Specify uinput device options
capabilities = {
    e.EV_KEY : [e.BTN_LEFT, e.BTN_RIGHT],
    e.EV_ABS : [
         (e.ABS_X, AbsInfo(value=5000, min=0, max=32767, fuzz=0, flat=0, resolution=0)),
         (e.ABS_Y, AbsInfo(5000, 0, 32767, 0, 0, 0))]
}

ui = UInput(capabilities)
pprint(('User Input:', ui.capabilities(verbose=True,absinfo=True)))d
time.sleep(15)
# Inject Event Example of Tutorial
#ui = UInput()
#ui.write(e.EV_KEY, e.KEY_G, 1)  # KEY_A down
#ui.write(e.EV_KEY, e.KEY_G, 0)  # KEY_A up
ui.write(e.EV_ABS, e.ABS_X, 25500)
ui.write(e.EV_ABS, e.ABS_Y, 14500)
ui.write(e.EV_KEY, e.BTN_RIGHT, 1)  # KEY_A down
ui.write(e.EV_KEY, e.BTN_RIGHT, 0)  # KEY_A up
ui.syn()
ui.close()
print('event injected')
#for event in device.read_loop():
##	print('output :',evdev.ecodes.EV_KEY)
#	if event.type == e.EV_KEY:
#		print(categorize(event))
# GV: Above works ok . Goes into a loop and displays lines like this: key event at 1475501496.997337, 272 (['BTN_LEFT', 'BTN_MOUSE']), up

# Sources
# https://python-evdev.readthedocs.io/en/latest/tutorial.html
# https://github.com/tuomasjjrasanen/python-uinput/blob/master/examples/mouse.py
# http://suanfazu.com/t/simulate-mouse-clicks-on-python/10334/3
# see file setup.py, input.h nd input-evet-codes.h
# https://python.swaroopch.com/basics.html
# Python-uinput
#stackoverflow - simulating key-press-event-using-python-for-linux

# https://www.kernel.org/doc/Documentation/input/multi-touch-protocol.txt , explanation of MT types (MultiTouch)
# https://www.kernel.org/doc/Documentation/input/event-codes.txt , explanation of event types

# Python-EvDev Tutorial : http://python-evdev.readthedocs.io/en/latest/tutorial.html



# Inject an Event with context manager of Tutorial
#ev = InputEvent(1475500749, 371716, e.EV_KEY, e.BTN_RIGHT, 1)
#with UInput() as ui:
#    ui.write_event(ev)
#    ui.syn()
#    ui.close()
#    print ('event injected')



#capabilities = {
#    e.EV_REL : (e.REL_X, e.REL_Y),
#    e.EV_KEY : (e.BTN_LEFT, e.BTN_RIGHT),
#}
#print('e.REL_X:',e.REL_X) #this prints 0
#print('e.REL_Y:',e.REL_Y) #this prints 1
#print('e.BTN_LEFT:',e.BTN_LEFT) # this prints 272
#print('e.BTN_RIGHT:',e.BTN_RIGHT) # this prints 273
#

#with UInput(capabilities) as ui:
#    ui.write(e.EV_REL, e.REL_X, 10)
#    ui.write(e.EV_REL, e.REL_Y, 10)
#    ui.write(e.EV_KEY, e.BTN_RIGHT, 1)
#    ui.syn()
#    ui.close()


#            ui.write(ecodes.EV_ABS, ecodes.ABS_X, 0)
#            ui.write(ecodes.EV_ABS, ecodes.ABS_Y, 0)
#            ui.write(ecodes.EV_KEY, ecodes.BTN_RIGHT, 1)
#            ui.write(ecodes.EV_KEY, ecodes.BTN_RIGHT, 0)
#            ui.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 0)
#            ui.syn()

