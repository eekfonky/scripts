#!/usr/bin/env python3
"""
Backup application configuration files to a Git repository.

This script backs up application backup files (Sonarr, Radarr, Lidarr, Whisparr, Sabnzbd)
from /var/lib to a Git repository, commits changes, and pushes to remote.
"""

import argparse
import datetime
import logging
import os
import shutil
import sys
from pathlib import Path

try:
    import git
except ImportError:
    print("GitPython is not installed. Install with: pip install GitPython")
    sys.exit(1)

# Configure logging
LOG_FILE = Path.home() / '.local' / 'log' / 'backup_to_git.log'
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration defaults
BACKUP_BASE_DIR = "/var/lib"
REPO_DIR = "/home/chris/backups"

APPS = {
    "sonarr": ("sonarr/Backups/scheduled", "zip"),
    "radarr": ("radarr/Backups/scheduled", "zip"),
    "lidarr": ("lidarr/Backups/scheduled", "zip"),
    "whisparr": ("whisparr/Backups/scheduled", "zip"),
    "sabnzbd": ("sabnzbd/Backups/scheduled", "zip")
}


def validate_directory(directory, purpose):
    """
    Validate that a directory exists and is accessible.

    Args:
        directory: Path to validate
        purpose: Description of directory purpose (for error messages)

    Returns:
        True if valid, False otherwise
    """
    path = Path(directory)

    if not path.exists():
        logger.error(f"{purpose} does not exist: {directory}")
        return False

    if not path.is_dir():
        logger.error(f"{purpose} is not a directory: {directory}")
        return False

    if not os.access(path, os.R_OK):
        logger.error(f"Cannot read {purpose}: {directory} (permission denied)")
        return False

    return True


def backup_application(app, backup_subdir, ext, repo, backup_base_dir, repo_dir, dry_run=False):
    """
    Backs up a single application to the Git repository.

    Args:
        app: Application name
        backup_subdir: Subdirectory path under backup_base_dir
        ext: File extension to look for
        repo: Git repository object
        backup_base_dir: Base directory for backups
        repo_dir: Git repository directory
        dry_run: If True, only show what would be done

    Returns:
        Number of files backed up
    """
    source_backup_dir = Path(backup_base_dir) / backup_subdir
    dest_backup_dir = Path(repo_dir) / app
    files_backed_up = 0

    # Validate source directory exists
    if not source_backup_dir.exists():
        logger.warning(f"Source directory {source_backup_dir} not found, skipping {app}")
        return 0

    # Check if directory is readable
    if not os.access(source_backup_dir, os.R_OK):
        logger.error(f"Cannot read {source_backup_dir}, permission denied")
        return 0

    # Create destination directory
    if not dry_run:
        dest_backup_dir.mkdir(parents=True, exist_ok=True)

    # Find backup files
    backup_files = list(source_backup_dir.glob(f'*.{ext}'))

    if not backup_files:
        logger.warning(f"No .{ext} files found for {app} in {source_backup_dir}")
        return 0

    logger.info(f"Processing {app}: found {len(backup_files)} backup file(s)")

    for source_path in backup_files:
        dest_path = dest_backup_dir / source_path.name

        try:
            # Check if file needs to be copied
            if dest_path.exists() and source_path.samefile(dest_path):
                logger.debug(f"Skipping {dest_path} (same file)")
                continue

            if dry_run:
                logger.info(f"[DRY-RUN] Would copy {source_path} to {dest_path}")
                files_backed_up += 1
            else:
                # Copy file
                shutil.copy2(source_path, dest_path)

                # Add to git
                repo.index.add([str(dest_path)])

                logger.info(f"Backed up {dest_path}")
                files_backed_up += 1

        except PermissionError as e:
            logger.error(f"Permission denied copying {source_path}: {e}")
        except Exception as e:
            logger.error(f"Error copying {source_path}: {e}")

    return files_backed_up


def commit_changes(repo, dry_run=False):
    """
    Commits changes to the Git repository.

    Args:
        repo: Git repository object
        dry_run: If True, only show what would be done

    Returns:
        True if successful, False otherwise
    """
    try:
        # Check if there are changes to commit
        if not repo.is_dirty(untracked_files=True):
            logger.info("No changes to commit")
            return True

        commit_message = f"Backup for {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"

        if dry_run:
            logger.info(f"[DRY-RUN] Would commit with message: {commit_message}")
            return True

        repo.index.commit(commit_message)
        logger.info("Committed changes successfully")
        return True

    except git.exc.GitCommandError as e:
        logger.error(f"Error during commit: {e}")
        return False


def push_changes(repo, branch='main', dry_run=False):
    """
    Pushes committed changes to the remote Git repository.

    Args:
        repo: Git repository object
        branch: Branch name to push
        dry_run: If True, only show what would be done

    Returns:
        True if successful, False otherwise
    """
    try:
        if dry_run:
            logger.info(f"[DRY-RUN] Would push changes to remote repository ({branch} branch)")
            return True

        origin = repo.remote("origin")
        origin.push(branch)
        logger.info(f"Pushed changes to remote repository ({branch} branch)")
        return True

    except git.exc.GitCommandError as e:
        logger.error(f"Error during push: {e}")
        return False


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        '--backup-dir',
        default=BACKUP_BASE_DIR,
        help=f'Base directory for backups (default: {BACKUP_BASE_DIR})'
    )
    parser.add_argument(
        '--repo-dir',
        default=REPO_DIR,
        help=f'Git repository directory (default: {REPO_DIR})'
    )
    parser.add_argument(
        '--branch',
        default='main',
        help='Git branch to push to (default: main)'
    )
    parser.add_argument(
        '-n', '--dry-run',
        action='store_true',
        help='Show what would be done without actually doing it'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )
    parser.add_argument(
        '--apps',
        nargs='+',
        choices=list(APPS.keys()),
        help='Backup only specific applications'
    )

    return parser.parse_args()


def main():
    """Main entry point."""
    try:
        args = parse_args()

        # Set logging level
        if args.verbose:
            logging.getLogger().setLevel(logging.DEBUG)

        logger.info("=" * 60)
        logger.info("Starting backup process")
        logger.info("=" * 60)

        if args.dry_run:
            logger.info("DRY-RUN mode enabled (no changes will be made)")

        # Validate directories
        if not validate_directory(args.backup_dir, "Backup base directory"):
            sys.exit(1)

        if not validate_directory(args.repo_dir, "Repository directory"):
            sys.exit(1)

        # Open Git repository
        try:
            repo = git.Repo(args.repo_dir)
        except git.exc.InvalidGitRepositoryError:
            logger.error(f"Not a valid Git repository: {args.repo_dir}")
            sys.exit(1)
        except Exception as e:
            logger.error(f"Error opening repository: {e}")
            sys.exit(1)

        # Determine which apps to backup
        apps_to_backup = args.apps if args.apps else APPS.keys()

        # Backup each application
        total_files = 0
        for app in apps_to_backup:
            backup_subdir, ext = APPS[app]
            files_backed_up = backup_application(
                app,
                backup_subdir,
                ext,
                repo,
                args.backup_dir,
                args.repo_dir,
                dry_run=args.dry_run
            )
            total_files += files_backed_up

        logger.info(f"Total files backed up: {total_files}")

        # Commit and push changes
        if total_files > 0 or repo.is_dirty(untracked_files=True):
            if commit_changes(repo, dry_run=args.dry_run):
                push_changes(repo, branch=args.branch, dry_run=args.dry_run)
        else:
            logger.info("No files to backup")

        logger.info("Backup process completed successfully")

    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
