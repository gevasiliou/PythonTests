#!/usr/bin/python
#https://www.tutorialspoint.com/python/python_functions.htm
#https://www.tutorialspoint.com/python/python_files_io.htm
def printinfo( name, age ):
   "This prints a passed info into this function"
   print "Name: ", name
   print "Age ", age
   return;


def addnumbers ( arg1, arg2):
   "This prints a passed info into this function"
   print "Arg1: ", arg1
   print "Arg2: ", arg2
   arg33=arg1+arg2
   arg44=arg33+100
   print "Sum Arg3: ",arg33
   return arg33,arg44;

sum = lambda arg1, arg2: arg1 + arg2;


Money = 2000
def AddMoney():
   # Uncomment the following line to fix the code. If not Python will consider money as undefined local var.
   global Money
   Money = Money + 199

printinfo( age=50, name="miki" )
printinfo( 50, "miki" )
total,multi=addnumbers(10,4)
#total,multi,rest=addnumbers(10,4) this giver error since function returns two vars
print "Total Sum - outside function: ",total,"+100=",multi
print "Value of total using lambda : ", sum( 10, 20 )
print "Money=",Money
AddMoney()
print "Money added. New Money:",Money
