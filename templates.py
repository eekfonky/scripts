#!/usr/bin/env python3

import os
import shutil
import sys
import subprocess
import re
import importlib
import tempfile
import zipfile

def installAndImport(package, module_name=None):
    module_name = module_name if module_name else package
    try:
        importlib.import_module(module_name)
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        importlib.import_module(module_name)

def unzip_and_remove_macosx(directory, extraction_path):
    for filename in os.listdir(directory):
        if filename.endswith('.zip'):
            zip_file_path = os.path.join(directory, filename)
            with zipfile.ZipFile(zip_file_path, 'r') as zip_ref:
                zip_ref.extractall(extraction_path)

            macosx_dir = os.path.join(extraction_path, '__MACOSX')
            if os.path.exists(macosx_dir) and os.path.isdir(macosx_dir):
                shutil.rmtree(macosx_dir)

            os.remove(zip_file_path)
            print(f"Extracted {filename} to {extraction_path}")

def create_branch_from_target(repo, target_branch, new_branch, GitCommandError):
    try:
        original_branch = repo.active_branch.name
        if orginal_branch != target_branch:
            repo.git.checkout(target_branch)
            repo.git.pull()  # Pull the latest changes from the remote repository
        repo.git.checkout('-b', new_branch)
        print(f"New branch '{new_branch}' created successfully from '{target_branch}'.")
    except GitCommandError as e:
        print(f"Error: {e}")

def ensure_directory_exists(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)

def copy_files_to_templates(extraction_dir, template_dir):
    # Dynamically get the first (top-level) directory name within the extraction directory
    try:
        top_level_dir_name = next(os.walk(extraction_dir))[1][0]
    except IndexError:
        print(f"No directories found in the extraction directory: {extraction_dir}")
        return

    top_level_dir_path = os.path.join(extraction_dir, top_level_dir_name)

    for dirpath, _, filenames in os.walk(top_level_dir_path):
        # Create a relative path from the top-level directory
        relative_dir = os.path.relpath(dirpath, top_level_dir_path)
        destination_dir = os.path.join(template_dir, top_level_dir_name, relative_dir)

        print(f"Source Directory: {dirpath}")
        print(f"Destination Directory: {destination_dir}")

        # Create the destination directory if it does not exist
        if not os.path.exists(destination_dir):
            os.makedirs(destination_dir)
            print(f"Created directory: {destination_dir}")

        # Copy each file in the current directory to the destination
        for filename in filenames:
            source_file = os.path.join(dirpath, filename)
            destination_file = os.path.join(destination_dir, filename)
            shutil.copy(source_file, destination_file)
            print(f"Copied {filename} to {destination_dir}")

def perform_git_operations(repo, template_dir, branch_name, original_branch, GitCommandError):
    try:
        repo.index.add([template_dir])
        repo.index.commit("Update templates")

        push_command = ["git", "push", "origin", branch_name]
        push_result = subprocess.check_output(push_command, text=True)

        if "Everything up-to-date" in push_result:
            print("Everything up-to-date. No changes to push.")
        else:
            print(push_result)

            # Checkout the original branch to allow removal of temp branch
            repo.git.checkout(original_branch)

            # Remove the local branch
            try:
                repo.git.branch('-D', branch_name)
                print(f"Local branch '{branch_name}' removed.")
            except GitCommandError as e:
                print(f"Error removing local branch: {e}")

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
    template_dir = "~/code/dev/server/trunk/services/src/main/resources/templates"
    default_branch = "release/17"
    zip_dir = "~/Downloads/email-sms-zips" # Where you save the zipped templated from Slack to
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
