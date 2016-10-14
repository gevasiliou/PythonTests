#https://www.tutorialspoint.com/python/python_command_line_arguments.htm
# An example of sending command line arguments to your python program.
import sys
import subprocess
print 'arguments found:', len(sys.argv)
print 'command line arguments', sys.argv
try:
    if sys.argv[1]=="--debug":
        #print 'Debug option selected'
        cmd='echo Debug option selected'
        q=subprocess.Popen(cmd,shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = q.communicate()[0]
        print out
    else:
        print 'You sent something else'

except IndexError:
    pass


