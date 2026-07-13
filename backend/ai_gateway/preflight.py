from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.request
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from storage import GatewayStorage


def request_json(url: str, admin_token: str = "") -> tuple[int, dict[str, Any]]:
    headers = {"Accept": "application/json", "X-Request-ID": "deployment-preflight"}
    if admin_token:
        headers["Authorization"] = f"Bearer {admin_token}"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8")
        return error.code, json.loads(body) if body else {}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run non-billable GalChat production preflight checks")
    parser.add_argument("--base-url", default="http://127.0.0.1:8787")
    parser.add_argument("--database", default=os.getenv("GALCHAT_DATABASE_PATH", "/data/ai_gateway.db"))
    parser.add_argument("--backup-output")
    parser.add_argument("--skip-backup", action="store_true")
    args = parser.parse_args()

    admin_token = os.getenv("GALCHAT_ADMIN_TOKEN", "").strip()
    require(len(admin_token) >= 32, "GALCHAT_ADMIN_TOKEN must contain at least 32 characters")
    base_url = args.base_url.rstrip("/")

    health_status, health = request_json(f"{base_url}/health")
    require(health_status == 200 and health.get("status") == "ok", "/health check failed")

    ready_status, ready = request_json(f"{base_url}/ready")
    require(ready_status == 200 and ready.get("status") == "ready", "/ready check failed")
    require(ready.get("email_configured") is True, "SMTP configuration is not ready")
    require(isinstance(ready.get("schema_version"), int), "/ready did not return a schema version")

    unauthorized_status, _ = request_json(f"{base_url}/admin/api/overview")
    require(unauthorized_status in {401, 403}, "admin API accepted a request without credentials")
    authorized_status, _ = request_json(f"{base_url}/admin/api/overview", admin_token)
    require(authorized_status == 200, "admin API rejected GALCHAT_ADMIN_TOKEN")

    result: dict[str, Any] = {
        "status": "passed",
        "health": health,
        "readiness": ready,
        "admin_authentication": "passed",
    }
    if not args.skip_backup:
        database = Path(args.database).resolve()
        timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
        backup_output = args.backup_output or str(database.parent / "backups" / f"preflight-{timestamp}.db")
        storage = GatewayStorage(str(database), refresh_days=30)
        backup_path = storage.create_backup(backup_output)
        result["backup"] = {"path": backup_path, **GatewayStorage.inspect_database(backup_path)}

    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "failed", "error": str(error)}, ensure_ascii=True))
        raise SystemExit(1) from error