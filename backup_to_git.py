#!/usr/bin/python3

import os
import time
from datetime import datetime

def list_files_with_creation_time(directory):
    """Lists files in a directory with their creation times."""

    for filename in os.listdir(directory):
        filepath = os.path.join(directory, filename)
        if os.path.isfile(filepath):
            creation_time = os.path.getctime(filepath)
            formatted_time = datetime.fromtimestamp(creation_time).strftime('%Y-%m-%d %H:%M:%S')
            print(f"{filename} Created: {formatted_time}")

# Specify the directory you want to examine
directory = "/home/chris/backups"

list_files_with_creation_time(directory)
