#!/usr/bin/env python3

import logging
import os
import importlib
import shutil
import zipfile
import datetime
from git import Repo, GitCommandError

# Define directory paths for backups and the Git repository
backup_base_dir = "/var/lib"  # Base directory for application backups
repo_dir = "/home/chris/backups"

# Define applications and their backup paths/extensions
apps = {
    "sonarr": ("sonarr/Backups/scheduled", "zip"),
    "radarr": ("radarr/Backups/scheduled", "zip"),
    "lidarr": ("lidarr/Backups/scheduled", "zip"),
    "whisparr": ("whisparr/Backups/scheduled", "zip"),
    "sabnzbd": ("sabnzbd/Backups/scheduled", "zip") 
}

def install_and_import(package, module_name=None):
    module_name = module_name if module_name else package
    try:
        importlib.import_module(module_name)
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        importlib.import_module(module_name)

def add_backups_to_git(repo):
    """Adds PVR backup zip files to the Git repository."""
    for app, (backup_subdir, ext) in apps.items():
        backup_path = os.path.join(backup_base_dir, backup_subdir, f"{app}_backup*.{ext}") if ext else os.path.join(backup_base_dir, backup_subdir)
        print(backup_path)

    if os.path.exists(backup_path):
        repo.index.add(backup_path)
        print(f"Added {backup_path} to staging area for {app}")

def commit_changes(repo):
    """Commits staged changes to the Git repository."""
    if not repo.index.diff(None):
        print("No changes detected. Skipping commit.")
        return

    commit_message = f"Backup for {datetime.datetime.now().strftime('%Y-%m-%d')}"
    repo.index.commit(commit_message)
    print(f"Committed changes with message: {commit_message}")

def push_changes(repo):
    """Pushes committed changes to the 'main' branch on the remote Git repository."""
    origin = repo.remote("origin")
    origin.push('main')  # Push directly to the 'main' branch
    print("Pushed changes to remote repository (main branch).")


def main():
    install_and_import('GitPython', 'git')
    from git import Repo, GitCommandError
    repo = Repo(repo_dir)
    add_backups_to_git(repo)
    commit_changes(repo)
    push_changes(repo)

if __name__ == "__main__":
    main()
