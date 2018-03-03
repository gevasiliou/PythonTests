from evdev import UInput, AbsInfo, ecodes as e
from time import sleep
import subprocess
#import os;cmd = "notify-send 'hellol'";os.system(cmd) # an alternative method to execute shell commands. Could also be cmd = 'ls -al' 

##http://suanfazu.com/t/simulate-mouse-clicks-on-python/10334/3
capabilities = {
    e.EV_REL : (e.REL_X, e.REL_Y), 
    e.EV_KEY : (e.BTN_LEFT, e.BTN_RIGHT),
}

with UInput(capabilities) as ui:
    sleep(10)
    ui.write(e.EV_REL, e.REL_X, 5) #or could be 0 = where the mouse pointer currently is.
    ui.write(e.EV_REL, e.REL_Y, 5) #or could be 0
    ui.write(e.EV_KEY, e.BTN_RIGHT, 1)
    ui.write(e.EV_KEY, e.BTN_RIGHT, 0)
    ui.syn()
#   ui.close() # not absolutelly necessary. ui is closed after the ui.sun().
subprocess.Popen(['notify-send', 'Right Click 1 injected'])
# Result: This works.... But a couple of times didn't work.
#
'''
capabilities = {
     e.EV_KEY : [e.BTN_LEFT, e.BTN_RIGHT],
     e.EV_REL : [
          (e.REL_X, AbsInfo(value=3100, min=0, max=3264, fuzz=0, flat=0, resolution=13)),
          (e.REL_Y, AbsInfo(1090, 0, 1856, 0, 0, 13))]
} 
#this method also works. You can apply AbsInfo values to EV_REL.

'''
#if notify-send not working then most probably daemon service is not running and you need to start this daemon manually:
# as root give-> #/usr/lib/notification-daemon/notification-daemon
# In my XFCE a "notification" icon appears on the task bar.
