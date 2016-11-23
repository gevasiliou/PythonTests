from evdev import UInput, AbsInfo
from evdev import ecodes as e 
import time
#set capabilities of the virtual uinput device.
capabilities = {
     e.EV_KEY : [e.BTN_LEFT, e.BTN_RIGHT],
     e.EV_ABS : [
          (e.ABS_X, AbsInfo(value=3100, min=0, max=3264, fuzz=0, flat=0, resolution=13)),
          (e.ABS_Y, AbsInfo(1090, 0, 1856, 0, 0, 13))]
}
ui = UInput(capabilities) #create the virtual device with the capabilies set above.

# apply some time for me to move (manually) my mouse pointer somewhere in the screen
time.sleep(10) 
# Now that i have move my mouse somewhere, a right click event will be fired automatically.
ui.write(e.EV_ABS, e.ABS_X, 0) #0 has the meaning 'wherever pointer it is already'
ui.write(e.EV_ABS, e.ABS_Y, 0)
# if we apply some numbers above right click will be injected in the new coords. I think mouse will not be moved.
ui.write(e.EV_KEY, e.BTN_RIGHT, 1) #1 for btn press
ui.write(e.EV_KEY, e.BTN_RIGHT, 0) #0 for btn release
ui.syn() #sync the event - empty the buffer - send the buffer commands to kernel.
#test
