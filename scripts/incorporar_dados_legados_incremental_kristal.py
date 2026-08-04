from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sqlite3
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description='Incorpora arquivos legados na KRISTAL com nomes tecnicos e hashes.')
parser.add_argument('--source-dir', required=True, help='Pasta contendo os arquivos originais.')
parser.add_argument('--dest-root', default=r'C:\kristal_laboratorial', help='Raiz da instalacao KRISTAL.')
parser.add_argument('--rar-exe', default='', help='Caminho opcional para Rar.exe.')
args = parser.parse_args()
source_dir = Path(args.source_dir)
dest_root = Path(args.dest_root)
rar_exe = Path(args.rar_exe) if args.rar_exe else source_dir / 'Rar.exe'
legacy_dir = dest_root / 'dados_legados_kristal'
raw_dir = legacy_dir / 'arquivos_originais'
extract_dir = legacy_dir / 'sql_extraido'
db_path = legacy_dir / 'kristal_dados_legados.sqlite3'
for path in (legacy_dir, raw_dir, extract_dir):
    path.mkdir(parents=True, exist_ok=True)

def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024 * 8), b''):
            digest.update(chunk)
    return digest.hexdigest()

def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript('''
    CREATE TABLE IF NOT EXISTS legacy_files (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      original_extension TEXT NOT NULL,
      stored_name TEXT NOT NULL,
      sha256 TEXT NOT NULL UNIQUE,
      size_bytes INTEGER NOT NULL,
      category TEXT NOT NULL,
      imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS legacy_sources (
      stored_name TEXT PRIMARY KEY,
      sha256 TEXT UNIQUE NOT NULL,
      size_bytes INTEGER NOT NULL,
      imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS legacy_sql_files (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source_sha256 TEXT NOT NULL,
      logical_database TEXT NOT NULL,
      stored_path TEXT NOT NULL,
      sha256 TEXT NOT NULL UNIQUE,
      size_bytes INTEGER NOT NULL,
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
    CREATE INDEX IF NOT EXISTS idx_legacy_files_sha256 ON legacy_files(sha256);
    CREATE INDEX IF NOT EXISTS idx_legacy_sources_sha256 ON legacy_sources(sha256);
    CREATE INDEX IF NOT EXISTS idx_legacy_sql_files_db ON legacy_sql_files(logical_database);
    CREATE INDEX IF NOT EXISTS idx_legacy_table_schemas_table ON legacy_table_schemas(table_name);
    ''')
    conn.commit()

def logical_name(name: str) -> str:
    return 'kristal_legado_' + hashlib.sha256(name.encode('utf-8')).hexdigest()[:12]

def copy_original(conn: sqlite3.Connection, path: Path, category: str) -> tuple[str, str, int]:
    digest = sha256_file(path)
    size = path.stat().st_size
    stored_name = f'KRISTAL_ARQUIVO_{digest[:16]}{path.suffix.lower()}'
    target = raw_dir / stored_name
    if not target.exists() or target.stat().st_size != size:
        shutil.copy2(path, target)
    conn.execute('''
      INSERT OR IGNORE INTO legacy_files (original_extension, stored_name, sha256, size_bytes, category)
      VALUES (?, ?, ?, ?, ?)
    ''', (path.suffix.lower(), stored_name, digest, size, category))
    if path.suffix.lower() == '.rar':
        conn.execute('''
          INSERT OR IGNORE INTO legacy_sources (stored_name, sha256, size_bytes)
          VALUES (?, ?, ?)
        ''', (stored_name, digest, size))
    conn.commit()
    print(f'ARQUIVO {stored_name} {size} {digest}')
    return stored_name, digest, size

def extract_rar(path: Path, digest: str) -> Path:
    target = extract_dir / digest[:16]
    target.mkdir(parents=True, exist_ok=True)
    if list(target.glob('*.sql')):
        return target
    result = subprocess.run([str(rar_exe), 'x', '-y', str(path), str(target) + '\\'], text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr or result.stdout or f'RAR falhou: {path}')
    return target

def split_columns(body: str) -> list[str]:
    cols=[]
    depth=0
    current=[]
    in_string=False
    escape=False
    for ch in body:
        if in_string:
            current.append(ch)
            if escape:
                escape=False
            elif ch == '\\':
                escape=True
            elif ch == "'":
                in_string=False
            continue
        if ch == "'":
            in_string=True; current.append(ch)
        elif ch == '(':
            depth += 1; current.append(ch)
        elif ch == ')':
            depth = max(0, depth-1); current.append(ch)
        elif ch == ',' and depth == 0:
            cols.append(''.join(current)); current=[]
        else:
            current.append(ch)
    if current:
        cols.append(''.join(current))
    return cols

def index_sql(conn: sqlite3.Connection, sql_path: Path, source_hash: str) -> None:
    digest = sha256_file(sql_path)
    size = sql_path.stat().st_size
    logical = logical_name(sql_path.stem)
    target_name = f'KRISTAL_SQL_{digest[:16]}.sql'
    target_path = sql_path.with_name(target_name)
    if sql_path.name != target_name:
        if target_path.exists():
            sql_path.unlink()
        else:
            sql_path.rename(target_path)
        sql_path = target_path
    conn.execute('''
      INSERT OR IGNORE INTO legacy_sql_files (source_sha256, logical_database, stored_path, sha256, size_bytes)
      VALUES (?, ?, ?, ?, ?)
    ''', (source_hash, logical, str(sql_path.relative_to(legacy_dir)), digest, size))
    conn.commit()
    statement=[]
    create_re = re.compile(r'CREATE\s+TABLE', re.IGNORECASE)
    table_re = re.compile(r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([^`\s(]+)`?', re.IGNORECASE)
    with sql_path.open('r', encoding='utf-8', errors='replace') as handle:
        for line in handle:
            if not statement and not create_re.search(line):
                continue
            statement.append(line.rstrip('\n'))
            if line.rstrip().endswith(';'):
                stmt='\n'.join(statement)
                statement=[]
                m=table_re.search(stmt)
                if not m:
                    continue
                table=m.group(1)
                open_i=stmt.find('(')
                close_i=stmt.rfind(')')
                columns=[]
                if open_i >= 0 and close_i > open_i:
                    for part in split_columns(stmt[open_i+1:close_i]):
                        stripped=part.strip()
                        if stripped.startswith('`'):
                            end=stripped.find('`',1)
                            if end > 1:
                                columns.append(stripped[1:end])
                conn.execute('''
                  INSERT OR REPLACE INTO legacy_table_schemas (source_sha256, logical_database, table_name, columns_json, create_sql_sha256)
                  VALUES (?, ?, ?, ?, ?)
                ''', (source_hash, logical, table, json.dumps(columns, ensure_ascii=False), hashlib.sha256(stmt.encode('utf-8')).hexdigest()))
                conn.commit()
    print(f'SQL {sql_path.name} {size} {digest}')

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
init_db(conn)
source_files = sorted(p for p in source_dir.iterdir() if p.is_file())
rar_items=[]
for item in source_files:
    category = 'ARQUIVO_RAR' if item.suffix.lower()=='.rar' else 'ARQUIVO_ORIGINAL'
    stored, digest, _ = copy_original(conn, item, category)
    if item.suffix.lower()=='.rar':
        rar_items.append((item, digest))
for item, digest in rar_items:
    folder = extract_rar(item, digest)
    for sql_path in sorted(folder.glob('*.sql')):
        index_sql(conn, sql_path, digest)
manifest = {
    'sistema': 'KRISTAL LABORATORIAL',
    'arquivos_originais': conn.execute('select count(*) from legacy_files').fetchone()[0],
    'fontes_rar': conn.execute('select count(*) from legacy_sources').fetchone()[0],
    'arquivos_sql': conn.execute('select count(*) from legacy_sql_files').fetchone()[0],
    'schemas': conn.execute('select count(*) from legacy_table_schemas').fetchone()[0],
}
(legacy_dir / 'manifesto_importacao_kristal.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(manifest, ensure_ascii=False, indent=2))
conn.close()
