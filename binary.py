# Python3 code to demonstrate working of 
# Converting String to binary 
# Using join() + bytearray() + format() 
  
# initializing string  
test_str = "Geeks for Geeks"
#test_str = "000111110010111001011101011111001110000011001101101111111001010000010001111100101110010111010111110011"
  
# printing original string  
print("The original string is : " + str(test_str)) 
  
# using join() + bytearray() + format() 
# Converting String to binary 
res = ''.join(format(i, 'b') for i in bytearray(test_str, encoding ='utf-8')) 
  
# printing result  
print("The string after binary conversion : " + str(res)) 

