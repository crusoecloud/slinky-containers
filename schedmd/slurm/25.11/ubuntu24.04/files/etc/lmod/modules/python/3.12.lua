help([[Python 3.12 - Python programming language interpreter]])

whatis("Name:        Python")
whatis("Version:     3.12")
whatis("Description: Python 3.12 interpreter and pip package manager")
whatis("URL:         https://www.python.org")

local base = "/usr"

prepend_path("PATH", pathJoin(base, "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(base, "lib/python3.12"))
prepend_path("MANPATH", pathJoin(base, "share/man"))
