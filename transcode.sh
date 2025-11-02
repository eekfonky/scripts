#!/bin/bash
set -euo pipefail

# Default configuration
CRF="${CRF:-30}"
PRESET="${PRESET:-slow}"
OUTPUT_SUFFIX="${OUTPUT_SUFFIX:-_h265}"
DRY_RUN=false
DIRECTORY="."
VERBOSE=false

# Colors
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m'

# Usage function
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY]

Transcode MKV files to H.265 (HEVC) codec

OPTIONS:
    -c, --crf VALUE       CRF value for encoding quality (default: $CRF)
                         Lower = better quality, higher file size (18-28 recommended)
    -p, --preset PRESET   Encoding preset (default: $PRESET)
                         Options: ultrafast, superfast, veryfast, faster, fast,
                                  medium, slow, slower, veryslow
    -s, --suffix SUFFIX   Output filename suffix (default: $OUTPUT_SUFFIX)
    -n, --dry-run         Show what would be done without doing it
    -v, --verbose         Show ffmpeg output
    -h, --help            Show this help message

EXAMPLES:
    $(basename "$0")                      # Transcode all MKV in current directory
    $(basename "$0") -c 28 ~/Videos       # Transcode with CRF 28
    $(basename "$0") --dry-run            # Preview operations
    $(basename "$0") -p faster -c 23      # Faster encoding, higher quality

NOTES:
    - CRF range: 0-51 (18-28 recommended for good quality)
    - Lower CRF = better quality but larger files
    - Slower presets = better compression but take longer
    - Output files will have '$OUTPUT_SUFFIX' suffix before .mkv extension
    - Original files are not modified
EOF
}

# Log message
log() {
    local level="$1"
    shift
    case "$level" in
        INFO)
            echo -e "${GREEN}[INFO]${NC} $*"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $*"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $*"
            ;;
    esac
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--crf)
            CRF="$2"
            shift 2
            ;;
        -p|--preset)
            PRESET="$2"
            shift 2
            ;;
        -s|--suffix)
            OUTPUT_SUFFIX="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            DIRECTORY="$1"
            shift
            ;;
    esac
done

# Validate CRF value
if ! [[ "$CRF" =~ ^[0-9]+$ ]] || [ "$CRF" -lt 0 ] || [ "$CRF" -gt 51 ]; then
    log ERROR "CRF must be between 0 and 51"
    exit 1
fi

# Validate directory
if [ ! -d "$DIRECTORY" ]; then
    log ERROR "Directory not found: $DIRECTORY"
    exit 1
fi

# Change to directory
cd "$DIRECTORY" || exit 1
log INFO "Processing directory: $(pwd)"
log INFO "CRF: $CRF, Preset: $PRESET, Suffix: $OUTPUT_SUFFIX"

if [ "$DRY_RUN" = true ]; then
    log WARN "DRY-RUN mode enabled (no files will be transcoded)"
fi

# Count total MKV files
total_files=0
for file in *.mkv; do
    [ -e "$file" ] || continue
    total_files=$((total_files + 1))
done

if [ "$total_files" -eq 0 ]; then
    log WARN "No MKV files found in directory"
    exit 0
fi

log INFO "Found $total_files MKV file(s) to process"
echo ""

# Process each file
current=0
skipped=0
processed=0
failed=0

for file in *.mkv; do
    [ -e "$file" ] || continue

    filename="${file%.*}"
    output="${filename}${OUTPUT_SUFFIX}.mkv"

    current=$((current + 1))

    # Skip if output already exists
    if [ -f "$output" ]; then
        log WARN "[$current/$total_files] Skipping $file (output already exists)"
        skipped=$((skipped + 1))
        continue
    fi

    log INFO "[$current/$total_files] Processing: $file"

    if [ "$DRY_RUN" = true ]; then
        log INFO "  Would transcode: $file -> $output"
        processed=$((processed + 1))
    else
        # Build ffmpeg command
        ffmpeg_cmd=(
            ffmpeg
            -i "$file"
            -map 0:v
            -c:v libx265
            -crf "$CRF"
            -x265-params "speed-preset=$PRESET"
            -map 0:a:0
            -c:a copy
            -y
            "$output"
        )

        # Run ffmpeg (suppress output unless verbose)
        if [ "$VERBOSE" = true ]; then
            if "${ffmpeg_cmd[@]}"; then
                log INFO "  Completed: $output"
                processed=$((processed + 1))
            else
                log ERROR "  Failed to transcode: $file"
                failed=$((failed + 1))
            fi
        else
            if "${ffmpeg_cmd[@]}" >/dev/null 2>&1; then
                log INFO "  Completed: $output"
                processed=$((processed + 1))
            else
                log ERROR "  Failed to transcode: $file"
                failed=$((failed + 1))
            fi
        fi
    fi
    echo ""
done

# Summary
echo "=" * 60
log INFO "Processing complete!"
log INFO "  Processed: $processed"
[ "$skipped" -gt 0 ] && log WARN "  Skipped: $skipped"
[ "$failed" -gt 0 ] && log ERROR "  Failed: $failed"

exit 0
