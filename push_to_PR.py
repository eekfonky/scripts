#!/usr/bin/env python3

import argparse
import logging
import os
import shutil
import sys
import subprocess
import importlib
import tempfile
import uuid
import zipfile
import git
import re
from git import Repo, GitCommandError

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(lineno)d: %(message)s")

# Define default values in a dictionary
DEFAULTS = {
	"default_branch": "release/17",
	"zip_dir": os.path.abspath(os.path.expanduser("~/Downloads/templates")),
}

def parse_arguments():
	"""Parses command-line arguments."""
	parser = argparse.ArgumentParser(description='''
	This script handles git repositories and templates based on internal defaults or command-line overrides.
	Use command-line options to specify custom settings for the script's operation.''')
	parser.add_argument('--def-branch', '-d', default=DEFAULTS["default_branch"],
						help='Default git branch name. Default is "%(default)s".')
	parser.add_argument('--zip-dir', '-z', default=DEFAULTS["zip_dir"],
						help='Directory for zipped templates. Default is "%(default)s".')
	parser.add_argument('--zip_file', '-f', type=str, default=None, nargs = '?',
						help='Specify the .zip filename explicitly. Defaults to the zip_dir if not specified.')
	return parser.parse_args()

def install_and_import(package, module_name=None):
	"""Installs a package if needed and imports it."""
	module_name = module_name if module_name else package
	try:
		importlib.import_module(module_name)
	except ImportError:
		subprocess.check_call([sys.executable, "-m", "pip", "install", package])
		importlib.import_module(module_name)

def ensure_directory_exists(directory):
	if not os.path.exists(directory):
		os.makedirs(directory)

def unzip_templates(zip_dir, extraction_path):
	"""Extracts a template ZIP, handling 'email' and 'sms' directories, preserving nested structures,"""

	if os.path.isdir(zip_dir):
		filename = next(f for f in os.listdir(zip_dir) if f.endswith('.zip'))
		zip_file_path = os.path.join(zip_dir, filename)
	else:
		filename = os.path.basename(zip_dir)
		zip_file_path = os.path.abspath(os.path.expanduser(zip_dir))

	if not zip_file_path:
		raise FileNotFoundError("No ZIP file found in the directory or provided file")

	template_name = os.path.splitext(filename)[0]

	# Rename template_name if it has spaces (optional)
	base_name, ext = os.path.splitext(template_name)
	if ' ' in base_name:
		new_base_name = base_name.replace(' ', '-')
		template_name = new_base_name + ext

	with zipfile.ZipFile(zip_file_path, 'r') as zip_ref:
		top_level_dirs = [name for name in zip_ref.namelist() if name.endswith('/')]

		if any(name.startswith('email/') or name.startswith('sms/') for name in top_level_dirs):  # Change here
			# Create the template_name directory within the extraction path
			brand_path = os.path.join(extraction_path, template_name)
			os.makedirs(brand_path, exist_ok=True)

			# Extract the ZIP contents into the template_name directory
			zip_ref.extractall(brand_path)
		else:
			# Extract directly (no 'email' or 'sms' at top level)
			zip_ref.extractall(extraction_path) 

	# Cleanup __MACOSX Directory
	macosx_dir = os.path.join(extraction_path, '__MACOSX')
	if os.path.exists(macosx_dir) and os.path.isdir(macosx_dir):
		shutil.rmtree(macosx_dir)

	logging.info(f"Extracted {filename} to {extraction_path}")
	return template_name, filename

def copy_templates_to_destination(extraction_dir, template_dir):
	"""Copies extracted templates, overwrites matching files, adds new files, and skips hidden files."""

	for subdir in os.listdir(extraction_dir):
		source_dir = os.path.join(extraction_dir, subdir)
		destination_dir = os.path.join(template_dir, subdir)

		# Filter out any hidden files before copying
		non_hidden_files = [f for f in os.listdir(source_dir) if not f.startswith('.')]

		# Copy with merge
		shutil.copytree(source_dir, destination_dir, ignore=shutil.ignore_patterns('.*'), dirs_exist_ok=True)
		logging.info(f"Merged {subdir} into {destination_dir}")

def cleanup(extraction_dir, args, filename=None):
	"""Clean up temporary files and optionally the original ZIP file(s)."""

	shutil.rmtree(extraction_dir)
	logging.info(f"Temporary files cleaned up from {extraction_dir}")

	# Use args.zip_dir if provided with -z flag
	zip_dir = args.zip_dir if args and args.zip_dir else None

	if filename:
		if args and args.zip_file and os.path.isfile(args.zip_file):  # If -f flag used, filename is the complete path
			original_zip_file = args.zip_file
		else:
			original_zip_file = os.path.join(zip_dir, filename)

		if os.path.isfile(original_zip_file):
			os.remove(original_zip_file)
			logging.debug(f"Original ZIP file removed: {original_zip_file}")
		else:
			logging.warning(f"No {filename} for ZIP file deletion.")


class GitRepoManager:
	def __init__(self, repo_path):
		self.repo = Repo(repo_path)

	def prepare_and_create_branch(self, default_branch, template_name, user_initials):
		"""Prepares the repository	and creates a new branch for template updates."""
		original_branch = self.repo.active_branch.name
		unique_suffix = str(uuid.uuid4())[:8]
		new_branch = f"{user_initials}/{template_name}-{unique_suffix}-no-build"
		stashed_changes = False

		try:
			if self.repo.is_dirty():
				logging.info("Changes detected in the working directory. Attempting to stash changes...")
				self.repo.git.stash('save', "Stashing changes before template update")
				logging.info("All changes stashed.")
				stashed_changes = True

			self.repo.git.checkout(default_branch)
			self.repo.git.pull()
			self.repo.git.checkout("HEAD", b=new_branch)
			logging.info(f"New branch '{new_branch}' created from '{default_branch}'.")

			return True, new_branch, original_branch, stashed_changes

		except git.exc.GitCommandError as e:
			logging.error(f"Error preparing repository or creating branch: {e}")
			return False, None, None, stashed_changes

	def handle_updates(self, template_dir, branch_name, original_branch, stashed_changes):
		"""Stages, commits, and pushes template changes"""
		try:
			if branch_name not in self.repo.git.branch().split():
				sys.exit(f"Branch '{branch_name}' does not exist locally. Cannot proceed with push.")
			self.repo.git.add(template_dir)
			self.repo.index.commit("Update templates")
			subprocess.run(["git", "push", "origin", branch_name, "--progress"])
			self.repo.git.checkout(original_branch)
			if stashed_changes:
				self.repo.git.stash('pop')
			self.repo.git.branch('-D', branch_name)
			logging.info(f"Templates pushed and local branch '{branch_name}' removed.")
		except git.exc.GitCommandError as e:
			logging.error(f"Git operations failed: {e}")

	def backup_current_state(self):
		# Create a temporary branch to hold the current state
		try:
			self.repo.git.branch('temp_backup_branch')
		except GitCommandError:
			# Branch already exists, force update it
			self.repo.git.branch('-D', 'temp_backup_branch')
			self.repo.git.branch('temp_backup_branch')

	def rollback_to_backup(self):
		try:
			# Reset the current branch to the backup branch
			self.repo.git.reset('--hard', 'temp_backup_branch')
			print("Rollback successful.")
		except GitCommandError as e:
			print(f"Rollback failed: {e}")

def main():
	args = parse_arguments()
	install_and_import('GitPython', 'git')
	from git import Repo, GitCommandError

	# Script variables with argparse and dynamic paths
	script_dir = os.path.dirname(os.path.abspath(__file__))
	os.chdir(script_dir)
	git_repo_root = os.path.abspath(os.path.join(script_dir, "../../../"))	# Example path
	template_dir = os.path.join(git_repo_root, "server/trunk/services/src/main/resources/templates")

	# Assign zip_dir with the highest priority to args.zip_file
	if args.zip_file:
		zip_dir = os.path.abspath(os.path.expanduser(args.zip_file))
		if not os.path.isfile(zip_dir):
			raise ValueError("Error: When using the -f flag, you must provide a valid file path to a ZIP file.")
	else:
		# Assign conditionally, ONLY if zip_file wasn't provided
		zip_dir = args.zip_dir	# Use provided zip_dir from arguments
		if args.zip_dir and not os.path.isdir(zip_dir):
			raise ValueError("Error: When using the -z flag, you must provide a directory containing ZIP files.")

		# If no command-line option given, THEN use the default
		if not zip_dir:
			zip_dir = os.path.abspath(os.path.expanduser(DEFAULTS["zip_dir"]))

	default_branch = args.def_branch
	ensure_directory_exists(zip_dir)
	extraction_dir = tempfile.mkdtemp(prefix='templates-extraction-', dir='/tmp')

	try:
		if len(zip_dir) == 0:
			print("Empty directory or file not found")
			raise Exception('zip template dir is empty')

		template_name, filename = unzip_templates(zip_dir, extraction_dir)
		repo_manager = GitRepoManager(git_repo_root)
		# Calculate user_initials
		whoami_output = subprocess.check_output(['whoami']).decode('utf-8').strip()
		parts = whoami_output.split('.')
		user_initials = parts[1][0] + parts[-1][0]	# Extract initials from first and last name
		success, branch_name, original_branch, stashed_changes = repo_manager.prepare_and_create_branch(default_branch, template_name, user_initials)
		if not success:
			logging.error("Failed to create the new branch. Aborting script.")
			sys.exit(1)
		copy_templates_to_destination(extraction_dir, template_dir)
		repo_manager.handle_updates(template_dir, branch_name, original_branch, stashed_changes)
		if success:
			cleanup(extraction_dir, args, filename)

	except Exception as e:
		logging.error(f"An error occurred: {e}")
		repo_manager.backup_current_state()
		repo_manager.rollback_to_backup()

# Call your main function
if __name__ == "__main__":
	main()