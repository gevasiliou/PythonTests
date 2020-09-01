#!/usr/bin/env python
# THE BEERWARE LICENSE (Revision 42):
# <thenoviceoof> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you
# think this stuff is worth it, you can buy me a beer in return
# - Nathan Hwang (thenoviceoof)
from __future__ import print_function #to take advantage of Python3 print function with customized end of line
import sys
import math

__version__ = (1, 0, 3)

def base92_chr(val):
    '''
    Map an integer value <91 to a char

    >>> base92_chr(0)
    '!'
    >>> base92_chr(1)
    '#'
    >>> base92_chr(61)
    '_'
    >>> base92_chr(62)
    'a'
    >>> base92_chr(90)
    '}'
    >>> base92_chr(91)
    Traceback (most recent call last):
        ...
    ValueError: val must be in [0, 91)
    '''
    if val < 0 or val >= 91:
        raise ValueError('val must be in [0, 91)')
    if val == 0:
        return '!'
    elif val <= 61:
        return chr(ord('#') + val - 1)
    else:
        return chr(ord('a') + val - 62)

def base92_ord(val):
    num = ord(val)
    if val == '!':
        return 0
    elif ord('#') <= num and num <= ord('_'):
        return num - ord('#') + 1
    elif ord('a') <= num and num <= ord('}'):
        return num - ord('a') + 62
    else:
        #print('val now is', val)
        raise ValueError(val,'is not a base92 character')

def base92_encode(bytstr):
    # always encode *something*, in case we need to avoid empty strings
    if not bytstr:
        return '~'
    # make sure we have a bytstr
    if not isinstance(bytstr, basestring):
        # we'll assume it's a sequence of ints
        bytstr = ''.join([chr(b) for b in bytstr])
    # prime the pump
    bitstr = ''
    while len(bitstr) < 13 and bytstr:
        bitstr += '{:08b}'.format(ord(bytstr[0]))
        bytstr = bytstr[1:]
    resstr = ''
    while len(bitstr) > 13 or bytstr:
        i = int(bitstr[:13], 2)
        resstr += base92_chr(i / 91)
        resstr += base92_chr(i % 91)
        bitstr = bitstr[13:]
        while len(bitstr) < 13 and bytstr:
            bitstr += '{:08b}'.format(ord(bytstr[0]))
            bytstr = bytstr[1:]
    if bitstr:
        if len(bitstr) < 7:
            bitstr += '0' * (6 - len(bitstr))
            resstr += base92_chr(int(bitstr,2))
        else:
            bitstr += '0' * (13 - len(bitstr))
            i = int(bitstr, 2)
            resstr += base92_chr(i / 91)
            resstr += base92_chr(i % 91)
    return resstr

def base92_decode(bstr):
    bitstr = ''
    resstr = ''
    if bstr == '~':
        return ''
    # we always have pairs of characters
    for i in range(len(bstr)/2):
        x = base92_ord(bstr[2*i])*91 + base92_ord(bstr[2*i+1])
        bitstr += '{:013b}'.format(x)
        while 8 <= len(bitstr):
            resstr += chr(int(bitstr[0:8], 2))
            bitstr = bitstr[8:]
    # if we have an extra char, check for extras
    if len(bstr) % 2 == 1:
        x = base92_ord(bstr[-1])
        bitstr += '{:06b}'.format(x)
        while 8 <= len(bitstr):
            resstr += chr(int(bitstr[0:8], 2))
            bitstr = bitstr[8:]
    return resstr

encode = base92_encode
b92encode = base92_encode

decode = base92_decode
b92decode = base92_decode

if __name__ == "__main__":
    if len(sys.argv) > 1: 
        if sys.argv[1]=="--help":
            print('This script can be used only with pipe. echo "hello" |base92gv.py or echo "hello" |base92gv.py --decode', end="\n")
        if sys.argv[1]=="--decode": #this particulary checks arg1.Raises an error if no argv[1] exists.
            for line in sys.stdin:
                #print line
                d=decode(line)
                print(d, end="") #end of line="" instead of new line. Decode of base92.py can not handle \n
        exit() 
    
    for line in sys.stdin:
        e=encode(line)
        print(e, end="")

'''
    import doctest
    doctest.testmod()

    ## more correctness tests
    import hashlib
    import random
    def gen_bytes(s):
        return hashlib.sha512(s).digest()[:random.randint(1,64)]
    for i in range(10000):
        s = gen_bytes(str(random.random()))
        assert s == decode(encode(s))
    print('correctness spot check passed')

'''
