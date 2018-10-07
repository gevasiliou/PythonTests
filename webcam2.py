#import numpy as np
import cv2

cap = cv2.VideoCapture(0) #this works ok with local web cam

#cap = cv2.VideoCapture('rtsp://192.168.1.110') #this is ip testing - not working

img_counter = 0

while(True):

    ret, frame = cap.read()
    cv2.imshow('frame',frame)

#    if cv2.waitKey(1) & 0xFF == ord('q'):
#        break

    k = cv2.waitKey(1)

    if k%256 == 27:
        # ESC pressed
        print("Escape hit, closing...")
        break
    elif k%256 == 32:
        # SPACE pressed
        img_name = "opencv_frame_{}.png".format(img_counter)
        cv2.imwrite(img_name, frame)
        print("{} written!".format(img_name))
        img_counter += 1

cap.release()
cv2.destroyAllWindows()
