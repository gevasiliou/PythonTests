import cv2
import numpy as np
import sys
#pip3 install opencv-python numpy
#https://www.thepythoncode.com/article/hide-secret-data-in-images-using-steganography-python?fbclid=IwAR2RC24BMuSDxzNU8_2djjKRmg_NQU5cX4WFdgCITXqbYw8RRGOEnSjvyHk

def to_bin(data):
    """Convert `data` to binary format as string"""
    if isinstance(data, str):
        return ''.join([ format(ord(i), "08b") for i in data ])
    elif isinstance(data, bytes) or isinstance(data, np.ndarray):
        return [ format(i, "08b") for i in data ]
    elif isinstance(data, int) or isinstance(data, np.uint8):
        return format(data, "08b")
    else:
        raise TypeError("Type not supported.")


def encode(image_name, secret_data):
    # read the image
    print("function encode, proceed with",image_name,",secret dara:",secret_data)
    image = cv2.imread(image_name) #image should be png with RGB. Don't rely on image extension. Verify that you deal with a real PNG using dile myimage.png. 
    #print("image:",image)  #unquote for debuging
    # maximum bytes to encode
    n_bytes = image.shape[0] * image.shape[1] * 3 // 8
    print("[*] Maximum bytes to encode:", n_bytes)
    if len(secret_data) > n_bytes:
        raise ValueError("[!] Insufficient bytes, need bigger image or less data.")
    print("[*] Encoding data...")
    # add stopping criteria
    secret_data += "====="
    data_index = 0
    # convert data to binary
    binary_secret_data = to_bin(secret_data)
    # size of data to hide
    data_len = len(binary_secret_data)
    
    for row in image:
        for pixel in row:
            # convert RGB values to binary format
            r, g, b = to_bin(pixel)
            # modify the least significant bit only if there is still data to store
            if data_index < data_len:
                # least significant red pixel bit
                pixel[0] = int(r[:-1] + binary_secret_data[data_index], 2)
                data_index += 1
            if data_index < data_len:
                # least significant green pixel bit
                pixel[1] = int(g[:-1] + binary_secret_data[data_index], 2)
                data_index += 1
            if data_index < data_len:
                # least significant blue pixel bit
                pixel[2] = int(b[:-1] + binary_secret_data[data_index], 2)
                data_index += 1
            # if data is encoded, just break out of the loop
            if data_index >= data_len:
                break
    return image


def decode(image_name):
    print("[+] Decoding...")
    # read the image
    image = cv2.imread(image_name)
    #print('image:',image)
    binary_data = ""
    for row in image:
        for pixel in row:
            r, g, b = to_bin(pixel)
            binary_data += r[-1]
            binary_data += g[-1]
            binary_data += b[-1]

    # split by 8-bits
    all_bytes = [ binary_data[i: i+8] for i in range(0, len(binary_data), 8) ]
    # convert from bits to characters
    decoded_data = ""
    for byte in all_bytes:
        decoded_data += chr(int(byte, 2))
        if decoded_data[-5:] == "=====":
            break
    return decoded_data[:-5]


if __name__ == "__main__":
	if len(sys.argv) > 1:
		if sys.argv[1]=="--encode":
			input_image = sys.argv[2]
			output_image = f"encoded_{input_image}"
			secret_data = sys.argv[3]
			# encode the data into the image
			print("data to encode:",secret_data, "into image",input_image, "with new name:",output_image)
			#encoded_image = encode(image_name=input_image, secret_data=secret_data)
			encoded_image = encode(input_image, secret_data)
			# save the output image (encoded image)
			cv2.imwrite(output_image, encoded_image)
		if sys.argv[1]=="--decode":
			#input_image = sys.argv[2]
			#output_image = f"encoded_{input_image}"
			output_image = sys.argv[2]
			print("Image to decode:",output_image)
			# decode the secret data from the image
			decoded_data = decode(output_image)
			print("[+] Decoded data:", decoded_data)
	else:
		print("usage : python3 steganography.py --encode <img> <secret message> or --decode <img>")

"""
#What is Steganography
#Steganography is the practice of hiding a file, message, image or video within another file, message, image or video. The word steganography is derived from the Greek words steganos (meaning hidden or covered) and graphe (meaning writing).
#
#It is often used among hackers to hide secret messages or data within media files such as images, videos or audio files. Even though there are many legitimate uses for Steganography such as watermarking, malware programmers have also been found to use it to obscure the transmission of malicious code.
#
#In this tutorial, we gonna write a Python code to hide text messages using a technique called Least Significant Bit.
#
#What is Least Significant Bit
#Least Significant Bit (LSB) is a technique in which last bit of each pixel is modified and replaced with the data bit. This method only works on Lossless-compression images, which means that the files are stored in a compressed format, but that this compression does not result in the data being lost or modified, PNG, TIFF, and BMP as an example, are lossless-compression image file formats.
#
#As you may already know, an image consists of several pixels, each pixel contains three values (which are Red, Green, Blue), these values range from 0 to 255, in other words, they are 8-bit values. For example, a value of 225 is 11100001 in binary and so on.
#
#Let's take an example of how this technique works, say I want to hide the message "hi" into a 4x4 image, here are the example image pixel values:
#
#[(225, 12, 99), (155, 2, 50), (99, 51, 15), (15, 55, 22),
#(155, 61, 87), (63, 30, 17), (1, 55, 19), (99, 81, 66),
#(219, 77, 91), (69, 39, 50), (18, 200, 33), (25, 54, 190)]
#By looking at the ASCII Table, we can convert this message into decimal values and then into binary:
#
#0110100 0110101
#Now, we iterate over the pixel values one by one, after converting them to binary, we replace each least significant bit with that message bits sequentially (e.g 225 is 11100001, we replace the last bit, the bit in the right (1) with the first data bit (0) and so on).
#
#This will only modify the pixel values by +1 or -1 which is not noticable at all, you can use 2-Least Significant Bits too which will modify the pixels by a range of -3 to +3.
#
#Here is the resulting pixel values (you can check them on your own):
#
#[(224, 13, 99),(154, 3, 50),(98, 50, 15),(15, 54, 23),
#(154, 61, 87),(63, 30, 17),(1, 55, 19),(99, 81, 66),
#(219, 77, 91),(69, 39, 50),(18, 200, 33),(25, 54, 190)]
#Python Implementation
#Now that we understand the technique we gonna use, let's dive in to the Python implementation, we gonna use OpenCV to manipulate the image, you can use any other imaging library you want (such as PIL): 
"""
