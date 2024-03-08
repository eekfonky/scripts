#!/usr/bin/env python3

import os
import shutil
import sys
import subprocess
import re
import importlib
import tempfile

def installAndImport(package, module_name=None):
    module_name = module_name if module_name else package
    try:
        importlib.import_module(module_name)
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        importlib.import_module(module_name)

def perform_git_operations(repo, template_dir, branch_name, original_branch, GitCommandError):
    try:
        repo.index.add([template_dir])
        repo.index.commit("Update backups")

        push_command = ["git", "push", "origin", branch_name]
        push_result = subprocess.check_output(push_command, text=True)

        if "Everything up-to-date" in push_result:
            print("Everything up-to-date. No changes to push.")
        else:
            print(push_result)

            # Checkout the original branch to allow removal of temp branch
            repo.git.checkout(original_branch)

    except subprocess.CalledProcessError as e:
        print(f"Error in Git operations: {e}")
    except GitCommandError as e:
        print(f"Error in Git operations: {e}")

def backup_current_state(repo, GitCommandError):
    # Create a temporary branch to hold the current state
    try:
        repo.git.branch('temp_backup_branch')
    except GitCommandError:
        # Branch already exists, force update it
        repo.git.branch('-D', 'temp_backup_branch')
        repo.git.branch('temp_backup_branch')

def rollback_to_backup(repo, GitCommandError):
    try:
        # Reset the current branch to the backup branch
        repo.git.reset('--hard', 'temp_backup_branch')
        print("Rollback successful.")
    except GitCommandError as e:
        print(f"Rollback failed: {e}")

def main():
    installAndImport('GitPython', 'git')
    from git import Repo, GitCommandError

    ##### Script Variables - EDIT THESE TO SUIT YOUR SETUP!! ####
    git_repo_root = os.path.expanduser("~/code/dev") # Where your repo starts
    default_branch = "main"
    #### END ####

    # Expand paths and ensure directories exist
    git_repo_root = os.path.expanduser(git_repo_root)
    templates_path = os.path.expanduser(template_dir)
    zip_dir = os.path.expanduser(zip_dir)
    ensure_directory_exists(zip_dir)

    # Create a unique temporary directory in /tmp
    extraction_dir = tempfile.mkdtemp(prefix='templates_extraction_', dir='/tmp')

    try:
        unzip_and_remove_macosx(zip_dir, extraction_dir)

        # Assuming the first directory name in the extraction_dir is the template name
        template_name = os.listdir(extraction_dir)[0]

        # Generate a unique suffix for the branch name
        unique_suffix = next(tempfile._get_candidate_names())

        # Extract username initials from the system's username
        whoami_output = subprocess.check_output(['whoami']).decode('utf-8').strip()
        parts = whoami_output.split('.')
        user_initials = parts[1][0] + parts[2][0] if len(parts) >= 3 else 'default'

        # Construct the full branch name
        full_branch_name = f"{user_initials}/{template_name}_{unique_suffix}-no-build"

        repo = Repo(git_repo_root)
        original_branch = repo.active_branch.name  # Capture the original branch
        create_branch_from_target(repo, default_branch, full_branch_name, GitCommandError)
        copy_files_to_templates(extraction_dir, templates_path)
        os.chdir(git_repo_root)
        perform_git_operations(repo, templates_path, full_branch_name, original_branch, GitCommandError)

        # Clean up the temporary directory after successful completion
        shutil.rmtree(extraction_dir)
        print(f"Temporary files cleaned up from {extraction_dir}")

    except Exception as e:
        print(f"An error occurred: {e}")
        print(f"Temporary files are located at {extraction_dir} for review")

        # Rollback changes in case of an error
        try:
            backup_current_state(repo, GitCommandError)
            rollback_to_backup(repo, GitCommandError)
        except Exception as rollback_error:
            print(f"Rollback failed: {rollback_error}")

if __name__ == "__main__":
    main()
