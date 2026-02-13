#!/usr/bin/env python3
"""
Sync word list files to GitHub repository with proper naming.

Converts underscore filenames (assets) to hyphen filenames (GitHub).
Example: cet6_core.json -> cet6-core.json
"""

import shutil
import subprocess
from pathlib import Path

ASSETS_DIR = Path(__file__).parent.parent.parent / 'assets' / 'wordlists' / 'english'
GITHUB_DIR = Path('D:/pc-project/wordmaster-wordlists/english')

# File mapping: assets filename -> github filename
FILE_MAPPING = {
    'cefr_a1.json': 'cefr-a1.json',
    'cefr_a2.json': 'cefr-a2.json',
    'cet4.json': 'cet4-full.json',
    'cet4_core.json': 'cet4-core.json',
    'cet4_full.json': 'cet4-full.json',
    'cet6_core.json': 'cet6-core.json',
    'cet6_full.json': 'cet6-full.json',
    'kaoyan_core.json': 'kaoyan-core.json',
    'kaoyan_full.json': 'kaoyan-full.json',
    'toefl_core.json': 'toefl-core.json',
    'toefl_full.json': 'toefl-full.json',
    'sat_core.json': 'sat-core.json',
    'sat_full.json': 'sat-full.json',
    'zhongkao_core.json': 'zhongkao-core.json',
    'zhongkao_full.json': 'zhongkao-full.json',
    'gaokao_core.json': 'gaokao-core.json',
    'gaokao_full.json': 'gaokao-full.json',
}


def sync_files():
    """Sync asset files to GitHub repo with proper naming."""
    GITHUB_DIR.mkdir(parents=True, exist_ok=True)

    synced = []
    for asset_name, github_name in FILE_MAPPING.items():
        src = ASSETS_DIR / asset_name
        dst = GITHUB_DIR / github_name

        if src.exists():
            shutil.copy2(src, dst)
            size_mb = src.stat().st_size / (1024 * 1024)
            print(f"✓ {asset_name} -> {github_name} ({size_mb:.2f} MB)")
            synced.append(github_name)
        else:
            print(f"  {asset_name} (not found, skipping)")

    return synced


def git_commit_and_push(files: list[str]):
    """Commit and push changes to GitHub."""
    if not files:
        print("\nNo files to commit")
        return

    import os
    os.chdir(GITHUB_DIR.parent)

    # Add files
    subprocess.run(['git', 'add', '.'], check=True)

    # Check if there are changes
    result = subprocess.run(['git', 'status', '--porcelain'], capture_output=True, text=True)
    if not result.stdout.strip():
        print("\nNo changes to commit")
        return

    # Commit
    msg = f"Update word lists: {', '.join(f.replace('.json', '') for f in files[:5])}"
    if len(files) > 5:
        msg += f" and {len(files) - 5} more"

    subprocess.run(['git', 'commit', '-m', msg], check=True)

    # Push
    print("\nPushing to GitHub...")
    subprocess.run(['git', 'push'], check=True)
    print("✓ Pushed successfully")


def main():
    print("Syncing word lists to GitHub repository...\n")

    synced = sync_files()

    print(f"\n{len(synced)} files synced")

    if synced:
        response = input("\nCommit and push to GitHub? (y/n): ")
        if response.lower() == 'y':
            git_commit_and_push(synced)


if __name__ == '__main__':
    main()
