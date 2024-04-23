#!/usr/bin/env python3

import os
import git
import shutil

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

def copy_and_add_backups_to_git(repo):
    """Copies new backup zip files to the Git repository and stages them."""
    existing_backups = [os.path.join(repo_dir, filename) for filename in repo.untracked_files]

    for app, (backup_subdir, ext) in apps.items():
        source_backup_dir = os.path.join(backup_base_dir, backup_subdir)
        dest_backup_dir = os.path.join(repo_dir, app)  # Create app-specific directories in the repo

        os.makedirs(dest_backup_dir, exist_ok=True)  # Ensure destination directory exists

        for filename in os.listdir(source_backup_dir):
            if filename.endswith('.zip'):
                source_path = os.path.join(source_backup_dir, filename)
                dest_path = os.path.join(dest_backup_dir, filename)

                if dest_path not in existing_backups:
                    shutil.copy2(source_path, dest_path)  # Copy to the repo
                    repo.index.add([dest_path])  # Stage in Git
                    print(f"Copied and added {dest_path} to staging area for {app}")
                else:
                    # Check if the file has changed before copying/adding
                    if not os.path.samefile(source_path, dest_path):
                        shutil.copy2(source_path, dest_path) 
                        repo.index.add([dest_path])
                        print(f"Updated {dest_path} in staging area for {app}")

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
    repo = git.Repo(repo_dir)
    copy_and_add_backups_to_git(repo)
    commit_changes(repo)
    push_changes(repo)

if __name__ == "__main__":
    main()
