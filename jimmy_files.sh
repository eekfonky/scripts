#!/bin/bash
find /mnt/extHD/Downloads/complete/jimmy -maxdepth 2 -type f -name "*.mp4" -exec mv {} . \;
find /mnt/extHD/Downloads/complete/jimmy -maxdepth 1 -type d -exec rm -rf {} \;
