#!/usr/bin/env python3

import os
import magic
import subprocess
import importlib

def install_package(package):
    """Installs a package using pip."""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
    except subprocess.CalledProcessError:
        print(f"Error installing {package}")

def import_module(module_name):
    """Imports a module."""
    try:
        importlib.import_module(module_name)
    except ImportError:
        print(f"{module_name} is not installed. Installing...")
        install_package(module_name)
        importlib.import_module(module_name)

def main():
    install_and_import('magic')
    import magic 

    path = input("Directory file path?: ")

    # Error handling
    try:
        if not os.path.isdir(path):
            raise ValueError("The provided path is not a directory.")

        video_count = 0  # Track the number of video files

        # Iterate over directory
        for filename in os.listdir(path):
            filepath = os.path.join(path, filename)

            # Use magic to determine file type
            mime_type = magic.from_file(filepath, mime=True)

            if mime_type and mime_type.startswith('video/'):
                video_count += 1

                if video_count > 1:
                    print("Multiple video files found in the directory. Skipping renaming.")
                    break

                directory_name = os.path.basename(path)
                new_filename = directory_name + os.path.splitext(filename)[1]  
                new_filepath = os.path.join(path, new_filename)

                try:
                    os.rename(filepath, new_filepath)
                    print(f"Video file '{filename}' renamed to '{new_filename}'")
                except OSError as e:
                    print(f"Error renaming file: {e}")

            else:
                print(filename)  # Not a video file

    except FileNotFoundError:
        print("Directory: {0} does not exist".format(path))
    except NotADirectoryError:
        print("{0} is not a directory".format(path))
    except PermissionError:
        print("You do not have permissions to change to {0}".format(path))
    except ValueError as e:
        print(e)

if __name__ == "__main__":
    main()
