from turtle import *
import turtle
 
def f(length, depth):
   if depth == 0:
     forward(length)
   else:
     f(length/3, depth-1)
     right(60)
     left(100)
     f(length/3, depth-1)
     left(120)
     f(length/3, depth-1)
     right(60)
     f(length/3, depth-1)
 
#f(500, 4)
def koch(depth, size):
    if depth == 0:
        forward(size)
    else:
        recurse = lambda: koch(depth-1, size/3)
        recurse()
        left(60)
        recurse()
        right(120)
        recurse()
        left(60)
        recurse()
 
#koch(3, 3**4)

# wget -O - https://gist.githubusercontent.com/viebel/5349bcca144c41b8f83af39079bf59ad/raw/ef08933521c26b4555f76bc0d9ad3d9ba8d0eaf7/hilbert%2520fractal.py |python
	 
def circ():
    window = turtle.Screen()
    window.bgcolor("yellow")
    b = turtle.Turtle()
    b.speed(150)
    b.width(width=1)
    b.shape('turtle')
    b.color('blue')
    d = 5
    angle = 145
    for i in range(1, 580):
        b.forward(d)
        b.left(angle)
        b.circle(40 + d / 7)
        d -= 3
    window.exitonclick()

    
circ()
