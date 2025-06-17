#!/usr/bin/env python3
"""
MathFonts Release Script

This script automates the process of creating releases for the MathFonts repository:
1. Builds fonts using the Makefile
2. Creates versioned archives of the dist/ directory
3. Creates GitHub releases with the font packages
4. Handles version tagging and change log generation

Usage:
    python release.py [--version VERSION] [--dry-run] [--token TOKEN]
    
Arguments:
    --version VERSION   Specify version (default: auto-increment patch)
    --dry-run          Show what would be done without executing
    --token TOKEN      GitHub personal access token (or set GITHUB_TOKEN env var)
"""

import argparse
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import requests


class MathFontsReleaser:
    def __init__(self, dry_run: bool = False, github_token: Optional[str] = None):
        self.dry_run = dry_run
        self.github_token = github_token or os.getenv('GITHUB_TOKEN')
        self.repo_owner = 'pde-rent'
        self.repo_name = 'MathFonts'
        self.base_dir = Path(__file__).parent
        self.dist_dir = self.base_dir / 'dist'
        
    def log(self, message: str, level: str = 'INFO'):
        """Log a message with timestamp and level."""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        prefix = '[DRY-RUN] ' if self.dry_run else ''
        print(f"{prefix}[{timestamp}] {level}: {message}")
        
    def run_command(self, cmd: List[str], capture_output: bool = True) -> subprocess.CompletedProcess:
        """Run a command, optionally in dry-run mode."""
        cmd_str = ' '.join(cmd)
        self.log(f"Running: {cmd_str}")
        
        if self.dry_run:
            return subprocess.CompletedProcess(cmd, 0, stdout=b'', stderr=b'')
            
        result = subprocess.run(cmd, capture_output=capture_output, text=True)
        if result.returncode != 0:
            self.log(f"Command failed: {cmd_str}", 'ERROR')
            self.log(f"Error output: {result.stderr}", 'ERROR')
            sys.exit(1)
        return result
        
    def get_current_version(self) -> str:
        """Get the current version from git tags."""
        try:
            result = self.run_command(['git', 'describe', '--tags', '--abbrev=0'])
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return 'v0.0.0'  # Default if no tags exist
            
    def increment_version(self, version: str, increment_type: str = 'patch') -> str:
        """Increment version number."""
        # Remove 'v' prefix if present
        version = version.lstrip('v')
        
        parts = version.split('.')
        if len(parts) != 3:
            return 'v1.0.0'
            
        major, minor, patch = map(int, parts)
        
        if increment_type == 'major':
            major += 1
            minor = 0
            patch = 0
        elif increment_type == 'minor':
            minor += 1
            patch = 0
        else:  # patch
            patch += 1
            
        return f'v{major}.{minor}.{patch}'
        
    def build_fonts(self):
        """Build all fonts using the Makefile."""
        self.log("Building fonts...")
        
        if not (self.base_dir / 'Makefile').exists():
            self.log("Makefile not found", 'ERROR')
            sys.exit(1)
            
        # Clean and build
        self.run_command(['make', 'clean'], capture_output=False)
        self.run_command(['make', 'all-parallel'], capture_output=False)
        
        if not self.dist_dir.exists():
            self.log("dist/ directory not created after build", 'ERROR')
            sys.exit(1)
            
        self.log("Font build completed successfully")
        
    def create_archives(self, version: str) -> Dict[str, Path]:
        """Create zip and tar.gz archives of the dist directory."""
        self.log(f"Creating archives for version {version}")
        
        archives = {}
        version_clean = version.lstrip('v')
        
        # Create zip archive
        zip_name = f"mathfonts-{version_clean}.zip"
        zip_path = self.base_dir / 'tmp' / zip_name
        zip_path.parent.mkdir(exist_ok=True)
        
        if not self.dry_run:
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                for root, dirs, files in os.walk(self.dist_dir):
                    for file in files:
                        file_path = Path(root) / file
                        arc_path = file_path.relative_to(self.dist_dir)
                        zf.write(file_path, f"mathfonts-{version_clean}/{arc_path}")
                        
        archives['zip'] = zip_path
        self.log(f"Created ZIP archive: {zip_path}")
        
        # Create tar.gz archive
        tar_name = f"mathfonts-{version_clean}.tar.gz"
        tar_path = self.base_dir / 'tmp' / tar_name
        
        if not self.dry_run:
            with tarfile.open(tar_path, 'w:gz') as tf:
                tf.add(self.dist_dir, arcname=f"mathfonts-{version_clean}")
                
        archives['tar.gz'] = tar_path
        self.log(f"Created TAR.GZ archive: {tar_path}")
        
        return archives
        
    def get_font_summary(self) -> Dict[str, any]:
        """Generate a summary of fonts in the distribution."""
        if not self.dist_dir.exists():
            return {}
            
        summary = {
            'total_fonts': 0,
            'total_size_mb': 0,
            'font_families': [],
            'math_fonts': []
        }
        
        for family_dir in self.dist_dir.iterdir():
            if not family_dir.is_dir():
                continue
                
            family_info = {
                'name': family_dir.name,
                'fonts': [],
                'size_mb': 0
            }
            
            for font_file in family_dir.glob('*.woff2'):
                size_bytes = font_file.stat().st_size
                size_mb = size_bytes / (1024 * 1024)
                
                family_info['fonts'].append({
                    'name': font_file.name,
                    'size_mb': round(size_mb, 2)
                })
                family_info['size_mb'] += size_mb
                summary['total_size_mb'] += size_mb
                summary['total_fonts'] += 1
                
                # Check if it's a math font
                if 'math' in font_file.name.lower():
                    summary['math_fonts'].append(f"{family_dir.name}/{font_file.name}")
                    
            family_info['size_mb'] = round(family_info['size_mb'], 2)
            summary['font_families'].append(family_info)
            
        summary['total_size_mb'] = round(summary['total_size_mb'], 2)
        return summary
        
    def generate_release_notes(self, version: str, previous_version: str) -> str:
        """Generate release notes."""
        font_summary = self.get_font_summary()
        
        notes = f"""# MathFonts Release {version}

## Overview
This release contains {font_summary.get('total_fonts', 0)} optimized WOFF2 math fonts from {len(font_summary.get('font_families', []))} font families, totaling {font_summary.get('total_size_mb', 0):.1f} MB.

## Font Families Included
"""
        
        for family in font_summary.get('font_families', []):
            notes += f"- **{family['name']}**: {len(family['fonts'])} fonts ({family['size_mb']:.1f} MB)\n"
            
        notes += f"""
## Math Fonts
The following fonts provide mathematical symbol support:
"""
        
        for math_font in font_summary.get('math_fonts', []):
            notes += f"- {math_font}\n"
            
        notes += f"""
## Installation
1. Download the archive (ZIP or TAR.GZ)
2. Extract to your desired location
3. Reference fonts in your CSS or LaTeX documents

## Usage
These fonts are optimized for web use and mathematical typesetting. See the main repository README for integration examples.

## Build Information
- Built with optimized WOFF2 compression
- All fonts include proper mathematical Unicode coverage
- Compatible with modern browsers and typesetting systems

---
*Generated automatically by the MathFonts release system*
"""
        return notes
        
    def create_github_release(self, version: str, archives: Dict[str, Path]) -> bool:
        """Create a GitHub release with the archives."""
        if not self.github_token:
            self.log("GitHub token required for release creation", 'ERROR')
            return False
            
        previous_version = self.get_current_version()
        release_notes = self.generate_release_notes(version, previous_version)
        
        # Create the release
        url = f"https://api.github.com/repos/{self.repo_owner}/{self.repo_name}/releases"
        headers = {
            'Authorization': f'token {self.github_token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        release_data = {
            'tag_name': version,
            'name': f'MathFonts {version}',
            'body': release_notes,
            'draft': False,
            'prerelease': False
        }
        
        self.log(f"Creating GitHub release {version}")
        
        if self.dry_run:
            self.log("Would create release with data:")
            self.log(json.dumps(release_data, indent=2))
            return True
            
        response = requests.post(url, headers=headers, json=release_data)
        
        if response.status_code != 201:
            self.log(f"Failed to create release: {response.status_code}", 'ERROR')
            self.log(response.text, 'ERROR')
            return False
            
        release_info = response.json()
        upload_url = release_info['upload_url'].replace('{?name,label}', '')
        
        # Upload archives
        for archive_type, archive_path in archives.items():
            self.upload_release_asset(upload_url, archive_path)
            
        self.log(f"Successfully created release: {release_info['html_url']}")
        return True
        
    def upload_release_asset(self, upload_url: str, asset_path: Path):
        """Upload a file to the GitHub release."""
        headers = {
            'Authorization': f'token {self.github_token}',
            'Content-Type': 'application/octet-stream'
        }
        
        params = {'name': asset_path.name}
        
        self.log(f"Uploading {asset_path.name}")
        
        with open(asset_path, 'rb') as f:
            response = requests.post(upload_url, headers=headers, params=params, data=f)
            
        if response.status_code != 201:
            self.log(f"Failed to upload {asset_path.name}: {response.status_code}", 'ERROR')
            self.log(response.text, 'ERROR')
        else:
            self.log(f"Successfully uploaded {asset_path.name}")
            
    def create_git_tag(self, version: str):
        """Create and push a git tag."""
        self.log(f"Creating git tag {version}")
        self.run_command(['git', 'tag', '-a', version, '-m', f'Release {version}'])
        self.run_command(['git', 'push', 'origin', version])
        
    def cleanup_archives(self, archives: Dict[str, Path]):
        """Clean up temporary archive files."""
        for archive_path in archives.values():
            if archive_path.exists() and not self.dry_run:
                archive_path.unlink()
                self.log(f"Cleaned up {archive_path}")
                
    def release(self, version: Optional[str] = None) -> bool:
        """Execute the complete release process."""
        try:
            # Determine version
            if not version:
                current_version = self.get_current_version()
                version = self.increment_version(current_version)
                
            self.log(f"Creating release {version}")
            
            # Build fonts
            self.build_fonts()
            
            # Create archives
            archives = self.create_archives(version)
            
            # Create GitHub release
            success = self.create_github_release(version, archives)
            
            if success:
                # Create git tag
                self.create_git_tag(version)
                
                self.log(f"Release {version} completed successfully!")
            else:
                self.log("Release creation failed", 'ERROR')
                return False
                
        except Exception as e:
            self.log(f"Release failed: {str(e)}", 'ERROR')
            return False
        finally:
            # Cleanup
            if 'archives' in locals():
                self.cleanup_archives(archives)
                
        return True


def main():
    parser = argparse.ArgumentParser(description='Create a MathFonts release')
    parser.add_argument('--version', help='Release version (e.g., v1.2.3)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done')
    parser.add_argument('--token', help='GitHub personal access token')
    
    args = parser.parse_args()
    
    releaser = MathFontsReleaser(dry_run=args.dry_run, github_token=args.token)
    
    success = releaser.release(args.version)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main() 