from __future__ import annotations

import argparse
import json
import sqlite3
from contextlib import closing
from pathlib import Path
from typing import Any


class SqliteCheckpointError(RuntimeError):
    pass


def checkpoint_database(database: Path) -> dict[str, Any]:
    resolved = database.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Banco SQLite nao encontrado: {resolved}")
    if resolved.stat().st_size == 0:
        raise SqliteCheckpointError("Banco SQLite vazio.")

    with closing(sqlite3.connect(str(resolved), timeout=300)) as connection, closing(
        connection.cursor()
    ) as cursor:
        cursor.execute("PRAGMA busy_timeout = 300000")
        checkpoint = cursor.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
        if checkpoint is None or int(checkpoint[0]) != 0:
            raise SqliteCheckpointError(f"Checkpoint WAL nao concluido: {checkpoint}")
        quick_rows = [str(row[0]) for row in cursor.execute("PRAGMA quick_check")]
        if quick_rows != ["ok"]:
            raise SqliteCheckpointError(f"PRAGMA quick_check falhou: {quick_rows[:20]}")

    wal_path = Path(str(resolved) + "-wal")
    wal_bytes = wal_path.stat().st_size if wal_path.exists() else 0
    if wal_bytes != 0:
        raise SqliteCheckpointError(f"WAL permaneceu com {wal_bytes} bytes.")
    return {
        "database": str(resolved),
        "database_bytes": resolved.stat().st_size,
        "checkpoint": [int(value) for value in checkpoint],
        "quick_check": "ok",
        "wal_bytes": wal_bytes,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Consolida WAL e executa quick_check em banco SQLite KRISTAL."
    )
    parser.add_argument("--database", required=True, type=Path)
    arguments = parser.parse_args()
    result = checkpoint_database(arguments.database)
    print(json.dumps(result, ensure_ascii=False, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
