import pycurl
from StringIO import StringIO
#http://pycurl.io/docs/latest/quickstart.html
buffer = StringIO()
c = pycurl.Curl()
#c.setopt(c.URL, 'http://pycurl.io/')
#c.setopt(c.VERBOSE, True)
c.setopt(c.URL, 'http://pyc.io/')
c.setopt(c.WRITEDATA, buffer)
c.perform()
c.close()

body = buffer.getvalue()
# Body is a string in some encoding.
# In Python 2, we can print it without knowing what the encoding is.
print(body)
