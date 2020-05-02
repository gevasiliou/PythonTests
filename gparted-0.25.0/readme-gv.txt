01 May 2020
Install gparted version 0.25 to Debian 10, in parallel to the existed installation of gparted 1.0.0 (installed with apt-get install gparted)

Why version 0.25?
In some cases (usb sticks like kali live usb) garted 1.0.0 fails to correctly determin the partitions of /dev/sdb
For example kali usb using gparted 1.0 advises that whole /dev/sdb (3.7GB) is occupied by Kali Live

Using version 0.25 , partitions in kali usb are detected correctly (2GB occupied by Kali - 1,5GB not allocated)
This behavior works up to version 0.28

How to correctly install gparted-0.25 from source 
0. Download https://sourceforge.net/projects/gparted/files/gparted/gparted-0.25.0/
1. apt-get build-dep gparted
2. apt-get install build-essential e2fsprogs uuid uuid-dev gnome-common libparted-dev libgtkmm-2.4-dev libdevmapper-dev gnome-doc-utils docbook-xml
3. inside gparted 0.25 folder run ./configure --enable-libparted-dmraid --enable-online-resize
4. if you have problems with scrollkeeper then run instead ./configure --disable-scrollkeeper --enable-libparted-dmraid --enable-online-resize
5. make
6. make install as root (basically i did all the steps as root)
7. Run it inside gparted-0.25 directory using ./gparted
8. In case of error about missing gpartedbin file under /usr/local/sbin then run cp ./src/gpartedbin /usr/local/sbin/gpartedbin inside gparted-0.25 directory 
9. Now everything should be ok , just run again ./gparted

Tip:
You can copy this new gparted file in /usr/local/sbin using a different name like gparted025 : cp gparted /usr/local/sbin/gparted025
From now on:
By running gparted under any root terminal the apt-get installed garted version 1.0.0 will be called.
By running gparted025 in root terminal the old gparted-0.25 will be called. (tested and works fine)
Similarily you can copy the generated gparted.desktop to /usr/share/applications folder, after renaming it to gparted25.desktop
Change also the Description texts / comments and adjust exec entry to call the correct file = gparted025 and everything works fine 
