"""Download TTS models from GitHub and upload to Gitee releases."""
import json
import os
import sys
import time
import urllib.request
import urllib.error

TOKEN = sys.argv[1] if len(sys.argv) > 1 else ""
OWNER = "lratusa"
REPO = "wordmaster-tts-models"
TAG = "v1"

GITHUB_BASE = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models"

MODELS = [
    "vits-piper-en_US-lessac-medium.tar.bz2",
    "vits-piper-en_GB-alba-medium.tar.bz2",
]

TEMP_DIR = os.path.join(os.path.dirname(__file__), "..", "temp_tts_download")


def create_release():
    """Create a release on Gitee."""
    url = f"https://gitee.com/api/v5/repos/{OWNER}/{REPO}/releases"
    payload = {
        "access_token": TOKEN,
        "tag_name": TAG,
        "name": "TTS Models v1",
        "body": "sherpa-onnx TTS models mirrored from GitHub for China users.",
        "target_commitish": "master",
    }
    try:
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        release_id = data.get("id")
        print(f"Created release '{TAG}' (id={release_id})")
        return release_id
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:300]
        if "已存在" in body or "already" in body.lower():
            print(f"Release '{TAG}' already exists, fetching...")
            return get_existing_release()
        print(f"Error creating release: {e.code} {body}")
        return None


def get_existing_release():
    """Get existing release ID."""
    url = f"https://gitee.com/api/v5/repos/{OWNER}/{REPO}/releases?access_token={TOKEN}"
    try:
        req = urllib.request.Request(url)
        resp = urllib.request.urlopen(req, timeout=30)
        releases = json.loads(resp.read())
        for r in releases:
            if r.get("tag_name") == TAG:
                rid = r.get("id")
                # Check existing assets
                assets = r.get("assets", [])
                existing = [a.get("name") for a in assets]
                print(f"Found release id={rid}, existing assets: {existing}")
                return rid
    except Exception as e:
        print(f"Error fetching releases: {e}")
    return None


def download_model(filename):
    """Download model from GitHub to temp directory."""
    os.makedirs(TEMP_DIR, exist_ok=True)
    local_path = os.path.join(TEMP_DIR, filename)

    if os.path.exists(local_path):
        size_mb = os.path.getsize(local_path) / (1024 * 1024)
        if size_mb > 10:  # Seems like a complete download
            print(f"  Already downloaded: {filename} ({size_mb:.1f} MB)")
            return local_path

    url = f"{GITHUB_BASE}/{filename}"
    print(f"  Downloading {filename} from GitHub...")
    try:
        urllib.request.urlretrieve(url, local_path)
        size_mb = os.path.getsize(local_path) / (1024 * 1024)
        print(f"  Downloaded: {size_mb:.1f} MB")
        return local_path
    except Exception as e:
        print(f"  Download failed: {e}")
        return None


def upload_to_release(release_id, local_path, filename):
    """Upload file as release asset via Gitee API."""
    url = f"https://gitee.com/api/v5/repos/{OWNER}/{REPO}/releases/{release_id}/attach_files"

    size_mb = os.path.getsize(local_path) / (1024 * 1024)
    print(f"  Uploading {filename} ({size_mb:.1f} MB) to Gitee release...")

    # Use multipart form upload
    import mimetypes
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

    with open(local_path, "rb") as f:
        file_data = f.read()

    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="access_token"\r\n\r\n'
        f"{TOKEN}\r\n"
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        f"Content-Type: application/octet-stream\r\n\r\n"
    ).encode() + file_data + f"\r\n--{boundary}--\r\n".encode()

    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        method="POST",
    )

    try:
        resp = urllib.request.urlopen(req, timeout=600)
        data = json.loads(resp.read())
        dl_url = data.get("browser_download_url", "")
        print(f"  UPLOADED: {filename}")
        print(f"  URL: {dl_url}")
        return True
    except urllib.error.HTTPError as e:
        body_text = e.read().decode()[:500]
        print(f"  Upload failed: {e.code} {body_text}")
        return False
    except Exception as e:
        print(f"  Upload failed: {e}")
        return False


def main():
    if not TOKEN:
        print("Usage: python upload_tts_to_gitee.py <gitee_access_token>")
        sys.exit(1)

    print("=== TTS Model Upload to Gitee ===\n")

    # Step 1: Create or get release
    release_id = create_release()
    if not release_id:
        print("Failed to create/get release")
        sys.exit(1)

    # Step 2: Download and upload each model
    for filename in MODELS:
        print(f"\nProcessing: {filename}")
        local_path = download_model(filename)
        if not local_path:
            print(f"  Skipping {filename} (download failed)")
            continue

        ok = upload_to_release(release_id, local_path, filename)
        if not ok:
            print(f"  FAILED to upload {filename}")

        time.sleep(2)

    print("\nDone!")


if __name__ == "__main__":
    main()
