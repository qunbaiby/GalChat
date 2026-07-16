from __future__ import annotations

import asyncio
import base64
import binascii
import ipaddress
import json
import logging
import logging.handlers
import os
import queue
import re
import secrets
import sys
import time
from collections import defaultdict, deque
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse, JSONResponse, Response, StreamingResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator

from auth import TokenService
from email_service import EmailService
from provider_secrets import ProviderSecretCipher
from storage import GatewayStorage


class Settings:
    def __init__(self) -> None:
        self.player_tokens = {
            token.strip()
            for token in os.getenv("GALCHAT_PLAYER_TOKENS", "").split(",")
            if token.strip()
        }
        self.provider_api_key = os.getenv("DEEPSEEK_API_KEY", "").strip()
        self.provider_base_url = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1").rstrip("/")
        self.allowed_models = {
            model.strip()
            for model in os.getenv("GALCHAT_ALLOWED_MODELS", "deepseek-chat,deepseek-reasoner").split(",")
            if model.strip()
        }
        self.rate_limit_requests = int(os.getenv("GALCHAT_RATE_LIMIT_REQUESTS", "30"))
        self.rate_limit_window_seconds = int(os.getenv("GALCHAT_RATE_LIMIT_WINDOW_SECONDS", "60"))
        self.request_timeout_seconds = float(os.getenv("GALCHAT_REQUEST_TIMEOUT_SECONDS", "90"))
        self.jwt_secret = os.getenv("GALCHAT_JWT_SECRET", "development-only-secret-change-me-now")
        self.jwt_issuer = os.getenv("GALCHAT_JWT_ISSUER", "galchat-ai-gateway")
        self.jwt_audience = os.getenv("GALCHAT_JWT_AUDIENCE", "galchat-client")
        self.access_token_minutes = int(os.getenv("GALCHAT_ACCESS_TOKEN_MINUTES", "15"))
        self.refresh_token_days = int(os.getenv("GALCHAT_REFRESH_TOKEN_DAYS", "30"))
        self.database_path = os.getenv("GALCHAT_DATABASE_PATH", "data/ai_gateway.db")
        self.daily_request_limit = int(os.getenv("GALCHAT_DAILY_REQUEST_LIMIT", "100"))
        self.usage_event_retention_days = int(os.getenv("GALCHAT_USAGE_EVENT_RETENTION_DAYS", "90"))
        self.capability_daily_limits = {
            capability: int(os.getenv(f"GALCHAT_{capability.upper()}_DAILY_LIMIT", str(self.daily_request_limit)))
            for capability in ("chat", "tts", "asr", "embedding", "vision", "image")
        }
        self.email_code_minutes = int(os.getenv("GALCHAT_EMAIL_CODE_MINUTES", "10"))
        self.email_code_cooldown_seconds = int(os.getenv("GALCHAT_EMAIL_CODE_COOLDOWN_SECONDS", "60"))
        self.login_max_attempts = int(os.getenv("GALCHAT_LOGIN_MAX_ATTEMPTS", "5"))
        self.login_lock_minutes = int(os.getenv("GALCHAT_LOGIN_LOCK_MINUTES", "15"))
        self.environment = os.getenv("GALCHAT_ENVIRONMENT", "development").strip().lower()
        self.development_test_account_enabled = os.getenv("GALCHAT_DEV_TEST_ACCOUNT_ENABLED", "true").lower() == "true"
        self.development_test_username = os.getenv("GALCHAT_DEV_TEST_USERNAME", "galchat_test").strip().lower()
        self.development_test_email = os.getenv("GALCHAT_DEV_TEST_EMAIL", "test@galchat.local").strip().lower()
        self.development_test_password = os.getenv("GALCHAT_DEV_TEST_PASSWORD", "GalChatTest2026!")
        self.admin_token = os.getenv("GALCHAT_ADMIN_TOKEN", "").strip()
        self.secrets_master_key = os.getenv("GALCHAT_SECRETS_MASTER_KEY", "").strip()
        self.capability_providers = {
            "tts": {
                "api_key": os.getenv("GALCHAT_TTS_API_KEY", "").strip(),
                "base_url": os.getenv("GALCHAT_TTS_BASE_URL", "https://openspeech.bytedance.com/api/v3/tts/unidirectional").strip(),
                "model": os.getenv("GALCHAT_TTS_MODEL", "").strip(),
                "resource_id": os.getenv("GALCHAT_TTS_RESOURCE_ID", "seed-tts-2.0").strip(),
            },
            "asr": {
                "api_key": os.getenv("GALCHAT_ASR_API_KEY", "").strip(),
                "base_url": os.getenv("GALCHAT_ASR_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions").strip(),
                "model": os.getenv("GALCHAT_ASR_MODEL", "qwen3-asr-flash").strip(),
                "resource_id": "",
            },
            "embedding": {
                "api_key": os.getenv("GALCHAT_EMBEDDING_API_KEY", "").strip(),
                "base_url": os.getenv("GALCHAT_EMBEDDING_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3/embeddings/multimodal").strip(),
                "model": os.getenv("GALCHAT_EMBEDDING_MODEL", "").strip(),
                "resource_id": "",
            },
            "image": {
                "api_key": os.getenv("GALCHAT_IMAGE_API_KEY", "").strip(),
                "base_url": os.getenv("GALCHAT_IMAGE_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3/images/generations").strip(),
                "model": os.getenv("GALCHAT_IMAGE_MODEL", "doubao-seedream-5-0-260128").strip(),
                "resource_id": "",
            },
            "vision": {
                "api_key": os.getenv("GALCHAT_VISION_API_KEY", "").strip(),
                "base_url": os.getenv("GALCHAT_VISION_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3/responses").strip(),
                "model": os.getenv("GALCHAT_VISION_MODEL", "doubao-seed-2-0-mini-260428").strip(),
                "resource_id": "",
            },
        }
        if self.environment == "production":
            production_errors: list[str] = []
            if len(self.jwt_secret) < 32 or self.jwt_secret == "development-only-secret-change-me-now":
                production_errors.append("GALCHAT_JWT_SECRET must contain at least 32 random characters")
            if len(self.admin_token) < 32:
                production_errors.append("GALCHAT_ADMIN_TOKEN must contain at least 32 random characters")
            if not self.secrets_master_key:
                production_errors.append("GALCHAT_SECRETS_MASTER_KEY must be configured")
            else:
                try:
                    from cryptography.fernet import Fernet

                    Fernet(self.secrets_master_key.encode("ascii"))
                except (ValueError, TypeError, UnicodeError):
                    production_errors.append("GALCHAT_SECRETS_MASTER_KEY must be a valid Fernet key")
            if self.database_path == "data/ai_gateway.db":
                production_errors.append("GALCHAT_DATABASE_PATH must use an explicit persistent production path")
            if os.getenv("GALCHAT_EMAIL_MODE", "console").strip().lower() == "console":
                production_errors.append("GALCHAT_EMAIL_MODE cannot be console in production")
            production_errors.extend(EmailService().configuration_errors())
            if production_errors:
                raise RuntimeError("Invalid production configuration: " + "; ".join(production_errors) + ".")


class ChatMessage(BaseModel):
    model_config = ConfigDict(extra="forbid")

    role: str = Field(pattern="^(system|user|assistant)$")
    content: str = Field(min_length=1, max_length=20_000)


class ChatCompletionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    model: str
    messages: list[ChatMessage] = Field(min_length=1, max_length=64)
    temperature: float = Field(default=0.7, ge=0.0, le=1.5)
    max_tokens: int = Field(default=2048, ge=1, le=4096)
    stream: bool = False


class TtsSpeechRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str = Field(min_length=1, max_length=2_000)
    speaker: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9_.-]+$")
    audio_format: str = Field(default="mp3", pattern="^(mp3|wav)$")
    sample_rate: int = Field(default=24_000, ge=8_000, le=48_000)
    bit_rate: int = Field(default=96_000, ge=32_000, le=320_000)
    speech_rate: int = Field(default=0, ge=-50, le=100)
    loudness_rate: int = Field(default=0, ge=-50, le=100)
    enable_subtitle: bool = False
    context_texts: list[str] = Field(default_factory=list, max_length=2)

    @field_validator("context_texts")
    @classmethod
    def validate_context_texts(cls, value: list[str]) -> list[str]:
        normalized = [entry.strip() for entry in value if entry.strip()]
        if any(len(entry) > 120 for entry in normalized):
            raise ValueError("TTS context instructions must not exceed 120 characters.")
        return normalized


class AsrTranscriptionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    audio_base64: str = Field(min_length=16, max_length=8_000_000, pattern=r"^[A-Za-z0-9+/=]+$")


class EmbeddingRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str = Field(min_length=1, max_length=20_000)


class VisionResponseRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    system_prompt: str = Field(min_length=1, max_length=12_000)
    user_prompt: str = Field(min_length=1, max_length=4_000)
    image_base64: str = Field(min_length=16, max_length=8_000_000, pattern=r"^[A-Za-z0-9+/=]+$")
    image_media_type: str = Field(default="image/jpeg", pattern="^image/(jpeg|png)$")


class ImageGenerationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    prompt: str = Field(min_length=1, max_length=8_000)


class DeviceCredentials(BaseModel):
    model_config = ConfigDict(extra="forbid")

    installation_id: str = Field(min_length=16, max_length=128)
    installation_secret: str = Field(min_length=32, max_length=256)


class RefreshRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    refresh_token: str = Field(min_length=32, max_length=512)


class EmailCodeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: str = Field(pattern=r"^[^\s@]+@[^\s@]+\.[^\s@]+$", max_length=254)


class EmailRegisterRequest(EmailCodeRequest):
    username: str = Field(pattern=r"^[A-Za-z0-9_\-]{3,24}$")
    password: str = Field(min_length=8, max_length=128)
    verification_code: str = Field(pattern=r"^[0-9]{6}$")


class EmailLoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    identity: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=8, max_length=128)


class PasswordResetRequest(EmailCodeRequest):
    new_password: str = Field(min_length=8, max_length=128)
    verification_code: str = Field(pattern=r"^[0-9]{6}$")


class ProviderConfigRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    api_key: str = Field(min_length=8, max_length=512)
    base_url: str = Field(min_length=10, max_length=500)
    allowed_models: list[str] = Field(min_length=1, max_length=20)

    @field_validator("base_url")
    @classmethod
    def validate_base_url(cls, value: str) -> str:
        normalized = value.strip().rstrip("/")
        if not normalized.startswith(("http://", "https://")):
            raise ValueError("Provider base URL must use HTTP or HTTPS.")
        return normalized

    @field_validator("allowed_models")
    @classmethod
    def validate_models(cls, value: list[str]) -> list[str]:
        normalized = list(dict.fromkeys(model.strip() for model in value if model.strip()))
        if not normalized or any(not model.replace("-", "").replace("_", "").isalnum() for model in normalized):
            raise ValueError("Provider model identifiers are invalid.")
        return normalized


class CapabilityProviderRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    api_key: str = Field(min_length=8, max_length=512)
    base_url: str = Field(min_length=10, max_length=500)
    model: str = Field(default="", max_length=200)
    resource_id: str = Field(default="", max_length=200)

    @field_validator("base_url")
    @classmethod
    def validate_base_url(cls, value: str) -> str:
        normalized = value.strip().rstrip("/")
        if not normalized.startswith(("http://", "https://")):
            raise ValueError("Provider base URL must use HTTP or HTTPS.")
        return normalized


class CapabilityQuotaRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    daily_limit: int = Field(ge=0, le=1_000_000)

class SlidingWindowLimiter:
    def __init__(self, limit: int, window_seconds: int) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self.requests: dict[str, deque[float]] = defaultdict(deque)
        self.lock = asyncio.Lock()

    async def check(self, key: str) -> None:
        now = time.monotonic()
        async with self.lock:
            bucket = self.requests[key]
            while bucket and bucket[0] <= now - self.window_seconds:
                bucket.popleft()
            if len(bucket) >= self.limit:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="AI request quota exceeded. Please retry later.",
                )
            bucket.append(now)


settings = Settings()
limiter = SlidingWindowLimiter(settings.rate_limit_requests, settings.rate_limit_window_seconds)
token_service = TokenService(settings.jwt_secret, settings.jwt_issuer, settings.jwt_audience, settings.access_token_minutes)
storage = GatewayStorage(settings.database_path, settings.refresh_token_days)
stored_quota_limits = storage.list_capability_quota_limits()
for capability, stored_limit in stored_quota_limits.items():
    if capability in settings.capability_daily_limits:
        settings.capability_daily_limits[capability] = int(stored_limit["daily_limit"])
provider_secret_cipher = ProviderSecretCipher(settings.secrets_master_key)
email_service = EmailService()
stored_provider_config = storage.get_provider_config()
if stored_provider_config is not None and provider_secret_cipher.is_configured:
    settings.provider_api_key = provider_secret_cipher.decrypt(stored_provider_config["encrypted_api_key"])
    settings.provider_base_url = stored_provider_config["base_url"]
    settings.allowed_models = {
        model for model in stored_provider_config["allowed_models"].split(",") if model
    }
stored_capability_configs = storage.list_capability_provider_configs()
if provider_secret_cipher.is_configured:
    for capability, stored_config in stored_capability_configs.items():
        if capability not in settings.capability_providers:
            continue
        settings.capability_providers[capability] = {
            "api_key": provider_secret_cipher.decrypt(stored_config["encrypted_api_key"]),
            "base_url": stored_config["base_url"],
            "model": stored_config["model"],
            "resource_id": stored_config["resource_id"],
        }
if settings.environment == "development" and settings.development_test_account_enabled:
    storage.ensure_development_user(
        settings.development_test_username,
        settings.development_test_email,
        settings.development_test_password,
    )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    storage.cleanup_usage_events(settings.usage_event_retention_days)
    app.state.http = httpx.AsyncClient(timeout=settings.request_timeout_seconds)
    access_log_listener.start()
    yield
    access_log_listener.stop()
    await app.state.http.aclose()


app = FastAPI(title="GalChat AI Gateway", version="0.1.0", lifespan=lifespan)

access_logger = logging.getLogger("galchat.access")
access_log_listener = getattr(access_logger, "_galchat_queue_listener", None)
if access_log_listener is None:
    access_log_queue: queue.SimpleQueue[logging.LogRecord] = queue.SimpleQueue()
    access_handler = logging.StreamHandler(sys.stdout)
    access_handler.setFormatter(logging.Formatter("%(message)s"))
    access_logger.addHandler(logging.handlers.QueueHandler(access_log_queue))
    access_log_listener = logging.handlers.QueueListener(access_log_queue, access_handler)
    access_logger._galchat_queue_listener = access_log_listener
access_logger.setLevel(logging.INFO)
access_logger.propagate = False

REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]{8,128}$")

GAME_CAPABILITY_PATHS = {
    "/v1/game/chat/completions": "chat",
    "/v1/game/tts/speech": "tts",
    "/v1/game/asr/transcriptions": "asr",
    "/v1/game/embeddings": "embedding",
    "/v1/game/vision/responses": "vision",
    "/v1/game/images/generations": "image",
}


@app.middleware("http")
async def request_context_and_logging(request: Request, call_next):
    incoming_request_id = request.headers.get("X-Request-ID", "")
    request_id = (
        incoming_request_id
        if REQUEST_ID_PATTERN.fullmatch(incoming_request_id)
        else f"req_{secrets.token_hex(16)}"
    )
    request.state.request_id = request_id
    started_at = time.monotonic()
    try:
        response = await call_next(request)
    except Exception:
        access_logger.exception(
            json.dumps(
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status": 500,
                    "latency_ms": int((time.monotonic() - started_at) * 1000),
                    "client_ip": request.client.host if request.client else "unknown",
                    "user_id": getattr(request.state, "user_id", None),
                },
                ensure_ascii=True,
            )
        )
        raise
    response.headers["X-Request-ID"] = request_id
    access_logger.info(
        json.dumps(
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "latency_ms": int((time.monotonic() - started_at) * 1000),
                "client_ip": request.client.host if request.client else "unknown",
                "user_id": getattr(request.state, "user_id", None),
            },
            ensure_ascii=True,
        )
    )
    return response


@app.middleware("http")
async def record_game_usage(request: Request, call_next):
    capability = GAME_CAPABILITY_PATHS.get(request.url.path)
    if capability is None:
        return await call_next(request)
    started_at = time.monotonic()
    response = await call_next(request)
    if getattr(request.state, "defer_usage_recording", False):
        return response
    user_id = getattr(request.state, "user_id", None)
    if user_id:
        if response.status_code < 400:
            event_status = "succeeded"
        elif response.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
            event_status = "quota_rejected"
        elif response.status_code in {status.HTTP_502_BAD_GATEWAY, status.HTTP_503_SERVICE_UNAVAILABLE}:
            event_status = "provider_error"
        elif response.status_code == status.HTTP_504_GATEWAY_TIMEOUT:
            event_status = "timeout"
        else:
            event_status = "failed"
        storage.record_usage_event(
            user_id,
            capability,
            event_status,
            int((time.monotonic() - started_at) * 1000),
            str(response.status_code),
            int(getattr(request.state, "usage_units", 1)),
        )
    return response


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token.")
    token = authorization.removeprefix("Bearer ").strip()
    return token


async def authorize_request(
    request: Request,
    authorization: str | None = Header(default=None),
) -> str:
    token = _extract_bearer_token(authorization)
    client_host = request.client.host if request.client else "unknown"
    if token in settings.player_tokens:
        user_id = f"legacy:{token}"
    else:
        claims = token_service.decode_access_token(token)
        user_id = str(claims["sub"])
        if not storage.session_is_active(user_id, str(claims["sid"])):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session is no longer active.")
    await limiter.check(f"{user_id}:{client_host}")
    request.state.user_id = user_id
    return user_id


def authorize_admin(authorization: str | None = Header(default=None)) -> None:
    if not settings.admin_token:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Admin console is not configured.")
    token = _extract_bearer_token(authorization)
    if not secrets.compare_digest(token, settings.admin_token):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin token.")


def _issue_session(user_id: str, session_id: str, refresh_token: str) -> dict[str, Any]:
    access_token, expires_in = token_service.issue_access_token(user_id, session_id)
    return {
        "user_id": user_id,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": expires_in,
    }


def _provider_headers() -> dict[str, str]:
    if not settings.provider_api_key:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="AI provider is not configured.")
    return {
        "Authorization": f"Bearer {settings.provider_api_key}",
        "Content-Type": "application/json",
    }


def _mask_email(email: str) -> str:
    local, separator, domain = email.partition("@")
    if not separator:
        return "***"
    visible = local[:2] if len(local) > 2 else local[:1]
    return f"{visible}***@{domain}"


def _validated_payload(payload: ChatCompletionRequest) -> dict[str, Any]:
    if payload.model not in settings.allowed_models:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Requested model is not allowed.")
    return payload.model_dump()


async def _test_provider_config(payload: ProviderConfigRequest) -> int:
    started_at = time.monotonic()
    try:
        response = await app.state.http.post(
            f"{payload.base_url}/chat/completions",
            headers={"Authorization": f"Bearer {payload.api_key}", "Content-Type": "application/json"},
            json={
                "model": payload.allowed_models[0],
                "messages": [{"role": "user", "content": "Reply with OK."}],
                "temperature": 0,
                "max_tokens": 8,
                "stream": False,
            },
        )
    except httpx.RequestError as error:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Could not connect to AI provider.") from error
    if response.status_code >= 400:
        if response.status_code in {401, 403}:
            detail = "AI provider rejected the API key."
        elif response.status_code == 402:
            detail = "AI provider account balance is insufficient."
        elif response.status_code == 429:
            detail = "AI provider rate limit was reached."
        else:
            detail = f"AI provider test failed with status {response.status_code}."
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=detail)
    return int((time.monotonic() - started_at) * 1000)


def _admin_source_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _get_capability_provider(capability: str) -> dict[str, str]:
    provider = settings.capability_providers.get(capability)
    if provider is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown provider capability.")
    return provider


def _consume_quota(user_id: str, capability: str) -> int:
    daily_limit = settings.capability_daily_limits[capability]
    if user_id.startswith("legacy:"):
        return daily_limit
    remaining = storage.consume_capability_quota(user_id, capability, daily_limit)
    if remaining is None:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Daily {capability} quota exceeded.",
        )
    return remaining


def _release_quota(user_id: str, capability: str) -> None:
    if not user_id.startswith("legacy:"):
        storage.release_capability_quota(user_id, capability)


def _quota_headers(capability: str, remaining: int) -> dict[str, str]:
    return {
        "X-Quota-Capability": capability,
        "X-Quota-Limit": str(settings.capability_daily_limits[capability]),
        "X-Quota-Remaining": str(remaining),
    }


def _quota_payload(user_id: str) -> dict[str, Any]:
    if user_id.startswith("legacy:"):
        capabilities = {
            capability: {"limit": limit, "used": 0, "remaining": limit}
            for capability, limit in settings.capability_daily_limits.items()
        }
        return {
            "limit": settings.daily_request_limit,
            "used": 0,
            "remaining": settings.daily_request_limit,
            "capabilities": capabilities,
        }
    used, remaining = storage.get_daily_quota(user_id, settings.daily_request_limit)
    return {
        "limit": settings.daily_request_limit,
        "used": used,
        "remaining": remaining,
        "capabilities": storage.get_capability_quotas(user_id, settings.capability_daily_limits),
    }


def _detect_image_media_type(content: bytes) -> str | None:
    if content.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(content) >= 12 and content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        return "image/webp"
    return None


def _validate_provider_image_url(image_url: str) -> None:
    parsed = urlparse(image_url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Image provider returned an unsafe image URL.")
    if parsed.hostname.lower() == "localhost":
        raise ValueError("Image provider returned an unsafe image URL.")
    try:
        address = ipaddress.ip_address(parsed.hostname)
    except ValueError:
        return
    if not address.is_global:
        raise ValueError("Image provider returned an unsafe image URL.")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/ready")
async def readiness(request: Request) -> dict[str, Any]:
    http_client = getattr(request.app.state, "http", None)
    email_ready = email_service.is_configured()
    ready = storage.check_ready() and http_client is not None and not http_client.is_closed and email_ready
    if not ready:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Gateway is not ready.")
    return {
        "status": "ready",
        "schema_version": storage.get_schema_version(),
        "usage_event_retention_days": settings.usage_event_retention_days,
        "email_configured": email_ready,
    }


@app.get("/admin", response_class=HTMLResponse, include_in_schema=False)
async def admin_console() -> HTMLResponse:
    page_path = Path(__file__).with_name("admin.html")
    if not page_path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Admin console is unavailable.")
    return HTMLResponse(page_path.read_text(encoding="utf-8"))


@app.get("/admin/api/overview", dependencies=[Depends(authorize_admin)])
async def admin_overview() -> dict[str, Any]:
    usage_date = datetime.now(UTC).date().isoformat()
    overview = storage.get_admin_overview(usage_date)
    return {
        **overview,
        "environment": settings.environment,
        "provider_configured": bool(settings.provider_api_key),
        "provider_base_url": settings.provider_base_url,
        "allowed_models": sorted(settings.allowed_models),
        "daily_request_limit": settings.daily_request_limit,
        "capability_daily_limits": settings.capability_daily_limits,
        "capability_stats": storage.get_capability_stats(usage_date),
        "rate_limit_requests": settings.rate_limit_requests,
        "rate_limit_window_seconds": settings.rate_limit_window_seconds,
        "usage_date": usage_date,
        "provider_updated_at": stored["updated_at"] if (stored := storage.get_provider_config()) else None,
        "provider_secret_storage_enabled": provider_secret_cipher.is_configured,
    }


@app.get("/admin/api/provider", dependencies=[Depends(authorize_admin)])
async def admin_provider_config() -> dict[str, Any]:
    stored = storage.get_provider_config()
    return {
        "configured": bool(settings.provider_api_key),
        "base_url": settings.provider_base_url,
        "allowed_models": sorted(settings.allowed_models),
        "updated_at": stored["updated_at"] if stored else None,
        "secret_storage_enabled": provider_secret_cipher.is_configured,
        "source": "encrypted_store" if stored else "environment",
    }


@app.post("/admin/api/provider/test", dependencies=[Depends(authorize_admin)])
async def admin_test_provider(payload: ProviderConfigRequest, request: Request) -> dict[str, Any]:
    latency_ms = await _test_provider_config(payload)
    storage.add_admin_audit_log("provider.test_succeeded", _admin_source_ip(request))
    return {"success": True, "latency_ms": latency_ms, "model": payload.allowed_models[0]}


@app.put("/admin/api/provider", dependencies=[Depends(authorize_admin)])
async def admin_save_provider(payload: ProviderConfigRequest, request: Request) -> dict[str, Any]:
    if not provider_secret_cipher.is_configured:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Provider secret storage is not configured.")
    latency_ms = await _test_provider_config(payload)
    encrypted_api_key = provider_secret_cipher.encrypt(payload.api_key)
    updated_at = storage.save_provider_config(
        encrypted_api_key,
        payload.base_url,
        ",".join(payload.allowed_models),
    )
    settings.provider_api_key = payload.api_key
    settings.provider_base_url = payload.base_url
    settings.allowed_models = set(payload.allowed_models)
    storage.add_admin_audit_log("provider.config_updated", _admin_source_ip(request))
    return {"success": True, "latency_ms": latency_ms, "updated_at": updated_at}


@app.delete("/admin/api/provider/key", dependencies=[Depends(authorize_admin)])
async def admin_delete_provider(request: Request) -> dict[str, bool]:
    storage.delete_provider_config()
    settings.provider_api_key = os.getenv("DEEPSEEK_API_KEY", "").strip()
    settings.provider_base_url = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1").rstrip("/")
    settings.allowed_models = {
        model.strip()
        for model in os.getenv("GALCHAT_ALLOWED_MODELS", "deepseek-chat,deepseek-reasoner").split(",")
        if model.strip()
    }
    storage.add_admin_audit_log("provider.encrypted_config_deleted", _admin_source_ip(request))
    return {"success": True}


@app.get("/admin/api/audit-logs", dependencies=[Depends(authorize_admin)])
async def admin_audit_logs(limit: int = Query(default=50, ge=1, le=100)) -> dict[str, Any]:
    return {"items": storage.list_admin_audit_logs(limit)}


@app.get("/admin/api/capability-providers", dependencies=[Depends(authorize_admin)])
async def admin_capability_providers() -> dict[str, Any]:
    stored = storage.list_capability_provider_configs()
    return {
        "items": {
            capability: {
                "configured": bool(provider["api_key"]),
                "base_url": provider["base_url"],
                "model": provider["model"],
                "resource_id": provider["resource_id"],
                "source": "encrypted_store" if capability in stored else "environment",
                "updated_at": stored.get(capability, {}).get("updated_at"),
            }
            for capability, provider in settings.capability_providers.items()
        },
        "secret_storage_enabled": provider_secret_cipher.is_configured,
    }


@app.put("/admin/api/capability-providers/{capability}", dependencies=[Depends(authorize_admin)])
async def admin_save_capability_provider(
    capability: str,
    payload: CapabilityProviderRequest,
    request: Request,
) -> dict[str, Any]:
    _get_capability_provider(capability)
    if not provider_secret_cipher.is_configured:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Provider secret storage is not configured.")
    encrypted_api_key = provider_secret_cipher.encrypt(payload.api_key)
    updated_at = storage.save_capability_provider_config(
        capability,
        encrypted_api_key,
        payload.base_url,
        payload.model.strip(),
        payload.resource_id.strip(),
    )
    settings.capability_providers[capability] = {
        "api_key": payload.api_key,
        "base_url": payload.base_url,
        "model": payload.model.strip(),
        "resource_id": payload.resource_id.strip(),
    }
    storage.add_admin_audit_log(f"provider.{capability}_config_updated", _admin_source_ip(request))
    return {"success": True, "updated_at": updated_at}


@app.delete("/admin/api/capability-providers/{capability}", dependencies=[Depends(authorize_admin)])
async def admin_delete_capability_provider(capability: str, request: Request) -> dict[str, bool]:
    _get_capability_provider(capability)
    storage.delete_capability_provider_config(capability)
    defaults = Settings().capability_providers[capability]
    settings.capability_providers[capability] = defaults
    storage.add_admin_audit_log(f"provider.{capability}_config_deleted", _admin_source_ip(request))
    return {"success": True}


@app.get("/admin/api/users", dependencies=[Depends(authorize_admin)])
async def admin_users(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    query: str = Query(default="", max_length=200),
    sort_by: str = Query(default="created_at", pattern="^(username|created_at|used_today|active_sessions)$"),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
) -> dict[str, Any]:
    usage_date = datetime.now(UTC).date().isoformat()
    users, total = storage.list_admin_users(usage_date, limit, offset, query, sort_by, sort_order)
    return {
        "items": [
            {
                **user,
                "email": _mask_email(str(user["email"])),
                "remaining_today": max(0, settings.daily_request_limit - int(user["used_today"])),
                "capability_quotas": storage.get_capability_quotas(
                    str(user["user_id"]), settings.capability_daily_limits
                ),
            }
            for user in users
        ],
        "total": total,
        "limit": limit,
        "offset": offset,
        "query": query,
        "sort_by": sort_by,
        "sort_order": sort_order,
    }


@app.get("/admin/api/usage-events", dependencies=[Depends(authorize_admin)])
async def admin_usage_events(
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    capability: str = Query(default="", pattern="^(|chat|tts|asr|embedding|vision|image)$"),
    event_status: str = Query(
        default="",
        pattern="^(|succeeded|failed|quota_rejected|provider_error|timeout|cancelled)$",
    ),
    user_query: str = Query(default="", max_length=200),
    sort_by: str = Query(
        default="created_at",
        pattern="^(created_at|capability|status|units|latency_ms|error_code|user_id)$",
    ),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
) -> dict[str, Any]:
    items, total = storage.query_usage_events(
        limit,
        offset,
        capability,
        event_status,
        user_query,
        sort_by,
        sort_order,
    )
    return {
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset,
        "capability": capability,
        "event_status": event_status,
        "user_query": user_query,
        "sort_by": sort_by,
        "sort_order": sort_order,
    }


@app.put("/admin/api/capability-quotas/{capability}", dependencies=[Depends(authorize_admin)])
async def admin_save_capability_quota(
    capability: str,
    payload: CapabilityQuotaRequest,
    request: Request,
) -> dict[str, Any]:
    if capability not in settings.capability_daily_limits:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown provider capability.")
    updated_at = storage.save_capability_quota_limit(capability, payload.daily_limit)
    settings.capability_daily_limits[capability] = payload.daily_limit
    storage.add_admin_audit_log(f"quota.{capability}_limit_updated", _admin_source_ip(request))
    return {"success": True, "daily_limit": payload.daily_limit, "updated_at": updated_at}


@app.post("/v1/auth/device/register", status_code=status.HTTP_201_CREATED)
async def register_device(credentials: DeviceCredentials):
    try:
        user_id = storage.register_device(credentials.installation_id, credentials.installation_secret)
    except Exception as error:
        if "UNIQUE constraint failed" in str(error):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Device is already registered.") from error
        raise
    session_id, refresh_token = storage.create_session(user_id)
    return _issue_session(user_id, session_id, refresh_token)


@app.post("/v1/auth/email/code", status_code=status.HTTP_204_NO_CONTENT)
async def send_email_code(payload: EmailCodeRequest):
    email = payload.email.strip().lower()
    code = f"{secrets.randbelow(1_000_000):06d}"
    if not storage.save_email_code(
        email, code, settings.email_code_minutes, settings.email_code_cooldown_seconds
    ):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Please wait before requesting another verification code.",
        )
    try:
        email_service.send_verification_code(email, code)
    except Exception as error:
        storage.delete_email_code(email)
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Verification email could not be sent.") from error


@app.post("/v1/auth/email/register", status_code=status.HTTP_201_CREATED)
async def register_email(payload: EmailRegisterRequest):
    email = payload.email.strip().lower()
    try:
        user_id = storage.register_email_user(payload.username.strip().lower(), email, payload.password, payload.verification_code)
    except Exception as error:
        if "UNIQUE constraint failed" in str(error):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email is already registered.") from error
        raise
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Verification code is invalid or expired.")
    session_id, refresh_token = storage.create_session(user_id)
    return _issue_session(user_id, session_id, refresh_token)


@app.post("/v1/auth/password/reset/code", status_code=status.HTTP_204_NO_CONTENT)
async def send_password_reset_code(payload: EmailCodeRequest):
    email = payload.email.strip().lower()
    code = f"{secrets.randbelow(1_000_000):06d}"
    if not storage.save_password_reset_code(
        email, code, settings.email_code_minutes, settings.email_code_cooldown_seconds
    ):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Please wait before requesting another verification code.",
        )
    try:
        email_service.send_password_reset_code(email, code)
    except Exception as error:
        storage.delete_password_reset_code(email)
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Verification email could not be sent.") from error


@app.post("/v1/auth/password/reset", status_code=status.HTTP_204_NO_CONTENT)
async def reset_password(payload: PasswordResetRequest):
    if not storage.reset_password(
        payload.email.strip().lower(), payload.new_password, payload.verification_code
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification code is invalid or expired.",
        )


@app.post("/v1/auth/email/login")
async def login_email(payload: EmailLoginRequest):
    user_id, locked = storage.authenticate_user(
        payload.identity.strip().lower(),
        payload.password,
        settings.login_max_attempts,
        settings.login_lock_minutes,
    )
    if locked:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed login attempts. Please retry later.",
        )
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password.")
    session_id, refresh_token = storage.create_session(user_id)
    return _issue_session(user_id, session_id, refresh_token)


@app.post("/v1/auth/device/login")
async def login_device(credentials: DeviceCredentials):
    user_id = storage.authenticate_device(credentials.installation_id, credentials.installation_secret)
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid device credentials.")
    session_id, refresh_token = storage.create_session(user_id)
    return _issue_session(user_id, session_id, refresh_token)


@app.post("/v1/auth/refresh")
async def refresh_session(payload: RefreshRequest):
    rotated = storage.rotate_refresh_token(payload.refresh_token)
    if rotated is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token.")
    user_id, session_id, refresh_token = rotated
    return _issue_session(user_id, session_id, refresh_token)


@app.post("/v1/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(user_id: str = Depends(authorize_request), authorization: str | None = Header(default=None)):
    token = _extract_bearer_token(authorization)
    if token not in settings.player_tokens:
        claims = token_service.decode_access_token(token)
        storage.revoke_session(str(claims["sid"]), user_id)


@app.post("/v1/auth/logout-all", status_code=status.HTTP_204_NO_CONTENT)
async def logout_all(user_id: str = Depends(authorize_request)):
    if not user_id.startswith("legacy:"):
        storage.revoke_all_sessions(user_id)


@app.get("/v1/account/quota")
async def account_quota(user_id: str = Depends(authorize_request)):
    return _quota_payload(user_id)


@app.get("/v1/account/profile")
async def account_profile(user_id: str = Depends(authorize_request)):
    if user_id.startswith("legacy:"):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account profile is unavailable.")
    profile = storage.get_user_profile(user_id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account was not found.")
    return {
        "user_id": profile["user_id"],
        "username": profile["username"],
        "masked_email": _mask_email(profile["email"]),
        "created_at": profile["created_at"],
        "quota": _quota_payload(user_id),
    }


@app.post("/v1/game/chat/completions")
async def chat_completions(
    payload: ChatCompletionRequest,
    request: Request,
    user_id: str = Depends(authorize_request),
):
    provider_payload = _validated_payload(payload)
    provider_url = f"{settings.provider_base_url}/chat/completions"
    headers = _provider_headers()
    request.state.usage_units = sum(len(message.content) for message in payload.messages)
    remaining = _consume_quota(user_id, "chat")
    quota_headers = _quota_headers("chat", remaining)

    if not payload.stream:
        try:
            response = await request.app.state.http.post(provider_url, headers=headers, json=provider_payload)
        except httpx.TimeoutException as error:
            _release_quota(user_id, "chat")
            raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="Chat provider timed out.") from error
        except httpx.RequestError as error:
            _release_quota(user_id, "chat")
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Chat provider is unavailable.") from error
        if response.status_code >= 400:
            _release_quota(user_id, "chat")
            return JSONResponse(
                status_code=status.HTTP_502_BAD_GATEWAY,
                content={"error": {"message": _safe_provider_error(response.content)}},
                headers=quota_headers,
            )
        return _json_response(response, quota_headers)

    request.state.defer_usage_recording = True
    started_at = time.monotonic()

    async def stream_provider() -> AsyncIterator[bytes]:
        event_status = "succeeded"
        error_code = "200"
        release_quota = False
        try:
            async with request.app.state.http.stream(
                "POST",
                provider_url,
                headers=headers,
                json=provider_payload,
            ) as response:
                if response.status_code >= 400:
                    error_body = await response.aread()
                    event_status = "provider_error"
                    error_code = str(response.status_code)
                    release_quota = True
                    error_payload = json.dumps({"error": {"message": _safe_provider_error(error_body)}})
                    yield f"data: {error_payload}\n\n".encode()
                    yield b"data: [DONE]\n\n"
                    return
                async for chunk in response.aiter_raw():
                    yield chunk
        except httpx.TimeoutException:
            event_status = "timeout"
            error_code = "504"
            release_quota = True
            error_payload = json.dumps({"error": {"message": "Chat provider timed out."}})
            yield f"data: {error_payload}\n\n".encode()
            yield b"data: [DONE]\n\n"
        except httpx.RequestError:
            event_status = "provider_error"
            error_code = "502"
            release_quota = True
            error_payload = json.dumps({"error": {"message": "Chat provider is unavailable."}})
            yield f"data: {error_payload}\n\n".encode()
            yield b"data: [DONE]\n\n"
        except asyncio.CancelledError:
            event_status = "cancelled"
            error_code = "499"
            raise
        finally:
            if release_quota:
                _release_quota(user_id, "chat")
            storage.record_usage_event(
                user_id,
                "chat",
                event_status,
                int((time.monotonic() - started_at) * 1000),
                error_code,
                int(request.state.usage_units),
            )

    return StreamingResponse(stream_provider(), media_type="text/event-stream", headers=quota_headers)


@app.post("/v1/game/tts/speech")
async def tts_speech(
    payload: TtsSpeechRequest,
    request: Request,
    user_id: str = Depends(authorize_request),
):
    provider = _get_capability_provider("tts")
    if not provider["api_key"]:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Official TTS is not configured.")

    request.state.usage_units = len(payload.text)
    remaining = _consume_quota(user_id, "tts")

    audio_params: dict[str, Any] = {
        "format": payload.audio_format,
        "sample_rate": payload.sample_rate,
        "speech_rate": payload.speech_rate,
        "loudness_rate": payload.loudness_rate,
    }
    if payload.audio_format == "mp3":
        audio_params["bit_rate"] = payload.bit_rate
    if payload.enable_subtitle:
        audio_params["enable_subtitle"] = True
    req_params: dict[str, Any] = {
        "text": payload.text.strip(),
        "speaker": payload.speaker,
        "audio_params": audio_params,
    }
    if payload.context_texts:
        req_params["additions"] = json.dumps(
            {"context_texts": payload.context_texts},
            ensure_ascii=False,
            separators=(",", ":"),
        )
    if provider["model"] and provider["model"] != "seed-tts-2.0":
        req_params["model"] = provider["model"]

    provider_headers = {
        "Content-Type": "application/json",
        "X-Api-Key": provider["api_key"],
        "X-Api-Resource-Id": provider["resource_id"] or provider["model"],
        "X-Api-Request-Id": f"tts_{secrets.token_hex(16)}",
        "X-Control-Require-Usage-Tokens-Return": "*",
    }
    try:
        response = await request.app.state.http.post(
            provider["base_url"],
            headers=provider_headers,
            json={"req_params": req_params},
        )
    except httpx.TimeoutException as error:
        _release_quota(user_id, "tts")
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="TTS provider timed out.") from error
    except httpx.RequestError as error:
        _release_quota(user_id, "tts")
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="TTS provider is unavailable.") from error

    quota_headers = _quota_headers("tts", remaining)
    log_id = response.headers.get("x-tt-logid")
    if log_id:
        quota_headers["X-Tt-Logid"] = log_id[:200]
    if response.status_code >= 400:
        _release_quota(user_id, "tts")
        return JSONResponse(
            status_code=status.HTTP_502_BAD_GATEWAY,
            content={"error": {"message": _safe_provider_error(response.content)}},
            headers=quota_headers,
        )
    content_type = response.headers.get("content-type", "application/octet-stream").split(";", 1)[0]
    return Response(content=response.content, status_code=status.HTTP_200_OK, media_type=content_type, headers=quota_headers)


@app.post("/v1/game/asr/transcriptions")
async def asr_transcription(
    payload: AsrTranscriptionRequest,
    request: Request,
    user_id: str = Depends(authorize_request),
):
    provider = _get_capability_provider("asr")
    if not provider["api_key"] or not provider["model"]:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Official ASR is not configured.")

    request.state.usage_units = len(payload.audio_base64) * 3 // 4
    remaining = _consume_quota(user_id, "asr")

    provider_payload = {
        "model": provider["model"],
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_audio",
                        "input_audio": f"data:audio/wav;base64,{payload.audio_base64}",
                    }
                ],
            }
        ],
    }
    try:
        response = await request.app.state.http.post(
            provider["base_url"],
            headers={"Authorization": f"Bearer {provider['api_key']}", "Content-Type": "application/json"},
            json=provider_payload,
        )
    except httpx.TimeoutException as error:
        _release_quota(user_id, "asr")
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="ASR provider timed out.") from error
    except httpx.RequestError as error:
        _release_quota(user_id, "asr")
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="ASR provider is unavailable.") from error

    quota_headers = _quota_headers("asr", remaining)
    if response.status_code >= 400:
        _release_quota(user_id, "asr")
        return JSONResponse(
            status_code=status.HTTP_502_BAD_GATEWAY,
            content={"error": {"message": _safe_provider_error(response.content)}},
            headers=quota_headers,
        )
    return _json_response(response, quota_headers)


@app.post("/v1/game/embeddings")
async def embeddings(
    payload: EmbeddingRequest,
    request: Request,
    user_id: str = Depends(authorize_request),
):
    provider = _get_capability_provider("embedding")
    if not provider["api_key"] or not provider["model"]:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Official Embedding is not configured.")

    request.state.usage_units = len(payload.text)
    remaining = _consume_quota(user_id, "embedding")

    provider_payload = {
        "model": provider["model"],
        "input": [{"type": "text", "text": payload.text.strip()}],
        "encoding_format": "float",
    }
    try:
        response = await request.app.state.http.post(
            provider["base_url"],
            headers={"Authorization": f"Bearer {provider['api_key']}", "Content-Type": "application/json"},
            json=provider_payload,
        )
    except httpx.TimeoutException as error:
        _release_quota(user_id, "embedding")
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="Embedding provider timed out.") from error
    except httpx.RequestError as error:
        _release_quota(user_id, "embedding")
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Embedding provider is unavailable.") from error

    quota_headers = _quota_headers("embedding", remaining)
    if response.status_code >= 400:
        _release_quota(user_id, "embedding")
        return JSONResponse(
            status_code=status.HTTP_502_BAD_GATEWAY,
            content={"error": {"message": _safe_provider_error(response.content)}},
            headers=quota_headers,
        )
    return _json_response(response, quota_headers)


@app.post("/v1/game/vision/responses")
async def vision_responses(
    payload: VisionResponseRequest,
    request: Request,
    user_id: str = Depends(authorize_request),
):
    provider = _get_capability_provider("vision")
    if not provider["api_key"] or not provider["model"]:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Official Vision is not configured.")

    request.state.usage_units = len(payload.image_base64) * 3 // 4
    remaining = _consume_quota(user_id, "vision")

    provider_payload = {
        "model": provider["model"],
        "input": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_image",
                        "image_url": f"data:{payload.image_media_type};base64,{payload.image_base64}",
                    },
                    {
                        "type": "input_text",
                        "text": f"{payload.system_prompt.strip()}\n\n{payload.user_prompt.strip()}",
                    },
                ],
            }
        ],
    }
    try:
        response = await request.app.state.http.post(
            provider["base_url"],
            headers={"Authorization": f"Bearer {provider['api_key']}", "Content-Type": "application/json"},
            json=provider_payload,
        )
    except httpx.TimeoutException as error:
        _release_quota(user_id, "vision")
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="Vision provider timed out.") from error
    except httpx.RequestError as error:
        _release_quota(user_id, "vision")
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Vision provider is unavailable.") from error

    quota_headers = _quota_headers("vision", remaining)
    if response.status_code >= 400:
        _release_quota(user_id, "vision")
        return JSONResponse(
            status_code=status.HTTP_502_BAD_GATEWAY,
            content={"error": {"message": _safe_provider_error(response.content)}},
            headers=quota_headers,
        )
    return _json_response(response, quota_headers)


@app.post("/v1/game/images/generations")
async def image_generations(
    payload: ImageGenerationRequest,
    request: Request,
    user_id: str = Depends(authorize_request),
):
    provider = _get_capability_provider("image")
    if not provider["api_key"] or not provider["model"]:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Official image generation is not configured.")

    request.state.usage_units = 1
    remaining = _consume_quota(user_id, "image")

    provider_payload = {
        "model": provider["model"],
        "prompt": payload.prompt.strip(),
        "sequential_image_generation": "disabled",
        "response_format": "url",
        "size": "2K",
        "stream": False,
        "watermark": True,
    }

    def release_quota() -> None:
        _release_quota(user_id, "image")

    try:
        response = await request.app.state.http.post(
            provider["base_url"],
            headers={"Authorization": f"Bearer {provider['api_key']}", "Content-Type": "application/json"},
            json=provider_payload,
        )
    except httpx.TimeoutException as error:
        release_quota()
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="Image provider timed out.") from error
    except httpx.RequestError as error:
        release_quota()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Image provider is unavailable.") from error

    quota_headers = _quota_headers("image", remaining)
    if response.status_code >= 400:
        release_quota()
        return JSONResponse(
            status_code=status.HTTP_502_BAD_GATEWAY,
            content={"error": {"message": _safe_provider_error(response.content)}},
            headers=quota_headers,
        )

    try:
        provider_body = response.json()
        image_item = provider_body["data"][0]
        encoded_image = image_item.get("b64_json") or image_item.get("image_base64")
        if encoded_image:
            image_bytes = base64.b64decode(encoded_image, validate=True)
        else:
            image_url = str(image_item["url"])
            _validate_provider_image_url(image_url)
            image_response = await request.app.state.http.get(image_url)
            if image_response.status_code != 200:
                raise ValueError("Image provider download failed.")
            image_bytes = image_response.content
    except httpx.TimeoutException as error:
        release_quota()
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="Generated image download timed out.") from error
    except httpx.RequestError as error:
        release_quota()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Generated image could not be downloaded.") from error
    except (KeyError, IndexError, TypeError, ValueError, binascii.Error) as error:
        release_quota()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Image provider returned an invalid response.") from error

    if len(image_bytes) > 12_000_000:
        release_quota()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Generated image is too large.")
    image_media_type = _detect_image_media_type(image_bytes)
    if image_media_type is None:
        release_quota()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Image provider returned unsupported image data.")
    return JSONResponse(
        content={
            "image_base64": base64.b64encode(image_bytes).decode("ascii"),
            "image_media_type": image_media_type,
        },
        headers=quota_headers,
    )


def _json_response(response: httpx.Response, headers: dict[str, str] | None = None) -> JSONResponse:
    try:
        body: Any = response.json()
    except ValueError:
        body = {"error": {"message": "AI provider returned an invalid response."}}
    return JSONResponse(content=body, status_code=response.status_code, headers=headers)


def _safe_provider_error(body: bytes) -> str:
    try:
        parsed = json.loads(body)
        message = parsed.get("error", {}).get("message")
        if isinstance(message, str) and message:
            return message[:500]
    except (ValueError, AttributeError):
        pass
    return "AI provider request failed."
