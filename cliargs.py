#https://www.tutorialspoint.com/python/python_command_line_arguments.htm
#https://www.cyberciti.biz/faq/python-command-line-arguments-argv-example/
#http://www.diveintopython.net/scripts_and_streams/command_line_arguments.html
# An example of sending command line arguments to your python program.
import sys
import subprocess
print 'arguments found:', len(sys.argv)
print 'command line arguments', sys.argv
#cmdargs = str(sys.argv)
#try:
if len(sys.argv) > 1:
	if sys.argv[1]=="--debug": #this particulary checks arg1.
		print 'Debug arg recevied in position 1'
		#cmd='echo Debug option selected'
		#q=subprocess.Popen(cmd,shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
		#out = q.communicate()[0]
		#print out
	#if "--debug" or "--dbg" in str(sys.argv): #this works but will catch debug even if it is part of another word (i.e --gtkdebug)
	#	print '--debug arg received somewhere within args' 
	for arg in sys.argv: 
		if arg=="--debug":
			print '--debug arg received somewhere within args'	

else:
	print 'You sent no extra args other than script name=arg[0]'

#except IndexError:
#    pass
