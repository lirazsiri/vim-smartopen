import re
from glob import glob as _glob
from os.path import *

def paths_complete(paths, lead):
    def glob(path):
        def f(p):
            if isdir(p):
                return p + "/"
            return p
        return [ path for path in map(f, _glob(path)) 
                 if not re.search(r'\.py[co]$', path) ]
        
    if re.match(r'^.?.?/', lead):
        return glob(lead + "*")

    def match(path, lead):
        path = abspath(path)
        for f in glob(join(path, lead) + "*"):
            yield f[len(path) + 1:]

    matches = reduce(lambda x, y: x+y,
                      [ list(match(path, lead)) for path in paths ])
    return sorted(set(matches))

