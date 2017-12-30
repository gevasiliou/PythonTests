#!/usr/bin/env python

import gtk
'''
#this simple 5 lines code just puts an icon to tray with no actions assigned.
statusIcon = gtk.StatusIcon() # create icon object
statusIcon.set_from_file("abp.png") # load it
statusIcon.set_visible(True) #show it
gtk.main() # and run main gtk loop
'''

#Just another test
#http://stackoverflow.com/questions/6782142/pygobject-left-click-menu-on-a-status-icon
#Bellow code gives a menu only a right click menu.  No actions assigned on left click.

class TrayIcon(gtk.StatusIcon):
    def __init__(self):
        gtk.StatusIcon.__init__(self)
        self.set_from_icon_name('help-about')
        self.set_has_tooltip(True)
        self.set_visible(True)
        self.connect("popup_menu", self.on_click)

    def greetme(self,data=None):  # if i ommit the data=none section python complains about too much arguments passed on greetme
        #added by gv , acc to previous example
        msg=gtk.MessageDialog(None, gtk.DIALOG_MODAL,gtk.MESSAGE_INFO, gtk.BUTTONS_OK, "Greetings")
        msg.run()
        msg.destroy()

    def on_click(self, widget, button, time):
        menu = gtk.Menu()
        menu_item1 = gtk.MenuItem("First Entry")
        menu.append(menu_item1)
        menu_item1.connect("activate", self.greetme) #added by gv

        menu_item2 = gtk.MenuItem("Quit")
        menu.append(menu_item2)
        menu_item2.connect("activate", gtk.main_quit)

        menu.show_all()
        #menu.popup(None, None, None, self, 3, time) #this was the original line but is not working.
        menu.popup(None,None,None, 1, time) #modified line - working ok now. The integer 3 if it becomes 1 or 2 makes no difference

if __name__ == '__main__':
    tray = TrayIcon()
    gtk.main()

'''
Explanation on .connect actions / signals according to:https://developer.gnome.org/gtk3/stable/GtkStatusIcon.html#GtkStatusIcon-activate
The entries activate and popup-menu are signal of object GtkStatusIcon
Other signals are button-press-event, button-release-event, scroll-event, etc

'''
