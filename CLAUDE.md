# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of utility scripts for Linux/Ubuntu system administration, focusing on:
- Media server setup and configuration (Sonarr, Radarr, NZBGet, Plex, Transmission)
- File management and renaming utilities
- Git workflow automation
- Network file system mounting (DFS/Active Directory)
- Video transcoding

The repository contains both Python scripts (with external dependencies) and Bash scripts (requiring various system utilities).

## Development Setup

### Installing Dependencies

```bash
# Install production dependencies
make install
# Or: pip install -r requirements.txt

# Install development dependencies
make install-dev
# Or: pip install -r requirements-dev.txt

# Set up pre-commit hooks
make setup-hooks
# Or: pre-commit install
```

### Development Tools

- **Makefile**: Run `make help` to see all available commands
- **Pre-commit hooks**: Automatically format and lint code before commits
- **Testing**: Run `make test` to execute unit tests
- **Linting**: Run `make lint` for Python and shell script linting
- **Formatting**: Run `make format` to auto-format Python code

## Python Scripts

All Python scripts now follow a standardized structure with:
- Proper argument parsing with `argparse`
- Logging to both console and `~/.local/log/`
- Dry-run mode support (`--dry-run` or `-n`)
- Verbose mode (`--verbose` or `-v`)
- Help documentation (`--help` or `-h`)

### Dependencies

Install Python dependencies with:
```bash
pip install -r requirements.txt
```

Required packages: `fuzzywuzzy`, `GitPython`, `python_magic`

### Key Scripts

**backup_to_git.py**
- Backs up application configs from `/var/lib` to a Git repository
- Supports: Sonarr, Radarr, Lidarr, Whisparr, Sabnzbd
- Automatically commits and pushes changes
- Usage: `./backup_to_git.py [OPTIONS]`
  - `--backup-dir DIR`: Source directory (default: `/var/lib`)
  - `--repo-dir DIR`: Git repository directory (default: `/home/chris/backups`)
  - `--branch BRANCH`: Git branch to push to (default: `main`)
  - `--apps APP [APP...]`: Backup only specific applications
  - `-n, --dry-run`: Preview without making changes
  - `-v, --verbose`: Enable verbose logging
- Logs to: `~/.local/log/backup_to_git.log`

**push_to_PR.py**
- Automates template deployment workflow for a larger project
- Extracts templates from ZIP files, creates feature branches, and pushes to remote
- Uses UUID-based branch naming: `{initials}/{template-name}-{uuid}-no-build`
- Usage: `./push_to_PR.py [-d BRANCH] [-z ZIP_DIR] [-f ZIP_FILE]`
- Default branch: `release/17`
- Default template location: `~/Downloads/templates`

**fuzzyRename.py**
- Renames AVI files to match corresponding MKV files using fuzzy string matching
- Usage: `./fuzzyRename.py [OPTIONS] DIRECTORY`
  - `-t, --threshold N`: Minimum match ratio 0-100 (default: 70)
  - `-n, --dry-run`: Preview without renaming
  - `-v, --verbose`: Enable verbose logging
- Example: `./fuzzyRename.py -t 80 ~/Videos`

**rename_files.py**
- Renames single video files to match their parent directory name
- Uses python-magic to detect video files by MIME type
- Usage: `./rename_files.py [OPTIONS] [DIRECTORY]`
  - `-n, --dry-run`: Preview without renaming
  - `-v, --verbose`: Enable verbose logging
- If no directory provided, will prompt interactively

## Bash Scripts

All bash scripts use:
- Color-coded output (RED, YELLOW, GREEN) for user feedback
- Strict error handling (`set -euo pipefail`)
- Help documentation (use `--help` or `-h`)

**media_setup.sh**
- Interactive installer for media server applications
- Must be run with sudo
- Provides menu-driven installation for: NZBGet, Transmission, Radarr, Sonarr, Plex
- Creates systemd service files for each application
- Configures services to run as the logged-in user
- Automatically enables services at boot

**dfs_ubuntu.sh**
- Mounts DFS shares and Active Directory home directories on Ubuntu
- Must be run with sudo
- Requires packages: `cifs-utils`, `keyutils`
- Modifies system files: `/etc/nsswitch.conf`, `/etc/request-key.conf`
- Creates fstab entries with Kerberos authentication (`sec=krb5`)
- Sets up autostart desktop files for mounting on login
- Creates NetworkManager dispatcher script for VPN-triggered mounts
- Mount points created in user's home directory

**transcode.sh**
- Transcodes MKV files to H.265 (HEVC) codec
- Usage: `./transcode.sh [OPTIONS] [DIRECTORY]`
  - `-c, --crf N`: CRF value for quality (default: 30, recommend: 18-28)
  - `-p, --preset PRESET`: Encoding preset (default: slow)
  - `-s, --suffix SUFFIX`: Output suffix (default: `_h265`)
  - `-n, --dry-run`: Preview without transcoding
  - `-v, --verbose`: Show ffmpeg output
- Example: `./transcode.sh -c 23 -p faster ~/Videos`
- Lower CRF = better quality, larger files
- Slower presets = better compression, longer encoding time

**jimmy_files.sh**
- Utility to move MP4 files from nested directories
- Usage: `./jimmy_files.sh [OPTIONS]`
  - `--source DIR`: Source directory (default: `/mnt/extHD/Downloads/complete/jimmy`)
  - `--dry-run`: Preview without moving/deleting
- Asks for confirmation before moving files and deleting directories
- Safety features prevent accidental data loss

## Ansible Playbooks

**media_setup.yml**
- Automated media server setup (alternative to media_setup.sh)
- Installs: Sonarr, Radarr, Transmission, NZBGet, Plex
- Mounts external HDD via fstab (UUID-based)
- Requires inventory with `server` host defined
- Run with: `ansible-playbook media_setup.yml`

**update.yml**
- System update playbook for all hosts
- Cross-distro compatible (RedHat and Debian families)
- Updates all packages, removes unused packages
- Automatically reboots if `/var/run/reboot-required` exists
- Run with: `ansible-playbook update.yml`

## Testing

Basic unit tests are provided in the `tests/` directory:
- `test_fuzzyRename.py`: Tests for fuzzy file renaming

Run tests with:
```bash
make test
# Or: pytest tests/ -v
```

## Code Quality

### Linting
```bash
# Run all linters
make lint

# Python only
make lint-python

# Shell scripts only
make lint-shell
```

### Formatting
```bash
# Format Python code
make format
```

## Important Notes

### Git Operations
- Python scripts that push to Git expect specific branch structures and remote names
- `backup_to_git.py` pushes to configurable branch (default: `main`)
- `push_to_PR.py` creates branches with pattern: `{initials}/{name}-{uuid}-no-build`

### System Requirements
- Scripts assume Ubuntu/Debian-based systems
- Many scripts require sudo/root privileges
- External HDD mount points expect specific UUIDs (update fstab entries accordingly)
- DFS mounting requires Kerberos tickets and domain authentication

### Configuration
All scripts now support command-line configuration instead of hardcoded values:
- Use `--help` on any script to see available options
- Default values can be overridden via command-line arguments
- Python scripts log to `~/.local/log/` directory

### Best Practices
- Always use `--dry-run` mode first to preview changes
- Use `--verbose` for debugging issues
- Check script help documentation with `--help`
- Run tests before committing changes: `make test`
- Use pre-commit hooks to ensure code quality: `make setup-hooks`
