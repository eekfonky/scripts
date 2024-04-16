#!/usr/bin/env python3

import os
from fuzzywuzzy import fuzz

def fuzzy_rename_avi(directory):
    """Renames AVI files in a directory (and subdirectories) based on fuzzy matching with MKV files."""

    for root, dirs, files in os.walk(directory):
        for filename in files:
            base, ext = os.path.splitext(filename)
            if ext.lower() == '.avi':
                best_match_ratio = 0
                best_match_mkv = None

                # Search for potential MKV matches in the same directory
                for potential_match in files:
                    if potential_match.endswith('.mkv'):
                        ratio = fuzz.ratio(base, potential_match[:-4]) 
                        if ratio > best_match_ratio:
                            best_match_ratio = ratio
                            best_match_mkv = potential_match

                # Rename if a good enough match is found
                if best_match_mkv:
                    new_filename = best_match_mkv[:-4] + '.avi' 
                    old_filepath = os.path.join(root, filename)
                    new_filepath = os.path.join(root, new_filename)
                    os.rename(old_filepath, new_filepath)
                    print(f'Renamed "{filename}" to "{new_filename}"')

# Specify the directory containing your AVI and MKV files
directory = "/mnt/intHD/Looney.Tunes.Golden.Collection/Looney.Tunes.Golden.Collection.Data/Volume.6"  # Replace with your actual directory

fuzzy_rename_avi(directory) 

