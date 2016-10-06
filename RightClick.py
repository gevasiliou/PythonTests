"""
Python Script for adding 1 & 2 finger multitouch gestures to implement
a right click option with Touchscreens in the Ubuntu unity environment.

This is implemented with the evdev Python library on an ELAN touchscreen.

Currently implements 2 types of right click options:
1 finger long touch: Timeout of 1.7 seconds, movement cancels action
2 finger tap: movement cancels action
"""

from evdev import InputDevice, ecodes, UInput, list_devices,AbsInfo
from pymouse import PyMouse
import datetime


class TrackedEvent(object):

	"""
	Class for multitouch event tracking.
	Track position, movement, slots used (total number of fingers in gesture),
	timing of long presses, and event completion.
	"""

	def __init__(self):
		""" Initialize tracking attributes. """
		self.position = {'ABS_X': None, 'ABS_Y': None}
		self.slots = []
		self.fingers = 0
		self.total_event_fingers = 0
		self.discard = 0
		self.moved = 0
		self.track_start = None
		self.click_delay = 1.1

	def add_finger(self, slot):
		"""  Add a detected finger. """
		if slot not in self.slots:
			self.fingers += 1
			self.slots.append(slot)
		if self.total_event_fingers < self.fingers:
			self.total_event_fingers = self.fingers

	def remove_fingers(self):
		""" Remove detected finger upon release. """
		if self.total_event_fingers == self.fingers:
			if self.total_event_fingers == 0:
				self.total_event_fingers = 1
			print('Total Fingers used: ', self.total_event_fingers)
		self.fingers -= 1

		if (self.fingers == 0 and
				self.total_event_fingers == 2 and
				self.moved == 0):
			self._initiate_right_click()

		elif ((self.fingers == 0 or self.fingers == -1) and
				self.total_event_fingers == 1 and
				self.moved == 0):
			self._internal_timing()

		if self.fingers == 0 or self.fingers == -1:
			self.discard = 1

	def position_event(self, event_code, value):
		""" tracks position to track movement of fingers """
		if self.position[event_code] is None:
			self.position[event_code] = value
			#print('position event None-event code, value=',event_code,value)
		else:
			old = self.position[event_code]
			new = value
			diff = old-new
			if abs(diff) > 50:
				self._moved_event()
				print('moved too much')

	def trackit(self):
		""" start timing for long press """
		self.track_start = datetime.datetime.now()

	def _moved_event(self):
		""" movement detected. """
		self.moved = 1  # GV: Initially was 1

	def _internal_timing(self):
		""" Internal method for determining long press time right clicking. """
		if self.track_start is not None:
			elapsed = datetime.datetime.now() - self.track_start
			if elapsed.total_seconds() >= self.click_delay:
				self._initiate_right_click()

	def _initiate_right_click(self):
		""" Internal method for initiating a right click at touch point. """
		'''
		The initial way
		#capabilities = {ecodes.EV_ABS: (ecodes.ABS_X, ecodes.ABS_Y),
		#               ecodes.EV_KEY: (ecodes.BTN_LEFT, ecodes.BTN_RIGHT)}
		'''

		'''
		the correct way
		capab = {
			ecodes.EV_KEY : [ecodes.BTN_LEFT, ecodes.BTN_RIGHT],
			ecodes.EV_ABS : [(ecodes.ABS_X, AbsInfo(value=1900, min=0, max=3264, fuzz=0, flat=0, resolution=13)),
				(ecodes.ABS_Y, AbsInfo(1050, 0, 1856, 0, 0, 13))]
		}

		ui=UInput(capab)
		#ui.write(ecodes.EV_ABS, ecodes.ABS_X, self.position['ABS_X'])
		#ui.write(ecodes.EV_ABS, ecodes.ABS_Y, self.position['ABS_Y'])
		ui.write(ecodes.EV_ABS, ecodes.ABS_X, 0)
		ui.write(ecodes.EV_ABS, ecodes.ABS_Y, 0)
		ui.write(ecodes.EV_KEY, ecodes.BTN_RIGHT, 1)
		ui.write(ecodes.EV_KEY, ecodes.BTN_RIGHT, 0)
		ui.syn()
		ui.close()
		'''
		m = PyMouse()
		x, y = m.position()  # gets mouse current position coordinates
		#m.click(x,y,1)
		#if m.press(x,y,1)==1:
			#print('button1 ',m.press(x,y))
		m.click(x, y, 2)  # the third argument represents the mouse button (1 click,2 right click,3 middle click)
		print('position:', x, y, ':-Right Click injected')

def initiate_gesture_find():
	"""
	This function will scan all input devices until it finds an
	ELAN touchscreen. It will then enter a loop to monitor this device
	without blocking its usage by the system.
	"""
	for device in list_devices():
		dev = InputDevice(device)
		if (dev.name == 'ELAN Touchscreen') or (dev.name == 'Atmel Atmel maXTouch Digitizer'):
			break

	codes = dev.capabilities()
	Abs_events = {}
	for code in codes:
		if code == 3:
			for type_code in codes[code]:
				Abs_events[type_code[0]] = ecodes.ABS[type_code[0]]

	MT_event = None
	for event in dev.read_loop():
		if MT_event:
			if MT_event.discard == 1:
				MT_event = None
		if event.type == ecodes.EV_ABS:
			if MT_event is None:
				MT_event = TrackedEvent()
			event_code = Abs_events[event.code]
			if event_code == 'ABS_MT_SLOT':
				MT_event.add_finger(event.value)
			elif event_code == 'ABS_X' or event_code == 'ABS_Y':
				MT_event.position_event(event_code, event.value)
			elif event_code == 'ABS_MT_TRACKING_ID':
				if event.value == -1:
					MT_event.remove_fingers()
				else:
					MT_event.trackit()

if __name__ == '__main__':
	initiate_gesture_find()
