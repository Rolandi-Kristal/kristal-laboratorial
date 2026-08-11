from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import sqlite3
import sys
from contextlib import closing
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
PORTAL_ROOT = PROJECT_ROOT / "portal_web"
if str(PORTAL_ROOT) not in sys.path:
    sys.path.insert(0, str(PORTAL_ROOT))

from app.corporate_sync import ALLOWED_SYNC_ENTITIES


REQUIRED_TABLES = frozenset(
    {
        "corporate_sync_sequence",
        "corporate_sync_records",
        "corporate_sync_history",
        "corporate_sync_operations",
        "corporate_sync_clients",
    }
)
REQUIRED_INDEXES = frozenset(
    {
        "idx_corporate_sync_version",
        "idx_corporate_sync_entity_version",
        "idx_corporate_history_entity_record",
    }
)
REQUIRED_TRIGGERS = frozenset(
    {
        "trg_corporate_history_no_update",
        "trg_corporate_history_no_delete",
    }
)


class CorporateDatabaseValidationError(RuntimeError):
    pass


@dataclass(frozen=True)
class CorporateValidationResult:
    database: str
    database_bytes: int
    validated_at: str
    quick_check: str
    integrity_check: str
    current_records: int
    history_records: int
    operations: int
    clients: int
    next_version: int
    current_version: int
    payload_hashes_validated: int
    entities: dict[str, int]
    required_tables: list[str]
    required_indexes: list[str]
    required_triggers: list[str]


def _single_pragma_result(cursor: sqlite3.Cursor, pragma: str) -> str:
    rows = [str(row[0]) for row in cursor.execute(f"PRAGMA {pragma}").fetchall()]
    if rows != ["ok"]:
        raise CorporateDatabaseValidationError(
            f"PRAGMA {pragma} falhou: {rows[:20]}"
        )
    return rows[0]


def _schema_names(cursor: sqlite3.Cursor, object_type: str) -> set[str]:
    return {
        str(row[0])
        for row in cursor.execute(
            "SELECT name FROM sqlite_master WHERE type = ?", (object_type,)
        ).fetchall()
    }


def _assert_required(
    cursor: sqlite3.Cursor,
    *,
    object_type: str,
    required: frozenset[str],
) -> None:
    missing = sorted(required - _schema_names(cursor, object_type))
    if missing:
        raise CorporateDatabaseValidationError(
            f"{object_type} obrigatorios ausentes: " + ", ".join(missing)
        )


def _validate_payload_hashes(cursor: sqlite3.Cursor, table: str) -> int:
    cursor.execute(
        f'SELECT entity, record_id, payload_json, deleted, sha256 FROM "{table}" '
        "ORDER BY version"
    )
    checked = 0
    while True:
        rows = cursor.fetchmany(500)
        if not rows:
            break
        for entity_value, record_id_value, payload_json_value, deleted_value, hash_value in rows:
            entity = str(entity_value)
            record_id = str(record_id_value)
            payload_json = str(payload_json_value)
            deleted = int(deleted_value)
            if deleted not in (0, 1):
                raise CorporateDatabaseValidationError(
                    f"Flag deleted invalida em {table}: {entity}/{record_id}."
                )
            try:
                payload = json.loads(payload_json)
            except json.JSONDecodeError as exc:
                raise CorporateDatabaseValidationError(
                    f"JSON invalido em {table}: {entity}/{record_id}."
                ) from exc
            if not isinstance(payload, dict):
                raise CorporateDatabaseValidationError(
                    f"Payload nao e objeto em {table}: {entity}/{record_id}."
                )
            if str(payload.get("id", "")) != record_id:
                raise CorporateDatabaseValidationError(
                    f"ID divergente no payload em {table}: {entity}/{record_id}."
                )
            canonical = json.dumps(
                payload,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            if canonical != payload_json:
                raise CorporateDatabaseValidationError(
                    f"JSON nao canonico em {table}: {entity}/{record_id}."
                )
            expected_hash = hashlib.sha256(
                (
                    entity
                    + "\n"
                    + record_id
                    + "\n"
                    + str(deleted)
                    + "\n"
                    + canonical
                ).encode("utf-8")
            ).hexdigest()
            if not hmac.compare_digest(expected_hash, str(hash_value)):
                raise CorporateDatabaseValidationError(
                    f"SHA-256 divergente em {table}: {entity}/{record_id}."
                )
            checked += 1
        if checked % 100_000 == 0:
            print(f"{table}: {checked} hashes validados", flush=True)
    return checked


def validate_corporate_database(database: Path) -> CorporateValidationResult:
    resolved = database.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Banco corporativo nao encontrado: {resolved}")
    if resolved.stat().st_size == 0:
        raise CorporateDatabaseValidationError("Banco corporativo vazio.")

    with closing(sqlite3.connect(str(resolved), timeout=300)) as connection, closing(
        connection.cursor()
    ) as cursor:
        cursor.execute("PRAGMA busy_timeout = 300000")
        checkpoint = cursor.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
        if checkpoint is None or int(checkpoint[0]) != 0:
            raise CorporateDatabaseValidationError(
                f"Checkpoint WAL nao concluido: {checkpoint}"
            )

        _assert_required(cursor, object_type="table", required=REQUIRED_TABLES)
        _assert_required(cursor, object_type="index", required=REQUIRED_INDEXES)
        _assert_required(cursor, object_type="trigger", required=REQUIRED_TRIGGERS)

        sequence_rows = cursor.execute(
            "SELECT id, next_version FROM corporate_sync_sequence ORDER BY id"
        ).fetchall()
        if len(sequence_rows) != 1 or int(sequence_rows[0][0]) != 1:
            raise CorporateDatabaseValidationError(
                f"Sequencia corporativa invalida: {sequence_rows}"
            )
        next_version = int(sequence_rows[0][1])
        if next_version < 1:
            raise CorporateDatabaseValidationError(
                f"next_version invalido: {next_version}"
            )
        current_version = next_version - 1

        counts = {
            "current_records": int(
                cursor.execute("SELECT COUNT(*) FROM corporate_sync_records").fetchone()[0]
            ),
            "history_records": int(
                cursor.execute("SELECT COUNT(*) FROM corporate_sync_history").fetchone()[0]
            ),
            "operations": int(
                cursor.execute("SELECT COUNT(*) FROM corporate_sync_operations").fetchone()[0]
            ),
            "clients": int(
                cursor.execute("SELECT COUNT(*) FROM corporate_sync_clients").fetchone()[0]
            ),
        }
        history_max = int(
            cursor.execute(
                "SELECT COALESCE(MAX(version), 0) FROM corporate_sync_history"
            ).fetchone()[0]
        )
        if history_max != current_version:
            raise CorporateDatabaseValidationError(
                f"Continuidade de versoes invalida: max={history_max}, atual={current_version}."
            )

        for table, expected_count in (
            ("corporate_sync_records", counts["current_records"]),
            ("corporate_sync_history", counts["history_records"]),
        ):
            distinct_versions = int(
                cursor.execute(
                    f'SELECT COUNT(DISTINCT version) FROM "{table}"'
                ).fetchone()[0]
            )
            if distinct_versions != expected_count:
                raise CorporateDatabaseValidationError(
                    f"Versoes duplicadas em {table}: {distinct_versions}/{expected_count}."
                )

        missing_history = int(
            cursor.execute(
                """
                SELECT COUNT(*)
                FROM corporate_sync_records current
                LEFT JOIN corporate_sync_history history
                  ON history.entity = current.entity
                 AND history.record_id = current.record_id
                 AND history.version = current.version
                 AND history.sha256 = current.sha256
                 AND history.deleted = current.deleted
                 AND history.payload_json = current.payload_json
                WHERE history.history_id IS NULL
                """
            ).fetchone()[0]
        )
        if missing_history:
            raise CorporateDatabaseValidationError(
                f"Registros atuais sem historico correspondente: {missing_history}."
            )

        operations_without_history = int(
            cursor.execute(
                """
                SELECT COUNT(*)
                FROM corporate_sync_operations operation
                LEFT JOIN corporate_sync_history history
                  ON history.version = operation.applied_version
                WHERE history.history_id IS NULL
                """
            ).fetchone()[0]
        )
        if operations_without_history:
            raise CorporateDatabaseValidationError(
                "Operacoes sem versao historica correspondente: "
                f"{operations_without_history}."
            )

        entities = {
            str(row[0]): int(row[1])
            for row in cursor.execute(
                "SELECT entity, COUNT(*) FROM corporate_sync_records "
                "GROUP BY entity ORDER BY entity"
            ).fetchall()
        }
        unknown_entities = sorted(set(entities) - ALLOWED_SYNC_ENTITIES)
        if unknown_entities:
            raise CorporateDatabaseValidationError(
                "Entidades corporativas nao autorizadas: " + ", ".join(unknown_entities)
            )

        current_hashes = _validate_payload_hashes(cursor, "corporate_sync_records")
        history_hashes = _validate_payload_hashes(cursor, "corporate_sync_history")
        quick_check = _single_pragma_result(cursor, "quick_check")
        integrity_check = _single_pragma_result(cursor, "integrity_check")

    return CorporateValidationResult(
        database=str(resolved),
        database_bytes=resolved.stat().st_size,
        validated_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        quick_check=quick_check,
        integrity_check=integrity_check,
        current_records=counts["current_records"],
        history_records=counts["history_records"],
        operations=counts["operations"],
        clients=counts["clients"],
        next_version=next_version,
        current_version=current_version,
        payload_hashes_validated=current_hashes + history_hashes,
        entities=entities,
        required_tables=sorted(REQUIRED_TABLES),
        required_indexes=sorted(REQUIRED_INDEXES),
        required_triggers=sorted(REQUIRED_TRIGGERS),
    )


def write_manifest(result: CorporateValidationResult, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.write_text(
        json.dumps(asdict(result), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(destination)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Valida integralmente o banco corporativo KRISTAL."
    )
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    arguments = parser.parse_args()
    result = validate_corporate_database(arguments.database)
    write_manifest(result, arguments.manifest)
    print(json.dumps(asdict(result), ensure_ascii=False, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
