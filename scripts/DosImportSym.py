import json

file = Document.askFile("load symbols", None, False)
with open(file) as f:
    nms = json.load(f)

doc = Document.getCurrentDocument()

for x in nms:
    adr = nms[x].split(':')
    if len(adr) != 2:
        continue
    lin = (int(adr[0], 16) << 4) + int(adr[1], 16)
    doc.setNameAtAddress(lin, x)
