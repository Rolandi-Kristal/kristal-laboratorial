from __future__ import annotations

import hashlib
import json
import os
import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from typing import Any, Iterable, Mapping


ALLOWED_SYNC_ENTITIES: frozenset[str] = frozenset(
    {
        "pacientes",
        "exames",
        "pedidos",
        "amostras",
        "resultados",
        "laudos",
        "equipamentos",
        "usuarios",
        "auditoria",
        "materiais",
        "estoque",
        "calibracoes",
        "manutencoes",
        "controle_qualidade",
        "agendamentos",
        "cadebens_integracao",
        "atendimentos",
        "historico_exames_pacientes",
        "equipment_connections",
        "equipment_test_mappings",
        "equipment_messages",
    }
)


class CorporateSyncError(ValueError):
    pass


class CorporateSyncStore:
    def __init__(self, db_path: str) -> None:
        clean = db_path.strip()
        if not clean:
            raise CorporateSyncError("Caminho do banco corporativo ausente.")
        self.db_path = os.path.abspath(clean)

    @staticmethod
    def now() -> str:
        return datetime.now(timezone.utc).isoformat(timespec="milliseconds")

    def connect(self) -> sqlite3.Connection:
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        conn = sqlite3.connect(self.db_path, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = FULL")
        conn.execute("PRAGMA busy_timeout = 30000")
        return conn

    def initialize(self) -> None:
        with closing(self.connect()) as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS corporate_sync_sequence (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    next_version INTEGER NOT NULL
                );
                INSERT OR IGNORE INTO corporate_sync_sequence (id, next_version)
                VALUES (1, 1);

                CREATE TABLE IF NOT EXISTS corporate_sync_records (
                    entity TEXT NOT NULL,
                    record_id TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    deleted INTEGER NOT NULL DEFAULT 0,
                    version INTEGER NOT NULL UNIQUE,
                    source_client TEXT NOT NULL,
                    client_updated_at TEXT,
                    server_updated_at TEXT NOT NULL,
                    sha256 TEXT NOT NULL,
                    PRIMARY KEY (entity, record_id)
                );

                CREATE TABLE IF NOT EXISTS corporate_sync_history (
                    history_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    entity TEXT NOT NULL,
                    record_id TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    deleted INTEGER NOT NULL DEFAULT 0,
                    version INTEGER NOT NULL UNIQUE,
                    source_client TEXT NOT NULL,
                    client_updated_at TEXT,
                    server_updated_at TEXT NOT NULL,
                    sha256 TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS corporate_sync_operations (
                    operation_id TEXT PRIMARY KEY,
                    client_id TEXT NOT NULL,
                    applied_version INTEGER NOT NULL,
                    applied_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS corporate_sync_clients (
                    client_id TEXT PRIMARY KEY,
                    last_seen_at TEXT NOT NULL,
                    last_pull_version INTEGER NOT NULL DEFAULT 0
                );

                CREATE INDEX IF NOT EXISTS idx_corporate_sync_version
                ON corporate_sync_records(version);

                CREATE INDEX IF NOT EXISTS idx_corporate_sync_entity_version
                ON corporate_sync_records(entity, version);

                CREATE INDEX IF NOT EXISTS idx_corporate_history_entity_record
                ON corporate_sync_history(entity, record_id, version DESC);

                INSERT OR IGNORE INTO corporate_sync_history (
                    entity, record_id, payload_json, deleted, version,
                    source_client, client_updated_at, server_updated_at, sha256
                )
                SELECT entity, record_id, payload_json, deleted, version,
                       source_client, client_updated_at, server_updated_at, sha256
                FROM corporate_sync_records;

                CREATE TRIGGER IF NOT EXISTS trg_corporate_history_no_update
                BEFORE UPDATE ON corporate_sync_history
                BEGIN
                    SELECT RAISE(ABORT, 'corporate_sync_history is immutable');
                END;

                CREATE TRIGGER IF NOT EXISTS trg_corporate_history_no_delete
                BEFORE DELETE ON corporate_sync_history
                BEGIN
                    SELECT RAISE(ABORT, 'corporate_sync_history is immutable');
                END;
                """
            )
            conn.commit()

    def push(self, *, client_id: str, records: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
        clean_client = self._validate_identifier(client_id, field="client_id")
        normalized = [self._normalize_record(item) for item in records]
        if not normalized:
            return {"accepted": 0, "versions": [], "server_version": self.current_version()}
        if len(normalized) > 500:
            raise CorporateSyncError("Cada lote aceita no máximo 500 registros.")

        versions: list[dict[str, Any]] = []
        now = self.now()
        with closing(self.connect()) as conn:
            conn.execute("BEGIN IMMEDIATE")
            for item in normalized:
                previous_operation = conn.execute(
                    "SELECT applied_version FROM corporate_sync_operations WHERE operation_id = ?",
                    (item["operation_id"],),
                ).fetchone()
                if previous_operation is not None:
                    versions.append(
                        {
                            "operation_id": item["operation_id"],
                            "version": int(previous_operation["applied_version"]),
                        }
                    )
                    continue

                current = conn.execute(
                    """
                    SELECT version, sha256, deleted
                    FROM corporate_sync_records
                    WHERE entity = ? AND record_id = ?
                    """,
                    (item["entity"], item["record_id"]),
                ).fetchone()

                if (
                    current is not None
                    and current["sha256"] == item["sha256"]
                    and int(current["deleted"]) == item["deleted"]
                ):
                    version = int(current["version"])
                else:
                    version = self._next_version(conn)
                    history_values = (
                        item["entity"],
                        item["record_id"],
                        item["payload_json"],
                        item["deleted"],
                        version,
                        clean_client,
                        item["client_updated_at"],
                        now,
                        item["sha256"],
                    )
                    conn.execute(
                        """
                        INSERT INTO corporate_sync_history (
                            entity, record_id, payload_json, deleted, version,
                            source_client, client_updated_at, server_updated_at, sha256
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        history_values,
                    )
                    conn.execute(
                        """
                        INSERT INTO corporate_sync_records (
                            entity, record_id, payload_json, deleted, version,
                            source_client, client_updated_at, server_updated_at, sha256
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(entity, record_id) DO UPDATE SET
                            payload_json = excluded.payload_json,
                            deleted = excluded.deleted,
                            version = excluded.version,
                            source_client = excluded.source_client,
                            client_updated_at = excluded.client_updated_at,
                            server_updated_at = excluded.server_updated_at,
                            sha256 = excluded.sha256
                        """,
                        history_values,
                    )

                conn.execute(
                    """
                    INSERT INTO corporate_sync_operations (
                        operation_id, client_id, applied_version, applied_at
                    ) VALUES (?, ?, ?, ?)
                    """,
                    (item["operation_id"], clean_client, version, now),
                )
                versions.append({"operation_id": item["operation_id"], "version": version})

            conn.execute(
                """
                INSERT INTO corporate_sync_clients (client_id, last_seen_at, last_pull_version)
                VALUES (?, ?, 0)
                ON CONFLICT(client_id) DO UPDATE SET last_seen_at = excluded.last_seen_at
                """,
                (clean_client, now),
            )
            conn.commit()

        return {
            "accepted": len(versions),
            "versions": versions,
            "server_version": self.current_version(),
        }

    def pull(self, *, client_id: str, since_version: int, limit: int) -> dict[str, Any]:
        clean_client = self._validate_identifier(client_id, field="client_id")
        if since_version < 0:
            raise CorporateSyncError("since_version não pode ser negativo.")
        safe_limit = min(max(limit, 1), 1000)
        with closing(self.connect()) as conn:
            rows = conn.execute(
                """
                SELECT entity, record_id, payload_json, deleted, version,
                       source_client, client_updated_at, server_updated_at, sha256
                FROM corporate_sync_records
                WHERE version > ?
                ORDER BY version ASC
                LIMIT ?
                """,
                (since_version, safe_limit),
            ).fetchall()
            records = [
                {
                    "entity": row["entity"],
                    "record_id": row["record_id"],
                    "payload": json.loads(row["payload_json"]),
                    "deleted": bool(row["deleted"]),
                    "version": int(row["version"]),
                    "source_client": row["source_client"],
                    "client_updated_at": row["client_updated_at"],
                    "server_updated_at": row["server_updated_at"],
                    "sha256": row["sha256"],
                }
                for row in rows
            ]
            next_version = int(rows[-1]["version"]) if rows else since_version
            conn.execute(
                """
                INSERT INTO corporate_sync_clients (client_id, last_seen_at, last_pull_version)
                VALUES (?, ?, ?)
                ON CONFLICT(client_id) DO UPDATE SET
                    last_seen_at = excluded.last_seen_at,
                    last_pull_version = excluded.last_pull_version
                """,
                (clean_client, self.now(), next_version),
            )
            conn.commit()

        return {
            "records": records,
            "next_version": next_version,
            "has_more": len(records) == safe_limit,
            "server_version": self.current_version(),
        }

    def status(self) -> dict[str, Any]:
        with closing(self.connect()) as conn:
            record_count = int(conn.execute("SELECT COUNT(*) FROM corporate_sync_records").fetchone()[0])
            history_count = int(conn.execute("SELECT COUNT(*) FROM corporate_sync_history").fetchone()[0])
            client_count = int(conn.execute("SELECT COUNT(*) FROM corporate_sync_clients").fetchone()[0])
        return {
            "status": "ok",
            "records": record_count,
            "history_records": history_count,
            "clients": client_count,
            "server_version": self.current_version(),
            "database": self.db_path,
        }

    def history(
        self,
        *,
        entity: str | None = None,
        record_id: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> dict[str, Any]:
        if entity is not None and entity not in ALLOWED_SYNC_ENTITIES:
            raise CorporateSyncError("Entidade não autorizada para consulta.")
        clean_record_id = (
            self._validate_identifier(record_id, field="record_id")
            if record_id is not None
            else None
        )
        safe_limit = min(max(limit, 1), 1000)
        safe_offset = max(offset, 0)
        clauses: list[str] = []
        parameters: list[Any] = []
        if entity is not None:
            clauses.append("entity = ?")
            parameters.append(entity)
        if clean_record_id is not None:
            clauses.append("record_id = ?")
            parameters.append(clean_record_id)
        where = " WHERE " + " AND ".join(clauses) if clauses else ""
        with closing(self.connect()) as conn:
            total = int(
                conn.execute(
                    f"SELECT COUNT(*) FROM corporate_sync_history{where}",
                    parameters,
                ).fetchone()[0]
            )
            rows = conn.execute(
                f"""
                SELECT entity, record_id, payload_json, deleted, version,
                       source_client, client_updated_at, server_updated_at, sha256
                FROM corporate_sync_history{where}
                ORDER BY version DESC
                LIMIT ? OFFSET ?
                """,
                [*parameters, safe_limit, safe_offset],
            ).fetchall()
        return {
            "records": [
                {
                    "entity": row["entity"],
                    "record_id": row["record_id"],
                    "payload": json.loads(row["payload_json"]),
                    "deleted": bool(row["deleted"]),
                    "version": int(row["version"]),
                    "source_client": row["source_client"],
                    "client_updated_at": row["client_updated_at"],
                    "server_updated_at": row["server_updated_at"],
                    "sha256": row["sha256"],
                }
                for row in rows
            ],
            "total": total,
            "limit": safe_limit,
            "offset": safe_offset,
        }

    def current_version(self) -> int:
        with closing(self.connect()) as conn:
            row = conn.execute(
                "SELECT next_version - 1 AS version FROM corporate_sync_sequence WHERE id = 1"
            ).fetchone()
        return 0 if row is None else int(row["version"])

    @staticmethod
    def _next_version(conn: sqlite3.Connection) -> int:
        row = conn.execute(
            "SELECT next_version FROM corporate_sync_sequence WHERE id = 1"
        ).fetchone()
        if row is None:
            raise CorporateSyncError("Sequência corporativa não inicializada.")
        version = int(row["next_version"])
        conn.execute(
            "UPDATE corporate_sync_sequence SET next_version = ? WHERE id = 1",
            (version + 1,),
        )
        return version

    def _normalize_record(self, item: Mapping[str, Any]) -> dict[str, Any]:
        operation_id = self._validate_identifier(str(item.get("operation_id", "")), field="operation_id")
        entity = str(item.get("entity", "")).strip()
        if entity not in ALLOWED_SYNC_ENTITIES:
            raise CorporateSyncError("Entidade não autorizada para sincronização.")
        record_id = self._validate_identifier(str(item.get("record_id", "")), field="record_id")
        payload = item.get("payload")
        if not isinstance(payload, dict):
            raise CorporateSyncError("payload deve ser um objeto JSON.")
        if str(payload.get("id", "")) != record_id:
            raise CorporateSyncError("O ID do payload deve coincidir com record_id.")
        payload_json = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        payload_size = len(payload_json.encode("utf-8"))
        payload_limit = 22_000_000 if entity == "laudos" else 1_000_000
        if payload_size > payload_limit:
            raise CorporateSyncError(
                f"Registro {entity} excede o limite de {payload_limit} bytes."
            )
        deleted = 1 if bool(item.get("deleted", False)) else 0
        digest = hashlib.sha256(
            (entity + "\n" + record_id + "\n" + str(deleted) + "\n" + payload_json).encode("utf-8")
        ).hexdigest()
        return {
            "operation_id": operation_id,
            "entity": entity,
            "record_id": record_id,
            "payload_json": payload_json,
            "deleted": deleted,
            "client_updated_at": str(item.get("client_updated_at", "")).strip() or None,
            "sha256": digest,
        }

    @staticmethod
    def _validate_identifier(value: str, *, field: str) -> str:
        clean = value.strip()
        if not clean or len(clean) > 200:
            raise CorporateSyncError(f"{field} inválido.")
        if any(ord(char) < 32 for char in clean):
            raise CorporateSyncError(f"{field} contém caractere inválido.")
        return clean
