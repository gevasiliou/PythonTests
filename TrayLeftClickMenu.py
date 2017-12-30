#!/usr/bin/env python
import pygtk
#pygtk.require('2.0')
import gtk


#Just another test
#http://stackoverflow.com/questions/6782142/pygobject-left-click-menu-on-a-status-icon
#With this code we connect the status icon using "activate" which is only LEFT click.
# As a result, the on_click function is called only with LEFT click.
# No actions assigned in Right Click of gtkstatusicon.


class TrayIcon(gtk.StatusIcon):
    def __init__(self):
        gtk.StatusIcon.__init__(self)
        self.set_from_icon_name('help-about')
        self.set_has_tooltip(True)
        self.set_visible(True)
        self.connect("activate", self.on_click)

    def greetme(self,data=None):  # if i ommit the data=none section python complains about too much arguments passed on greetme

        print ('greetme data',data)
        msg=gtk.MessageDialog(None, gtk.DIALOG_MODAL,gtk.MESSAGE_INFO, gtk.BUTTONS_OK, "Greetings")
        msg.run()
        msg.destroy()

    def on_click(self,data): #data1 and data2 received by the connect action line 23
        print ('self :', self)
        print('data1 :',data)
        event=gtk.get_current_event()
        print('event :',event)
        btn=event.button #this gets the button value of gtk event.
        print('event.button :',btn)
        time=gtk.get_current_event_time() # required by the popup. No time - no popup.
        print ('time:', time)

        menu = gtk.Menu()

        menu_item1 = gtk.MenuItem("First Entry")
        menu.append(menu_item1)
        menu_item1.connect("activate", self.greetme) #added by gv - it had nothing before

        menu_item2 = gtk.MenuItem("Quit")
        menu.append(menu_item2)
        menu_item2.connect("activate", gtk.main_quit)

        menu.show_all()
        menu.popup(None, None, None, btn, time) #button can be hardcoded (i.e 1) but time must be correct.

        '''menu.popup (var1,var2,var3,var4,var5)
        http://developer.gnome.org/ -> search gtkmenu
        http://www.pygtk.org/pygtk2reference/

        Bellow are the python prompts in mismatched data given
        var1: parent_menu_shell - GtkWidget or None
        var2: parent_menu_item - GtkWidget or None
        var3: func - must be a callable object or None
        var4: an integer is required - works with any integer. Acc to pygtk this is "button"
        var5: last argument must be int or long - applied random ints but not work. pygtk=>time
        '''

if __name__ == '__main__':
    print('gtk version:',pygtk._get_available_versions())
    tray = TrayIcon()
    gtk.main()

'''
Explanation on .connect actions / signals according to:
https://developer.gnome.org/gtk3/stable/GtkStatusIcon.html#GtkStatusIcon-activate
The entries activate and popup-menu are signal of object GtkStatusIcon
Other signals are button-press-event, button-release-event, scroll-event, etc
http://www.pygtk.org/pygtk2tutorial/ -> See the example section in the end of the tutorial
'''
