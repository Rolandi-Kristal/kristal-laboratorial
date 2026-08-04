from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class ImportStats:
    archives: int = 0
    sql_files: int = 0
    tables: int = 0
    rows: int = 0


class LegacyImportError(RuntimeError):
    pass


class LegacyMysqlDumpImporter:
    def __init__(self, *, source_dir: Path, dest_root: Path, rar_exe: Path | None = None) -> None:
        self.source_dir = source_dir
        self.dest_root = dest_root
        self.rar_exe = rar_exe
        self.legacy_dir = dest_root / 'dados_legados_kristal'
        self.raw_dir = self.legacy_dir / 'arquivos_originais'
        self.extract_dir = self.legacy_dir / 'sql_extraido'
        self.db_path = self.legacy_dir / 'kristal_dados_legados.sqlite3'

    def run(self) -> ImportStats:
        if not self.source_dir.exists():
            raise LegacyImportError(f'Pasta de origem nao encontrada: {self.source_dir}')
        self.legacy_dir.mkdir(parents=True, exist_ok=True)
        self.raw_dir.mkdir(parents=True, exist_ok=True)
        self.extract_dir.mkdir(parents=True, exist_ok=True)
        self._init_db()

        original_files = sorted(path for path in self.source_dir.iterdir() if path.is_file())
        archives = [path for path in original_files if path.suffix.lower() == '.rar']
        if not archives:
            raise LegacyImportError(f'Nenhum arquivo .rar encontrado em: {self.source_dir}')

        total_sql = 0
        total_rows = 0
        table_names: set[str] = set()

        with sqlite3.connect(self.db_path) as conn:
            conn.execute('PRAGMA journal_mode=WAL')
            conn.execute('PRAGMA synchronous=NORMAL')
            for source_file in original_files:
                if source_file.suffix.lower() != '.rar':
                    self._copy_supporting_file(conn, source_file)
            for archive in archives:
                archive_hash = self._copy_archive(conn, archive)
                extracted = self._extract_archive(archive=archive, archive_hash=archive_hash)
                for sql_file in extracted:
                    total_sql += 1
                    rows, tables = self._import_sql_file(
                        conn=conn,
                        sql_file=sql_file,
                        archive_hash=archive_hash,
                    )
                    total_rows += rows
                    table_names.update(tables)
            conn.commit()

        manifest = {
            'sistema': 'KRISTAL LABORATORIAL',
            'destino': str(self.legacy_dir),
            'banco_legado': str(self.db_path),
            'arquivos_rar': len(archives),
            'arquivos_sql': total_sql,
            'tabelas': len(table_names),
            'linhas': total_rows,
        }
        (self.legacy_dir / 'manifesto_importacao_kristal.json').write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + '\n',
            encoding='utf-8',
        )
        return ImportStats(
            archives=len(archives),
            sql_files=total_sql,
            tables=len(table_names),
            rows=total_rows,
        )

    def _init_db(self) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.executescript(
                '''
                CREATE TABLE IF NOT EXISTS legacy_sources (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    stored_name TEXT NOT NULL,
                    sha256 TEXT NOT NULL UNIQUE,
                    size_bytes INTEGER NOT NULL,
                    imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );                CREATE TABLE IF NOT EXISTS legacy_files (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    original_extension TEXT NOT NULL,
                    stored_name TEXT NOT NULL,
                    sha256 TEXT NOT NULL UNIQUE,
                    size_bytes INTEGER NOT NULL,
                    category TEXT NOT NULL,
                    imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS legacy_table_schemas (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    source_sha256 TEXT NOT NULL,
                    logical_database TEXT NOT NULL,
                    table_name TEXT NOT NULL,
                    columns_json TEXT NOT NULL,
                    create_sql_sha256 TEXT NOT NULL,
                    imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(source_sha256, logical_database, table_name)
                );
                CREATE TABLE IF NOT EXISTS legacy_rows (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    source_sha256 TEXT NOT NULL,
                    logical_database TEXT NOT NULL,
                    table_name TEXT NOT NULL,
                    row_index INTEGER NOT NULL,
                    row_json TEXT NOT NULL,
                    row_sha256 TEXT NOT NULL UNIQUE,
                    imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_legacy_rows_table ON legacy_rows(table_name);
                CREATE INDEX IF NOT EXISTS idx_legacy_rows_db_table ON legacy_rows(logical_database, table_name);
                CREATE INDEX IF NOT EXISTS idx_legacy_rows_hash ON legacy_rows(row_sha256);
                '''
            )
            conn.commit()

    def _copy_archive(self, conn: sqlite3.Connection, archive: Path) -> str:
        stored_name, digest, size_bytes = self._copy_original_file(conn, archive, category='ARQUIVO_RAR')
        conn.execute(
            '''
            INSERT OR IGNORE INTO legacy_sources (stored_name, sha256, size_bytes)
            VALUES (?, ?, ?)
            ''',
            (stored_name, digest, size_bytes),
        )
        return digest

    def _copy_supporting_file(self, conn: sqlite3.Connection, source_file: Path) -> str:
        stored_name, digest, _ = self._copy_original_file(conn, source_file, category='ARQUIVO_ORIGINAL')
        return stored_name

    def _copy_original_file(self, conn: sqlite3.Connection, source_file: Path, *, category: str) -> tuple[str, str, int]:
        digest = self._sha256_file(source_file)
        size_bytes = source_file.stat().st_size
        stored_name = f'KRISTAL_ARQUIVO_{digest[:16]}{source_file.suffix.lower()}'
        target = self.raw_dir / stored_name
        if not target.exists() or target.stat().st_size != size_bytes:
            shutil.copy2(source_file, target)
        conn.execute(
            '''
            INSERT OR IGNORE INTO legacy_files (original_extension, stored_name, sha256, size_bytes, category)
            VALUES (?, ?, ?, ?, ?)
            ''',
            (source_file.suffix.lower(), stored_name, digest, size_bytes, category),
        )
        return stored_name, digest, size_bytes

    def _extract_archive(self, *, archive: Path, archive_hash: str) -> list[Path]:
        target_dir = self.extract_dir / archive_hash[:16]
        target_dir.mkdir(parents=True, exist_ok=True)
        existing = sorted(target_dir.glob('*.sql'))
        if existing:
            return existing

        rar_exe = self._resolve_rar_exe()
        if rar_exe is None:
            raise LegacyImportError('Rar.exe nao encontrado. Informe --rar-exe apontando para o executavel RAR.')

        with tempfile.TemporaryDirectory(prefix='kristal_legacy_extract_') as temp_name:
            temp_dir = Path(temp_name)
            command = [str(rar_exe), 'x', '-o+', '-inul', str(archive), str(temp_dir) + os.sep]
            completed = subprocess.run(command, check=False, capture_output=True, text=True)
            if completed.returncode != 0:
                raise LegacyImportError(
                    'Falha ao extrair arquivo legado. Codigo=' + str(completed.returncode)
                )
            sql_files = sorted(temp_dir.rglob('*.sql'))
            if not sql_files:
                raise LegacyImportError(f'Arquivo legado sem SQL extraivel: {archive.name}')
            for sql_file in sql_files:
                shutil.move(str(sql_file), str(target_dir / sql_file.name))
        return sorted(target_dir.glob('*.sql'))

    def _resolve_rar_exe(self) -> Path | None:
        candidates: list[Path] = []
        if self.rar_exe is not None:
            candidates.append(self.rar_exe)
        candidates.append(self.source_dir / 'Rar.exe')
        path_value = shutil.which('Rar.exe') or shutil.which('rar')
        if path_value:
            candidates.append(Path(path_value))
        for candidate in candidates:
            if candidate.exists() and candidate.is_file():
                return candidate
        return None

    def _import_sql_file(self, *, conn: sqlite3.Connection, sql_file: Path, archive_hash: str) -> tuple[int, set[str]]:
        logical_database = self._safe_logical_database(sql_file.stem)
        columns_by_table: dict[str, list[str]] = {}
        total_rows = 0
        tables: set[str] = set()
        statement_buffer: list[str] = []

        with sql_file.open('r', encoding='utf-8', errors='replace') as handle:
            for raw_line in handle:
                line = raw_line.rstrip('\n')
                if not line or line.startswith('--') or line.startswith('/*'):
                    continue
                statement_buffer.append(line)
                if line.endswith(';'):
                    statement = '\n'.join(statement_buffer)
                    statement_buffer.clear()
                    table = self._table_from_create(statement)
                    if table:
                        columns = self._columns_from_create(statement)
                        if columns:
                            columns_by_table[table] = columns
                            tables.add(table)
                            conn.execute(
                                '''
                                INSERT OR REPLACE INTO legacy_table_schemas (
                                    source_sha256, logical_database, table_name,
                                    columns_json, create_sql_sha256
                                ) VALUES (?, ?, ?, ?, ?)
                                ''',
                                (
                                    archive_hash,
                                    logical_database,
                                    table,
                                    json.dumps(columns, ensure_ascii=False),
                                    hashlib.sha256(statement.encode('utf-8')).hexdigest(),
                                ),
                            )
                        continue
                    insert_table = self._table_from_insert(statement)
                    if insert_table:
                        tables.add(insert_table)
                        inserted = self._import_insert_statement(
                            conn=conn,
                            statement=statement,
                            archive_hash=archive_hash,
                            logical_database=logical_database,
                            table_name=insert_table,
                            columns_by_table=columns_by_table,
                            start_index=total_rows,
                        )
                        total_rows += inserted
                        if total_rows and total_rows % 5000 == 0:
                            conn.commit()
        return total_rows, tables

    def _table_from_create(self, statement: str) -> str | None:
        prefix = 'CREATE TABLE'
        upper = statement.upper()
        if prefix not in upper:
            return None
        marker = '`'
        first = statement.find(marker)
        second = statement.find(marker, first + 1)
        if first < 0 or second < 0:
            return None
        return statement[first + 1:second]

    def _table_from_insert(self, statement: str) -> str | None:
        upper = statement.upper()
        if not upper.startswith('INSERT INTO'):
            return None
        first = statement.find('`')
        second = statement.find('`', first + 1)
        if first < 0 or second < 0:
            return None
        return statement[first + 1:second]

    def _columns_from_create(self, statement: str) -> list[str]:
        columns: list[str] = []
        open_index = statement.find('(')
        close_index = statement.rfind(')')
        if open_index < 0 or close_index <= open_index:
            return columns
        body = statement[open_index + 1:close_index]
        for definition in self._split_sql_columns(body):
            stripped = definition.strip()
            if not stripped.startswith('`'):
                continue
            end = stripped.find('`', 1)
            if end > 1:
                columns.append(stripped[1:end])
        return columns

    def _split_sql_columns(self, body: str) -> list[str]:
        parts: list[str] = []
        current: list[str] = []
        in_string = False
        escape = False
        depth = 0
        for char in body:
            if in_string:
                current.append(char)
                if escape:
                    escape = False
                elif char == '\\':
                    escape = True
                elif char == "'":
                    in_string = False
                continue
            if char == "'":
                in_string = True
                current.append(char)
            elif char == '(':
                depth += 1
                current.append(char)
            elif char == ')':
                depth = max(0, depth - 1)
                current.append(char)
            elif char == ',' and depth == 0:
                parts.append(''.join(current))
                current = []
            else:
                current.append(char)
        if current:
            parts.append(''.join(current))
        return parts

    def _import_insert_statement(
        self,
        *,
        conn: sqlite3.Connection,
        statement: str,
        archive_hash: str,
        logical_database: str,
        table_name: str,
        columns_by_table: dict[str, list[str]],
        start_index: int,
    ) -> int:
        values_index = statement.upper().find(' VALUES ')
        if values_index < 0:
            return 0
        head = statement[:values_index]
        columns = self._columns_from_insert_head(head) or columns_by_table.get(table_name, [])
        values_text = statement[values_index + len(' VALUES '):].rstrip().rstrip(';')
        rows = self._parse_values(values_text)
        inserted = 0
        for offset, values in enumerate(rows, start=1):
            if columns and len(columns) == len(values):
                row_object: dict[str, object | None] = dict(zip(columns, values))
            else:
                row_object = {f'coluna_{index + 1}': value for index, value in enumerate(values)}
            row_json = json.dumps(row_object, ensure_ascii=False, sort_keys=True)
            row_hash = hashlib.sha256(
                f'{archive_hash}|{logical_database}|{table_name}|{row_json}'.encode('utf-8')
            ).hexdigest()
            conn.execute(
                '''
                INSERT OR IGNORE INTO legacy_rows (
                    source_sha256, logical_database, table_name, row_index,
                    row_json, row_sha256
                ) VALUES (?, ?, ?, ?, ?, ?)
                ''',
                (archive_hash, logical_database, table_name, start_index + offset, row_json, row_hash),
            )
            inserted += 1
        return inserted

    def _columns_from_insert_head(self, head: str) -> list[str]:
        open_index = head.find('(')
        close_index = head.rfind(')')
        if open_index < 0 or close_index < open_index:
            return []
        raw = head[open_index + 1:close_index]
        return [item.strip().strip('`') for item in raw.split(',') if item.strip()]

    def _parse_values(self, values_text: str) -> list[list[object | None]]:
        rows: list[list[object | None]] = []
        current_row: list[object | None] = []
        current_value: list[str] = []
        in_string = False
        escape = False
        row_depth = 0
        token_was_quoted = False

        def finish_value() -> None:
            token = ''.join(current_value)
            current_value.clear()
            current_row.append(self._convert_token(token, token_was_quoted))

        index = 0
        while index < len(values_text):
            char = values_text[index]
            if in_string:
                if escape:
                    current_value.append(self._unescape_char(char))
                    escape = False
                elif char == '\\':
                    escape = True
                elif char == "'":
                    in_string = False
                else:
                    current_value.append(char)
            else:
                if char == "'":
                    in_string = True
                    token_was_quoted = True
                elif char == '(':
                    row_depth += 1
                    if row_depth == 1:
                        current_row = []
                        current_value = []
                        token_was_quoted = False
                    else:
                        current_value.append(char)
                elif char == ')':
                    if row_depth == 1:
                        finish_value()
                        rows.append(current_row)
                        current_row = []
                        current_value = []
                        token_was_quoted = False
                    else:
                        current_value.append(char)
                    row_depth -= 1
                elif char == ',' and row_depth == 1:
                    finish_value()
                    token_was_quoted = False
                elif row_depth >= 1:
                    current_value.append(char)
            index += 1
        return rows

    def _convert_token(self, token: str, quoted: bool) -> object | None:
        if quoted:
            return token
        clean = token.strip()
        if clean.upper() == 'NULL':
            return None
        if clean == '':
            return ''
        return clean

    def _unescape_char(self, char: str) -> str:
        return {
            '0': '\x00',
            'n': '\n',
            'r': '\r',
            't': '\t',
            'b': '\b',
            'Z': '\x1a',
        }.get(char, char)

    def _safe_logical_database(self, value: str) -> str:
        digest = hashlib.sha256(value.strip().encode('utf-8')).hexdigest()[:12]
        return f'kristal_legado_{digest}'

    def _sha256_file(self, file_path: Path) -> str:
        digest = hashlib.sha256()
        with file_path.open('rb') as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b''):
                digest.update(chunk)
        return digest.hexdigest()


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Importa dados legados para o repositÃ³rio KRISTAL.')
    parser.add_argument('--source-dir', required=True, help='Pasta contendo os arquivos .rar originais.')
    parser.add_argument('--dest-root', default='D:\\kristal_laboratorial', help='Raiz da instalaÃ§Ã£o KRISTAL.')
    parser.add_argument('--rar-exe', default='', help='Caminho opcional para Rar.exe.')
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    args = parse_args(argv)
    importer = LegacyMysqlDumpImporter(
        source_dir=Path(args.source_dir),
        dest_root=Path(args.dest_root),
        rar_exe=Path(args.rar_exe) if args.rar_exe else None,
    )
    stats = importer.run()
    print('Importacao KRISTAL concluida.')
    print(f'Arquivos RAR: {stats.archives}')
    print(f'Arquivos SQL: {stats.sql_files}')
    print(f'Tabelas: {stats.tables}')
    print(f'Linhas: {stats.rows}')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main(sys.argv[1:]))
    except LegacyImportError as error:
        print(f'ERRO: {error}', file=sys.stderr)
        raise SystemExit(2)



