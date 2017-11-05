import json

doc = Document.getCurrentDocument()
seg = doc.getSegment(0)
sex = [x.getStartingAddress() for x in seg.getSectionsList()]

def secAddr(addr):
    s = max([x for x in sex if x <= addr]) >> 4
    return "{:04X}:{:04X}".format(s, addr-(s << 4))

out = {}
for x in seg.getLabelsList():
    addr = doc.getAddressForName(x)
    out[x] = secAddr(addr)

file = Document.askFile("save symbols", None, True)
with open(file, "w") as f:
    json.dump(out, f, indent=2, separators=(',' ,': '))
