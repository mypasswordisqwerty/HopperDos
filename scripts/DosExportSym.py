import json

doc = Document.getCurrentDocument()
seg = doc.getSegment(0)
sex = [x.getStartingAddress() for x in seg.getSectionsList()]


def secAddr(addr, ofs=None):
    s = max([x for x in sex if x <= addr]) >> 4
    if ofs is None:
        ofs = addr-(s << 4)
    return "{:04X}:{:04X}".format(s, ofs)

out = {}
names = {}
for x in seg.getSectionsList():
    nm = x.getName().split()[-1]
    if nm in names:
        names[nm] += 1
    else:
        names[nm] = 0
    out["__SEG__"+nm+str(names[nm])] = "0x{:04X}".format(x.getStartingAddress() >> 4)

for x in seg.getLabelsList():
    addr = doc.getAddressForName(x)
    out[x] = secAddr(addr)

file = Document.askFile("save symbols", None, True)
with open(file, "w") as f:
    json.dump(out, f, indent=2, separators=(',', ': '))
