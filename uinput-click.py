from evdev import InputDevice, InputEvent, UInput, AbsInfo, categorize, ecodes as e
import evdev
import time

#device = evdev.InputDevice('/dev/input/event2')
device = InputDevice('/dev/input/event10') # adjust the correct event number
print(device)
cap = device.capabilities(verbose=True,absinfo=True)
#cap = device.capabilities()
print('Device Capabilities:', cap) # Prints device capabilities in format Type : Values

# Tutorial: Specify uinput device options

capabilities = {
     e.EV_KEY : [e.BTN_LEFT, e.BTN_RIGHT],
     e.EV_ABS : [
          (e.ABS_X, AbsInfo(value=3100, min=0, max=3264, fuzz=0, flat=0, resolution=13)),
          (e.ABS_Y, AbsInfo(1090, 0, 1856, 0, 0, 13))]
} #this really works - mouse moved and right click menu appeared.Also looks steady=always working

'''
capabilities = {
     e.EV_KEY : [e.BTN_LEFT, e.BTN_RIGHT],
     e.EV_ABS : [e.ABS_X, e.ABS_Y]
}  # this method does not working
'''
ui = UInput(capabilities)
#ui = UInput()
print('UInput Capabilites:', ui.capabilities(verbose=True,absinfo=True))
time.sleep(10)

#Inject Event Example of Tutorial
ui.write(e.EV_ABS, e.ABS_X, 2555) #this works: moves mouse and injects right click.
ui.write(e.EV_ABS, e.ABS_Y, 226) #this works: moves mouse and injects right click.
'''
ui.write(e.EV_ABS, e.ABS_X, 0) #this also works: Right click injected at wherever mouse it is
ui.write(e.EV_ABS, e.ABS_Y, 0) #this also works: Right click injected at wherever mouse it is.
'''
ui.write(e.EV_KEY, e.BTN_RIGHT, 1)
ui.write(e.EV_KEY, e.BTN_RIGHT, 0)
ui.syn()
ui.close()

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

