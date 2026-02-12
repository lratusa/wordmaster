#!/usr/bin/env python3
"""
Coqui TTS Server for WordMaster App
Provides local text-to-speech via HTTP API.

Usage:
    python start_server.py

API Endpoints:
    GET /api/tts?text=hello&language-id=en  -> Returns WAV audio
    GET /health                              -> Health check
"""

import subprocess
import sys
import os

def main():
    # Use VITS model - fast and good quality, supports multiple languages
    # For Japanese: tts_models/ja/kokoro/tacotron2-DDC
    # For English: tts_models/en/ljspeech/vits
    # For multilingual: tts_models/multilingual/multi-dataset/xtts_v2 (slower but best quality)

    model = os.environ.get("TTS_MODEL", "tts_models/en/ljspeech/vits")
    port = os.environ.get("TTS_PORT", "5002")

    print(f"Starting Coqui TTS Server...")
    print(f"Model: {model}")
    print(f"Port: {port}")
    print(f"API: http://localhost:{port}/api/tts?text=hello")
    print("-" * 50)

    cmd = [
        sys.executable, "-m", "TTS.server.server",
        "--model_name", model,
        "--port", port,
    ]

    try:
        subprocess.run(cmd, check=True)
    except KeyboardInterrupt:
        print("\nServer stopped.")
    except Exception as e:
        print(f"Error: {e}")
        print("\nMake sure TTS is installed: pip install TTS")
        sys.exit(1)

if __name__ == "__main__":
    main()
