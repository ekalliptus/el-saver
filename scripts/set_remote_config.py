#!/usr/bin/env python3
"""
Set Firebase Remote Config for the ANR Saver auto-updater.

Updates these parameters (project: anrsaver):
  latest_version_name, latest_version_code, download_url_base, changelog, is_forced

Auth: a Firebase service-account JSON (Console -> Project Settings ->
Service Accounts -> Generate new private key). Point FIREBASE_SA_JSON at it
(default: scripts/.firebase-sa.json, gitignored).

Usage:
  scripts/set_remote_config.py \
    --version-name 1.6.0 --version-code 8 \
    --url-base https://github.com/anrdart/medsos_downloader/releases/download/v1.6.0 \
    --changelog "Perbaikan download YouTube & auto-update" [--forced]

Requires: google-auth, requests  (pip install -r scripts/requirements.txt)
"""
import argparse
import ipaddress
import os
import socket
import sys
from urllib.parse import urlparse

import requests
from google.oauth2 import service_account
from google.auth.transport.requests import Request

PROJECT_ID = "anrsaver"
SCOPES = ["https://www.googleapis.com/auth/firebase.remoteconfig"]
BASE = "https://firebaseremoteconfig.googleapis.com/v1/projects/anrsaver/remoteConfig"
ALLOWED_HOST = "firebaseremoteconfig.googleapis.com"


def _assert_safe_url(url: str):
    """Fixed-host HTTPS only; resolve DNS and block private/loopback/link-local
    targets so the request can never be pointed at internal services."""
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != ALLOWED_HOST:
        raise SystemExit(f"blocked non-{ALLOWED_HOST} URL: {url}")
    for family, _, _, _, sockaddr in socket.getaddrinfo(parsed.hostname, 443):
        ip = ipaddress.ip_address(sockaddr[0])
        if not ip.is_global:
            raise SystemExit(f"blocked non-public address for {parsed.hostname}: {ip}")


def _token(sa_path: str) -> str:
    creds = service_account.Credentials.from_service_account_file(
        sa_path, scopes=SCOPES
    )
    creds.refresh(Request())
    return creds.token


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version-name", required=True)
    ap.add_argument("--version-code", required=True, type=int)
    ap.add_argument("--url-base", required=True,
                    help="Folder holding app-<abi>-release.apk (e.g. a GitHub release)")
    ap.add_argument("--changelog", default="")
    ap.add_argument("--forced", action="store_true")
    ap.add_argument("--sa", default=os.getenv("FIREBASE_SA_JSON",
                    os.path.join(os.path.dirname(__file__), ".firebase-sa.json")))
    args = ap.parse_args()

    if not os.path.exists(args.sa):
        print(f"ERROR: service-account JSON not found: {args.sa}\n"
              "Download it from Firebase Console -> Project Settings -> "
              "Service Accounts -> Generate new private key.", file=sys.stderr)
        return 2

    token = _token(args.sa)
    headers = {"Authorization": f"Bearer {token}"}

    _assert_safe_url(BASE)

    # GET current template + ETag
    r = requests.get(BASE, headers={**headers, "Accept-Encoding": "gzip"},
                     timeout=30, allow_redirects=False)
    r.raise_for_status()
    template = r.json()
    etag = r.headers.get("ETag", "*")

    params = template.setdefault("parameters", {})

    def set_param(key: str, value: str):
        params[key] = {"defaultValue": {"value": str(value)}}

    set_param("latest_version_name", args.version_name)
    set_param("latest_version_code", args.version_code)
    set_param("download_url_base", args.url_base)
    set_param("changelog", args.changelog)
    set_param("is_forced", "true" if args.forced else "false")

    # PUT with If-Match to avoid clobbering concurrent edits
    put = requests.put(
        BASE,
        headers={**headers, "Content-Type": "application/json; UTF-8",
                 "If-Match": etag},
        json=template, timeout=30, allow_redirects=False,
    )
    put.raise_for_status()
    print(f"Remote Config updated: {args.version_name} (code {args.version_code})")
    print(f"  download_url_base = {args.url_base}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
