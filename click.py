from pymouse import PyMouse
from time import sleep
m = PyMouse()
x, y = m.position()
print('current:',x,y)
#m.click(x,y,2)
a, b = m.screen_size()
print(a,b)
print(a/2,b/2)
sleep(5)
m.move(a/2,b/2)
m.click(a/2,b/2,2)
## this extra line added for testing  with git synchronization (local file updates remote file)
