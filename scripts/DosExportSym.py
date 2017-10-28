
doc = Document.getCurrentDocument()
seg = doc.getSegment(0)

i = 0
for x in seg.labelList():
    print x
    addr = doc.getAddressByName(x)
    print addr
    i += 1
    if i > 10:
        return

print "running"
