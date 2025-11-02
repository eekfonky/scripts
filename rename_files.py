#!/usr/bin/env python3
"""
Rename a single video file in a directory to match the directory name.

This script detects video files using MIME type detection and renames them
to match their parent directory name. Only works if there's exactly one
video file in the directory.
"""

import argparse
import logging
import os
import sys
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def check_magic_available():
    """Check if python-magic is installed."""
    try:
        import magic
        return True
    except ImportError:
        logger.error("python-magic is not installed")
        logger.error("Install with: pip install python-magic")
        logger.error("On Debian/Ubuntu, you may also need: apt-get install libmagic1")
        return False


def rename_video_to_directory_name(path, dry_run=False):
    """
    Rename a single video file to match the directory name.

    Args:
        path: Path to directory containing the video file
        dry_run: If True, only show what would be done

    Returns:
        True if successful (or would be successful in dry-run mode), False otherwise
    """
    import magic

    directory = Path(path).resolve()

    if not directory.is_dir():
        logger.error(f"Not a directory: {directory}")
        return False

    video_files = []

    # Iterate over directory
    for filepath in directory.iterdir():
        if not filepath.is_file():
            continue

        # Use magic to determine file type
        try:
            mime_type = magic.from_file(str(filepath), mime=True)
        except Exception as e:
            logger.warning(f"Could not determine MIME type for {filepath.name}: {e}")
            continue

        if mime_type and mime_type.startswith('video/'):
            video_files.append(filepath)
            logger.debug(f"Found video file: {filepath.name} ({mime_type})")

    # Check if we found exactly one video file
    if len(video_files) == 0:
        logger.error(f"No video files found in {directory}")
        return False

    if len(video_files) > 1:
        logger.error(f"Multiple video files found in {directory}:")
        for vf in video_files:
            logger.error(f"  - {vf.name}")
        logger.error("This script only works with directories containing a single video file")
        return False

    # We have exactly one video file
    video_file = video_files[0]
    directory_name = directory.name
    file_extension = video_file.suffix
    new_filename = directory_name + file_extension
    new_filepath = directory / new_filename

    # Check if renaming is necessary
    if video_file.name == new_filename:
        logger.info(f"File already has the correct name: {new_filename}")
        return True

    # Check if destination file already exists
    if new_filepath.exists():
        logger.error(f"Cannot rename: destination file already exists: {new_filename}")
        return False

    if dry_run:
        logger.info(f"[DRY-RUN] Would rename '{video_file.name}' to '{new_filename}'")
        return True

    # Perform the rename
    try:
        video_file.rename(new_filepath)
        logger.info(f"Successfully renamed '{video_file.name}' to '{new_filename}'")
        return True
    except OSError as e:
        logger.error(f"Error renaming file: {e}")
        return False


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        'directory',
        nargs='?',
        help='Directory containing the video file (will prompt if not provided)'
    )
    parser.add_argument(
        '-n', '--dry-run',
        action='store_true',
        help='Show what would be done without actually renaming'
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

        # Check if python-magic is available
        if not check_magic_available():
            sys.exit(1)

        # Get directory path
        if args.directory:
            path = args.directory
        else:
            path = input("Directory file path?: ").strip()

        if not path:
            logger.error("No directory path provided")
            sys.exit(1)

        # Validate directory
        directory = Path(path).resolve()
        if not directory.exists():
            logger.error(f"Directory does not exist: {directory}")
            sys.exit(1)

        if not directory.is_dir():
            logger.error(f"Not a directory: {directory}")
            sys.exit(1)

        if args.dry_run:
            logger.info("DRY-RUN mode enabled (no files will be renamed)")

        # Rename the video file
        success = rename_video_to_directory_name(directory, dry_run=args.dry_run)

        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
