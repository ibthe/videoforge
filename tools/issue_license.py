#!/usr/bin/env python3
"""Issue a VideoForge Ed25519 license token. Requires: python -m pip install cryptography

Keep the matching private key secret. Never put it into the app or distribute it.
Example:
  python tools/issue_license.py --private-key /secure/path/private.pem --license-id VF-0001 --days 365
  python tools/issue_license.py --private-key /secure/path/private.pem --license-id VF-0002 --days 365 --install-id <ID_FROM_APP>
"""
import argparse
import base64
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from cryptography.hazmat.primitives import serialization


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a signed VideoForge license key")
    parser.add_argument("--private-key", required=True, help="Path to Ed25519 PKCS8 PEM private key")
    parser.add_argument("--license-id", required=True, help="Human-readable license identifier")
    parser.add_argument("--days", type=int, default=365, help="License duration in days (default: 365)")
    parser.add_argument("--install-id", help="Optional install ID to bind the key to one app installation")
    args = parser.parse_args()
    if args.days < 1 or args.days > 36500:
        parser.error("--days must be between 1 and 36500")
    key = serialization.load_pem_private_key(Path(args.private_key).read_bytes(), password=None)
    payload = {
        "licenseId": args.license_id,
        "issuedAt": int(datetime.now(timezone.utc).timestamp() * 1000),
        "expiresAt": int((datetime.now(timezone.utc) + timedelta(days=args.days)).timestamp() * 1000),
    }
    if args.install_id:
        payload["installId"] = args.install_id
    payload_bytes = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    signature = key.sign(payload_bytes)
    print("VF1." + b64url(payload_bytes) + "." + b64url(signature))


if __name__ == "__main__":
    main()
