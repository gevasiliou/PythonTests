#!/usr/bin/env python
import pygtk
#pygtk.require('2.0')
import gtk
statusIcon = gtk.StatusIcon() # create icon object
statusIcon.set_from_file("abp.png") # load it
statusIcon.set_visible(True) #show it
gtk.main() # and run main gtk loop
