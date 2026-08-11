from __future__ import annotations

import argparse
import base64
import hashlib
import json
import sqlite3
import sys
from contextlib import closing
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PORTAL_ROOT = PROJECT_ROOT / "portal_web"
if str(PORTAL_ROOT) not in sys.path:
    sys.path.insert(0, str(PORTAL_ROOT))

from app.corporate_sync import ALLOWED_SYNC_ENTITIES, CorporateSyncStore


def _json_value(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, bytes):
        return base64.b64encode(value).decode("ascii")
    raise TypeError(f"Tipo SQLite não suportado para sincronização: {type(value).__name__}")


def _stable_operation_id(entity: str, record_id: str, payload: dict[str, Any]) -> str:
    canonical = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"SEED:{entity}:{record_id}:{digest}"


def seed(*, operational_db: Path, corporate_db: Path, batch_size: int = 500) -> dict[str, int]:
    if not operational_db.is_file():
        raise FileNotFoundError(f"Banco operacional não encontrado: {operational_db}")
    if batch_size < 1 or batch_size > 500:
        raise ValueError("batch_size deve estar entre 1 e 500.")

    store = CorporateSyncStore(str(corporate_db))
    store.initialize()
    totals: dict[str, int] = {}

    with closing(sqlite3.connect(str(operational_db), timeout=30)) as source:
        source.row_factory = sqlite3.Row
        source.execute("PRAGMA query_only = ON")
        available = {
            str(row[0])
            for row in source.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }
        for entity in sorted(ALLOWED_SYNC_ENTITIES & available):
            columns = {
                str(row[1])
                for row in source.execute(f'PRAGMA table_info("{entity}")').fetchall()
            }
            if "id" not in columns:
                continue
            count = 0
            last_id = ""
            while True:
                rows = source.execute(
                    f'SELECT * FROM "{entity}" WHERE id > ? ORDER BY id LIMIT ?',
                    (last_id, batch_size),
                ).fetchall()
                if not rows:
                    break
                records: list[dict[str, Any]] = []
                for row in rows:
                    payload = {key: _json_value(row[key]) for key in row.keys()}
                    record_id = str(payload.get("id", "")).strip()
                    if not record_id:
                        raise ValueError(f"Registro sem ID em {entity}, após {last_id!r}.")
                    records.append(
                        {
                            "operation_id": _stable_operation_id(entity, record_id, payload),
                            "entity": entity,
                            "record_id": record_id,
                            "payload": payload,
                            "deleted": False,
                            "client_updated_at": None,
                        }
                    )
                result = store.push(client_id="SERVIDOR-CARGA-INICIAL", records=records)
                accepted = int(result["accepted"])
                if accepted != len(records):
                    raise RuntimeError(
                        f"Lote incompleto em {entity}: {accepted}/{len(records)}."
                    )
                count += len(records)
                last_id = str(rows[-1]["id"])
                print(f"{entity}: {count} registros processados", flush=True)
            totals[entity] = count

    print(
        json.dumps(
            {
                "status": "carga_corporativa_concluida",
                "operational_db": str(operational_db.resolve()),
                "corporate_db": str(corporate_db.resolve()),
                "total": sum(totals.values()),
                "tabelas": totals,
                "server_version": store.current_version(),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return totals


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Carrega o banco operacional KRISTAL no banco corporativo de sincronização."
    )
    parser.add_argument("--operational-db", required=True, type=Path)
    parser.add_argument("--corporate-db", required=True, type=Path)
    parser.add_argument("--batch-size", type=int, default=500)
    args = parser.parse_args()
    seed(
        operational_db=args.operational_db,
        corporate_db=args.corporate_db,
        batch_size=args.batch_size,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())