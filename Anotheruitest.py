from evdev import UInput, ecodes as e
# http://suanfazu.com/t/simulate-mouse-clicks-on-python/10334/3capabilities = {
    e.EV_REL : (e.REL_X, e.REL_Y), 
    e.EV_KEY : (e.BTN_LEFT, e.BTN_RIGHT),
}

with UInput(capabilities) as ui:
    ui.write(e.EV_REL, e.REL_X, 10)
    ui.write(e.EV_REL, e.REL_Y, 10)
    ui.write(e.EV_KEY, e.BTN_LEFT, 1)
    ui.syn()
