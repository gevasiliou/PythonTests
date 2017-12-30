# Python 2.7 Virtual Key Tester
# Requires PyUserInput library to be installed (https://pypi.python.org/pypi/PyUserInput/)
# run this script as python pykey-test.py
import time
from pykeyboard import PyKeyboard

k = PyKeyboard()

print ' Lets start - A Key will be typed in terminal now just for testing.'
time.sleep(2)
k.tap_key('H')
print ' key tapped'
	
print 'Control Alt F1 will be pressed now'
time.sleep(2)
k.press_key(k.alt_key)
k.press_key(k.control_key)
k.tap_key(k.function_keys[1]) # Tap F1 also k.tap_key('F1') works fine
k.release_key(k.alt_key) 
k.release_key(k.control_key)


