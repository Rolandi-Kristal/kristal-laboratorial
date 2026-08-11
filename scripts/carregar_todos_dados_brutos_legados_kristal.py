from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from collections.abc import Iterator
from contextlib import closing
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


class RawLoadError(RuntimeError):
    pass


@dataclass
class RawStats:
    sql_files: int = 0
    tables: int = 0
    raw_rows: int = 0


def now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")


def stable_id(prefix: str, *parts: object) -> str:
    raw = "|".join("" if part is None else str(part) for part in parts)
    return f"{prefix}-{hashlib.sha256(raw.encode('utf-8', errors='replace')).hexdigest()[:32]}"


def normalize_sql_token(raw: str) -> str | None:
    clean = raw.strip()
    if clean.upper() == "NULL":
        return None
    return clean


def split_insert_values(values: str) -> Iterator[list[str | None]]:
    in_string = False
    escaped = False
    in_tuple = False
    current: list[str] = []
    row: list[str | None] = []
    for char in values:
        if not in_tuple:
            if char == "(":
                in_tuple = True
                current = []
                row = []
            continue
        if in_string:
            if escaped:
                current.append({
                    "n": "\n",
                    "r": "\r",
                    "t": "\t",
                    "0": "\0",
                    "\\": "\\",
                    "'": "'",
                    '"': '"',
                }.get(char, char))
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == "'":
                in_string = False
            else:
                current.append(char)
            continue
        if char == "'":
            in_string = True
        elif char == ",":
            row.append(normalize_sql_token("".join(current)))
            current = []
        elif char == ")":
            row.append(normalize_sql_token("".join(current)))
            yield row
            in_tuple = False
            current = []
            row = []
        else:
            current.append(char)


def split_ddl_parts(body: str) -> list[str]:
    parts: list[str] = []
    current: list[str] = []
    depth = 0
    in_string = False
    escaped = False
    for char in body:
        if in_string:
            current.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == "'":
                in_string = False
            continue
        if char == "'":
            in_string = True
            current.append(char)
        elif char == "(":
            depth += 1
            current.append(char)
        elif char == ")":
            depth = max(0, depth - 1)
            current.append(char)
        elif char == "," and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)
    if current:
        parts.append("".join(current))
    return parts


def extract_create_columns(body: str) -> list[str]:
    columns: list[str] = []
    for raw_part in split_ddl_parts(body):
        part = raw_part.strip()
        if not part.startswith("`"):
            continue
        end = part.find("`", 1)
        if end > 1:
            columns.append(part[1:end])
    return columns


def row_to_dict(columns: list[str], values: list[str | None]) -> dict[str, str | None]:
    if not columns:
        return {str(index): value for index, value in enumerate(values)}
    return {column: values[index] if index < len(values) else None for index, column in enumerate(columns)}


def iter_sql_inserts(
    sql_path: Path,
    inherited_columns: dict[str, list[list[str]]] | None = None,
) -> Iterator[tuple[str, list[str], list[str | None]]]:
    insert_re = re.compile(
        r"INSERT\s+INTO\s+`?([^`\s(]+)`?\s*(?:\((.*?)\))?\s+VALUES\s*(.*)\s*;\s*$",
        re.IGNORECASE | re.DOTALL,
    )
    create_re = re.compile(
        r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([^`\s(]+)`?\s*\((.*)\)\s*[^;]*;\s*$",
        re.IGNORECASE | re.DOTALL,
    )
    statement: list[str] = []
    columns_by_table: dict[str, list[str]] = {}
    inherited = inherited_columns or {}
    with sql_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            stripped = line.strip()
            upper = stripped.upper()
            if not statement and not (upper.startswith("INSERT INTO") or upper.startswith("CREATE TABLE")):
                continue
            statement.append(line.rstrip("\n"))
            if not stripped.endswith(";"):
                continue
            sql = "\n".join(statement)
            statement.clear()
            create_match = create_re.match(sql)
            if create_match is not None:
                columns_by_table[create_match.group(1).lower()] = extract_create_columns(create_match.group(2))
                continue
            insert_match = insert_re.match(sql)
            if insert_match is None:
                continue
            table = insert_match.group(1).lower()
            columns_raw = insert_match.group(2) or ""
            explicit_columns = [
                part.strip().strip("`")
                for part in columns_raw.split(",")
                if part.strip()
            ]
            for row in split_insert_values(insert_match.group(3)):
                columns = explicit_columns or columns_by_table.get(table, [])
                if not columns:
                    compatible = [
                        variant
                        for variant in inherited.get(table, [])
                        if len(variant) == len(row)
                    ]
                    columns = compatible[0] if len(compatible) == 1 else []
                yield table, columns, row


def load_schema_index(legacy_root: Path) -> dict[str, dict[str, list[list[str]]]]:
    index_path = legacy_root / "kristal_dados_legados.sqlite3"
    if not index_path.is_file():
        return {}
    schemas: dict[str, dict[str, list[list[str]]]] = {}
    with closing(sqlite3.connect(index_path)) as connection:
        rows = connection.execute(
            "SELECT source_sha256, table_name, columns_json "
            "FROM legacy_table_schemas ORDER BY id"
        ).fetchall()
    for source_sha256, table_name, columns_json in rows:
        source_key = str(source_sha256).lower()[:16]
        table = str(table_name).lower()
        try:
            decoded = json.loads(str(columns_json))
        except json.JSONDecodeError as error:
            raise RawLoadError(
                f"Esquema JSON corrompido para {source_key}/{table}: {error}"
            ) from error
        if not isinstance(decoded, list) or not all(isinstance(item, str) for item in decoded):
            raise RawLoadError(f"Esquema invalido para {source_key}/{table}.")
        columns = [item for item in decoded if item]
        variants = schemas.setdefault(source_key, {}).setdefault(table, [])
        if columns not in variants:
            variants.append(columns)
    return schemas

def create_raw_rows_table(conn: sqlite3.Connection, table_name: str) -> None:
    if not re.fullmatch(r"[a-z0-9_]+", table_name):
        raise RawLoadError(f"Nome de tabela interna invalido: {table_name}")
    conn.execute(
        f"""
        CREATE TABLE {table_name} (
            id TEXT NOT NULL,
            origem TEXT NOT NULL,
            tabela_legada TEXT NOT NULL,
            indice_linha INTEGER NOT NULL,
            dados_json TEXT NOT NULL,
            hash_integridade TEXT NOT NULL,
            importado_em TEXT NOT NULL,
            PRIMARY KEY (origem, indice_linha)
        ) WITHOUT ROWID
        """
    )


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS legacy_raw_progress (
            origem TEXT PRIMARY KEY,
            status TEXT NOT NULL,
            linhas_brutas INTEGER NOT NULL DEFAULT 0,
            atualizado_em TEXT NOT NULL
        )
        """
    )
    table_sql = conn.execute(
        "SELECT sql FROM sqlite_master "
        "WHERE type = 'table' AND name = 'legacy_raw_rows'"
    ).fetchone()
    if table_sql is None:
        create_raw_rows_table(conn, "legacy_raw_rows")
    elif "WITHOUT ROWID" not in str(table_sql[0]).upper():
        conn.execute("DROP INDEX IF EXISTS idx_legacy_raw_rows_origem")
        conn.execute("DROP INDEX IF EXISTS idx_legacy_raw_rows_tabela")
        conn.execute("DROP INDEX IF EXISTS idx_legacy_raw_rows_hash")
        conn.execute("DROP INDEX IF EXISTS idx_legacy_raw_rows_origem_linha")
        create_raw_rows_table(conn, "legacy_raw_rows_v2")
        conn.execute(
            """
            INSERT OR REPLACE INTO legacy_raw_rows_v2 (
                id, origem, tabela_legada, indice_linha, dados_json,
                hash_integridade, importado_em
            )
            SELECT id, origem, tabela_legada, indice_linha, dados_json,
                   hash_integridade, importado_em
              FROM legacy_raw_rows
             ORDER BY importado_em, rowid
            """
        )
        conn.execute("DROP TABLE legacy_raw_rows")
        conn.execute("ALTER TABLE legacy_raw_rows_v2 RENAME TO legacy_raw_rows")
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_legacy_raw_rows_tabela "
        "ON legacy_raw_rows(tabela_legada)"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_legacy_raw_rows_hash "
        "ON legacy_raw_rows(hash_integridade)"
    )
    conn.commit()

def source_progress(conn: sqlite3.Connection) -> dict[str, tuple[str, int]]:
    rows = conn.execute(
        "SELECT origem, status, linhas_brutas FROM legacy_raw_progress"
    ).fetchall()
    progress = {
        str(origem): (str(status), max(0, int(linhas_brutas)))
        for origem, status, linhas_brutas in rows
    }
    persisted_rows = conn.execute(
        "SELECT origem, MAX(indice_linha) FROM legacy_raw_rows GROUP BY origem"
    ).fetchall()
    for origem, max_index in persisted_rows:
        key = str(origem)
        status, recorded_index = progress.get(key, ("PROCESSANDO", 0))
        progress[key] = (status, max(recorded_index, int(max_index or 0)))
    return progress


def load_raw_rows(legacy_root: Path, operational_db: Path) -> RawStats:
    if not legacy_root.exists():
        raise RawLoadError(f"Pasta de dados legados nao encontrada: {legacy_root}")
    sql_root = legacy_root / "sql_extraido"
    sql_files = sorted(sql_root.rglob("*.sql"))
    if not sql_files:
        raise RawLoadError(f"Nenhum SQL extraido encontrado em: {sql_root}")
    operational_db.parent.mkdir(parents=True, exist_ok=True)
    stats = RawStats(sql_files=len(sql_files))
    seen_tables: set[str] = set()
    schemas = load_schema_index(legacy_root)
    with closing(sqlite3.connect(operational_db)) as conn:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")
        conn.execute("PRAGMA temp_store=MEMORY")
        conn.execute("PRAGMA cache_size=-262144")
        ensure_schema(conn)
        progress = source_progress(conn)
        conn.execute("DROP INDEX IF EXISTS idx_legacy_raw_rows_origem")
        conn.execute("DROP INDEX IF EXISTS idx_legacy_raw_rows_tabela")
        conn.execute("DROP INDEX IF EXISTS idx_legacy_raw_rows_hash")
        conn.commit()
        for sql_path in sql_files:
            origem = str(sql_path.relative_to(legacy_root))
            status, resume_at = progress.get(origem, ("PENDENTE", 0))
            if status == "CONCLUIDO":
                continue
            line_index = 0
            pending_rows: list[tuple[str, str, str, int, str, str, str]] = []
            imported_at = now_iso()
            inherited = schemas.get(sql_path.parent.name.lower(), {})
            for table, columns, values in iter_sql_inserts(sql_path, inherited):
                line_index += 1
                if line_index <= resume_at:
                    continue
                row = row_to_dict(columns, values)
                payload_json = json.dumps(row, ensure_ascii=False, sort_keys=True)
                digest = hashlib.sha256(
                    (
                        origem
                        + "|"
                        + table
                        + "|"
                        + str(line_index)
                        + "|"
                        + payload_json
                    ).encode("utf-8")
                ).hexdigest()
                pending_rows.append(
                    (
                        stable_id("RAW", origem, table, line_index, digest),
                        origem,
                        table,
                        line_index,
                        payload_json,
                        digest,
                        imported_at,
                    )
                )
                seen_tables.add(table)
                stats.raw_rows += 1
                if len(pending_rows) >= 10000:
                    conn.executemany(
                        """
                        INSERT OR IGNORE INTO legacy_raw_rows (
                            id, origem, tabela_legada, indice_linha, dados_json,
                            hash_integridade, importado_em
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                        pending_rows,
                    )
                    conn.execute(
                        """
                        INSERT OR REPLACE INTO legacy_raw_progress (
                            origem, status, linhas_brutas, atualizado_em
                        ) VALUES (?, ?, ?, ?)
                        """,
                        (origem, "PROCESSANDO", line_index, now_iso()),
                    )
                    conn.commit()
                    pending_rows.clear()
            if pending_rows:
                conn.executemany(
                    """
                    INSERT OR IGNORE INTO legacy_raw_rows (
                        id, origem, tabela_legada, indice_linha, dados_json,
                        hash_integridade, importado_em
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    pending_rows,
                )
            conn.execute(
                """
                INSERT OR REPLACE INTO legacy_raw_progress (
                    origem, status, linhas_brutas, atualizado_em
                ) VALUES (?, ?, ?, ?)
                """,
                (origem, "CONCLUIDO", line_index, now_iso()),
            )
            conn.commit()

        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_legacy_raw_rows_tabela "
            "ON legacy_raw_rows(tabela_legada)"
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_legacy_raw_rows_hash "
            "ON legacy_raw_rows(hash_integridade)"
        )

        conn.commit()
    stats.tables = len(seen_tables)
    return stats


def write_manifest(legacy_root: Path, operational_db: Path, stats: RawStats) -> None:
    with closing(sqlite3.connect(operational_db)) as connection:
        total_rows = int(
            connection.execute("SELECT COUNT(*) FROM legacy_raw_rows").fetchone()[0]
        )
        total_tables = int(
            connection.execute(
                "SELECT COUNT(DISTINCT tabela_legada) FROM legacy_raw_rows"
            ).fetchone()[0]
        )
        completed_sources = int(
            connection.execute(
                "SELECT COUNT(*) FROM legacy_raw_progress WHERE status = 'CONCLUIDO'"
            ).fetchone()[0]
        )
    manifest = {
        "sistema": "KRISTAL LABORATORIAL",
        "tipo": "CARGA_BRUTA_TOTAL_SEM_EXCECAO",
        "banco_operacional": str(operational_db),
        "arquivos_sql_processados": stats.sql_files,
        "fontes_concluidas": completed_sources,
        "tabelas_com_insert": total_tables,
        "linhas_brutas_carregadas": total_rows,
        "linhas_nesta_execucao": stats.raw_rows,
        "gerado_em": now_iso(),
    }
    (legacy_root / "manifesto_carga_bruta_total_kristal.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Carrega TODAS as linhas brutas dos SQLs legados no SQLite KRISTAL.")
    parser.add_argument("--legacy-root", required=True, help="Pasta dados_legados_kristal.")
    parser.add_argument("--operational-db", required=True, help="Banco SQLite operacional KRISTAL.")
    args = parser.parse_args()
    legacy_root = Path(args.legacy_root)
    operational_db = Path(args.operational_db)
    stats = load_raw_rows(legacy_root, operational_db)
    write_manifest(legacy_root, operational_db, stats)
    print(json.dumps(stats.__dict__, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
