# PythonTests
Here i keep some personal testing files about Python 2.7.12 in Debian 8.5 Sid + XFCE


Click.py : A draft file demonstrating mouse movement and right click on touchscreen with the use of python pymouse.

devlist:py : A draft file printing out capabilities of all devices found under /dev/input/event

uninput-click.py: A draft injecting right click using python-evdev on ELAN Touchscreen. 

uinput-click-vbox: Similar as the above but adjusted to work in vbox machine (input device set as VBox Tablet at VBox settings)

rightclick.py: The zyell script with modifications and testing.

anotheruitest.py : Inject a right click using uinput combined with REL type instead of ABS type.

RightClick.py: The modified fork of Zyell initiall script, using PyMouse instead of uinput.

RightClick v3.py: Latest Release of Zyell Touchscreen Right Click script.
(https://github.com/Zyell/Python-Touchscreen-RightClick)

This script works nice with ELAN TouchScreen , providing right click support on touchscreens , when Desktop Environments and Xserver fails to do so.
Tested on Debian 8.5 Sid + XFCE 4.12 with ELAN TouchScreen (Toshiba Radius 11) and works fine
In this latest release of script, right click menu pops up after the necessary time, without the need of user to release it's finger from the screen. 

This modifications may includes some personal experiments, like the use of PyMouse to inject right click instead of Zyell UInput method.
(PyMouse worked better for me).

Tkinter files : Test files to play with tkinter.

TrayRightClickMenu.py : Script using PyGTK to create a tray icon and provide a default popup menu in right click.

TrayLeftClickMenu.py : Script using PyGTK to create a tray icon and provide tray icon default popup menu in left click

TrayAllClicksMenu.py : Script using PyGTK to create a tray icon and provide a default popup menu in all mouse clicks (left-right-middle).
Default popup menu : You don't need to "design" the menu from the very beginning. You just add the items on the menu.

TrayTypical: A typical tray icon using PyGTK. Pops up the default popup menu on right click and executes a default click action on left click.

Autorot.sh -> a bash shell script that provides autorotate capabilities in modern laptops. Based on the iio-sensor-proxy and inotify tools . Should work with any accelerometer that is recognized by iio-sensor-proxy.

gtkmenu.py -> a sample from pygtk tutorial, building a small gtk window / menu.
