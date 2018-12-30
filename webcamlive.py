import pygame, sys
import pygame.camera
#from pygame.locals import *

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
        if event.type == pygame.QUIT:
            sys.exit()

