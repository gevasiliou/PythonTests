import pygame #pip install pygame is required first to be run at bash
import pygame.camera
#import Image #used for display only - not needed for caption

from PIL import Image
# pip install pillow
# http://www.pygame.org/docs/tut/CameraIntro.html

pygame.camera.init()
#pygame.camera.list_camera() #Camera detected or not
#cam = pygame.camera.Camera("/dev/video0",(640,480))
cam = pygame.camera.Camera("/dev/video0",(800,600))
cam.start()
img = cam.get_image()
pygame.image.save(img,"filename.jpg")
cam.stop() #can be ommited - cam will be closed when program is finished
#End of Caption

image = Image.open('filename.jpg')
image.show() #this calls imagemagick to display the image
