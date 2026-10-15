#!/usr/bin/env python3
"""Offline issuer for one-device VideoForge activation vouchers.

Requires: python -m pip install cryptography
Example:
 python tools/issue_license.py --private-key /secure/issuer_private.pem \
   --license-id VF-2026-0001 --email customer@example.com --install-id <INSTALL_ID>
The resulting VF1 voucher expires for activation exactly 7 days after creation.
The server then starts the 365-day license term on first successful activation.
"""
import argparse, base64, json, re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from cryptography.hazmat.primitives import serialization


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('ascii').rstrip('=')


def main() -> None:
    p = argparse.ArgumentParser(description='Issue a one-device VideoForge activation voucher')
    p.add_argument('--private-key', required=True, help='Offline Ed25519 issuer private PEM')
    p.add_argument('--license-id', required=True, help='Unique license ID; never reuse')
    p.add_argument('--email', required=True, help='Customer email bound to the voucher')
    p.add_argument('--install-id', required=True, help='Exact install ID shown in VideoForge')
    args = p.parse_args()
    email = args.email.strip().casefold()
    if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
        p.error('--email must be a valid email address')
    if not re.fullmatch(r'[a-fA-F0-9-]{16,256}', args.install_id):
        p.error('--install-id must be the installation ID shown in the app')
    if not re.fullmatch(r'[A-Za-z0-9_-]{3,128}', args.license_id):
        p.error('--license-id may contain letters, numbers, hyphens and underscores')
    key = serialization.load_pem_private_key(Path(args.private_key).read_bytes(), password=None)
    now = datetime.now(timezone.utc)
    created = int(now.timestamp() * 1000)
    activate_by = int((now + timedelta(days=7)).timestamp() * 1000)
    payload = {
        'licenseId': args.license_id,
        'email': email,
        'installId': args.install_id,
        'createdAt': created,
        'activateBy': activate_by,
        'durationDays': 365,
        'version': 1,
    }
    raw = json.dumps(payload, separators=(',', ':'), sort_keys=True).encode('utf-8')
    print('VF1.' + b64url(raw) + '.' + b64url(key.sign(raw)))
    print(f'# Activate before: {datetime.fromtimestamp(activate_by/1000, timezone.utc).isoformat()}', file=__import__('sys').stderr)

if __name__ == '__main__':
    main()
