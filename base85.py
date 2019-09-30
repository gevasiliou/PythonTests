import base64,sys

for line in sys.stdin:
	if len(sys.argv) > 1:
		if sys.argv[1]=="--decode": 
			s1 = line #by gv
			b1 = s1.encode("UTF-8")      # Encoding the Base85 encoded string into bytes
			d = base64.b85decode(b1)     # Decoding the Base85 bytes
			s2 = d.decode("UTF-8")       # Decoding the bytes to string
			print(s2)
	else:
		s = line
		b = s.encode("UTF-8")   # Encoding the string into bytes
		e = base64.b85encode(b) # Base85 Encode the bytes
		s1 = e.decode("UTF-8")  # Decoding the Base85 bytes to string
		print(s1) # Printing Base85 encoded string

#Tip: Base85 doesn't like new lines. From shell use either printf without \n or use echo -n (suppress new lines)
