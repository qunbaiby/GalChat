# pyright: reportAny=false, reportExplicitAny=false, reportImplicitRelativeImport=false, reportMissingParameterType=false, reportUnknownArgumentType=false, reportUnknownMemberType=false, reportUnknownParameterType=false, reportUnknownVariableType=false

import importlib
import json
import logging
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, override

import httpx
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient

GATEWAY_ROOT = Path(__file__).resolve().parents[1]
if str(GATEWAY_ROOT) not in sys.path:
    sys.path.insert(0, str(GATEWAY_ROOT))


def load_app(tmp_path: Path | None = None) -> Any:
    os.environ["GALCHAT_PLAYER_TOKENS"] = "test-player-token"
    os.environ["DEEPSEEK_API_KEY"] = "test-provider-key"
    os.environ["GALCHAT_JWT_SECRET"] = "test-secret-with-at-least-32-characters"
    os.environ["GALCHAT_DATABASE_PATH"] = str((tmp_path or Path(".")).joinpath("gateway-test.db"))
    os.environ["GALCHAT_EMAIL_CODE_COOLDOWN_SECONDS"] = "60"
    os.environ["GALCHAT_LOGIN_MAX_ATTEMPTS"] = "5"
    os.environ["GALCHAT_LOGIN_LOCK_MINUTES"] = "15"
    os.environ["GALCHAT_EMAIL_MODE"] = "console"
    os.environ["GALCHAT_ENVIRONMENT"] = "development"
    os.environ["GALCHAT_DEV_TEST_ACCOUNT_ENABLED"] = "true"
    os.environ["GALCHAT_DEV_TEST_USERNAME"] = "galchat_test"
    os.environ["GALCHAT_DEV_TEST_EMAIL"] = "test@galchat.local"
    os.environ["GALCHAT_DEV_TEST_PASSWORD"] = "GalChatTest2026!"
    os.environ["GALCHAT_ADMIN_TOKEN"] = "test-admin-token-with-at-least-32-characters"
    os.environ["GALCHAT_SECRETS_MASTER_KEY"] = Fernet.generate_key().decode("ascii")
    import app

    return importlib.reload(app)


def test_health_is_public(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_request_id_is_returned_and_unsafe_value_is_replaced(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        accepted = client.get("/health", headers={"X-Request-ID": "deploy-check-1234"})
        replaced = client.get("/health", headers={"X-Request-ID": "unsafe\nvalue"})

    assert accepted.headers["x-request-id"] == "deploy-check-1234"
    assert replaced.headers["x-request-id"].startswith("req_")
    assert replaced.headers["x-request-id"] != "unsafe\nvalue"


def test_access_log_is_json_and_excludes_sensitive_request_data(tmp_path):
    module = load_app(tmp_path)
    records: list[logging.LogRecord] = []

    class CaptureHandler(logging.Handler):
        @override
        def emit(self, record: logging.LogRecord) -> None:
            records.append(record)

    handler = CaptureHandler()
    module.access_logger.addHandler(handler)
    try:
        with TestClient(module.app) as client:
            response = client.get(
                "/health",
                headers={"Authorization": "Bearer secret-player-token", "X-Request-ID": "log-check-1234"},
            )
    finally:
        module.access_logger.removeHandler(handler)

    assert response.status_code == 200
    payload = json.loads(records[-1].getMessage())
    assert payload["request_id"] == "log-check-1234"
    assert payload["path"] == "/health"
    assert "secret-player-token" not in records[-1].getMessage()
    assert "authorization" not in records[-1].getMessage().lower()


def test_readiness_reports_schema_and_retention(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        response = client.get("/ready")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ready",
        "schema_version": module.GatewayStorage.SCHEMA_VERSION,
        "usage_event_retention_days": module.settings.usage_event_retention_days,
        "email_configured": True,
    }


def test_storage_tracks_schema_version_and_rejects_newer_database(tmp_path):
    module = load_app(tmp_path)
    assert module.storage.get_schema_version() == module.GatewayStorage.SCHEMA_VERSION

    with module.storage._connect() as connection:
        connection.execute(
            "UPDATE schema_metadata SET metadata_value = ? WHERE metadata_key = 'schema_version'",
            (str(module.GatewayStorage.SCHEMA_VERSION + 1),),
        )

    try:
        module.GatewayStorage(module.settings.database_path, module.settings.refresh_token_days)
    except RuntimeError as error:
        assert "newer than supported" in str(error)
    else:
        raise AssertionError("A newer database schema must be rejected.")


def test_usage_event_cleanup_preserves_recent_events(tmp_path):
    module = load_app(tmp_path)
    module.storage.record_usage_event("usr_recent", "chat", "succeeded", 10, "200", 5)
    with module.storage._connect() as connection:
        connection.execute("INSERT INTO usage_events (event_id, user_id, capability, status, units, latency_ms, error_code, created_at) VALUES ('evt_expired', 'usr_old', 'tts', 'succeeded', 1, 10, '200', '2020-01-01T00:00:00+00:00')")

    deleted = module.storage.cleanup_usage_events(90)
    events = module.storage.list_usage_events(10)

    assert deleted == 1
    assert [event["user_id"] for event in events] == ["usr_recent"]


def test_database_backup_is_consistent_and_restorable(tmp_path):
    module = load_app(tmp_path)
    module.storage.record_usage_event("usr_backup", "chat", "succeeded", 12, "200", 7)
    backup_path = tmp_path / "backups" / "snapshot.db"

    created_path = module.storage.create_backup(str(backup_path))
    inspection = module.GatewayStorage.inspect_database(created_path)

    assert inspection["integrity"] == "ok"
    assert inspection["schema_version"] == module.GatewayStorage.SCHEMA_VERSION

    module.storage.record_usage_event("usr_after_backup", "image", "succeeded", 20, "200", 1)
    restore_result = module.GatewayStorage.restore_backup(created_path, module.settings.database_path)
    restored_storage = module.GatewayStorage(module.settings.database_path, module.settings.refresh_token_days)
    restored_users = [event["user_id"] for event in restored_storage.list_usage_events(10)]

    assert restore_result["previous_database_path"]
    assert Path(restore_result["previous_database_path"]).is_file()
    assert restored_users == ["usr_backup"]


def test_database_restore_rejects_corrupt_backup(tmp_path):
    module = load_app(tmp_path)
    corrupt_backup = tmp_path / "corrupt.db"
    corrupt_backup.write_bytes(b"not-a-sqlite-database")

    try:
        module.GatewayStorage.restore_backup(str(corrupt_backup), module.settings.database_path)
    except Exception as error:
        assert "database" in str(error).lower() or "file" in str(error).lower()
    else:
        raise AssertionError("A corrupt backup must not be restored.")


def test_maintenance_cli_creates_and_inspects_backup(tmp_path):
    module = load_app(tmp_path)
    backup_path = tmp_path / "cli-backup.db"
    maintenance_path = GATEWAY_ROOT / "maintenance.py"
    backup_result = subprocess.run(
        [
            sys.executable,
            str(maintenance_path),
            "backup",
            "--database",
            module.settings.database_path,
            "--output",
            str(backup_path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    inspect_result = subprocess.run(
        [sys.executable, str(maintenance_path), "inspect", str(backup_path)],
        check=True,
        capture_output=True,
        text=True,
    )

    created = json.loads(backup_result.stdout)
    inspected = json.loads(inspect_result.stdout)
    assert Path(created["backup_path"]).is_file()
    assert created["integrity"] == "ok"
    assert inspected["schema_version"] == module.GatewayStorage.SCHEMA_VERSION


def test_deployment_preflight_checks_admin_and_creates_backup(tmp_path, monkeypatch, capsys):
    module = load_app(tmp_path)
    import preflight

    preflight = importlib.reload(preflight)
    requests: list[tuple[str, bool]] = []

    def fake_request_json(url: str, admin_token: str = "") -> tuple[int, dict[str, Any]]:
        requests.append((url, bool(admin_token)))
        if url.endswith("/health"):
            return 200, {"status": "ok"}
        if url.endswith("/ready"):
            return 200, {
                "status": "ready",
                "schema_version": module.GatewayStorage.SCHEMA_VERSION,
                "email_configured": True,
            }
        return (200, {"status": "ok"}) if admin_token else (401, {"detail": "Unauthorized"})

    backup_path = tmp_path / "preflight-backup.db"
    monkeypatch.setattr(preflight, "request_json", fake_request_json)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "preflight.py",
            "--database",
            module.settings.database_path,
            "--backup-output",
            str(backup_path),
        ],
    )

    assert preflight.main() == 0
    result = json.loads(capsys.readouterr().out)
    assert result["status"] == "passed"
    assert result["backup"]["integrity"] == "ok"
    assert backup_path.is_file()
    assert requests[-2][1] is False
    assert requests[-1][1] is True


def test_production_configuration_rejects_insecure_defaults(tmp_path):
    module = load_app(tmp_path)
    os.environ["GALCHAT_ENVIRONMENT"] = "production"
    os.environ["GALCHAT_JWT_SECRET"] = "short"
    os.environ["GALCHAT_ADMIN_TOKEN"] = "short"
    os.environ["GALCHAT_SECRETS_MASTER_KEY"] = "invalid"
    os.environ["GALCHAT_DATABASE_PATH"] = "data/ai_gateway.db"
    os.environ["GALCHAT_EMAIL_MODE"] = "console"

    try:
        module.Settings()
    except RuntimeError as error:
        message = str(error)
        assert "GALCHAT_JWT_SECRET" in message
        assert "GALCHAT_ADMIN_TOKEN" in message
        assert "GALCHAT_SECRETS_MASTER_KEY" in message
        assert "GALCHAT_DATABASE_PATH" in message
        assert "GALCHAT_EMAIL_MODE" in message
    else:
        raise AssertionError("Production must reject insecure defaults.")


def test_production_configuration_accepts_explicit_secure_values(tmp_path):
    module = load_app(tmp_path)
    os.environ["GALCHAT_ENVIRONMENT"] = "production"
    os.environ["GALCHAT_JWT_SECRET"] = "j" * 48
    os.environ["GALCHAT_ADMIN_TOKEN"] = "a" * 48
    os.environ["GALCHAT_SECRETS_MASTER_KEY"] = Fernet.generate_key().decode("ascii")
    os.environ["GALCHAT_DATABASE_PATH"] = str(tmp_path / "production.db")
    os.environ["GALCHAT_EMAIL_MODE"] = "smtp"
    os.environ["GALCHAT_SMTP_HOST"] = "smtp.example.com"
    os.environ["GALCHAT_EMAIL_FROM"] = "no-reply@example.com"

    production_settings = module.Settings()

    assert production_settings.environment == "production"
    assert production_settings.database_path == str(tmp_path / "production.db")


def test_admin_console_page_is_public_but_api_requires_admin_token(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        page = client.get("/admin")
        unauthorized = client.get("/admin/api/overview")
    assert page.status_code == 200
    assert "GalChat" in page.text
    assert "官方能力配置" in page.text
    assert 'api("/admin/api/capability-providers")' in page.text
    assert "Promise.allSettled" in page.text
    assert "usageCapabilityFilter" in page.text
    assert "accountQueryInput" in page.text
    assert "data-usage-sort" in page.text
    assert unauthorized.status_code == 401


def test_admin_api_returns_overview_without_provider_secret(tmp_path):
    module = load_app(tmp_path)
    headers = {"Authorization": "Bearer test-admin-token-with-at-least-32-characters"}
    with TestClient(module.app) as client:
        response = client.get("/admin/api/overview", headers=headers)
    assert response.status_code == 200
    payload = response.json()
    assert payload["provider_configured"] is True
    assert payload["users"] == 1
    assert "test-provider-key" not in response.text


def test_admin_lists_support_server_side_filtering_sorting_and_pagination(tmp_path):
    module = load_app(tmp_path)
    headers = {"Authorization": "Bearer test-admin-token-with-at-least-32-characters"}
    module.storage.record_usage_event("usr_filter_alpha", "tts", "provider_error", 40, "503", 2)
    module.storage.record_usage_event("usr_filter_beta", "tts", "succeeded", 10, "200", 1)
    module.storage.record_usage_event("usr_filter_alpha", "chat", "succeeded", 5, "200", 3)

    with TestClient(module.app) as client:
        usage = client.get(
            "/admin/api/usage-events",
            headers=headers,
            params={
                "limit": 10,
                "offset": 0,
                "capability": "tts",
                "event_status": "provider_error",
                "user_query": "filter_alpha",
                "sort_by": "latency_ms",
                "sort_order": "desc",
            },
        )
        users = client.get(
            "/admin/api/users",
            headers=headers,
            params={"query": "galchat_test", "sort_by": "username", "sort_order": "asc"},
        )

    assert usage.status_code == 200
    assert usage.json()["total"] == 1
    assert usage.json()["items"][0]["capability"] == "tts"
    assert usage.json()["items"][0]["status"] == "provider_error"
    assert usage.json()["sort_by"] == "latency_ms"
    assert users.status_code == 200
    assert users.json()["total"] == 1
    assert users.json()["items"][0]["username"] == "galchat_test"
    assert users.json()["sort_order"] == "asc"


def test_admin_user_list_masks_email_and_rejects_player_token(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        rejected = client.get(
            "/admin/api/users",
            headers={"Authorization": "Bearer test-player-token"},
        )
        response = client.get(
            "/admin/api/users",
            headers={"Authorization": "Bearer test-admin-token-with-at-least-32-characters"},
        )
    assert rejected.status_code == 401
    assert response.status_code == 200
    assert response.json()["items"][0]["email"] == "te***@galchat.local"
    assert "test@galchat.local" not in response.text


def test_admin_api_is_disabled_without_configured_token(tmp_path):
    module = load_app(tmp_path)
    module.settings.admin_token = ""
    with TestClient(module.app) as client:
        response = client.get(
            "/admin/api/overview",
            headers={"Authorization": "Bearer any-token"},
        )
    assert response.status_code == 503


def test_admin_can_test_and_save_encrypted_provider_config(tmp_path):
    module = load_app(tmp_path)
    headers = {"Authorization": "Bearer test-admin-token-with-at-least-32-characters"}
    payload = {
        "api_key": "new-provider-secret-key",
        "base_url": "https://provider.example/v1",
        "allowed_models": ["deepseek-chat", "deepseek-reasoner"],
    }

    def provider_response(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer new-provider-secret-key"
        return httpx.Response(200, json={"choices": [{"message": {"content": "OK"}}]})

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        tested = client.post("/admin/api/provider/test", headers=headers, json=payload)
        saved = client.put("/admin/api/provider", headers=headers, json=payload)
        provider = client.get("/admin/api/provider", headers=headers)
        audit = client.get("/admin/api/audit-logs", headers=headers)

    assert tested.status_code == 200
    assert saved.status_code == 200
    assert provider.json()["source"] == "encrypted_store"
    assert provider.json()["configured"] is True
    assert module.settings.provider_api_key == "new-provider-secret-key"
    stored = module.storage.get_provider_config()
    assert stored is not None
    assert stored["encrypted_api_key"] != "new-provider-secret-key"
    assert "new-provider-secret-key" not in audit.text
    assert audit.json()["items"][0]["action"] == "provider.config_updated"


def test_admin_rejects_invalid_provider_key_without_saving(tmp_path):
    module = load_app(tmp_path)
    headers = {"Authorization": "Bearer test-admin-token-with-at-least-32-characters"}
    payload = {
        "api_key": "invalid-provider-key",
        "base_url": "https://provider.example/v1",
        "allowed_models": ["deepseek-chat"],
    }

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(
            transport=httpx.MockTransport(lambda _request: httpx.Response(401, json={"error": {"message": "invalid"}}))
        )
        response = client.put("/admin/api/provider", headers=headers, json=payload)

    assert response.status_code == 502
    assert module.storage.get_provider_config() is None
    assert "invalid-provider-key" not in response.text


def test_admin_can_delete_encrypted_provider_config(tmp_path):
    module = load_app(tmp_path)
    headers = {"Authorization": "Bearer test-admin-token-with-at-least-32-characters"}
    module.storage.save_provider_config(
        module.provider_secret_cipher.encrypt("stored-provider-key"),
        "https://provider.example/v1",
        "deepseek-chat",
    )
    module.settings.provider_api_key = "stored-provider-key"

    with TestClient(module.app) as client:
        response = client.delete("/admin/api/provider/key", headers=headers)

    assert response.status_code == 200
    assert response.json() == {"success": True}
    assert module.storage.get_provider_config() is None
    assert module.settings.provider_api_key == "test-provider-key"


def test_admin_can_manage_encrypted_capability_provider_config(tmp_path, monkeypatch):
    monkeypatch.setenv("GALCHAT_TTS_API_KEY", "environment-tts-key")
    module = load_app(tmp_path)
    headers = {"Authorization": "Bearer test-admin-token-with-at-least-32-characters"}
    payload = {
        "api_key": "stored-tts-secret-key",
        "base_url": "https://tts.example/v3/synthesize",
        "model": "seed-tts-2.0",
        "resource_id": "seed-tts-resource",
    }

    with TestClient(module.app) as client:
        saved = client.put("/admin/api/capability-providers/tts", headers=headers, json=payload)
        providers = client.get("/admin/api/capability-providers", headers=headers)
        stored = module.storage.list_capability_provider_configs()["tts"]
        deleted = client.delete("/admin/api/capability-providers/tts", headers=headers)
        audit = client.get("/admin/api/audit-logs", headers=headers)

    assert saved.status_code == 200
    assert providers.status_code == 200
    assert providers.json()["items"]["tts"]["source"] == "encrypted_store"
    assert "stored-tts-secret-key" not in providers.text
    assert stored["encrypted_api_key"] != "stored-tts-secret-key"
    assert module.settings.capability_providers["tts"]["api_key"] == "environment-tts-key"
    assert deleted.json() == {"success": True}
    assert "tts" not in module.storage.list_capability_provider_configs()
    assert "stored-tts-secret-key" not in audit.text
    assert audit.json()["items"][0]["action"] == "provider.tts_config_deleted"


def test_development_account_can_login_without_registration(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        response = client.post(
            "/v1/auth/email/login",
            json={"identity": "galchat_test", "password": "GalChatTest2026!"},
        )
    assert response.status_code == 200
    assert response.json()["user_id"].startswith("usr_dev_")


def test_production_never_seeds_development_account(tmp_path):
    os.environ["GALCHAT_PLAYER_TOKENS"] = "test-player-token"
    os.environ["DEEPSEEK_API_KEY"] = "test-provider-key"
    os.environ["GALCHAT_JWT_SECRET"] = "test-secret-with-at-least-32-characters"
    os.environ["GALCHAT_ADMIN_TOKEN"] = "test-admin-token-with-at-least-32-characters"
    os.environ["GALCHAT_SECRETS_MASTER_KEY"] = Fernet.generate_key().decode("ascii")
    os.environ["GALCHAT_DATABASE_PATH"] = str(tmp_path.joinpath("production-gateway.db"))
    os.environ["GALCHAT_EMAIL_MODE"] = "smtp"
    os.environ["GALCHAT_SMTP_HOST"] = "smtp.example.com"
    os.environ["GALCHAT_EMAIL_FROM"] = "no-reply@example.com"
    os.environ["GALCHAT_ENVIRONMENT"] = "production"
    os.environ["GALCHAT_DEV_TEST_ACCOUNT_ENABLED"] = "true"
    import app

    module = importlib.reload(app)
    with TestClient(module.app) as client:
        response = client.post(
            "/v1/auth/email/login",
            json={"identity": "galchat_test", "password": "GalChatTest2026!"},
        )
    assert response.status_code == 401
    os.environ["GALCHAT_ENVIRONMENT"] = "development"


def test_chat_requires_player_token(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        response = client.post(
            "/v1/game/chat/completions",
            json={"model": "deepseek-chat", "messages": [{"role": "user", "content": "hello"}]},
        )
    assert response.status_code == 401


def test_chat_rejects_unknown_fields(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        response = client.post(
            "/v1/game/chat/completions",
            headers={"Authorization": "Bearer test-player-token"},
            json={
                "model": "deepseek-chat",
                "messages": [{"role": "user", "content": "hello"}],
                "provider_url": "https://attacker.example",
            },
        )
    assert response.status_code == 422


def test_chat_rejects_unapproved_model(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        response = client.post(
            "/v1/game/chat/completions",
            headers={"Authorization": "Bearer test-player-token"},
            json={"model": "unapproved-model", "messages": [{"role": "user", "content": "hello"}]},
        )
    assert response.status_code == 400


def test_rate_limiter_rejects_excess_requests(tmp_path):
    module = load_app(tmp_path)
    module.limiter = module.SlidingWindowLimiter(limit=1, window_seconds=60)
    with TestClient(module.app) as client:
        headers = {"Authorization": "Bearer test-player-token"}
        payload = {"model": "unapproved-model", "messages": [{"role": "user", "content": "hello"}]}
        first_response = client.post("/v1/game/chat/completions", headers=headers, json=payload)
        second_response = client.post("/v1/game/chat/completions", headers=headers, json=payload)
    assert first_response.status_code == 400
    assert second_response.status_code == 429


def test_device_registration_and_refresh_rotation(tmp_path):
    module = load_app(tmp_path)
    credentials = {"installation_id": "installation-123456", "installation_secret": "s" * 48}
    with TestClient(module.app) as client:
        registered = client.post("/v1/auth/device/register", json=credentials)
        assert registered.status_code == 201
        first_tokens = registered.json()
        quota = client.get(
            "/v1/account/quota",
            headers={"Authorization": f"Bearer {first_tokens['access_token']}"},
        )
        assert quota.status_code == 200
        assert quota.json()["remaining"] == module.settings.daily_request_limit

        refreshed = client.post("/v1/auth/refresh", json={"refresh_token": first_tokens["refresh_token"]})
        assert refreshed.status_code == 200
        second_tokens = refreshed.json()
        assert second_tokens["refresh_token"] != first_tokens["refresh_token"]

        replay = client.post("/v1/auth/refresh", json={"refresh_token": first_tokens["refresh_token"]})
        assert replay.status_code == 401


def test_device_login_rejects_wrong_secret(tmp_path):
    module = load_app(tmp_path)
    credentials = {"installation_id": "installation-123456", "installation_secret": "s" * 48}
    with TestClient(module.app) as client:
        assert client.post("/v1/auth/device/register", json=credentials).status_code == 201
        credentials["installation_secret"] = "x" * 48
        assert client.post("/v1/auth/device/login", json=credentials).status_code == 401


def test_daily_quota_is_enforced_before_provider_call(tmp_path):
    module = load_app(tmp_path)
    module.settings.daily_request_limit = 1
    module.settings.capability_daily_limits["chat"] = 1
    credentials = {"installation_id": "installation-123456", "installation_secret": "s" * 48}
    with TestClient(module.app) as client:
        tokens = client.post("/v1/auth/device/register", json=credentials).json()
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        payload = {"model": "unapproved-model", "messages": [{"role": "user", "content": "hello"}]}
        assert client.post("/v1/game/chat/completions", headers=headers, json=payload).status_code == 400

        valid_payload = {"model": "deepseek-chat", "messages": [{"role": "user", "content": "hello"}]}
        provider_calls = 0

        def provider_response(_request: httpx.Request) -> httpx.Response:
            nonlocal provider_calls
            provider_calls += 1
            return httpx.Response(200, json={"choices": [{"message": {"content": "ok"}}]})

        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        successful = client.post("/v1/game/chat/completions", headers=headers, json=valid_payload)
        assert successful.status_code == 200
        quota = client.get("/v1/account/quota", headers=headers).json()
        assert quota["remaining"] == 0
        exceeded = client.post("/v1/game/chat/completions", headers=headers, json=valid_payload)
        assert exceeded.status_code == 429
        assert provider_calls == 1


def test_chat_timeout_releases_quota_and_records_timeout(tmp_path):
    module = load_app(tmp_path)
    credentials = {"installation_id": "chat-timeout-install", "installation_secret": "s" * 48}

    def provider_timeout(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out", request=request)

    with TestClient(module.app) as client:
        tokens = client.post("/v1/auth/device/register", json=credentials).json()
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_timeout))
        response = client.post(
            "/v1/game/chat/completions",
            headers=headers,
            json={"model": "deepseek-chat", "messages": [{"role": "user", "content": "hello"}]},
        )
        quota = client.get("/v1/account/quota", headers=headers).json()
        events = module.storage.list_usage_events(10)

    assert response.status_code == 504
    assert quota["capabilities"]["chat"]["used"] == 0
    assert events[0]["status"] == "timeout"


def test_chat_provider_error_releases_quota(tmp_path):
    module = load_app(tmp_path)
    credentials = {"installation_id": "chat-provider-error", "installation_secret": "s" * 48}

    def provider_error(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(429, json={"error": {"message": "provider limited"}})

    with TestClient(module.app) as client:
        tokens = client.post("/v1/auth/device/register", json=credentials).json()
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_error))
        response = client.post(
            "/v1/game/chat/completions",
            headers=headers,
            json={"model": "deepseek-chat", "messages": [{"role": "user", "content": "hello"}]},
        )
        quota = client.get("/v1/account/quota", headers=headers).json()

    assert response.status_code == 502
    assert quota["capabilities"]["chat"]["used"] == 0


def test_streaming_chat_provider_error_records_final_status(tmp_path):
    module = load_app(tmp_path)
    credentials = {"installation_id": "chat-stream-error", "installation_secret": "s" * 48}

    def provider_error(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, json={"error": {"message": "provider unavailable"}})

    with TestClient(module.app) as client:
        tokens = client.post("/v1/auth/device/register", json=credentials).json()
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_error))
        with client.stream(
            "POST",
            "/v1/game/chat/completions",
            headers=headers,
            json={
                "model": "deepseek-chat",
                "messages": [{"role": "user", "content": "hello"}],
                "stream": True,
            },
        ) as response:
            _ = response.read()
        quota = client.get("/v1/account/quota", headers=headers).json()
        events = module.storage.list_usage_events(10)

    assert response.status_code == 200
    assert quota["capabilities"]["chat"]["used"] == 0
    assert events[0]["status"] == "provider_error"
    assert not any(event["status"] == "succeeded" for event in events)


def test_capability_quotas_are_isolated_and_reported(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_daily_limits["chat"] = 1
    module.settings.capability_daily_limits["embedding"] = 2
    module.settings.capability_providers["embedding"] = {
        "api_key": "server-embedding-secret",
        "base_url": "https://embedding.example/v3/embeddings",
        "model": "embedding-model",
        "resource_id": "",
    }
    credentials = {"installation_id": "capability-installation", "installation_secret": "s" * 48}

    def provider_response(request: httpx.Request) -> httpx.Response:
        if "/embeddings" in str(request.url):
            return httpx.Response(200, json={"data": [{"embedding": [0.1, 0.2]}]})
        return httpx.Response(200, json={"choices": [{"message": {"content": "ok"}}]})

    with TestClient(module.app) as client:
        tokens = client.post("/v1/auth/device/register", json=credentials).json()
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        chat_payload = {"model": "deepseek-chat", "messages": [{"role": "user", "content": "hello"}]}
        assert client.post("/v1/game/chat/completions", headers=headers, json=chat_payload).status_code == 200
        assert client.post("/v1/game/chat/completions", headers=headers, json=chat_payload).status_code == 429
        embedding = client.post("/v1/game/embeddings", headers=headers, json={"text": "memory"})
        quota = client.get("/v1/account/quota", headers=headers).json()

    assert embedding.status_code == 200
    assert embedding.headers["x-quota-capability"] == "embedding"
    assert quota["capabilities"]["chat"] == {"limit": 1, "used": 1, "remaining": 0}
    assert quota["capabilities"]["embedding"] == {"limit": 2, "used": 1, "remaining": 1}


def test_admin_overview_reports_capability_usage_events(tmp_path):
    module = load_app(tmp_path)
    headers = {"Authorization": "Bearer admin-test-token-1234567890"}
    module.settings.admin_token = "admin-test-token-1234567890"
    module.storage.record_usage_event("usr_test", "tts", "succeeded", 120, "200", 25)
    module.storage.record_usage_event("usr_test", "tts", "timeout", 900, "504", 25)

    with TestClient(module.app) as client:
        response = client.get("/admin/api/overview", headers=headers)

    assert response.status_code == 200
    tts_stats = next(item for item in response.json()["capability_stats"] if item["capability"] == "tts")
    assert tts_stats == {
        "capability": "tts",
        "requests": 2,
        "succeeded": 1,
        "failed": 1,
        "quota_rejected": 0,
        "units": 50,
        "average_latency_ms": 510,
    }


def test_admin_can_update_and_persist_capability_limit(tmp_path):
    module = load_app(tmp_path)
    module.settings.admin_token = "admin-test-token-1234567890"
    admin_headers = {"Authorization": "Bearer admin-test-token-1234567890"}

    with TestClient(module.app) as client:
        updated = client.put(
            "/admin/api/capability-quotas/image",
            headers=admin_headers,
            json={"daily_limit": 3},
        )

    assert updated.status_code == 200
    assert module.settings.capability_daily_limits["image"] == 3
    stored = module.storage.list_capability_quota_limits()
    assert stored["image"]["daily_limit"] == 3

    restored_storage = module.GatewayStorage(module.settings.database_path, module.settings.refresh_token_days)
    assert restored_storage.list_capability_quota_limits()["image"]["daily_limit"] == 3


def test_official_tts_injects_server_config_and_returns_audio(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["tts"] = {
        "api_key": "server-tts-secret",
        "base_url": "https://tts.example/v3/speech",
        "model": "seed-tts-model",
        "resource_id": "seed-tts-resource",
    }

    def provider_response(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "https://tts.example/v3/speech"
        assert request.headers["X-Api-Key"] == "server-tts-secret"
        assert request.headers["X-Api-Resource-Id"] == "seed-tts-resource"
        body = __import__("json").loads(request.content)
        assert body["req_params"]["text"] == "hello"
        assert body["req_params"]["speaker"] == "S_voice_001"
        assert body["req_params"]["model"] == "seed-tts-model"
        assert body["req_params"]["audio_params"]["format"] == "mp3"
        additions = __import__("json").loads(body["req_params"]["additions"])
        assert additions == {
            "context_texts": ["请用略带担心但克制的语气说话，保持原本声线和音高。"]
        }
        return httpx.Response(
            200,
            content=b"ID3\x04mock-audio",
            headers={"Content-Type": "audio/mpeg", "X-Tt-Logid": "tts-log-123"},
        )

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        response = client.post(
            "/v1/game/tts/speech",
            headers={"Authorization": "Bearer test-player-token"},
            json={
                "text": "hello",
                "speaker": "S_voice_001",
                "audio_format": "mp3",
                "context_texts": ["请用略带担心但克制的语气说话，保持原本声线和音高。"],
            },
        )

    assert response.status_code == 200
    assert response.content == b"ID3\x04mock-audio"
    assert response.headers["content-type"].startswith("audio/mpeg")
    assert response.headers["x-tt-logid"] == "tts-log-123"


def test_official_tts_rejects_unconfigured_provider_and_extra_fields(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["tts"]["api_key"] = ""
    headers = {"Authorization": "Bearer test-player-token"}
    with TestClient(module.app) as client:
        unconfigured = client.post(
            "/v1/game/tts/speech",
            headers=headers,
            json={"text": "hello", "speaker": "S_voice_001"},
        )
        injected = client.post(
            "/v1/game/tts/speech",
            headers=headers,
            json={"text": "hello", "speaker": "S_voice_001", "api_key": "attacker-key"},
        )

    assert unconfigured.status_code == 503
    assert injected.status_code == 422


def test_official_tts_does_not_forward_resource_id_as_model(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["tts"] = {
        "api_key": "server-tts-secret",
        "base_url": "https://tts.example/v3/speech",
        "model": "seed-tts-2.0",
        "resource_id": "seed-tts-2.0",
    }

    def provider_response(request: httpx.Request) -> httpx.Response:
        body = __import__("json").loads(request.content)
        assert "model" not in body["req_params"]
        return httpx.Response(200, content=b"ID3\x04mock-audio", headers={"Content-Type": "audio/mpeg"})

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        response = client.post(
            "/v1/game/tts/speech",
            headers={"Authorization": "Bearer test-player-token"},
            json={"text": "hello", "speaker": "S_voice_001"},
        )

    assert response.status_code == 200


def test_official_tts_maps_provider_timeout(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["tts"]["api_key"] = "server-tts-secret"
    module.storage.save_email_code("tts@example.com", "123456", 10, 0)
    user_id = module.storage.register_email_user("tts_player", "tts@example.com", "secure-password", "123456")
    session_id, _refresh = module.storage.create_session(user_id)
    access_token, _expires_in = module.token_service.issue_access_token(user_id, session_id)

    def provider_timeout(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out", request=request)

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_timeout))
        response = client.post(
            "/v1/game/tts/speech",
            headers={"Authorization": f"Bearer {access_token}"},
            json={"text": "hello", "speaker": "S_voice_001"},
        )
        quota = client.get("/v1/account/quota", headers={"Authorization": f"Bearer {access_token}"})

    assert response.status_code == 504
    assert response.json()["detail"] == "TTS provider timed out."
    assert quota.json()["used"] == 0


def test_official_asr_injects_server_config_and_returns_transcript(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["asr"] = {
        "api_key": "server-asr-secret",
        "base_url": "https://asr.example/v1/chat/completions",
        "model": "qwen-asr-model",
        "resource_id": "",
    }
    encoded_audio = "UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YQAAAAA="

    def provider_response(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "https://asr.example/v1/chat/completions"
        assert request.headers["Authorization"] == "Bearer server-asr-secret"
        body = __import__("json").loads(request.content)
        assert body["model"] == "qwen-asr-model"
        assert body["messages"][0]["content"][0]["input_audio"] == f"data:audio/wav;base64,{encoded_audio}"
        return httpx.Response(200, json={"choices": [{"message": {"content": "璇嗗埆鎴愬姛"}}]})

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        response = client.post(
            "/v1/game/asr/transcriptions",
            headers={"Authorization": "Bearer test-player-token"},
            json={"audio_base64": encoded_audio},
        )

    assert response.status_code == 200
    assert response.json()["choices"][0]["message"]["content"] == "璇嗗埆鎴愬姛"


def test_official_asr_rejects_unconfigured_provider_and_extra_fields(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["asr"]["api_key"] = ""
    headers = {"Authorization": "Bearer test-player-token"}
    audio = "UklGRiQAAABXQVZFZm10IA=="
    with TestClient(module.app) as client:
        unconfigured = client.post(
            "/v1/game/asr/transcriptions", headers=headers, json={"audio_base64": audio}
        )
        injected = client.post(
            "/v1/game/asr/transcriptions",
            headers=headers,
            json={"audio_base64": audio, "model": "attacker-model"},
        )

    assert unconfigured.status_code == 503
    assert injected.status_code == 422


def test_official_asr_timeout_releases_quota(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["asr"]["api_key"] = "server-asr-secret"
    module.storage.save_email_code("asr@example.com", "123456", 10, 0)
    user_id = module.storage.register_email_user("asr_player", "asr@example.com", "secure-password", "123456")
    session_id, _refresh = module.storage.create_session(user_id)
    access_token, _expires_in = module.token_service.issue_access_token(user_id, session_id)

    def provider_timeout(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out", request=request)

    headers = {"Authorization": f"Bearer {access_token}"}
    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_timeout))
        response = client.post(
            "/v1/game/asr/transcriptions",
            headers=headers,
            json={"audio_base64": "UklGRiQAAABXQVZFZm10IA=="},
        )
        quota = client.get("/v1/account/quota", headers=headers)

    assert response.status_code == 504
    assert quota.json()["used"] == 0


def test_official_embedding_injects_server_config_and_returns_vector(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["embedding"] = {
        "api_key": "server-embedding-secret",
        "base_url": "https://embedding.example/v3/embeddings/multimodal",
        "model": "ep-server-endpoint",
        "resource_id": "",
    }

    def provider_response(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "https://embedding.example/v3/embeddings/multimodal"
        assert request.headers["Authorization"] == "Bearer server-embedding-secret"
        body = __import__("json").loads(request.content)
        assert body == {
            "model": "ep-server-endpoint",
            "input": [{"type": "text", "text": "memory text"}],
            "encoding_format": "float",
        }
        return httpx.Response(200, json={"data": [{"embedding": [0.1, 0.2, 0.3]}]})

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        response = client.post(
            "/v1/game/embeddings",
            headers={"Authorization": "Bearer test-player-token"},
            json={"text": "memory text"},
        )

    assert response.status_code == 200
    assert response.json()["data"][0]["embedding"] == [0.1, 0.2, 0.3]


def test_official_embedding_rejects_unconfigured_provider_and_extra_fields(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["embedding"]["api_key"] = ""
    headers = {"Authorization": "Bearer test-player-token"}
    with TestClient(module.app) as client:
        unconfigured = client.post("/v1/game/embeddings", headers=headers, json={"text": "memory"})
        injected = client.post(
            "/v1/game/embeddings",
            headers=headers,
            json={"text": "memory", "model": "attacker-model"},
        )

    assert unconfigured.status_code == 503
    assert injected.status_code == 422


def test_official_embedding_timeout_releases_quota(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["embedding"] = {
        "api_key": "server-embedding-secret",
        "base_url": "https://embedding.example/v3/embeddings/multimodal",
        "model": "ep-server-endpoint",
        "resource_id": "",
    }
    module.storage.save_email_code("embedding@example.com", "123456", 10, 0)
    user_id = module.storage.register_email_user(
        "embedding_player", "embedding@example.com", "secure-password", "123456"
    )
    session_id, _refresh = module.storage.create_session(user_id)
    access_token, _expires_in = module.token_service.issue_access_token(user_id, session_id)

    def provider_timeout(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out", request=request)

    headers = {"Authorization": f"Bearer {access_token}"}
    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_timeout))
        response = client.post("/v1/game/embeddings", headers=headers, json={"text": "memory text"})
        quota = client.get("/v1/account/quota", headers=headers)

    assert response.status_code == 504
    assert quota.json()["used"] == 0


def test_official_vision_injects_server_config_and_preserves_image_type(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["vision"] = {
        "api_key": "server-vision-secret",
        "base_url": "https://vision.example/v3/responses",
        "model": "vision-server-model",
        "resource_id": "",
    }
    image_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB"

    def provider_response(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "https://vision.example/v3/responses"
        assert request.headers["Authorization"] == "Bearer server-vision-secret"
        body = __import__("json").loads(request.content)
        assert body["model"] == "vision-server-model"
        content = body["input"][0]["content"]
        assert content[0]["image_url"] == f"data:image/png;base64,{image_base64}"
        assert content[1]["text"] == "system prompt\n\ndescribe this image"
        return httpx.Response(
            200,
            json={"output": [{"type": "message", "content": [{"type": "output_text", "text": "image description"}]}]},
        )

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        response = client.post(
            "/v1/game/vision/responses",
            headers={"Authorization": "Bearer test-player-token"},
            json={
                "system_prompt": "system prompt",
                "user_prompt": "describe this image",
                "image_base64": image_base64,
                "image_media_type": "image/png",
            },
        )

    assert response.status_code == 200
    assert response.json()["output"][0]["content"][0]["text"] == "image description"


def test_official_vision_rejects_unconfigured_provider_and_extra_fields(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["vision"]["api_key"] = ""
    headers = {"Authorization": "Bearer test-player-token"}
    payload = {
        "system_prompt": "system prompt",
        "user_prompt": "describe this image",
        "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB",
        "image_media_type": "image/png",
    }
    with TestClient(module.app) as client:
        unconfigured = client.post("/v1/game/vision/responses", headers=headers, json=payload)
        injected = client.post(
            "/v1/game/vision/responses",
            headers=headers,
            json={**payload, "model": "attacker-model"},
        )

    assert unconfigured.status_code == 503
    assert injected.status_code == 422


def test_official_vision_timeout_releases_quota(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["vision"]["api_key"] = "server-vision-secret"
    module.storage.save_email_code("vision@example.com", "123456", 10, 0)
    user_id = module.storage.register_email_user("vision_player", "vision@example.com", "secure-password", "123456")
    session_id, _refresh = module.storage.create_session(user_id)
    access_token, _expires_in = module.token_service.issue_access_token(user_id, session_id)

    def provider_timeout(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out", request=request)

    headers = {"Authorization": f"Bearer {access_token}"}
    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_timeout))
        response = client.post(
            "/v1/game/vision/responses",
            headers=headers,
            json={
                "system_prompt": "system prompt",
                "user_prompt": "describe this image",
                "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB",
                "image_media_type": "image/png",
            },
        )
        quota = client.get("/v1/account/quota", headers=headers)

    assert response.status_code == 504
    assert quota.json()["used"] == 0


def test_official_image_injects_server_config_and_normalizes_url_response(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["image"] = {
        "api_key": "server-image-secret",
        "base_url": "https://image.example/v3/images/generations",
        "model": "image-server-model",
        "resource_id": "",
    }
    png_bytes = b"\x89PNG\r\n\x1a\nminimal-image"

    def provider_response(request: httpx.Request) -> httpx.Response:
        if str(request.url) == "https://cdn.example/generated.png":
            return httpx.Response(200, content=png_bytes)
        assert str(request.url) == "https://image.example/v3/images/generations"
        assert request.headers["Authorization"] == "Bearer server-image-secret"
        body = __import__("json").loads(request.content)
        assert body == {
            "model": "image-server-model",
            "prompt": "generate a night sky illustration",
            "sequential_image_generation": "disabled",
            "response_format": "url",
            "size": "2K",
            "stream": False,
            "watermark": True,
        }
        return httpx.Response(200, json={"data": [{"url": "https://cdn.example/generated.png"}]})

    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        response = client.post(
            "/v1/game/images/generations",
            headers={"Authorization": "Bearer test-player-token"},
            json={"prompt": "generate a night sky illustration"},
        )

    assert response.status_code == 200
    assert response.json() == {
        "image_base64": __import__("base64").b64encode(png_bytes).decode("ascii"),
        "image_media_type": "image/png",
    }


def test_official_image_accepts_base64_and_rejects_client_provider_fields(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["image"]["api_key"] = "server-image-secret"
    jpeg_bytes = b"\xff\xd8\xffminimal-image"

    def provider_response(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"data": [{"b64_json": __import__("base64").b64encode(jpeg_bytes).decode("ascii")}]},
        )

    headers = {"Authorization": "Bearer test-player-token"}
    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
        response = client.post("/v1/game/images/generations", headers=headers, json={"prompt": "generate portrait"})
        injected = client.post(
            "/v1/game/images/generations",
            headers=headers,
            json={"prompt": "generate portrait", "model": "attacker-model"},
        )

    assert response.status_code == 200
    assert response.json()["image_media_type"] == "image/jpeg"
    assert injected.status_code == 422


def test_official_image_failure_releases_quota(tmp_path):
    module = load_app(tmp_path)
    module.settings.capability_providers["image"]["api_key"] = "server-image-secret"
    module.storage.save_email_code("image@example.com", "123456", 10, 0)
    user_id = module.storage.register_email_user("image_player", "image@example.com", "secure-password", "123456")
    session_id, _refresh = module.storage.create_session(user_id)
    access_token, _expires_in = module.token_service.issue_access_token(user_id, session_id)

    def invalid_provider_response(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"data": [{"url": "http://127.0.0.1/private.png"}]})

    headers = {"Authorization": f"Bearer {access_token}"}
    with TestClient(module.app) as client:
        module.app.state.http = httpx.AsyncClient(transport=httpx.MockTransport(invalid_provider_response))
        response = client.post("/v1/game/images/generations", headers=headers, json={"prompt": "generate portrait"})
        quota = client.get("/v1/account/quota", headers=headers)

    assert response.status_code == 502
    assert quota.json()["used"] == 0


def test_email_code_registration_and_password_login(tmp_path):
    module = load_app(tmp_path)

    class CapturingEmailService:
        code: str = ""

        def send_verification_code(self, _email: str, code: str) -> None:
            self.code = code

    capture = CapturingEmailService()
    module.email_service = capture
    with TestClient(module.app) as client:
        assert client.post("/v1/auth/email/code", json={"email": "Player@Example.com"}).status_code == 204
        registered = client.post(
            "/v1/auth/email/register",
            json={"username": "player_one", "email": "player@example.com", "password": "secure-password", "verification_code": capture.code},
        )
        assert registered.status_code == 201
        assert "access_token" in registered.json()
        assert registered.json()["user_id"].startswith("usr_")

        replay = client.post(
            "/v1/auth/email/register",
            json={"username": "player_two", "email": "player@example.com", "password": "secure-password", "verification_code": capture.code},
        )
        assert replay.status_code in (400, 409)

        login = client.post(
            "/v1/auth/email/login",
            json={"identity": "player_one", "password": "secure-password"},
        )
        assert login.status_code == 200
        wrong_password = client.post(
            "/v1/auth/email/login",
            json={"identity": "player@example.com", "password": "wrong-password"},
        )
        assert wrong_password.status_code == 401


def test_email_code_has_cooldown(tmp_path):
    module = load_app(tmp_path)
    with TestClient(module.app) as client:
        payload = {"email": "player@example.com"}
        assert client.post("/v1/auth/email/code", json=payload).status_code == 204
        assert client.post("/v1/auth/email/code", json=payload).status_code == 429


def test_email_code_can_retry_after_delivery_failure(tmp_path):
    module = load_app(tmp_path)

    class FailingEmailService:
        def send_verification_code(self, _email: str, _code: str) -> None:
            raise RuntimeError("delivery failed")

    module.email_service = FailingEmailService()
    with TestClient(module.app) as client:
        payload = {"email": "player@example.com"}
        assert client.post("/v1/auth/email/code", json=payload).status_code == 503
        assert client.post("/v1/auth/email/code", json=payload).status_code == 503


def test_email_code_is_blocked_after_five_failures(tmp_path):
    module = load_app(tmp_path)
    module.storage.save_email_code("player@example.com", "123456", 10, 0)
    for _attempt in range(5):
        assert module.storage.register_email_user(
            "player_one", "player@example.com", "secure-password", "000000"
        ) is None
    assert module.storage.register_email_user(
        "player_one", "player@example.com", "secure-password", "123456"
    ) is None


def test_password_login_locks_after_five_failures(tmp_path):
    module = load_app(tmp_path)
    module.storage.save_email_code("player@example.com", "123456", 10, 0)
    module.storage.register_email_user("player_one", "player@example.com", "secure-password", "123456")
    with TestClient(module.app) as client:
        for _attempt in range(4):
            response = client.post(
                "/v1/auth/email/login",
                json={"identity": "player_one", "password": "wrong-password"},
            )
            assert response.status_code == 401
        locked = client.post(
            "/v1/auth/email/login",
            json={"identity": "player_one", "password": "wrong-password"},
        )
        assert locked.status_code == 429
        correct_password = client.post(
            "/v1/auth/email/login",
            json={"identity": "player_one", "password": "secure-password"},
        )
        assert correct_password.status_code == 429


def test_password_reset_revokes_sessions_and_changes_password(tmp_path):
    module = load_app(tmp_path)

    class CapturingEmailService:
        reset_code: str = ""

        def send_password_reset_code(self, _email: str, code: str) -> None:
            self.reset_code = code

    capture = CapturingEmailService()
    module.email_service = capture
    module.storage.save_email_code("player@example.com", "123456", 10, 0)
    user_id = module.storage.register_email_user(
        "player_one", "player@example.com", "old-password", "123456"
    )
    first_session_id, first_refresh = module.storage.create_session(user_id)
    second_session_id, _second_refresh = module.storage.create_session(user_id)
    first_access, _expires_in = module.token_service.issue_access_token(user_id, first_session_id)
    second_access, _expires_in = module.token_service.issue_access_token(user_id, second_session_id)

    with TestClient(module.app) as client:
        assert client.post(
            "/v1/auth/password/reset/code", json={"email": "player@example.com"}
        ).status_code == 204
        assert client.post(
            "/v1/auth/password/reset",
            json={
                "email": "player@example.com",
                "new_password": "new-password",
                "verification_code": capture.reset_code,
            },
        ).status_code == 204
        assert client.get(
            "/v1/account/quota", headers={"Authorization": f"Bearer {first_access}"}
        ).status_code == 401
        assert client.get(
            "/v1/account/quota", headers={"Authorization": f"Bearer {second_access}"}
        ).status_code == 401
        assert client.post("/v1/auth/refresh", json={"refresh_token": first_refresh}).status_code == 401
        assert client.post(
            "/v1/auth/email/login", json={"identity": "player_one", "password": "old-password"}
        ).status_code == 401
        assert client.post(
            "/v1/auth/email/login", json={"identity": "player_one", "password": "new-password"}
        ).status_code == 200


def test_logout_all_revokes_every_session(tmp_path):
    module = load_app(tmp_path)
    module.storage.save_email_code("player@example.com", "123456", 10, 0)
    user_id = module.storage.register_email_user(
        "player_one", "player@example.com", "secure-password", "123456"
    )
    first_session_id, _refresh = module.storage.create_session(user_id)
    second_session_id, _refresh = module.storage.create_session(user_id)
    first_access, _expires_in = module.token_service.issue_access_token(user_id, first_session_id)
    second_access, _expires_in = module.token_service.issue_access_token(user_id, second_session_id)

    with TestClient(module.app) as client:
        assert client.post(
            "/v1/auth/logout-all", headers={"Authorization": f"Bearer {first_access}"}
        ).status_code == 204
        assert client.get(
            "/v1/account/quota", headers={"Authorization": f"Bearer {first_access}"}
        ).status_code == 401
        assert client.get(
            "/v1/account/quota", headers={"Authorization": f"Bearer {second_access}"}
        ).status_code == 401


def test_account_profile_returns_identity_and_quota(tmp_path):
    module = load_app(tmp_path)
    module.storage.save_email_code("player@example.com", "123456", 10, 0)
    user_id = module.storage.register_email_user(
        "player_one", "player@example.com", "secure-password", "123456"
    )
    session_id, _refresh = module.storage.create_session(user_id)
    access_token, _expires_in = module.token_service.issue_access_token(user_id, session_id)

    with TestClient(module.app) as client:
        response = client.get(
            "/v1/account/profile", headers={"Authorization": f"Bearer {access_token}"}
        )
    assert response.status_code == 200
    assert response.json()["username"] == "player_one"
    assert response.json()["masked_email"] == "pl***@example.com"
    assert response.json()["quota"]["remaining"] == module.settings.daily_request_limit
