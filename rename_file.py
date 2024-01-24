#!/bin/python3

import os

def rename_files_in_directory(directory_path):
    for root, dirs, files in os.walk(directory_path):
        for file_name in files:
            file_path = os.path.join(root, file_name)
            directory_name = os.path.basename(root)
            file_extension = os.path.splitext(file_name)[1]
            new_file_name = directory_name + file_extension
            new_file_path = os.path.join(root, new_file_name)
            os.rename(file_path, new_file_path)

# Example usage
directory_path = '/mnt/extHD/Downloads/nzb'
rename_files_in_directory(directory_path)
