"""VideoForge license activation API. Deploy behind HTTPS reverse proxy.

The offline issuer signs activation vouchers; this server verifies them and
atomically binds each license ID to the first installation. The server then
signs the one-year active token returned to the app.
"""
from __future__ import annotations
import base64, json, os, re, sqlite3, time
from contextlib import contextmanager
from pathlib import Path
from typing import Any
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr, Field
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey, Ed25519PrivateKey

DATA_DIR = Path(os.environ.get("VF_LICENSE_DATA_DIR", "./data"))
DB_PATH = Path(os.environ.get("VF_LICENSE_DB", str(DATA_DIR / "licenses.sqlite3")))
ISSUER_PUBLIC_KEY = Path(os.environ.get("VF_ISSUER_PUBLIC_KEY", "./keys/issuer_public.pem"))
SERVER_PRIVATE_KEY = Path(os.environ.get("VF_SERVER_PRIVATE_KEY", "./keys/server_private.pem"))
DATA_DIR.mkdir(parents=True, exist_ok=True)


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def unb64u(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def load_public(path: Path) -> Ed25519PublicKey:
    return serialization.load_pem_public_key(path.read_bytes())  # type: ignore[return-value]


def load_private(path: Path) -> Ed25519PrivateKey:
    key = serialization.load_pem_private_key(path.read_bytes(), password=None)
    if not isinstance(key, Ed25519PrivateKey):
        raise RuntimeError(f"Expected Ed25519 private key: {path}")
    return key


def verify_token(token: str, prefix: str, key: Ed25519PublicKey) -> dict[str, Any]:
    parts = token.strip().split(".")
    if len(parts) != 3 or parts[0] != prefix:
        raise ValueError("Invalid token format")
    payload = unb64u(parts[1])
    key.verify(unb64u(parts[2]), payload)
    data = json.loads(payload)
    if not isinstance(data, dict):
        raise ValueError("Invalid payload")
    return data


def signed_token(prefix: str, payload: dict[str, Any], key: Ed25519PrivateKey) -> str:
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    return f"{prefix}.{b64u(raw)}.{b64u(key.sign(raw))}"


def db_connect() -> sqlite3.Connection:
    con = sqlite3.connect(DB_PATH, timeout=15, isolation_level=None)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA busy_timeout=15000")
    return con


def init_db() -> None:
    with db_connect() as con:
        con.execute("""CREATE TABLE IF NOT EXISTS licenses (
            license_id TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            install_id TEXT NOT NULL,
            activated_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            active_token TEXT NOT NULL
        )""")


app = FastAPI(title="VideoForge License API", docs_url=None, redoc_url=None)


class ActivateRequest(BaseModel):
    key: str = Field(min_length=20, max_length=12000)
    email: EmailStr
    installId: str = Field(min_length=16, max_length=256, pattern=r"^[a-fA-F0-9-]+$")


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/activate")
def activate(req: ActivateRequest) -> dict[str, Any]:
    try:
        issuer_public = load_public(ISSUER_PUBLIC_KEY)
        server_private = load_private(SERVER_PRIVATE_KEY)
        voucher = verify_token(req.key, "VF1", issuer_public)
    except Exception:
        raise HTTPException(status_code=400, detail="Ключ не прошёл проверку подписи.")

    now = int(time.time() * 1000)
    email = str(req.email).strip().casefold()
    if str(voucher.get("email", "")).strip().casefold() != email:
        raise HTTPException(status_code=403, detail="Email не совпадает с данными ключа.")
    if voucher.get("installId") != req.installId:
        raise HTTPException(status_code=403, detail="Ключ выпущен для другой установки VideoForge.")
    try:
        created = int(voucher["createdAt"])
        activate_by = int(voucher["activateBy"])
        duration_days = int(voucher["durationDays"])
        license_id = str(voucher["licenseId"])
    except (KeyError, TypeError, ValueError):
        raise HTTPException(status_code=400, detail="В ключе отсутствуют обязательные поля.")
    if not license_id or len(license_id) > 128 or duration_days != 365:
        raise HTTPException(status_code=400, detail="Неверные параметры лицензии.")
    if now < created - 5 * 60 * 1000:
        raise HTTPException(status_code=400, detail="Проверьте системное время.")
    if now > activate_by:
        raise HTTPException(status_code=410, detail="Срок активации ключа истёк.")
    if activate_by - created != 7 * 24 * 60 * 60 * 1000:
        raise HTTPException(status_code=400, detail="Недопустимое окно активации.")

    con = db_connect()
    try:
        con.execute("BEGIN IMMEDIATE")
        row = con.execute("SELECT * FROM licenses WHERE license_id=?", (license_id,)).fetchone()
        if row:
            if row["email"].casefold() != email or row["install_id"] != req.installId:
                con.rollback()
                raise HTTPException(status_code=409, detail="Этот ключ уже активирован на другом устройстве.")
            # Same installation may retry safely and receives the original token.
            con.commit()
            return {"licenseToken": row["active_token"], "activatedAt": row["activated_at"], "expiresAt": row["expires_at"]}

        expires = now + duration_days * 24 * 60 * 60 * 1000
        payload = {
            "licenseId": license_id,
            "email": email,
            "installId": req.installId,
            "activatedAt": now,
            "expiresAt": expires,
            "version": 1,
        }
        active_token = signed_token("VFL1", payload, server_private)
        con.execute("INSERT INTO licenses(license_id,email,install_id,activated_at,expires_at,active_token) VALUES(?,?,?,?,?,?)",
                    (license_id, email, req.installId, now, expires, active_token))
        con.commit()
        return {"licenseToken": active_token, "activatedAt": now, "expiresAt": expires}
    except HTTPException:
        raise
    except sqlite3.IntegrityError:
        con.rollback()
        raise HTTPException(status_code=409, detail="Этот ключ уже активирован.")
    finally:
        con.close()
