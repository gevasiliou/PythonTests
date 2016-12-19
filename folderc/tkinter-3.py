#https://wiki.python.org/moin/Intro%20to%20programming%20with%20Python%20and%20Tkinter
#https://docs.python.org/2/library/tkinter.html

from Tkinter import *           # Import all (*) from Tkinter library
root = Tk()                    # Create a background window object
                                # A simple way to create 2 lists
li     = ['Carl','Patrick','Lindsay','Helmut','Chris','Gwen']
movie  = ['God Father','Beauty and the Beast','Brave heart']
listb  = Listbox(root)          # Create 2 listbox widgets
listb2 = Listbox(root)
for item in li:                 # Insert each item inside li into the listb
    listb.insert(0,item)

for item in movie:              # Do the same for the second listbox
    listb2.insert(0,item)

listb.pack()                    # Pack each listbox into the main window
listb2.pack()
root.mainloop()                 # Invoke the main event handling loop
