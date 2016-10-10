from evdev import UInput, AbsInfo, ecodes as e
import time
capabilities = {
     e.EV_KEY : [e.BTN_LEFT, e.BTN_RIGHT],
     e.EV_ABS : [
          (e.ABS_X, AbsInfo(value=3100, min=0, max=3264, fuzz=0, flat=0, resolution=13)),
          (e.ABS_Y, AbsInfo(1090, 0, 1856, 0, 0, 13))]
}
ui = UInput(capabilities)
time.sleep(10) # just some time to move the mouse somewhere
ui.write(e.EV_ABS, e.ABS_X, 0)
ui.write(e.EV_ABS, e.ABS_Y, 0)
ui.write(e.EV_KEY, e.BTN_RIGHT, 1)
ui.write(e.EV_KEY, e.BTN_RIGHT, 0)
ui.syn()
