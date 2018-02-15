def dupl(a):
	#https://docs.python.org/2/tutorial/datastructures.html#nested-list-comprehensions
    b = []
    item = 0
    while item < len(a):
        #print a[item]
#        b.insert(item,a[item]) #works ok
#        b[item] = a[item] #this does not work - b out of range error
        if a.count(a[item]) > 1:
			print item,":",a[item],a.index(a[item])
			del a[item]
			#b.insert(item,a[item])
        item += 1
    print "a=",a
    #print "first duplicate is",a[b[0]], "at position" , b[0] 
a = [1,2,3,3,4,5,6,2]
print "len of a=",len(a),
print "a:" , a
dupl(a)

