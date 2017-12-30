from music21 import *

environment.set("musicxmlPath", "/usr/bin/musescore")

#music21.environment.set("musicxmlPath", "/usr/bin/musescore")

converter.parse("tinynotation: 3/4 c4 d8 f g16 a g f#").show()

'''
n1 = note.Note('e4')
n1.duration.type = 'whole'
n2 = note.Note('d4')
n2.duration.type = 'whole'
m1 = stream.Measure()
m2 = stream.Measure()
m1.append(n1)
m2.append(n2)
partLower = stream.Part()
partLower.append(m1)
partLower.append(m2)
partLower.show() 
'''
