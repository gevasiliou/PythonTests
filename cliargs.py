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
validflags=0
if len(sys.argv) > 1:
	#if sys.argv[1]=="--debug": #this particulary checks arg1.
		#print 'Debug arg recevied in position 1'
		#cmd='echo Debug option selected'
		#q=subprocess.Popen(cmd,shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
		#out = q.communicate()[0]
		#print out
	#if "--debug" or "--dbg" in str(sys.argv): #this works but will catch debug even if it is part of another word (i.e --gtkdebug)
	#	print '--debug arg received somewhere within args' 
	for arg in sys.argv: 
		if arg==sys.argv[0]:
			print "ignoring scripts name"
		elif arg=="--nfr":
			print '--NFR arg received somewhere within args'
			validflags=validflags+1
		elif arg=="--pymouse":	
			print "Pymouse arg received somewhere"
			validflags=validflags+1
		else:
			print arg,"is not a valid arg"
if len(sys.argv)==1 or validflags==0:
		print "No Valid flags sent at all. Default Values will be used"

#except IndexError:
#    pass
