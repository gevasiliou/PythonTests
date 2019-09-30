#!/usr/bin/env python
#Rot13 encryption
#Usage: echo "foobar" |python rot13.py
#echo "sbbone" |python rot13.py --decode
#https://docs.python.org/2/library/codecs.html
import codecs, sys, base64 
#myline = b'one'

if len(sys.argv) > 1:
    if sys.argv[1]=="--base64": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            print(base64.b64encode(line))

    if sys.argv[1]=="--base32": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            print(base64.b32encode(line))

    if sys.argv[1]=="--base16": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            print(base64.b16encode(line))

    if sys.argv[1]=="--base85": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            s = line
            b = s.encode("UTF-8")   # Encoding the string into bytes
            e = base64.b85encode(b) # Base85 Encode the bytes
            s1 = e.decode("UTF-8")  # Decoding the Base85 bytes to string
            print(s1) # Printing Base85 encoded string

    if sys.argv[1]=="--ascii85": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            s = line
            b = s.encode("UTF-8")   # Encoding the string into bytes
            e = base64.a85encode(b) # Base85 Encode the bytes
            s1 = e.decode("UTF-8")  # Decoding the Base85 bytes to string
            print(s1) # Printing Base85 encoded string

#Decode Functions-----------------------------------------------------------------------------------------#
    if sys.argv[1]=="--decodebase64": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            print("b64decode")
            print(base64.b64decode(line))
            print("")
            print("standard_b64decode")
            print(base64.standard_b64decode(line))
            print("")
            print("urlsafe_b64decode")
            print(base64.urlsafe_b64decode(line))
    if sys.argv[1]=="--decodebase32": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            print(base64.b32decode(line))

    if sys.argv[1]=="--decodebase16": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            print(base64.b16decode(line))

    if sys.argv[1]=="--decodebase85": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            s1 = line
            b1 = s1.encode("UTF-8")      # Encoding the Base85 encoded string into bytes
            d = base64.b85decode(b1)     # Decoding the Base85 bytes
            s2 = d.decode("UTF-8")       # Decoding the bytes to string
            print(s2)

    if sys.argv[1]=="--decodeascii85": #this particulary checks arg1.Raises an error if no argv[1] exists.
        for line in sys.stdin:
            s1 = line
            b1 = s1.encode("UTF-8")      # Encoding the Base85 encoded string into bytes
            d = base64.a85decode(b1)     # Decoding the Base85 bytes
            s2 = d.decode("UTF-8")       # Decoding the bytes to string
            print(s2)

    if sys.argv[1]=="--help": #Raises an error if no argv[1] exists.
        print('Usage: --base64 --base32 --base16 --base85 --ascii85 --decodebase64 --decodebase32 --decodebase16 --decodebase85 --decodeascii85')
        #exit
#else:
#    print('Encoding Function')
#    for line in sys.stdin:           #default operation - encodes the input (pipe)
#        print(codecs.encode(line, 'rot13'))
