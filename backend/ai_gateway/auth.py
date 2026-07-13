from __future__ import annotations

import hashlib
import secrets
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import HTTPException, status


class TokenService:
    def __init__(self, secret: str, issuer: str, audience: str, access_minutes: int) -> None:
        if len(secret) < 32:
            raise RuntimeError("GALCHAT_JWT_SECRET must contain at least 32 characters.")
        self.secret = secret
        self.issuer = issuer
        self.audience = audience
        self.access_minutes = access_minutes

    def issue_access_token(self, user_id: str, session_id: str) -> tuple[str, int]:
        now = datetime.now(UTC)
        expires_at = now + timedelta(minutes=self.access_minutes)
        token = jwt.encode(
            {
                "sub": user_id,
                "sid": session_id,
                "iat": now,
                "exp": expires_at,
                "iss": self.issuer,
                "aud": self.audience,
            },
            self.secret,
            algorithm="HS256",
        )
        return token, int((expires_at - now).total_seconds())

    def decode_access_token(self, token: str) -> dict:
        try:
            return jwt.decode(
                token,
                self.secret,
                algorithms=["HS256"],
                issuer=self.issuer,
                audience=self.audience,
                options={"require": ["sub", "sid", "iat", "exp", "iss", "aud"]},
            )
        except jwt.PyJWTError as error:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired access token.") from error


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_secret(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def verify_secret(value: str, expected_hash: str) -> bool:
    return secrets.compare_digest(hash_secret(value), expected_hash)
