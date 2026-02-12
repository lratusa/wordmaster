#!/usr/bin/env python3
"""
Download sherpa-onnx TTS models for WordMaster app.

This script downloads the TTS model files and extracts them to the correct location.
Run this once before using TTS in the app.

Usage:
    python download_models.py [model_name]

Models:
    en-us   - English (US) - LibriTTS medium (default)
    en-gb   - English (GB) - Cori medium
    ja      - Japanese - Tohoku medium
    zh      - Chinese + English - Melo TTS
"""

import os
import sys
import tarfile
import urllib.request
import shutil
from pathlib import Path

MODELS = {
    'en-us': {
        'name': 'vits-piper-en_US-libritts_r-medium',
        'url': 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-libritts_r-medium.tar.bz2',
    },
    'en-gb': {
        'name': 'vits-piper-en_GB-cori-medium',
        'url': 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_GB-cori-medium.tar.bz2',
    },
    'ja': {
        'name': 'vits-piper-ja_JP-tohoku-medium',
        'url': 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-ja_JP-tohoku-medium.tar.bz2',
    },
    'zh': {
        'name': 'vits-melo-tts-zh_en',
        'url': 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2',
    },
}

def get_app_data_dir():
    """Get the app's documents directory based on platform."""
    if sys.platform == 'win32':
        return Path(os.environ['USERPROFILE']) / 'Documents' / 'wordmaster'
    elif sys.platform == 'darwin':
        return Path.home() / 'Library' / 'Application Support' / 'com.example.wordmaster'
    else:
        return Path.home() / '.local' / 'share' / 'wordmaster'

def download_file(url, dest_path):
    """Download a file with progress indicator."""
    print(f"Downloading: {url}")
    print(f"To: {dest_path}")

    def progress_hook(count, block_size, total_size):
        percent = int(count * block_size * 100 / total_size)
        print(f"\rProgress: {percent}%", end='', flush=True)

    urllib.request.urlretrieve(url, dest_path, progress_hook)
    print()  # New line after progress

def main():
    model_key = sys.argv[1] if len(sys.argv) > 1 else 'en-us'

    if model_key not in MODELS:
        print(f"Unknown model: {model_key}")
        print(f"Available models: {', '.join(MODELS.keys())}")
        sys.exit(1)

    model = MODELS[model_key]
    print(f"Downloading TTS model: {model['name']}")

    # Create directories
    app_dir = get_app_data_dir()
    tts_models_dir = app_dir / 'tts_models'
    tts_models_dir.mkdir(parents=True, exist_ok=True)

    # Download the model archive
    archive_path = tts_models_dir / f"{model['name']}.tar.bz2"
    download_file(model['url'], archive_path)

    # Extract the archive
    print(f"Extracting to: {tts_models_dir}")
    with tarfile.open(archive_path, 'r:bz2') as tar:
        tar.extractall(tts_models_dir)

    # Move files to the expected location
    extracted_dir = tts_models_dir / model['name']
    if extracted_dir.exists():
        # Copy model files to root of tts_models
        for item in extracted_dir.iterdir():
            dest = tts_models_dir / item.name
            if dest.exists():
                if dest.is_dir():
                    shutil.rmtree(dest)
                else:
                    dest.unlink()
            shutil.move(str(item), str(dest))

        # Clean up extracted directory
        extracted_dir.rmdir()

    # Clean up archive
    archive_path.unlink()

    print(f"\nModel installed successfully!")
    print(f"Location: {tts_models_dir}")
    print("\nThe app will automatically detect the model on next launch.")

if __name__ == '__main__':
    main()
