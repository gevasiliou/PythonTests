#
Advanced Find

Use select files form

options:
search for folders only & checkbox display files in folder found
search multiple directories
exclude directories from search (either by selecting particular directory or by entering directory pattern)

search files only (find -type f) 
exlude file extensions # find / -name gnome-mines -type f -executable |egrep -v 'help|icon|locale'
use extensions patterns (*.txt or *.py or .... ) 

search files and folders using patterns
search executable files only (-executable) using patterns

Check box "save this search profile"
Button "load saved search profile"
Check Box "use locate instead of find"
Button "remove file" - with confirmation
Search for files based on dates /size range
Search applications -> call the appslist.sh script


Display Find Results
Results include filename, path, directory, executable attribute, owner
checkbox of a result and give options exclude folder, exclude extension 
dpkg information (pop up window with dpkg -S or -L or both)
installation info (manual, automatc, date installed, source package, versions, )
run the file (if it is executable) and maybe mark file as executable
view the file (editor if text, viewer if image/icon, etc)
copy / move selected files to another directory
save results to file

tips:
provide pulsating progress bars during find


