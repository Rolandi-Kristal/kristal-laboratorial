from __future__ import annotations

import argparse
import json
import sqlite3
from contextlib import closing
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


REQUIRED_TABLES = (
    "pacientes",
    "exames",
    "pedidos",
    "amostras",
    "resultados",
    "legacy_operational_manifest",
)


class OperationalEntityValidationError(RuntimeError):
    pass


@dataclass(frozen=True)
class TableCount:
    table: str
    rows: int
    minimum_rowid: int | None
    maximum_rowid: int | None


@dataclass(frozen=True)
class OperationalEntityValidationResult:
    database: str
    database_bytes: int
    validated_at: str
    tables: list[TableCount]
    orphan_orders: int
    orphan_samples_patients: int
    orphan_samples_orders: int
    orphan_results_patients: int
    orphan_results_orders: int
    orphan_results_samples: int
    empty_ids: dict[str, int]


def _count(cursor: sqlite3.Cursor, sql: str) -> int:
    row = cursor.execute(sql).fetchone()
    if row is None:
        raise OperationalEntityValidationError(f"Consulta sem retorno: {sql}")
    return int(row[0])


def validate_operational_entities(database: Path) -> OperationalEntityValidationResult:
    resolved = database.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Banco operacional não encontrado: {resolved}")
    if resolved.stat().st_size == 0:
        raise OperationalEntityValidationError("Banco operacional vazio.")

    with closing(sqlite3.connect(f"file:{resolved.as_posix()}?mode=ro", uri=True, timeout=300)) as connection, closing(
        connection.cursor()
    ) as cursor:
        cursor.execute("PRAGMA busy_timeout = 300000")
        tables = {
            str(row[0])
            for row in cursor.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }
        missing = sorted(set(REQUIRED_TABLES) - tables)
        if missing:
            raise OperationalEntityValidationError(
                "Tabelas operacionais ausentes: " + ", ".join(missing)
            )

        counts: list[TableCount] = []
        empty_ids: dict[str, int] = {}
        for table in REQUIRED_TABLES:
            row = cursor.execute(
                f'SELECT COUNT(*), MIN(rowid), MAX(rowid) FROM "{table}"'
            ).fetchone()
            if row is None:
                raise OperationalEntityValidationError(
                    f"Contagem sem retorno para {table}."
                )
            rows = int(row[0])
            if rows < 1:
                raise OperationalEntityValidationError(f"Tabela operacional vazia: {table}")
            counts.append(
                TableCount(
                    table=table,
                    rows=rows,
                    minimum_rowid=None if row[1] is None else int(row[1]),
                    maximum_rowid=None if row[2] is None else int(row[2]),
                )
            )
            empty_ids[table] = _count(
                cursor,
                f'SELECT COUNT(*) FROM "{table}" WHERE id IS NULL OR TRIM(CAST(id AS TEXT)) = \'\'',
            )

        checks = {
            "orphan_orders": _count(
                cursor,
                "SELECT COUNT(*) FROM pedidos x LEFT JOIN pacientes p ON p.id=x.pacienteId "
                "WHERE x.pacienteId IS NOT NULL AND TRIM(x.pacienteId)<>'' AND p.id IS NULL",
            ),
            "orphan_samples_patients": _count(
                cursor,
                "SELECT COUNT(*) FROM amostras x LEFT JOIN pacientes p ON p.id=x.pacienteId "
                "WHERE x.pacienteId IS NOT NULL AND TRIM(x.pacienteId)<>'' AND p.id IS NULL",
            ),
            "orphan_samples_orders": _count(
                cursor,
                "SELECT COUNT(*) FROM amostras x LEFT JOIN pedidos p ON p.id=x.pedidoId "
                "WHERE x.pedidoId IS NOT NULL AND TRIM(x.pedidoId)<>'' AND p.id IS NULL",
            ),
            "orphan_results_patients": _count(
                cursor,
                "SELECT COUNT(*) FROM resultados x LEFT JOIN pacientes p ON p.id=x.pacienteId "
                "WHERE x.pacienteId IS NOT NULL AND TRIM(x.pacienteId)<>'' AND p.id IS NULL",
            ),
            "orphan_results_orders": _count(
                cursor,
                "SELECT COUNT(*) FROM resultados x LEFT JOIN pedidos p ON p.id=x.pedidoId "
                "WHERE x.pedidoId IS NOT NULL AND TRIM(x.pedidoId)<>'' AND p.id IS NULL",
            ),
            "orphan_results_samples": _count(
                cursor,
                "SELECT COUNT(*) FROM resultados x LEFT JOIN amostras a ON a.id=x.amostraId "
                "WHERE x.amostraId IS NOT NULL AND TRIM(x.amostraId)<>'' AND a.id IS NULL",
            ),
        }
        invalid = {name: value for name, value in checks.items() if value != 0}
        invalid.update({f"empty_ids_{name}": value for name, value in empty_ids.items() if value != 0})
        if invalid:
            raise OperationalEntityValidationError(
                "Integridade relacional operacional rejeitada: "
                + json.dumps(invalid, ensure_ascii=False, sort_keys=True)
            )

    return OperationalEntityValidationResult(
        database=str(resolved),
        database_bytes=resolved.stat().st_size,
        validated_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        tables=counts,
        empty_ids=empty_ids,
        **checks,
    )


def write_manifest(result: OperationalEntityValidationResult, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.write_text(
        json.dumps(asdict(result), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(destination)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Valida contagens e relações das entidades operacionais KRISTAL."
    )
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    arguments = parser.parse_args()
    result = validate_operational_entities(arguments.database)
    write_manifest(result, arguments.manifest)
    print(json.dumps(asdict(result), ensure_ascii=False, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
