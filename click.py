# Right Click simulation using Python pymouse module (requires also python-xlib to be present)
# While python evdev/uinput method works as a virtual input device injecting events directly to the kernel , pymouse works at xserver level.
from pymouse import PyMouse
from time import sleep
m = PyMouse()
sleep(5) #wait 10 seconds....
x, y = m.position()
a, b = m.screen_size() #Just for fun
m.move(a/2,b/2) #With this line your mouse pointer is moved on the center of the screen
sleep(2)
m.move(x,y) #move the mouse back to beginning
print("current position:", x, y)
print('screen dimensions:', a, b) #Just for fun
sleep(2) #wait
m.click(x,y,2) #With this line, right click happens wherever your mouse is

#m.click(a/2,b/2,2) #and right click is injected in the center of the screen regardless your mouse pointer current position
#moving the mouse pointer is not mandatory for m.click to work but m.click will move the mouse pointer!
#The third argument in the m.click represent the mouse button to be emulated (1 for left, 2 for right , 3 for middle)
