from __future__ import annotations

import argparse
import json
import sqlite3
from contextlib import closing
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REQUIRED_INDEXES = frozenset(
    {
        "idx_legacy_raw_rows_tabela",
        "idx_legacy_raw_rows_hash",
    }
)


class DatabaseValidationError(RuntimeError):
    pass


@dataclass(frozen=True)
class SourceValidation:
    origem: str
    status: str
    expected_rows: int
    actual_rows: int
    minimum_index: int | None
    maximum_index: int | None


@dataclass(frozen=True)
class ValidationResult:
    database: str
    database_bytes: int
    validated_at: str
    quick_check: str
    integrity_check: str
    completed_sources: int
    distinct_legacy_tables: int
    total_rows: int
    required_indexes: list[str]
    sources: list[SourceValidation]


def _single_pragma_result(cursor: sqlite3.Cursor, pragma: str) -> str:
    rows = [str(row[0]) for row in cursor.execute(f"PRAGMA {pragma}").fetchall()]
    if rows != ["ok"]:
        raise DatabaseValidationError(f"PRAGMA {pragma} falhou: {rows[:20]}")
    return rows[0]


def validate_database(database: Path) -> ValidationResult:
    resolved = database.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Banco de dados não encontrado: {resolved}")
    if resolved.stat().st_size == 0:
        raise DatabaseValidationError("Banco de dados vazio.")

    with closing(sqlite3.connect(str(resolved), timeout=300)) as conn, closing(
        conn.cursor()
    ) as cursor:
        cursor.execute("PRAGMA busy_timeout = 300000")
        checkpoint = cursor.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
        if checkpoint is None or int(checkpoint[0]) != 0:
            raise DatabaseValidationError(f"Checkpoint WAL não concluído: {checkpoint}")

        tables = {
            str(row[0])
            for row in cursor.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }
        required_tables = {"legacy_raw_rows", "legacy_raw_progress"}
        missing_tables = sorted(required_tables - tables)
        if missing_tables:
            raise DatabaseValidationError(
                "Tabelas obrigatórias ausentes: " + ", ".join(missing_tables)
            )

        index_names = {
            str(row[0])
            for row in cursor.execute(
                "SELECT name FROM sqlite_master WHERE type = 'index'"
            ).fetchall()
        }
        missing_indexes = sorted(REQUIRED_INDEXES - index_names)
        if missing_indexes:
            raise DatabaseValidationError(
                "Índices obrigatórios ausentes: " + ", ".join(missing_indexes)
            )

        progress_rows = cursor.execute(
            "SELECT origem, status, linhas_brutas "
            "FROM legacy_raw_progress ORDER BY origem"
        ).fetchall()
        if len(progress_rows) != 8:
            raise DatabaseValidationError(
                f"Quantidade de fontes inválida: {len(progress_rows)}; esperado: 8."
            )
        incomplete = [str(row[0]) for row in progress_rows if str(row[1]) != "CONCLUIDO"]
        if incomplete:
            raise DatabaseValidationError(
                "Fontes não concluídas: " + ", ".join(incomplete)
            )

        grouped = {
            str(row[0]): (int(row[1]), int(row[2]), int(row[3]))
            for row in cursor.execute(
                "SELECT origem, COUNT(*), MIN(indice_linha), MAX(indice_linha) "
                "FROM legacy_raw_rows GROUP BY origem"
            ).fetchall()
        }
        source_results: list[SourceValidation] = []
        for origem_value, status_value, expected_value in progress_rows:
            origem = str(origem_value)
            expected = int(expected_value)
            actual, minimum, maximum = grouped.get(origem, (0, 0, 0))
            if actual != expected or minimum != 1 or maximum != expected:
                raise DatabaseValidationError(
                    f"Continuidade inválida em {origem}: "
                    f"esperado={expected}, atual={actual}, min={minimum}, max={maximum}."
                )
            source_results.append(
                SourceValidation(
                    origem=origem,
                    status=str(status_value),
                    expected_rows=expected,
                    actual_rows=actual,
                    minimum_index=minimum,
                    maximum_index=maximum,
                )
            )

        total_rows = sum(item.actual_rows for item in source_results)
        distinct_tables = int(
            cursor.execute(
                "SELECT COUNT(DISTINCT tabela_legada) FROM legacy_raw_rows"
            ).fetchone()[0]
        )
        quick_check = _single_pragma_result(cursor, "quick_check")
        integrity_check = _single_pragma_result(cursor, "integrity_check")

    return ValidationResult(
        database=str(resolved),
        database_bytes=resolved.stat().st_size,
        validated_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        quick_check=quick_check,
        integrity_check=integrity_check,
        completed_sources=len(source_results),
        distinct_legacy_tables=distinct_tables,
        total_rows=total_rows,
        required_indexes=sorted(REQUIRED_INDEXES),
        sources=source_results,
    )


def write_manifest(result: ValidationResult, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    payload: dict[str, Any] = asdict(result)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(destination)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Valida integralmente o banco de produção KRISTAL."
    )
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    result = validate_database(args.database)
    write_manifest(result, args.manifest)
    print(json.dumps(asdict(result), ensure_ascii=False, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
