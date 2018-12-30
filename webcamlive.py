import pygame, sys
import pygame.camera
from pygame.locals import *
#https://gist.github.com/stuartwesterman/967046abf8f00756089345edd950b6bc
#pygame.init()
size = (640,480)
pygame.camera.init()

screen = pygame.display.set_mode(size)
cam = pygame.camera.Camera("/dev/video0",size)
cam.start()

while 1:
    image = cam.get_image()
    screen.blit(image,(0,0))
    pygame.display.update()
    for event in pygame.event.get():
        print event #works nicely. Prints on screen all events like mouse move, keydown, key codes, etc
        #print pygame.event.get() #on the other hand this does NOT work nicely,
        if event.type == pygame.QUIT:
            sys.exit()
        elif event.type == KEYDOWN and event.key == K_s:
            pygame.image.save(image, "filename.jpg") #control+s saves the image

