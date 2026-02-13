"""Upload word list files to Gitee repo via API with retry and rate limiting."""
import base64
import json
import os
import sys
import time
import urllib.request
import urllib.error

TOKEN = sys.argv[1] if len(sys.argv) > 1 else ""
OWNER = "lratusa"
REPO = "wordmaster-wordlists"
BASE_API = f"https://gitee.com/api/v5/repos/{OWNER}/{REPO}/contents"
ASSETS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "wordlists")

MAX_RETRIES = 3
DELAY_BETWEEN_UPLOADS = 2  # seconds


def api_request(url, data=None, method="GET"):
    """Make an API request with retry."""
    for attempt in range(MAX_RETRIES):
        try:
            if data is not None:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(data).encode(),
                    headers={"Content-Type": "application/json"},
                    method=method,
                )
            else:
                req = urllib.request.Request(url, method=method)
            resp = urllib.request.urlopen(req, timeout=120)
            return json.loads(resp.read()), resp.status
        except urllib.error.HTTPError as e:
            body = e.read().decode()[:300]
            if e.code == 404:
                return None, 404
            if attempt < MAX_RETRIES - 1:
                wait = (attempt + 1) * 5
                print(f"    HTTP {e.code}, retrying in {wait}s... ({body})")
                time.sleep(wait)
            else:
                print(f"    FAILED HTTP {e.code}: {body}")
                return None, e.code
        except Exception as e:
            if attempt < MAX_RETRIES - 1:
                wait = (attempt + 1) * 5
                print(f"    Error: {e}, retrying in {wait}s...")
                time.sleep(wait)
            else:
                print(f"    FAILED: {e}")
                return None, 0


def file_exists(remote_path):
    """Check if file already exists on Gitee, return sha if so."""
    url = f"{BASE_API}/{remote_path}?access_token={TOKEN}"
    data, status = api_request(url)
    if status == 200 and data and isinstance(data, dict):
        return data.get("sha", "")
    return None


def upload_file(local_path, remote_path):
    """Upload a single file to Gitee."""
    size_kb = os.path.getsize(local_path) / 1024

    # Check if already exists
    sha = file_exists(remote_path)
    if sha:
        print(f"  EXISTS   {remote_path} ({size_kb:.0f} KB) - skipping")
        return True

    with open(local_path, "rb") as f:
        content = base64.b64encode(f.read()).decode("ascii")

    payload = {
        "access_token": TOKEN,
        "content": content,
        "message": f"Add {remote_path}",
    }
    data, status = api_request(f"{BASE_API}/{remote_path}", payload, "POST")
    if status in (200, 201):
        print(f"  CREATED  {remote_path} ({size_kb:.0f} KB)")
        return True
    else:
        print(f"  ERROR    {remote_path} ({size_kb:.0f} KB) - status {status}")
        return False


def main():
    if not TOKEN:
        print("Usage: python upload_to_gitee.py <gitee_access_token>")
        sys.exit(1)

    # Collect all JSON files
    files = []
    for lang_dir in ["english", "japanese"]:
        lang_path = os.path.join(ASSETS_DIR, lang_dir)
        if not os.path.isdir(lang_path):
            continue
        for fname in sorted(os.listdir(lang_path)):
            if fname.endswith(".json"):
                local = os.path.join(lang_path, fname)
                remote = f"{lang_dir}/{fname}"
                files.append((local, remote))

    print(f"Found {len(files)} files to upload\n")

    success = 0
    failed = 0
    for i, (local, remote) in enumerate(files):
        ok = upload_file(local, remote)
        if ok:
            success += 1
        else:
            failed += 1

        # Rate limit delay (skip for last file and already-existing files)
        if i < len(files) - 1:
            time.sleep(DELAY_BETWEEN_UPLOADS)

    print(f"\nDone: {success} uploaded/existing, {failed} failed")


if __name__ == "__main__":
    main()
