from evdev import UInput, AbsInfo, ecodes as e
from time import sleep
import subprocess
#import os;cmd = 'ls -al';os.system(cmd)

##http://suanfazu.com/t/simulate-mouse-clicks-on-python/10334/3
capabilities = {
    e.EV_REL : (e.REL_X, e.REL_Y), 
    e.EV_KEY : (e.BTN_LEFT, e.BTN_RIGHT),
}

with UInput(capabilities) as ui:
    sleep(10)
    ui.write(e.EV_REL, e.REL_X, 5)
    ui.write(e.EV_REL, e.REL_Y, 5)
    ui.write(e.EV_KEY, e.BTN_RIGHT, 1)
    ui.write(e.EV_KEY, e.BTN_RIGHT, 0)
    ui.syn()
#   ui.close()
#subprocess.Popen(['notify-send', 'Right Click 1 injected'])
# Result: This works.... But a couple of times it didn't work.
#
'''
capabilities = {
     e.EV_KEY : [e.BTN_LEFT, e.BTN_RIGHT],
     e.EV_REL : [
          (e.REL_X, AbsInfo(value=3100, min=0, max=3264, fuzz=0, flat=0, resolution=13)),
          (e.REL_Y, AbsInfo(1090, 0, 1856, 0, 0, 13))]
} #this really works - mouse moved and right click menu appeared

with UInput(capabilities) as ui:
    sleep(10)
    ui.write(e.EV_REL, e.REL_X, 0)
    ui.write(e.EV_REL, e.REL_Y, 0)
    ui.write(e.EV_KEY, e.BTN_RIGHT, 1)
    ui.write(e.EV_KEY, e.BTN_RIGHT, 0)
    ui.syn()
    ui.close()
#subprocess.Popen(['notify-send', 'Right Click 2 injected'])
'''
#if notify send not working then start the daemon manually:
# as root give-> #/usr/lib/notification-daemon/notification-daemon
