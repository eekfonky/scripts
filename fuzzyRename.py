#!/usr/bin/env python3
"""
Rename AVI files to match corresponding MKV files using fuzzy string matching.

This script uses fuzzy matching to find the best MKV file match for each AVI file
in a directory and renames the AVI file accordingly.
"""

import argparse
import logging
import os
import sys
from pathlib import Path
from fuzzywuzzy import fuzz

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def fuzzy_rename_avi(directory, threshold=70, dry_run=False):
    """
    Renames AVI files in a directory based on fuzzy matching with MKV files.

    Args:
        directory: Path to directory containing AVI and MKV files
        threshold: Minimum match ratio (0-100) to consider a match
        dry_run: If True, only show what would be done without renaming

    Returns:
        Number of files renamed (or would be renamed in dry-run mode)
    """
    rename_count = 0

    for root, dirs, files in os.walk(directory):
        avi_files = [f for f in files if f.lower().endswith('.avi')]
        mkv_files = [f for f in files if f.lower().endswith('.mkv')]

        if not avi_files:
            logger.info(f"No AVI files found in {root}")
            continue

        if not mkv_files:
            logger.warning(f"No MKV files found to match against in {root}")
            continue

        for avi_filename in avi_files:
            base, ext = os.path.splitext(avi_filename)
            best_match_ratio = 0
            best_match_mkv = None

            # Search for potential MKV matches in the same directory
            for mkv_filename in mkv_files:
                mkv_base = mkv_filename[:-4]  # Remove .mkv extension
                ratio = fuzz.ratio(base, mkv_base)

                if ratio > best_match_ratio:
                    best_match_ratio = ratio
                    best_match_mkv = mkv_filename

            # Rename if a good enough match is found
            if best_match_mkv and best_match_ratio >= threshold:
                new_filename = best_match_mkv[:-4] + '.avi'
                old_filepath = os.path.join(root, avi_filename)
                new_filepath = os.path.join(root, new_filename)

                # Skip if source and destination are the same
                if old_filepath == new_filepath:
                    logger.debug(f"Skipping {avi_filename} (already has correct name)")
                    continue

                # Check if destination file already exists
                if os.path.exists(new_filepath) and not dry_run:
                    logger.warning(
                        f"Cannot rename '{avi_filename}' to '{new_filename}': "
                        f"destination already exists"
                    )
                    continue

                if dry_run:
                    logger.info(
                        f"[DRY-RUN] Would rename '{avi_filename}' to '{new_filename}' "
                        f"(match: {best_match_ratio}%)"
                    )
                else:
                    try:
                        os.rename(old_filepath, new_filepath)
                        logger.info(
                            f"Renamed '{avi_filename}' to '{new_filename}' "
                            f"(match: {best_match_ratio}%)"
                        )
                        rename_count += 1
                    except OSError as e:
                        logger.error(f"Error renaming '{avi_filename}': {e}")
            else:
                logger.warning(
                    f"No good match found for '{avi_filename}' "
                    f"(best match: {best_match_ratio}% < threshold: {threshold}%)"
                )

    return rename_count


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        'directory',
        help='Directory containing AVI and MKV files'
    )
    parser.add_argument(
        '-t', '--threshold',
        type=int,
        default=70,
        help='Minimum match ratio (0-100, default: 70)'
    )
    parser.add_argument(
        '-r', '--recursive',
        action='store_true',
        help='Process subdirectories recursively (default behavior)'
    )
    parser.add_argument(
        '-n', '--dry-run',
        action='store_true',
        help='Show what would be done without actually renaming files'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )

    return parser.parse_args()


def main():
    """Main entry point."""
    try:
        args = parse_args()

        # Set logging level
        if args.verbose:
            logging.getLogger().setLevel(logging.DEBUG)

        # Validate directory
        directory = Path(args.directory).resolve()
        if not directory.exists():
            logger.error(f"Directory does not exist: {directory}")
            sys.exit(1)

        if not directory.is_dir():
            logger.error(f"Not a directory: {directory}")
            sys.exit(1)

        # Validate threshold
        if not 0 <= args.threshold <= 100:
            logger.error("Threshold must be between 0 and 100")
            sys.exit(1)

        logger.info(f"Processing directory: {directory}")
        logger.info(f"Match threshold: {args.threshold}%")

        if args.dry_run:
            logger.info("DRY-RUN mode enabled (no files will be renamed)")

        # Process files
        rename_count = fuzzy_rename_avi(
            directory,
            threshold=args.threshold,
            dry_run=args.dry_run
        )

        if args.dry_run:
            logger.info(f"Would rename {rename_count} file(s)")
        else:
            logger.info(f"Successfully renamed {rename_count} file(s)")

    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
