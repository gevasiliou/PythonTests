# Sample Code using python-evdev tutorials to list properties of all devices.
#https://python-evdev.readthedocs.io/en/latest/tutorial.html
from evdev import InputDevice, list_devices
from pprint import pprint #the pretty print modules
for dev in list_devices(): # scan all devices
   device = InputDevice(dev)
   pprint(('device: ', device,'-',device.name))
   cap = device.capabilities(verbose=True,absinfo=True)
   pprint(('Device Capabilities:', cap))
   #This works nicely.
