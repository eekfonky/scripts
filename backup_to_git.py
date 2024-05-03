#!/usr/bin/env python3

import datetime
import os
import git
import shutil
import logging
import argparse

# Configuration (Make these configurable if desired)
BACKUP_BASE_DIR = "/var/lib"  
REPO_DIR = "/home/chris/backups"

APPS = {
    "sonarr": ("sonarr/Backups/scheduled", "zip"),
    "radarr": ("radarr/Backups/scheduled", "zip"),
    "lidarr": ("lidarr/Backups/scheduled", "zip"),
    "whisparr": ("whisparr/Backups/scheduled", "zip"),
    "sabnzbd": ("sabnzbd/Backups/scheduled", "zip") 
}

def backup_application(app, backup_subdir, ext, repo):
    """Backs up a single application to the Git repository."""
    source_backup_dir = os.path.join(BACKUP_BASE_DIR, backup_subdir)
    dest_backup_dir = os.path.join(REPO_DIR, app)

    os.makedirs(dest_backup_dir, exist_ok=True)

    for filename in os.listdir(source_backup_dir):
        if filename.endswith(f'.{ext}'):
            source_path = os.path.join(source_backup_dir, filename)
            dest_path = os.path.join(dest_backup_dir, filename)

            backup_changed = not os.path.samefile(source_path, dest_path) 

            if backup_changed or dest_path not in repo.untracked_files:
                shutil.copy2(source_path, dest_path)
                repo.index.add([dest_path])
                logging.info(f"{'Copied' if backup_changed else 'Added'} {dest_path} for {app}")

def commit_changes(repo):
    """Commits changes to the Git repository."""
    try:
        commit_message = f"Backup for {datetime.datetime.now().strftime('%Y-%m-%d')}"
        repo.index.commit(commit_message)
        logging.info("Committed changes successfully")
    except git.exc.GitCommandError as e:
        logging.error(f"Error during commit: {e}")

def push_changes(repo):
    """Pushes committed changes to the remote Git repository."""
    try:
        origin = repo.remote("origin")
        origin.push('main')
        logging.info("Pushed changes to remote repository (main branch)")
    except git.exc.GitCommandError as e:
        logging.error(f"Error during push: {e}")

def main():
    parser = argparse.ArgumentParser(description="Application backup script")
    parser.add_argument('--backup-dir', default=BACKUP_BASE_DIR, help='Base directory for backups')
    parser.add_argument('--repo-dir', default=REPO_DIR, help='Git repository directory')
    args = parser.parse_args()

    logging.basicConfig(filename='backup.log', level=logging.INFO) 

    repo = git.Repo(args.repo_dir)

    for app, (backup_subdir, ext) in APPS.items():
        backup_application(app, backup_subdir, ext, repo)

    commit_changes(repo)
    push_changes(repo)

if __name__ == "__main__":
    main()
