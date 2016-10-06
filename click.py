from pymouse import PyMouse
from time import sleep
m = PyMouse()
x, y = m.position()
a, b = m.screen_size()
print('current position:',x,y)
print('screen dimensions:', a, b)
sleep(10) #wait 10 seconds
#m.click(x,y,2) #With this line, right click happens wherever your mouse is 

m.move(a/2,b/2) #With this line your mouse pointer is moved on the center of the screen
m.click(a/2,b/2,2) #and right click is injected in the center of the screen.
#moving the mouse pointer is not mandatory for m.click to work.
