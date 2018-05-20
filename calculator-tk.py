from tkinter import *
from tkinter import messagebox
from math import *
#apt install python3-tk && apt install python-tk
#in python 2 (run as python) tkinter needs capital T : import Tkinter
calculator = Tk()
calculator.title("CALCULATOR")
calculator.resizable(0, 1)#remove or change this in order to get different screen sizes
fgc = "black" #button foreground color
bgc = "gray" #button background color
bow = 5 #button borderwidth value
fh = 44  #button font height
wv = 4 #button width value given in text units == chars. If ommitted width is auto adjusted.
rlf = "raised" #button relief value. Options: flat, groove, raised (default when ommitted), ridge, solid, or sunken

class Application(Frame):
	def __init__(self, master, *args, **kwargs):
		Frame.__init__(self, master, *args, **kwargs)
		self.createWidgets()

	def replaceText(self, text):
		self.display.delete(0, END)
		self.display.insert(0, text)

	def delText(self):
		self.display.delete(len(self.display.get())-1)
		
	def appendToDisplay(self, text):
		self.entryText = self.display.get()
		self.textLength = len(self.entryText)

		if self.entryText == "0":
			self.replaceText(text)
		else:
			self.display.insert(self.textLength, text)

	def calculateExpression(self):#python's calculate function 
		self.expression = self.display.get()
		self.expression = self.expression.replace("%", "/ 100")
		self.expression = self.expression.replace("^", "**")
		try:
			self.result = eval(self.expression)
			self.replaceText(self.result)
		except:
			messagebox.showinfo("ERROR", "Invalid input", icon="warning", parent=calculator)
#Another Test
	def SqrtExpression(self):#python's calculate function 
		self.expression = self.display.get()
#		print(sqrt(eval(self.expression))) #prints to stdout for troubleshooting
		try:
			self.result = sqrt(eval(self.expression)) #eval is required because display.get returns the display as text and not as number
			#sqrt is a function from math library. You could import math and then use math.sqrt
			self.replaceText(self.result)
		except:
			messagebox.showinfo("ERROR", "Invalid input", icon="warning", parent=calculator)
#End  of Test

	def clearText(self):#clears imput on pressing C on Calculator
		self.replaceText("0")
	def createWidgets(self):
	#http://effbot.org/tkinterbook/entry.htm
		self.display = Entry(self, font=("Helvetica", fh+int(fh/2)), borderwidth=bow,  fg=fgc, bg=bgc, relief=RAISED, justify=RIGHT)
		self.display.insert(0, "0")
		self.display.grid(row=0, column=0, columnspan=5) #columnspan=number of columns

#This is the First Row
#http://effbot.org/tkinterbook/button.htm
		self.DelButton = Button(self, font=("Helvetica", fh), text="<--", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.delText()) #command=lambda: exit())
		self.DelButton.grid(row=1, column=3, sticky="NWNESWSE")
		
		self.ExitButton = Button(self, font=("Helvetica", fh), text="exit", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: exit())
		self.ExitButton.grid(row=1, column=4, sticky="NWNESWSE")

#second row
		self.sevenButton = Button(self, font=("Helvetica", fh), text="7", borderwidth=bow, width=wv, fg=fgc, bg=bgc,  command=lambda: self.appendToDisplay("7"))
		self.sevenButton.grid(row=2, column=0, sticky="NWNESWSE")

		self.eightButton = Button(self, font=("Helvetica", fh), text="8", borderwidth=bow, width=wv, fg=fgc, bg=bgc, relief=rlf, command=lambda: self.appendToDisplay("8"))
		self.eightButton.grid(row=2, column=1, sticky="NWNESWSE")

		self.nineButton = Button(self, font=("Helvetica", fh), text="9", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("9"))
		self.nineButton.grid(row=2, column=2, sticky="NWNESWSE")

		self.timesButton = Button(self, font=("Helvetica", fh), text="*", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("*"))
		self.timesButton.grid(row=2, column=3, sticky="NWNESWSE")

		self.clearButton = Button(self, font=("Helvetica", fh), text="C", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.clearText())
		self.clearButton.grid(row=2, column=4, sticky="NWNESWSE")

#This is the third Row
		self.fourButton = Button(self, font=("Helvetica", fh), text="4", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("4"))
		self.fourButton.grid(row=3, column=0, sticky="NWNESWSE")

		self.fiveButton = Button(self, font=("Helvetica", fh), text="5", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("5"))
		self.fiveButton.grid(row=3, column=1, sticky="NWNESWSE")

		self.sixButton = Button(self, font=("Helvetica", fh), text="6", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("6"))
		self.sixButton.grid(row=3, column=2, sticky="NWNESWSE")

		self.divideButton = Button(self, font=("Helvetica", fh), text="/", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("/"))
		self.divideButton.grid(row=3, column=3, sticky="NWNESWSE")

		self.percentageButton = Button(self, font=("Helvetica", fh), text="%", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("%"))
		self.percentageButton.grid(row=3, column=4, sticky="NWNESWSE")

#This is the fourth Row
		self.oneButton = Button(self, font=("Helvetica", fh), text="1", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("1"))
		self.oneButton.grid(row=4, column=0, sticky="NWNESWSE")

		self.twoButton = Button(self, font=("Helvetica", fh), text="2", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("2"))
		self.twoButton.grid(row=4, column=1, sticky="NWNESWSE")

		self.threeButton = Button(self, font=("Helvetica", fh), text="3", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("3"))
		self.threeButton.grid(row=4, column=2, sticky="NWNESWSE")

		self.minusButton = Button(self, font=("Helvetica", fh), text="-", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("-"))
		self.minusButton.grid(row=4, column=3, sticky="NWNESWSE")

		self.equalsButton = Button(self, font=("Helvetica", fh), text="=", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.calculateExpression())
		self.equalsButton.grid(row=4, column=4, sticky="NWNESWSE", rowspan=3)

#This is the fifth Row
		self.zeroButton = Button(self, font=("Helvetica", fh), text="0", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("0"))
		self.zeroButton.grid(row=5, column=0, columnspan=2, sticky="NWNESWSE") #columnspan here determines how many columns the button will occupy

		self.dotButton = Button(self, font=("Helvetica", fh), text=".", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("."))
		self.dotButton.grid(row=5, column=2, sticky="NWNESWSE")

		self.plusButton = Button(self, font=("Helvetica", fh), text="+", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("+"))
		self.plusButton.grid(row=5, column=3, sticky="NWNESWSE")

#This is the sixth Row
		self.LeftParButton = Button(self, font=("Helvetica", fh), text="(", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("("))
		self.LeftParButton.grid(row=6, column=0, sticky="NWNESWSE")

		self.RightParButton = Button(self, font=("Helvetica", fh), text=")", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay(")"))
		self.RightParButton.grid(row=6, column=1, sticky="NWNESWSE")

		self.PowButton = Button(self, font=("Helvetica", fh), text="x^y", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.appendToDisplay("^"))
		self.PowButton.grid(row=6, column=2, sticky="NWNESWSE")

		self.SqrtButton = Button(self, font=("Helvetica", fh), text="sqrt", borderwidth=bow, width=wv, fg=fgc, bg=bgc, command=lambda: self.SqrtExpression()) #command=lambda: self.calculateExpression())
		self.SqrtButton.grid(row=6, column=3, sticky="NWNESWSE")
		

app = Application(calculator).grid()		
calculator.mainloop()
