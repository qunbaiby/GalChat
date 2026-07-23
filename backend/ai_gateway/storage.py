from __future__ import annotations

# pyright: reportAny=false, reportExplicitAny=false, reportImplicitRelativeImport=false, reportImplicitStringConcatenation=false, reportMissingParameterType=false, reportUnannotatedClassAttribute=false, reportUnknownArgumentType=false, reportUnknownMemberType=false, reportUnknownParameterType=false, reportUnknownVariableType=false, reportUnusedCallResult=false

import secrets
import shutil
import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path
from contextlib import closing
from types import TracebackType
from typing import Literal, override

from auth import generate_refresh_token, hash_secret, verify_secret
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError


class ClosingConnection(sqlite3.Connection):
    @override
    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> Literal[False]:
        try:
            return super().__exit__(exc_type, exc_value, traceback)
        finally:
            self.close()


class GatewayStorage:
    SCHEMA_VERSION = 4

    def __init__(self, database_path: str, refresh_days: int) -> None:
        self.database_path = database_path
        self.refresh_days = refresh_days
        self.password_hasher = PasswordHasher()
        Path(database_path).parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(
            self.database_path,
            timeout=10,
            isolation_level=None,
            factory=ClosingConnection,
        )
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = WAL")
        return connection

    def _initialize(self) -> None:
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS devices (
                    installation_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL UNIQUE,
                    secret_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS sessions (
                    session_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    refresh_hash TEXT NOT NULL UNIQUE,
                    expires_at TEXT NOT NULL,
                    revoked_at TEXT,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS daily_usage (
                    user_id TEXT NOT NULL,
                    usage_date TEXT NOT NULL,
                    used INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (user_id, usage_date)
                );
                CREATE TABLE IF NOT EXISTS capability_daily_usage (
                    user_id TEXT NOT NULL,
                    usage_date TEXT NOT NULL,
                    capability TEXT NOT NULL,
                    used INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (user_id, usage_date, capability)
                );
                CREATE TABLE IF NOT EXISTS usage_events (
                    event_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    capability TEXT NOT NULL,
                    status TEXT NOT NULL,
                    units INTEGER NOT NULL DEFAULT 1,
                    input_tokens INTEGER,
                    output_tokens INTEGER,
                    total_tokens INTEGER,
                    latency_ms INTEGER NOT NULL DEFAULT 0,
                    error_code TEXT,
                    created_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_usage_events_date_capability
                    ON usage_events(created_at, capability);
                CREATE INDEX IF NOT EXISTS idx_usage_events_user_date
                    ON usage_events(user_id, created_at);
                CREATE INDEX IF NOT EXISTS idx_usage_events_created_at
                    ON usage_events(created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_usage_events_capability_status_date
                    ON usage_events(capability, status, created_at DESC);
                CREATE TABLE IF NOT EXISTS users (
                    user_id TEXT PRIMARY KEY,
                    username TEXT NOT NULL UNIQUE,
                    email TEXT NOT NULL UNIQUE,
                    password_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS email_codes (
                    email TEXT PRIMARY KEY,
                    code_hash TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    consumed_at TEXT,
                    failed_attempts INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS login_attempts (
                    identity TEXT PRIMARY KEY,
                    failed_attempts INTEGER NOT NULL DEFAULT 0,
                    locked_until TEXT,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS password_reset_codes (
                    email TEXT PRIMARY KEY,
                    code_hash TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    failed_attempts INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS provider_config (
                    config_id INTEGER PRIMARY KEY CHECK (config_id = 1),
                    encrypted_api_key TEXT NOT NULL,
                    base_url TEXT NOT NULL,
                    allowed_models TEXT NOT NULL,
                    default_model TEXT NOT NULL DEFAULT 'deepseek-chat',
                    enabled INTEGER NOT NULL DEFAULT 1,
                    temperature REAL NOT NULL DEFAULT 0.7,
                    max_tokens INTEGER NOT NULL DEFAULT 2048,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS admin_audit_logs (
                    audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    action TEXT NOT NULL,
                    source_ip TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS capability_provider_config (
                    capability TEXT PRIMARY KEY,
                    encrypted_api_key TEXT NOT NULL,
                    base_url TEXT NOT NULL,
                    model TEXT NOT NULL,
                    resource_id TEXT NOT NULL DEFAULT '',
                    enabled INTEGER NOT NULL DEFAULT 1,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS capability_quota_limits (
                    capability TEXT PRIMARY KEY,
                    daily_limit INTEGER NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS ark_provider_config (
                    config_id INTEGER PRIMARY KEY CHECK (config_id = 1),
                    encrypted_api_key TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS schema_metadata (
                    metadata_key TEXT PRIMARY KEY,
                    metadata_value TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """
            )
            user_columns = {row["name"] for row in connection.execute("PRAGMA table_info(users)").fetchall()}
            if "username" not in user_columns:
                connection.execute("ALTER TABLE users ADD COLUMN username TEXT")
                connection.execute("UPDATE users SET username = 'legacy_' || substr(user_id, 1, 16) WHERE username IS NULL")
            connection.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username)")
            email_code_columns = {row["name"] for row in connection.execute("PRAGMA table_info(email_codes)").fetchall()}
            if "failed_attempts" not in email_code_columns:
                connection.execute("ALTER TABLE email_codes ADD COLUMN failed_attempts INTEGER NOT NULL DEFAULT 0")
            usage_event_columns = {
                row["name"] for row in connection.execute("PRAGMA table_info(usage_events)").fetchall()
            }
            for column_name in ("input_tokens", "output_tokens", "total_tokens"):
                if column_name not in usage_event_columns:
                    connection.execute(f"ALTER TABLE usage_events ADD COLUMN {column_name} INTEGER")
            usage_metadata_migrations = {
                "generated_images": "INTEGER",
                "audio_characters": "INTEGER",
                "provider_request_id": "TEXT",
            }
            for column_name, definition in usage_metadata_migrations.items():
                if column_name not in usage_event_columns:
                    connection.execute(f"ALTER TABLE usage_events ADD COLUMN {column_name} {definition}")
            provider_columns = {
                row["name"] for row in connection.execute("PRAGMA table_info(provider_config)").fetchall()
            }
            provider_migrations = {
                "default_model": "TEXT NOT NULL DEFAULT 'deepseek-chat'",
                "enabled": "INTEGER NOT NULL DEFAULT 1",
                "temperature": "REAL NOT NULL DEFAULT 0.7",
                "max_tokens": "INTEGER NOT NULL DEFAULT 2048",
            }
            for column_name, definition in provider_migrations.items():
                if column_name not in provider_columns:
                    connection.execute(f"ALTER TABLE provider_config ADD COLUMN {column_name} {definition}")
            capability_provider_columns = {
                row["name"] for row in connection.execute("PRAGMA table_info(capability_provider_config)").fetchall()
            }
            if "enabled" not in capability_provider_columns:
                connection.execute(
                    "ALTER TABLE capability_provider_config ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1"
                )
            schema_row = connection.execute(
                "SELECT metadata_value FROM schema_metadata WHERE metadata_key = 'schema_version'"
            ).fetchone()
            existing_version = int(schema_row["metadata_value"]) if schema_row else 0
            if existing_version > self.SCHEMA_VERSION:
                raise RuntimeError(
                    f"Database schema version {existing_version} is newer than supported version {self.SCHEMA_VERSION}."
                )
            connection.execute(
                "INSERT INTO schema_metadata (metadata_key, metadata_value, updated_at) VALUES ('schema_version', ?, ?) "
                "ON CONFLICT(metadata_key) DO UPDATE SET metadata_value = excluded.metadata_value, updated_at = excluded.updated_at",
                (str(self.SCHEMA_VERSION), datetime.now(UTC).isoformat()),
            )

    def get_schema_version(self) -> int:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT metadata_value FROM schema_metadata WHERE metadata_key = 'schema_version'"
            ).fetchone()
        return int(row["metadata_value"]) if row else 0

    def check_ready(self) -> bool:
        try:
            with self._connect() as connection:
                connection.execute("BEGIN IMMEDIATE")
                connection.execute("CREATE TEMP TABLE IF NOT EXISTS readiness_probe (value INTEGER)")
                connection.execute("DELETE FROM readiness_probe")
                connection.execute("INSERT INTO readiness_probe (value) VALUES (1)")
                connection.rollback()
            return True
        except sqlite3.Error:
            return False

    def cleanup_usage_events(self, retention_days: int) -> int:
        cutoff = datetime.now(UTC) - timedelta(days=max(1, retention_days))
        with self._connect() as connection:
            cursor = connection.execute(
                "DELETE FROM usage_events WHERE created_at < ?",
                (cutoff.isoformat(),),
            )
        return max(0, cursor.rowcount)

    def create_backup(self, backup_path: str) -> str:
        destination_path = Path(backup_path).resolve()
        destination_path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = destination_path.with_suffix(destination_path.suffix + ".tmp")
        temporary_path.unlink(missing_ok=True)
        try:
            with closing(self._connect()) as source, closing(sqlite3.connect(temporary_path)) as destination:
                source.backup(destination)
                integrity = destination.execute("PRAGMA integrity_check").fetchone()
                if integrity is None or str(integrity[0]).lower() != "ok":
                    raise RuntimeError("Backup integrity check failed.")
            temporary_path.replace(destination_path)
        finally:
            temporary_path.unlink(missing_ok=True)
        return str(destination_path)

    @classmethod
    def inspect_database(cls, database_path: str) -> dict[str, object]:
        path = Path(database_path).resolve()
        if not path.is_file():
            raise FileNotFoundError(f"Database does not exist: {path}")
        with closing(sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)) as connection:
            integrity = connection.execute("PRAGMA integrity_check").fetchone()
            if integrity is None or str(integrity[0]).lower() != "ok":
                raise RuntimeError("Database integrity check failed.")
            metadata_exists = connection.execute(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'schema_metadata'"
            ).fetchone()
            schema_version = 0
            if metadata_exists:
                row = connection.execute(
                    "SELECT metadata_value FROM schema_metadata WHERE metadata_key = 'schema_version'"
                ).fetchone()
                schema_version = int(row[0]) if row else 0
            if schema_version > cls.SCHEMA_VERSION:
                raise RuntimeError(
                    f"Database schema version {schema_version} is newer than supported version {cls.SCHEMA_VERSION}."
                )
            tables = int(
                connection.execute(
                    "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
                ).fetchone()[0]
            )
        return {"path": str(path), "schema_version": schema_version, "tables": tables, "integrity": "ok"}

    @classmethod
    def restore_backup(cls, backup_path: str, destination_path: str) -> dict[str, str]:
        cls.inspect_database(backup_path)
        source = Path(backup_path).resolve()
        destination = Path(destination_path).resolve()
        destination.parent.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
        previous_path = destination.with_name(f"{destination.name}.before-restore-{timestamp}")
        temporary_path = destination.with_suffix(destination.suffix + ".restore-tmp")
        temporary_path.unlink(missing_ok=True)
        shutil.copy2(source, temporary_path)
        cls.inspect_database(str(temporary_path))
        if destination.exists():
            destination.replace(previous_path)
        temporary_path.replace(destination)
        return {
            "database_path": str(destination),
            "previous_database_path": str(previous_path) if previous_path.exists() else "",
        }

    def save_email_code(self, email: str, code: str, expires_minutes: int, cooldown_seconds: int) -> bool:
        now = datetime.now(UTC)
        expires_at = now + timedelta(minutes=expires_minutes)
        with self._connect() as connection:
            row = connection.execute("SELECT created_at FROM email_codes WHERE email = ?", (email,)).fetchone()
            if row is not None and datetime.fromisoformat(row["created_at"]) + timedelta(seconds=cooldown_seconds) > now:
                return False
            connection.execute(
                "INSERT INTO email_codes (email, code_hash, expires_at, consumed_at, failed_attempts, created_at) VALUES (?, ?, ?, NULL, 0, ?) "
                "ON CONFLICT(email) DO UPDATE SET code_hash = excluded.code_hash, expires_at = excluded.expires_at, consumed_at = NULL, failed_attempts = 0, created_at = excluded.created_at",
                (email, hash_secret(code), expires_at.isoformat(), now.isoformat()),
            )
            return True

    def delete_email_code(self, email: str) -> None:
        with self._connect() as connection:
            connection.execute("DELETE FROM email_codes WHERE email = ?", (email,))

    def save_password_reset_code(self, email: str, code: str, expires_minutes: int, cooldown_seconds: int) -> bool:
        now = datetime.now(UTC)
        with self._connect() as connection:
            row = connection.execute(
                "SELECT created_at FROM password_reset_codes WHERE email = ?", (email,)
            ).fetchone()
            if row is not None and datetime.fromisoformat(row["created_at"]) + timedelta(seconds=cooldown_seconds) > now:
                return False
            connection.execute(
                "INSERT INTO password_reset_codes (email, code_hash, expires_at, failed_attempts, created_at) VALUES (?, ?, ?, 0, ?) "
                "ON CONFLICT(email) DO UPDATE SET code_hash = excluded.code_hash, expires_at = excluded.expires_at, failed_attempts = 0, created_at = excluded.created_at",
                (email, hash_secret(code), (now + timedelta(minutes=expires_minutes)).isoformat(), now.isoformat()),
            )
        return True

    def delete_password_reset_code(self, email: str) -> None:
        with self._connect() as connection:
            connection.execute("DELETE FROM password_reset_codes WHERE email = ?", (email,))

    def reset_password(self, email: str, password: str, code: str) -> bool:
        now = datetime.now(UTC)
        with self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            user = connection.execute("SELECT user_id, username FROM users WHERE email = ?", (email,)).fetchone()
            code_row = connection.execute(
                "SELECT code_hash, expires_at, failed_attempts FROM password_reset_codes WHERE email = ?", (email,)
            ).fetchone()
            if user is None or code_row is None or datetime.fromisoformat(code_row["expires_at"]) <= now or int(code_row["failed_attempts"]) >= 5:
                connection.rollback()
                return False
            if not verify_secret(code, code_row["code_hash"]):
                connection.execute(
                    "UPDATE password_reset_codes SET failed_attempts = failed_attempts + 1 WHERE email = ?", (email,)
                )
                connection.commit()
                return False
            connection.execute(
                "UPDATE users SET password_hash = ? WHERE user_id = ?",
                (self.password_hasher.hash(password), user["user_id"]),
            )
            connection.execute("DELETE FROM password_reset_codes WHERE email = ?", (email,))
            connection.execute("DELETE FROM login_attempts WHERE identity IN (?, ?)", (email, user["username"]))
            connection.execute(
                "UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL",
                (now.isoformat(), user["user_id"]),
            )
            connection.commit()
        return True

    def register_email_user(self, username: str, email: str, password: str, code: str) -> str | None:
        now = datetime.now(UTC)
        user_id = f"usr_{secrets.token_urlsafe(18)}"
        with self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            code_row = connection.execute(
                "SELECT code_hash, expires_at, consumed_at, failed_attempts FROM email_codes WHERE email = ?", (email,)
            ).fetchone()
            if code_row is None or code_row["consumed_at"] is not None or datetime.fromisoformat(code_row["expires_at"]) <= now or int(code_row["failed_attempts"]) >= 5:
                connection.rollback()
                return None
            if not verify_secret(code, code_row["code_hash"]):
                connection.execute("UPDATE email_codes SET failed_attempts = failed_attempts + 1 WHERE email = ?", (email,))
                connection.commit()
                return None
            connection.execute(
                "INSERT INTO users (user_id, username, email, password_hash, created_at) VALUES (?, ?, ?, ?, ?)",
                (user_id, username, email, self.password_hasher.hash(password), now.isoformat()),
            )
            connection.execute("UPDATE email_codes SET consumed_at = ? WHERE email = ?", (now.isoformat(), email))
            connection.commit()
        return user_id

    def ensure_development_user(self, username: str, email: str, password: str) -> str:
        now = datetime.now(UTC).isoformat()
        with self._connect() as connection:
            row = connection.execute(
                "SELECT user_id FROM users WHERE username = ? OR email = ?", (username, email)
            ).fetchone()
            if row is not None:
                return str(row["user_id"])
            user_id = f"usr_dev_{secrets.token_urlsafe(12)}"
            connection.execute(
                "INSERT INTO users (user_id, username, email, password_hash, created_at) VALUES (?, ?, ?, ?, ?)",
                (user_id, username, email, self.password_hasher.hash(password), now),
            )
        return user_id

    def authenticate_user(self, identity: str, password: str, max_attempts: int, lock_minutes: int) -> tuple[str | None, bool]:
        now = datetime.now(UTC)
        with self._connect() as connection:
            attempt = connection.execute(
                "SELECT failed_attempts, locked_until FROM login_attempts WHERE identity = ?", (identity,)
            ).fetchone()
            if attempt is not None and attempt["locked_until"] and datetime.fromisoformat(attempt["locked_until"]) > now:
                return None, True
            row = connection.execute(
                "SELECT user_id, password_hash FROM users WHERE email = ? OR username = ?", (identity, identity)
            ).fetchone()
        password_valid = False
        if row is not None:
            try:
                password_valid = self.password_hasher.verify(row["password_hash"], password)
            except VerifyMismatchError:
                pass
        if row is not None and password_valid:
            with self._connect() as connection:
                connection.execute("DELETE FROM login_attempts WHERE identity = ?", (identity,))
            return str(row["user_id"]), False
        failed_attempts = (int(attempt["failed_attempts"]) if attempt else 0) + 1
        locked_until = now + timedelta(minutes=lock_minutes) if failed_attempts >= max_attempts else None
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO login_attempts (identity, failed_attempts, locked_until, updated_at) VALUES (?, ?, ?, ?) "
                "ON CONFLICT(identity) DO UPDATE SET failed_attempts = excluded.failed_attempts, locked_until = excluded.locked_until, updated_at = excluded.updated_at",
                (identity, failed_attempts, locked_until.isoformat() if locked_until else None, now.isoformat()),
            )
        return None, locked_until is not None

    def get_user_profile(self, user_id: str) -> dict[str, str] | None:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT user_id, username, email, created_at FROM users WHERE user_id = ?", (user_id,)
            ).fetchone()
        if row is None:
            return None
        return {
            "user_id": str(row["user_id"]),
            "username": str(row["username"]),
            "email": str(row["email"]),
            "created_at": str(row["created_at"]),
        }

    def get_admin_overview(self, usage_date: str) -> dict[str, int]:
        with self._connect() as connection:
            users = int(connection.execute("SELECT COUNT(*) FROM users").fetchone()[0])
            active_sessions = int(
                connection.execute(
                    "SELECT COUNT(*) FROM sessions WHERE revoked_at IS NULL AND expires_at > ?",
                    (datetime.now(UTC).isoformat(),),
                ).fetchone()[0]
            )
            usage_row = connection.execute(
                "SELECT COUNT(*), COUNT(DISTINCT user_id) FROM usage_events WHERE substr(created_at, 1, 10) = ?",
                (usage_date,),
            ).fetchone()
        return {
            "users": users,
            "active_sessions": active_sessions,
            "requests_today": int(usage_row[0]),
            "active_users_today": int(usage_row[1]),
        }

    def list_admin_users(
        self,
        usage_date: str,
        limit: int,
        offset: int,
        query: str = "",
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> tuple[list[dict[str, object]], int]:
        sort_columns = {
            "username": "users.username",
            "created_at": "users.created_at",
            "used_today": "used_today",
            "active_sessions": "active_sessions",
        }
        order_column = sort_columns.get(sort_by, "users.created_at")
        order_direction = "ASC" if sort_order == "asc" else "DESC"
        normalized_query = query.strip()
        search_pattern = f"%{normalized_query}%"
        where_clause = "WHERE users.username LIKE ? OR users.email LIKE ? OR users.user_id LIKE ?" if normalized_query else ""
        search_parameters = (search_pattern, search_pattern, search_pattern) if normalized_query else ()
        with self._connect() as connection:
            total = int(
                connection.execute(
                    f"SELECT COUNT(*) FROM users {where_clause}",
                    search_parameters,
                ).fetchone()[0]
            )
            rows = connection.execute(
                f"""
                SELECT
                    users.user_id,
                    users.username,
                    users.email,
                    users.created_at,
                    COALESCE(daily_usage.used, 0) AS used_today,
                    COUNT(CASE WHEN sessions.revoked_at IS NULL AND sessions.expires_at > ? THEN 1 END) AS active_sessions
                FROM users
                LEFT JOIN daily_usage
                    ON daily_usage.user_id = users.user_id AND daily_usage.usage_date = ?
                LEFT JOIN sessions ON sessions.user_id = users.user_id
                {where_clause}
                GROUP BY users.user_id
                ORDER BY {order_column} {order_direction}, users.user_id ASC
                LIMIT ? OFFSET ?
                """,
                (datetime.now(UTC).isoformat(), usage_date, *search_parameters, limit, offset),
            ).fetchall()
        return (
            [
                {
                    "user_id": str(row["user_id"]),
                    "username": str(row["username"]),
                    "email": str(row["email"]),
                    "created_at": str(row["created_at"]),
                    "used_today": int(row["used_today"]),
                    "active_sessions": int(row["active_sessions"]),
                }
                for row in rows
            ],
            total,
        )

    def get_provider_config(self) -> dict[str, object] | None:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT encrypted_api_key, base_url, allowed_models, default_model, enabled, temperature, max_tokens, updated_at FROM provider_config WHERE config_id = 1"
            ).fetchone()
        if row is None:
            return None
        return {
            "encrypted_api_key": str(row["encrypted_api_key"]),
            "base_url": str(row["base_url"]),
            "allowed_models": str(row["allowed_models"]),
            "default_model": str(row["default_model"]),
            "enabled": bool(row["enabled"]),
            "temperature": float(row["temperature"]),
            "max_tokens": int(row["max_tokens"]),
            "updated_at": str(row["updated_at"]),
        }

    def save_provider_config(
        self,
        encrypted_api_key: str,
        base_url: str,
        allowed_models: str,
        default_model: str = "deepseek-chat",
        enabled: bool = True,
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> str:
        updated_at = datetime.now(UTC).isoformat()
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO provider_config (config_id, encrypted_api_key, base_url, allowed_models, default_model, enabled, temperature, max_tokens, updated_at) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?) "
                "ON CONFLICT(config_id) DO UPDATE SET encrypted_api_key = excluded.encrypted_api_key, base_url = excluded.base_url, allowed_models = excluded.allowed_models, default_model = excluded.default_model, enabled = excluded.enabled, temperature = excluded.temperature, max_tokens = excluded.max_tokens, updated_at = excluded.updated_at",
                (encrypted_api_key, base_url, allowed_models, default_model, int(enabled), temperature, max_tokens, updated_at),
            )
        return updated_at

    def delete_provider_config(self) -> None:
        with self._connect() as connection:
            connection.execute("DELETE FROM provider_config WHERE config_id = 1")

    def list_capability_provider_configs(self) -> dict[str, dict[str, str | bool]]:
        with self._connect() as connection:
            rows = connection.execute(
                "SELECT capability, encrypted_api_key, base_url, model, resource_id, enabled, updated_at FROM capability_provider_config"
            ).fetchall()
        return {
            str(row["capability"]): {
                "encrypted_api_key": str(row["encrypted_api_key"]),
                "base_url": str(row["base_url"]),
                "model": str(row["model"]),
                "resource_id": str(row["resource_id"]),
                "enabled": bool(row["enabled"]),
                "updated_at": str(row["updated_at"]),
            }
            for row in rows
        }

    def save_capability_provider_config(
        self,
        capability: str,
        encrypted_api_key: str,
        base_url: str,
        model: str,
        resource_id: str,
        enabled: bool = True,
    ) -> str:
        updated_at = datetime.now(UTC).isoformat()
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO capability_provider_config (capability, encrypted_api_key, base_url, model, resource_id, enabled, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?) "
                "ON CONFLICT(capability) DO UPDATE SET encrypted_api_key = excluded.encrypted_api_key, base_url = excluded.base_url, model = excluded.model, resource_id = excluded.resource_id, enabled = excluded.enabled, updated_at = excluded.updated_at",
                (capability, encrypted_api_key, base_url, model, resource_id, int(enabled), updated_at),
            )
        return updated_at

    def delete_capability_provider_config(self, capability: str) -> None:
        with self._connect() as connection:
            connection.execute("DELETE FROM capability_provider_config WHERE capability = ?", (capability,))

    def add_admin_audit_log(self, action: str, source_ip: str) -> None:
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO admin_audit_logs (action, source_ip, created_at) VALUES (?, ?, ?)",
                (action, source_ip, datetime.now(UTC).isoformat()),
            )

    def list_admin_audit_logs(self, limit: int = 50) -> list[dict[str, str]]:
        with self._connect() as connection:
            rows = connection.execute(
                "SELECT action, source_ip, created_at FROM admin_audit_logs ORDER BY audit_id DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return [
            {"action": str(row["action"]), "source_ip": str(row["source_ip"]), "created_at": str(row["created_at"])}
            for row in rows
        ]

    def register_device(self, installation_id: str, installation_secret: str) -> str:
        user_id = f"usr_{secrets.token_urlsafe(18)}"
        now = datetime.now(UTC).isoformat()
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO devices (installation_id, user_id, secret_hash, created_at) VALUES (?, ?, ?, ?)",
                (installation_id, user_id, hash_secret(installation_secret), now),
            )
        return user_id

    def authenticate_device(self, installation_id: str, installation_secret: str) -> str | None:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT user_id, secret_hash FROM devices WHERE installation_id = ?",
                (installation_id,),
            ).fetchone()
        if row is None or not verify_secret(installation_secret, row["secret_hash"]):
            return None
        return str(row["user_id"])

    def create_session(self, user_id: str) -> tuple[str, str]:
        session_id = f"ses_{secrets.token_urlsafe(18)}"
        refresh_token = generate_refresh_token()
        now = datetime.now(UTC)
        expires_at = now + timedelta(days=self.refresh_days)
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO sessions (session_id, user_id, refresh_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)",
                (session_id, user_id, hash_secret(refresh_token), expires_at.isoformat(), now.isoformat()),
            )
        return session_id, refresh_token

    def rotate_refresh_token(self, refresh_token: str) -> tuple[str, str, str] | None:
        refresh_hash = hash_secret(refresh_token)
        now = datetime.now(UTC)
        with self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT session_id, user_id, expires_at, revoked_at FROM sessions WHERE refresh_hash = ?",
                (refresh_hash,),
            ).fetchone()
            if row is None or row["revoked_at"] is not None or datetime.fromisoformat(row["expires_at"]) <= now:
                connection.rollback()
                return None
            new_refresh = generate_refresh_token()
            connection.execute(
                "UPDATE sessions SET refresh_hash = ? WHERE session_id = ?",
                (hash_secret(new_refresh), row["session_id"]),
            )
            connection.commit()
        return str(row["user_id"]), str(row["session_id"]), new_refresh

    def session_is_active(self, user_id: str, session_id: str) -> bool:
        now = datetime.now(UTC)
        with self._connect() as connection:
            row = connection.execute(
                "SELECT expires_at, revoked_at FROM sessions WHERE session_id = ? AND user_id = ?",
                (session_id, user_id),
            ).fetchone()
        return row is not None and row["revoked_at"] is None and datetime.fromisoformat(row["expires_at"]) > now

    def revoke_session(self, session_id: str, user_id: str) -> None:
        with self._connect() as connection:
            connection.execute(
                "UPDATE sessions SET revoked_at = ? WHERE session_id = ? AND user_id = ?",
                (datetime.now(UTC).isoformat(), session_id, user_id),
            )

    def revoke_all_sessions(self, user_id: str) -> None:
        with self._connect() as connection:
            connection.execute(
                "UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL",
                (datetime.now(UTC).isoformat(), user_id),
            )

    def consume_daily_quota(self, user_id: str, daily_limit: int) -> int | None:
        usage_date = datetime.now(UTC).date().isoformat()
        with self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT used FROM daily_usage WHERE user_id = ? AND usage_date = ?",
                (user_id, usage_date),
            ).fetchone()
            used = int(row["used"]) if row else 0
            if used >= daily_limit:
                connection.rollback()
                return None
            new_used = used + 1
            connection.execute(
                "INSERT INTO daily_usage (user_id, usage_date, used) VALUES (?, ?, ?) "
                "ON CONFLICT(user_id, usage_date) DO UPDATE SET used = excluded.used",
                (user_id, usage_date, new_used),
            )
            connection.commit()
        return daily_limit - new_used

    def get_daily_quota(self, user_id: str, daily_limit: int) -> tuple[int, int]:
        usage_date = datetime.now(UTC).date().isoformat()
        with self._connect() as connection:
            row = connection.execute(
                "SELECT used FROM daily_usage WHERE user_id = ? AND usage_date = ?",
                (user_id, usage_date),
            ).fetchone()
        used = int(row["used"]) if row else 0
        return used, max(0, daily_limit - used)

    def release_daily_quota(self, user_id: str) -> None:
        usage_date = datetime.now(UTC).date().isoformat()
        with self._connect() as connection:
            connection.execute(
                "UPDATE daily_usage SET used = MAX(0, used - 1) WHERE user_id = ? AND usage_date = ?",
                (user_id, usage_date),
            )

    def consume_capability_quota(self, user_id: str, capability: str, daily_limit: int) -> int | None:
        usage_date = datetime.now(UTC).date().isoformat()
        with self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT used FROM capability_daily_usage WHERE user_id = ? AND usage_date = ? AND capability = ?",
                (user_id, usage_date, capability),
            ).fetchone()
            used = int(row["used"]) if row else 0
            if used >= daily_limit:
                connection.rollback()
                return None
            new_used = used + 1
            connection.execute(
                "INSERT INTO capability_daily_usage (user_id, usage_date, capability, used) VALUES (?, ?, ?, ?) "
                "ON CONFLICT(user_id, usage_date, capability) DO UPDATE SET used = excluded.used",
                (user_id, usage_date, capability, new_used),
            )
            connection.execute(
                "INSERT INTO daily_usage (user_id, usage_date, used) VALUES (?, ?, 1) "
                "ON CONFLICT(user_id, usage_date) DO UPDATE SET used = used + 1",
                (user_id, usage_date),
            )
            connection.commit()
        return daily_limit - new_used

    def release_capability_quota(self, user_id: str, capability: str) -> None:
        usage_date = datetime.now(UTC).date().isoformat()
        with self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT used FROM capability_daily_usage WHERE user_id = ? AND usage_date = ? AND capability = ?",
                (user_id, usage_date, capability),
            ).fetchone()
            if row is not None and int(row["used"]) > 0:
                connection.execute(
                    "UPDATE capability_daily_usage SET used = used - 1 WHERE user_id = ? AND usage_date = ? AND capability = ?",
                    (user_id, usage_date, capability),
                )
                connection.execute(
                    "UPDATE daily_usage SET used = MAX(0, used - 1) WHERE user_id = ? AND usage_date = ?",
                    (user_id, usage_date),
                )
            connection.commit()

    def get_capability_quotas(self, user_id: str, limits: dict[str, int]) -> dict[str, dict[str, int]]:
        usage_date = datetime.now(UTC).date().isoformat()
        with self._connect() as connection:
            rows = connection.execute(
                "SELECT capability, used FROM capability_daily_usage WHERE user_id = ? AND usage_date = ?",
                (user_id, usage_date),
            ).fetchall()
        usage = {str(row["capability"]): int(row["used"]) for row in rows}
        return {
            capability: {
                "limit": limit,
                "used": usage.get(capability, 0),
                "remaining": max(0, limit - usage.get(capability, 0)),
            }
            for capability, limit in limits.items()
        }

    def record_usage_event(
        self,
        user_id: str,
        capability: str,
        event_status: str,
        latency_ms: int,
        error_code: str | None = None,
        units: int = 1,
        input_tokens: int | None = None,
        output_tokens: int | None = None,
        total_tokens: int | None = None,
    ) -> None:
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO usage_events (event_id, user_id, capability, status, units, input_tokens, output_tokens, total_tokens, latency_ms, error_code, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    f"evt_{secrets.token_hex(16)}",
                    user_id,
                    capability,
                    event_status,
                    max(0, units),
                    max(0, input_tokens) if input_tokens is not None else None,
                    max(0, output_tokens) if output_tokens is not None else None,
                    max(0, total_tokens) if total_tokens is not None else None,
                    max(0, latency_ms),
                    error_code[:100] if error_code else None,
                    datetime.now(UTC).isoformat(),
                ),
            )

    def get_capability_stats(self, usage_date: str) -> list[dict[str, object]]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT capability,
                       COUNT(*) AS requests,
                       SUM(CASE WHEN status = 'succeeded' THEN 1 ELSE 0 END) AS succeeded,
                       SUM(CASE WHEN status NOT IN ('succeeded', 'quota_rejected') THEN 1 ELSE 0 END) AS failed,
                       SUM(CASE WHEN status = 'quota_rejected' THEN 1 ELSE 0 END) AS quota_rejected,
                       COALESCE(SUM(units), 0) AS units,
                       SUM(input_tokens) AS input_tokens,
                       SUM(output_tokens) AS output_tokens,
                       SUM(total_tokens) AS total_tokens,
                       COALESCE(ROUND(AVG(latency_ms)), 0) AS average_latency_ms
                FROM usage_events
                WHERE substr(created_at, 1, 10) = ?
                GROUP BY capability
                ORDER BY capability
                """,
                (usage_date,),
            ).fetchall()
        return [dict(row) for row in rows]

    def list_capability_quota_limits(self) -> dict[str, dict[str, object]]:
        with self._connect() as connection:
            rows = connection.execute(
                "SELECT capability, daily_limit, updated_at FROM capability_quota_limits"
            ).fetchall()
        return {
            str(row["capability"]): {
                "daily_limit": int(row["daily_limit"]),
                "updated_at": str(row["updated_at"]),
            }
            for row in rows
        }

    def save_capability_quota_limit(self, capability: str, daily_limit: int) -> str:
        updated_at = datetime.now(UTC).isoformat()
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO capability_quota_limits (capability, daily_limit, updated_at) VALUES (?, ?, ?) "
                "ON CONFLICT(capability) DO UPDATE SET daily_limit = excluded.daily_limit, updated_at = excluded.updated_at",
                (capability, daily_limit, updated_at),
            )
        return updated_at

    def list_usage_events(self, limit: int) -> list[dict[str, object]]:
        items, _ = self.query_usage_events(limit=limit)
        return items

    def query_usage_events(
        self,
        limit: int,
        offset: int = 0,
        capability: str = "",
        event_status: str = "",
        user_query: str = "",
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> tuple[list[dict[str, object]], int]:
        sort_columns = {
            "created_at": "created_at",
            "capability": "capability",
            "status": "status",
            "units": "units",
            "latency_ms": "latency_ms",
            "error_code": "error_code",
            "user_id": "user_id",
        }
        order_column = sort_columns.get(sort_by, "created_at")
        order_direction = "ASC" if sort_order == "asc" else "DESC"
        conditions: list[str] = []
        parameters: list[object] = []
        if capability:
            conditions.append("capability = ?")
            parameters.append(capability)
        if event_status:
            conditions.append("status = ?")
            parameters.append(event_status)
        if user_query.strip():
            conditions.append("user_id LIKE ?")
            parameters.append(f"%{user_query.strip()}%")
        where_clause = f"WHERE {' AND '.join(conditions)}" if conditions else ""
        with self._connect() as connection:
            total = int(
                connection.execute(
                    f"SELECT COUNT(*) FROM usage_events {where_clause}",
                    parameters,
                ).fetchone()[0]
            )
            rows = connection.execute(
                f"""
                SELECT event_id, user_id, capability, status, units, input_tokens, output_tokens, total_tokens, latency_ms, error_code, created_at
                FROM usage_events
                {where_clause}
                ORDER BY {order_column} {order_direction}, event_id ASC
                LIMIT ? OFFSET ?
                """,
                (*parameters, limit, offset),
            ).fetchall()
        return [dict(row) for row in rows], total
