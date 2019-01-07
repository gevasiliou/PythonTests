import pygame, sys
import pygame.camera
from pygame.locals import *
import pygame.mouse
#import pygame.surface #when pygame.mouse is imported we can use surface functions like blit automatically. No idea why.
#https://gist.github.com/stuartwesterman/967046abf8f00756089345edd950b6bc
#pygame.init()
size = (640,480)
pygame.camera.init()

screen = pygame.display.set_mode(size)
cam = pygame.camera.Camera("/dev/video0",size)
cam.start()
pygame.mouse.set_pos(1,1) #moves the mouse in 1,1 of the pygame object (cam window)
#pygame.mouse.set_visible(0) #makes the mouse cursor invisible inside pygame object

while 1:
    print pygame.mouse.get_pos(),pygame.mouse.get_pressed() #prints mouse absolute x,y position inside pygame object (camera window in this case)
    image = cam.get_image()
    screen.blit(image,(0,0)) #blit is defined in pygame.surface
    pygame.display.update()
    for event in pygame.event.get():
        #print event #works nicely. Prints on screen all events like mouse move, keydown, key codes, etc
        #print pygame.event.get() #on the other hand this does NOT work nicely,
        if event.type == pygame.QUIT:
            sys.exit()
        elif event.type == KEYDOWN and event.key == K_s:
            pygame.image.save(image, "filename.jpg") #control+s saves the image

