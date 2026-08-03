from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import time
from typing import Any


class SecurityService:
    @staticmethod
    def hash_password(password: str) -> str:
        salt = secrets.token_bytes(32)
        iterations = 210000
        digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
        salt_b64 = base64.urlsafe_b64encode(salt).decode()
        digest_b64 = base64.urlsafe_b64encode(digest).decode()
        return f"pbkdf2_sha256${iterations}${salt_b64}${digest_b64}"

    @staticmethod
    def verify_password(password: str, stored_hash: str) -> bool:
        try:
            algorithm, iterations, salt_b64, digest_b64 = stored_hash.split("$")
        except ValueError:
            return False
        if algorithm != "pbkdf2_sha256":
            return False
        salt = base64.urlsafe_b64decode(salt_b64.encode("utf-8"))
        expected = base64.urlsafe_b64decode(digest_b64.encode("utf-8"))
        calculated = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, int(iterations))
        return hmac.compare_digest(calculated, expected)

    @staticmethod
    def constant_time_compare(left: str, right: str) -> bool:
        return hmac.compare_digest(left.encode("utf-8"), right.encode("utf-8"))

    @staticmethod
    def create_token(
        *,
        secret_key: str,
        subject: str,
        role: str,
        expires_seconds: int,
        extra: dict[str, Any] | None = None,
    ) -> str:
        now = int(time.time())
        payload: dict[str, Any] = {"sub": subject, "role": role, "iat": now, "exp": now + expires_seconds}
        if extra:
            payload.update(extra)
        payload_json = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        payload_b64 = base64.urlsafe_b64encode(payload_json).decode().rstrip("=")
        signature = hmac.new(secret_key.encode("utf-8"), payload_b64.encode("utf-8"), hashlib.sha256).digest()
        signature_b64 = base64.urlsafe_b64encode(signature).decode().rstrip("=")
        return f"{payload_b64}.{signature_b64}"

    @staticmethod
    def verify_token(*, secret_key: str, token: str) -> dict[str, Any]:
        try:
            payload_b64, signature_b64 = token.split(".", 1)
        except ValueError as error:
            raise ValueError("Token inválido.") from error
        expected = hmac.new(secret_key.encode("utf-8"), payload_b64.encode("utf-8"), hashlib.sha256).digest()
        received = base64.urlsafe_b64decode(SecurityService._pad(signature_b64))
        if not hmac.compare_digest(expected, received):
            raise ValueError("Token inválido.")
        payload_bytes = base64.urlsafe_b64decode(SecurityService._pad(payload_b64))
        payload = json.loads(payload_bytes.decode("utf-8"))
        if int(payload.get("exp", 0)) < int(time.time()):
            raise ValueError("Token expirado.")
        return payload

    @staticmethod
    def _pad(value: str) -> bytes:
        return (value + "=" * (-len(value) % 4)).encode("utf-8")
