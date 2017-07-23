#!/usr/bin/env python
import sys
import getopt
import os
import json
from collections import OrderedDict


class App:
    MODE_INIT = -1
    MODE_WAIT = 0
    MODE_INT = 1
    MODE_PARAMS = 2
    CATS = "BCDEHMSTV"
    HEX = "0123456789ABCDEF"

    def __init__(self):
        self.mode = self.MODE_WAIT
        self.curInt = None
        self.path = None

    def ishex(self, string):
        for x in string:
            if not x in self.HEX:
                return False
        return True

    def wait(self, line, obj):
        if not line.startswith("--------"):
            return
        if len(line) < 9 or line[8] not in self.CATS:
            return
        self.mode = self.MODE_INT

    def saveInt(self, obj):
        self.mode = self.MODE_WAIT
        if not self.curInt:
            return
        o = self.curInt
        self.curInt = None
        i = o['int']
        if i.endswith('h'):
            i = i[:-1]
        if o['cond'] is None:
            if i not in obj:
                obj[i] = {'name': o['name'] + o['params']}
            return
        if i not in obj or isinstance(obj[i], basestring):
            obj[i] = {}
        reg = o['cond'][0]
        if reg not in obj[i]:
            obj[i][reg] = OrderedDict()
        val = o['cond'][1]
        obj[i][reg][val] = (o['name'] + "\n" + o['params']).strip().replace("\r\n\n", "\n")

    def readInt(self, line, obj):
        if not line.startswith("INT "):
            self.saveInt(obj)
            return
        words = line.split()
        inter = words[1]
        self.curInt = {'int': inter, 'name': '-'.join(line.split('-')[1:]).strip(), 'cond': None, 'params': ""}
        self.mode = self.MODE_PARAMS

    def params(self, line, obj):
        if not self.curInt or (line[0] != "\t" and line.split(':')[0] != "Return"):
            self.saveInt(obj)
            return
        if len(self.curInt['params']) == 0:
            while True:
                if self.curInt['cond'] is not None or line[0] != '\t':
                    break
                words = line.split()
                if len(words) != 3:
                    break
                val = words[2]
                if val.endswith('h'):
                    val = val[:-1]
                if words[1] != '=' or not self.ishex(val):
                    break
                self.curInt['cond'] = (words[0], val)
                return
            self.curInt['params'] = line
        else:
            self.curInt['params'] += "\n" + line

    def parseInts(self, line, obj):
        if line is None:
            with open(os.path.join(self.path, "OVERVIEW.LST")) as f:
                for line in f:
                    if not line.startswith("INT "):
                        continue
                    words = line.split()
                    obj[words[1]] = {'name': ' '.join(words[3:])}
            return

        if line.startswith("--------"):
            self.saveInt(obj)
        if self.mode == self.MODE_WAIT:
            self.wait(line, obj)
        elif self.mode == self.MODE_INT:
            self.readInt(line, obj)
        elif self.mode == self.MODE_PARAMS:
            self.params(line, obj)

    def parsePorts(self, line, obj):
        if line is None or not self.ishex(line[0]):
            return
        words = line.split()
        if len(words) < 3 or len(words[0]) < 4:
            return
        key = words[0][:4]
        if not self.ishex(key) or key in obj:
            return
        obj[key] = ' '.join(words[2:])

    def parseFiles(self, file, outfile, proc):
        ext = 'A'
        data = OrderedDict()
        path = os.path.join(self.path, file)
        self.mode = self.MODE_INIT
        proc(None, data)
        while os.path.exists(path + ext):
            fname = path + ext
            ext = chr(ord(ext) + 1)
            print "processing file " + fname
            with open(fname, "r") as f:
                for line in f:
                    proc(line, data)
        with open(outfile, "w") as f:
            json.dump(data, f, indent=2, separators=(',', ': '))

    def run(self):
        try:
            opts, args = getopt.getopt(sys.argv, 'h', ["help"])
            for o, a in opts:
                if o in ("-h", "--help"):
                    return self.usage()

            self.path = args[1] if len(args) > 1 else os.path.realpath(__file__)
            self.parseFiles("INTERRUP.", "ints.json", self.parseInts)
            self.parseFiles("PORTS.", "ports.json", self.parsePorts)
        except getopt.GetoptError as e:
            print str(e)
            return self.usage()
        except Exception as e:
            print str(e)
            return 2

    def usage(self):
        print """
mk_ints.py - convert Ralf Brown's interrupt list to xml.
        """
        return 1


if __name__ == "__main__":
    sys.exit(App().run())
