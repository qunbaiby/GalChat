from __future__ import annotations

import argparse
import json
import os
from datetime import UTC, datetime
from pathlib import Path

from storage import GatewayStorage


def main() -> int:
    parser = argparse.ArgumentParser(description="GalChat AI Gateway database maintenance")
    subparsers = parser.add_subparsers(dest="command", required=True)

    backup_parser = subparsers.add_parser("backup", help="Create an online SQLite backup")
    backup_parser.add_argument("--database", default=os.getenv("GALCHAT_DATABASE_PATH", "data/ai_gateway.db"))
    backup_parser.add_argument("--output")

    inspect_parser = subparsers.add_parser("inspect", help="Validate a SQLite database or backup")
    inspect_parser.add_argument("path")

    restore_parser = subparsers.add_parser("restore", help="Restore a validated backup while the Gateway is stopped")
    restore_parser.add_argument("backup")
    restore_parser.add_argument("--database", default=os.getenv("GALCHAT_DATABASE_PATH", "data/ai_gateway.db"))
    restore_parser.add_argument("--confirm", action="store_true")

    args = parser.parse_args()
    if args.command == "backup":
        database = Path(args.database).resolve()
        timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
        output = args.output or str(database.parent / "backups" / f"ai_gateway-{timestamp}.db")
        storage = GatewayStorage(str(database), refresh_days=30)
        result = {"backup_path": storage.create_backup(output), **GatewayStorage.inspect_database(output)}
    elif args.command == "inspect":
        result = GatewayStorage.inspect_database(args.path)
    else:
        if not args.confirm:
            parser.error("restore requires --confirm and the Gateway process must be stopped")
        result = GatewayStorage.restore_backup(args.backup, args.database)
    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())