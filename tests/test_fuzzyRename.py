#!/usr/bin/env python3
"""
Unit tests for fuzzyRename.py
"""

import unittest
import tempfile
import os
from pathlib import Path
import sys

# Add parent directory to path to import fuzzyRename
sys.path.insert(0, str(Path(__file__).parent.parent))
from fuzzyRename import fuzzy_rename_avi


class TestFuzzyRename(unittest.TestCase):
    """Test cases for fuzzy renaming functionality."""

    def setUp(self):
        """Set up test fixtures."""
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.test_dir)

    def test_renames_matching_files(self):
        """Test that AVI files are renamed to match MKV files."""
        # Create test files
        mkv_file = Path(self.test_dir, "movie_2023_1080p.mkv")
        avi_file = Path(self.test_dir, "movie.avi")
        mkv_file.touch()
        avi_file.touch()

        # Run rename
        renamed_count = fuzzy_rename_avi(self.test_dir, threshold=50)

        # Check renamed file exists
        expected_file = Path(self.test_dir, "movie_2023_1080p.avi")
        self.assertTrue(expected_file.exists(), "Renamed file should exist")
        self.assertFalse(avi_file.exists(), "Original file should be renamed")
        self.assertEqual(renamed_count, 1, "Should rename 1 file")

    def test_no_rename_below_threshold(self):
        """Test that files below threshold are not renamed."""
        # Create test files with very different names
        mkv_file = Path(self.test_dir, "completely_different_name.mkv")
        avi_file = Path(self.test_dir, "movie.avi")
        mkv_file.touch()
        avi_file.touch()

        # Run rename with high threshold
        renamed_count = fuzzy_rename_avi(self.test_dir, threshold=90)

        # Check original file still exists
        self.assertTrue(avi_file.exists(), "Original file should not be renamed")
        self.assertEqual(renamed_count, 0, "Should not rename any files")

    def test_handles_multiple_avi_files(self):
        """Test handling of multiple AVI files."""
        # Create test files
        Path(self.test_dir, "movie1.mkv").touch()
        Path(self.test_dir, "movie2.mkv").touch()
        Path(self.test_dir, "movie1_old.avi").touch()
        Path(self.test_dir, "movie2_old.avi").touch()

        # Run rename
        renamed_count = fuzzy_rename_avi(self.test_dir, threshold=50)

        # Check both files were renamed
        self.assertTrue(Path(self.test_dir, "movie1.avi").exists())
        self.assertTrue(Path(self.test_dir, "movie2.avi").exists())
        self.assertEqual(renamed_count, 2, "Should rename 2 files")

    def test_no_avi_files(self):
        """Test handling when no AVI files are present."""
        # Create only MKV file
        Path(self.test_dir, "movie.mkv").touch()

        # Run rename
        renamed_count = fuzzy_rename_avi(self.test_dir)

        # Should return 0
        self.assertEqual(renamed_count, 0, "Should rename 0 files")

    def test_no_mkv_files(self):
        """Test handling when no MKV files are present."""
        # Create only AVI file
        Path(self.test_dir, "movie.avi").touch()

        # Run rename
        renamed_count = fuzzy_rename_avi(self.test_dir)

        # Should return 0
        self.assertEqual(renamed_count, 0, "Should rename 0 files")

    def test_dry_run_mode(self):
        """Test that dry-run mode doesn't actually rename files."""
        # Create test files
        mkv_file = Path(self.test_dir, "movie_2023.mkv")
        avi_file = Path(self.test_dir, "movie.avi")
        mkv_file.touch()
        avi_file.touch()

        # Run in dry-run mode
        renamed_count = fuzzy_rename_avi(self.test_dir, dry_run=True)

        # Original file should still exist
        self.assertTrue(avi_file.exists(), "Original file should not be renamed in dry-run")
        expected_file = Path(self.test_dir, "movie_2023.avi")
        self.assertFalse(expected_file.exists(), "New file should not be created in dry-run")
        # But it should count what would be renamed
        self.assertEqual(renamed_count, 0, "Dry run should not count as renamed")


if __name__ == "__main__":
    unittest.main()
