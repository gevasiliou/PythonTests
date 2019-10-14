#!/usr/bin/env python

import codecs, sys
from pycipher import *


if len(sys.argv) > 1 and sys.argv[1] == "--decode":
	for line in sys.stdin:
		d=Enigma(settings=('A','A','A'),rotors=(1,2,3),reflector='B', ringstellung=('F','V','N'),steckers=[('P','O'),('M','L'),('I','U'),('K','J'),('N','H'),('Y','T'),('G','B'),('V','F'),('R','E'),('D','C')]).decipher(line)
		print d
		print 'Gronsfeld'
		ee=Gronsfeld([4,5,3,2,9]).decipher(line)
		print ee
		print 'Railfence'
		plaintext = Railfence(3).decipher(line)
		print plaintext 
else:
	for line in sys.stdin:
		e=Enigma(settings=('A','A','A'),rotors=(1,2,3),reflector='B', ringstellung=('F','V','N'),steckers=[('P','O'),('M','L'),('I','U'),('K','J'),('N','H'),('Y','T'),('G','B'),('V','F'),('R','E'),('D','C')]).encipher(line)
		print e

