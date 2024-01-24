#!/usr/bin/python3

# import required module
import os
from pathlib import Path

# Get filepath
path = input("Directory file path?: ")

# Error handling
try:
    # Iterate over directory
    for filename in os.listdir(path):
        print(filename)

except FileNotFoundError:
    print("Directory: {0} does not exist".format(path))
except NotADirectoryError:
    print("{0} is not a directory".format(path))
except PermissionError:
    print("You do not have permissions to change to {0}".format(path))
