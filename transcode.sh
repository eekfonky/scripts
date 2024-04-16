#!/bin/bash

# Set the CRF value (adjust as needed)
CRF=30

# Loop through all MKV files in the current directory
for file in *.mkv; do
  # Extract filename without extension
  filename="${file%.*}"
  
  # ffmpeg command for transcoding
  ffmpeg -i "$file" -map 0:v -c:v libx265 -crf $CRF -x265-params "speed-preset=slow" -map 0:a:0 -c:a copy -y "${filename}_h265.mkv"

  echo "Transcoded: $file to ${filename}_h265.mkv"
done

echo "All MKV files processed!"
