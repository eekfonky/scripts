#!/bin/bash
set -euo pipefail

# Configuration
SOURCE_DIR="/mnt/extHD/Downloads/complete/jimmy"
DRY_RUN=false

# Colors
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Move MP4 files from nested directories and optionally remove empty directories"
            echo ""
            echo "OPTIONS:"
            echo "  --source DIR    Source directory (default: $SOURCE_DIR)"
            echo "  --dry-run       Show what would be done without doing it"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Verify directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    exit 1
fi

# Count MP4 files
mp4_count=$(find "$SOURCE_DIR" -maxdepth 2 -type f -name "*.mp4" | wc -l)
echo -e "${YELLOW}Found $mp4_count MP4 file(s) to move${NC}"

if [ "$mp4_count" -eq 0 ]; then
    echo -e "${YELLOW}No MP4 files found. Nothing to do.${NC}"
    exit 0
fi

# List files to be moved
echo -e "${YELLOW}Files to be moved:${NC}"
find "$SOURCE_DIR" -maxdepth 2 -type f -name "*.mp4"

if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}[DRY-RUN] Would move $mp4_count file(s)${NC}"
else
    # Ask for confirmation
    read -p "Move these files to current directory? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${YELLOW}Aborted${NC}"
        exit 0
    fi

    # Move files with progress
    find "$SOURCE_DIR" -maxdepth 2 -type f -name "*.mp4" -print -exec mv {} . \;
    echo -e "${GREEN}Moved $mp4_count file(s)${NC}"
fi

# Find directories that could be removed (excluding the source dir itself)
dir_list=$(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d)
dir_count=$(echo "$dir_list" | grep -c . || true)

if [ "$dir_count" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Directories that can be removed ($dir_count):${NC}"
    echo "$dir_list"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}[DRY-RUN] Would remove $dir_count director(y/ies)${NC}"
    else
        read -p "Delete these directories? (yes/no): " CONFIRM_DELETE
        if [ "$CONFIRM_DELETE" = "yes" ]; then
            echo "$dir_list" | while read -r dir; do
                rm -rf "$dir"
                echo -e "${GREEN}Removed: $dir${NC}"
            done
            echo -e "${GREEN}Removed $dir_count director(y/ies)${NC}"
        else
            echo -e "${YELLOW}Skipped directory deletion${NC}"
        fi
    fi
else
    echo -e "${YELLOW}No directories to remove${NC}"
fi

echo -e "${GREEN}Done!${NC}"
