#Rot13 encryption
#Usage: echo "foobar" |python rot13.py
#echo "sbbone" |python rot13.py --decode
#https://docs.python.org/2/library/codecs.html
import codecs, sys

if len(sys.argv) > 1:
    if sys.argv[1]=="--decode": #this particulary checks arg1.Raises an error if no argv[1] exists.
        print('decoding function')
        for line in sys.stdin:
            print(codecs.decode(line, 'rot13'))
        #exit
    if sys.argv[1]=="--help": #Raises an error if no argv[1] exists.
        print('Usage: echo "foobar" |python rot13.py OR echo "sbbone" |python rot13.py --decode')
        #exit
else:
    print('Encoding Function')
    for line in sys.stdin:           #default operation - encodes the input (pipe)
        print(codecs.encode(line, 'rot13'))
