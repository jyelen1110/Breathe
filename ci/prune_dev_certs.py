"""Revoke stale development certificates created by CI cloud signing.

Each ephemeral runner mints a fresh 'Created via API' development certificate;
the private keys die with the runner, so the certificates are pure garbage that
eventually hits Apple's account cap. Distribution certificates and anything not
named 'Created via API' are left untouched.
"""
import json
import os
import time
import urllib.request

import jwt

KEY_ID = os.environ["APPSTORE_KEY_ID"]
ISSUER_ID = os.environ["APPSTORE_ISSUER_ID"]
KEY_PATH = os.path.expanduser(f"~/private_keys/AuthKey_{KEY_ID}.p8")

with open(KEY_PATH) as f:
    private_key = f.read()

now = int(time.time())
token = jwt.encode(
    {"iss": ISSUER_ID, "iat": now - 30, "exp": now + 1200, "aud": "appstoreconnect-v1"},
    private_key,
    algorithm="ES256",
    headers={"kid": KEY_ID, "typ": "JWT"},
)

def request(method, url):
    req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        return resp.read()

listing = json.loads(request(
    "GET",
    "https://api.appstoreconnect.apple.com/v1/certificates"
    "?filter[certificateType]=DEVELOPMENT&limit=200",
))

revoked = 0
for cert in listing.get("data", []):
    name = cert["attributes"].get("displayName") or ""
    if not name.startswith("Created via API"):
        continue
    try:
        request("DELETE", f"https://api.appstoreconnect.apple.com/v1/certificates/{cert['id']}")
        revoked += 1
        print(f"revoked {cert['id']} ({name})")
    except Exception as error:  # noqa: BLE001 — a failed prune must not fail the build
        print(f"could not revoke {cert['id']}: {error}")

print(f"pruned {revoked} stale development certificate(s)")
