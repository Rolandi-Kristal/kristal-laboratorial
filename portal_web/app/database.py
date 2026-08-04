from __future__ import annotations

import os
import sqlite3
from datetime import datetime
from typing import Any

from app.config import Settings
from app.security import SecurityService


class Database:
    def __init__(self, db_path: str) -> None:
        self.db_path = db_path

    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    @staticmethod
    def now() -> str:
        return datetime.now().isoformat(timespec="seconds")

    @staticmethod
    def new_id(prefix: str) -> str:
        return f"{prefix}-{datetime.now().strftime('%Y%m%d%H%M%S%f')}"

    @staticmethod
    def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
        return None if row is None else dict(row)

    def initialize(self, settings: Settings) -> None:
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        with self.connect() as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS usuarios_admin (
                    id TEXT PRIMARY KEY,
                    login TEXT UNIQUE NOT NULL,
                    senha_hash TEXT NOT NULL,
                    nome TEXT NOT NULL,
                    perfil TEXT NOT NULL,
                    graduacao TEXT,
                    posto TEXT,
                    identidade_militar TEXT,
                    ativo TEXT NOT NULL DEFAULT '1',
                    criado_em TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS pacientes (
                    id TEXT PRIMARY KEY,
                    nome TEXT NOT NULL,
                    cpf TEXT UNIQUE NOT NULL,
                    preccp TEXT,
                    identidade_militar TEXT,
                    cns TEXT,
                    nascimento TEXT,
                    telefone TEXT,
                    email TEXT,
                    codigo_acesso_hash TEXT NOT NULL,
                    ativo TEXT NOT NULL DEFAULT '1',
                    ativo_consulta_recente TEXT NOT NULL DEFAULT '1',
                    arquivado TEXT NOT NULL DEFAULT '0',
                    excluido_fisicamente TEXT NOT NULL DEFAULT '0',
                    criado_em TEXT NOT NULL,
                    atualizado_em TEXT
                );
                CREATE TABLE IF NOT EXISTS exames (
                    id TEXT PRIMARY KEY,
                    paciente_id TEXT NOT NULL,
                    pedido_id TEXT,
                    amostra_id TEXT,
                    exame_nome TEXT NOT NULL,
                    valor TEXT,
                    unidade TEXT,
                    referencia TEXT,
                    status_laudo TEXT NOT NULL,
                    critico TEXT NOT NULL DEFAULT 'NÃO',
                    coletado_em TEXT,
                    liberado_em TEXT,
                    profissional_responsavel TEXT,
                    equipamento TEXT,
                    origem TEXT NOT NULL DEFAULT 'KRISTAL',
                    pdf_path TEXT,
                    ativo_consulta_recente TEXT NOT NULL DEFAULT '1',
                    arquivado TEXT NOT NULL DEFAULT '0',
                    excluido_fisicamente TEXT NOT NULL DEFAULT '0',
                    criado_em TEXT NOT NULL,
                    atualizado_em TEXT,
                    observacao TEXT,
                    FOREIGN KEY (paciente_id) REFERENCES pacientes(id)
                );
                CREATE TABLE IF NOT EXISTS historico_exames_pacientes (
                    id TEXT PRIMARY KEY,
                    paciente_id TEXT,
                    paciente_nome TEXT,
                    cpf TEXT,
                    preccp TEXT,
                    identidade_militar TEXT,
                    cns TEXT,
                    pedido_id TEXT,
                    amostra_id TEXT,
                    exame_nome TEXT,
                    valor TEXT,
                    unidade TEXT,
                    referencia TEXT,
                    status_laudo TEXT,
                    critico TEXT,
                    coletado_em TEXT,
                    liberado_em TEXT,
                    profissional_responsavel TEXT,
                    equipamento TEXT,
                    origem TEXT,
                    pdf_path TEXT,
                    ativo_consulta_recente TEXT NOT NULL DEFAULT '0',
                    arquivado TEXT NOT NULL DEFAULT '1',
                    excluido_fisicamente TEXT NOT NULL DEFAULT '0',
                    criado_em TEXT NOT NULL,
                    atualizado_em TEXT,
                    observacao TEXT
                );
                CREATE TABLE IF NOT EXISTS auditoria (
                    id TEXT PRIMARY KEY,
                    usuario TEXT,
                    acao TEXT NOT NULL,
                    tabela TEXT,
                    registro_id TEXT,
                    data_hora TEXT NOT NULL,
                    detalhes TEXT
                );
                CREATE TABLE IF NOT EXISTS catalogo_exames (
                    id TEXT PRIMARY KEY,
                    mne TEXT NOT NULL,
                    codigo_sire TEXT,
                    nome TEXT NOT NULL,
                    setor TEXT,
                    material TEXT,
                    metodo TEXT,
                    unidade TEXT,
                    referencia TEXT,
                    valor_cheio TEXT,
                    valor_indenizar_20 TEXT,
                    equipamento TEXT,
                    ativo TEXT NOT NULL DEFAULT '1',
                    criado_em TEXT NOT NULL,
                    atualizado_em TEXT
                );
                CREATE TABLE IF NOT EXISTS sire_cdm_envios (
                    id TEXT PRIMARY KEY,
                    paciente_id TEXT,
                    pedido_id TEXT,
                    beneficiario_id TEXT NOT NULL,
                    plano_interno_id TEXT NOT NULL,
                    percentual_desconto TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    retorno_json TEXT,
                    cdm_id TEXT,
                    status TEXT NOT NULL,
                    hash_integridade TEXT NOT NULL,
                    criado_em TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS legacy_sources (
                    stored_name TEXT PRIMARY KEY,
                    sha256 TEXT UNIQUE NOT NULL,
                    size_bytes INTEGER NOT NULL,
                    imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS legacy_files (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    original_extension TEXT NOT NULL,
                    stored_name TEXT NOT NULL,
                    sha256 TEXT UNIQUE NOT NULL,
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
                    row_sha256 TEXT UNIQUE NOT NULL,
                    imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_pacientes_cpf ON pacientes(cpf);
                CREATE INDEX IF NOT EXISTS idx_exames_paciente ON exames(paciente_id);
                CREATE INDEX IF NOT EXISTS idx_hist_paciente ON historico_exames_pacientes(paciente_id);
                CREATE INDEX IF NOT EXISTS idx_catalogo_exames_nome ON catalogo_exames(nome);
                CREATE INDEX IF NOT EXISTS idx_catalogo_exames_mne ON catalogo_exames(mne);
                CREATE INDEX IF NOT EXISTS idx_catalogo_exames_sire ON catalogo_exames(codigo_sire);
                CREATE INDEX IF NOT EXISTS idx_sire_cdm_envios_pedido ON sire_cdm_envios(pedido_id);
                CREATE INDEX IF NOT EXISTS idx_sire_cdm_envios_cdm ON sire_cdm_envios(cdm_id);
                CREATE INDEX IF NOT EXISTS idx_legacy_rows_table ON legacy_rows(table_name);
                CREATE INDEX IF NOT EXISTS idx_legacy_rows_db_table ON legacy_rows(logical_database, table_name);
                CREATE INDEX IF NOT EXISTS idx_legacy_rows_hash ON legacy_rows(row_sha256);
                CREATE INDEX IF NOT EXISTS idx_legacy_sources_sha256 ON legacy_sources(sha256);
                CREATE INDEX IF NOT EXISTS idx_legacy_files_sha256 ON legacy_files(sha256);
                CREATE INDEX IF NOT EXISTS idx_legacy_files_category ON legacy_files(category);
            """)
            self._ensure_columns(
                conn,
                table="usuarios_admin",
                columns={
                    "graduacao": "TEXT",
                    "posto": "TEXT",
                    "identidade_militar": "TEXT",
                },
            )
            self._ensure_columns(
                conn,
                table="pacientes",
                columns={"identidade_militar": "TEXT"},
            )
            self._ensure_columns(
                conn,
                table="historico_exames_pacientes",
                columns={"identidade_militar": "TEXT"},
            )
            admin = conn.execute("SELECT id FROM usuarios_admin WHERE login = ?", (settings.admin_login,)).fetchone()
            if admin is None:
                conn.execute(
                    """
                    INSERT INTO usuarios_admin (id, login, senha_hash, nome, perfil, graduacao, posto, identidade_militar, ativo, criado_em)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        self.new_id("ADM"),
                        settings.admin_login,
                        SecurityService.hash_password(settings.admin_password),
                        "Administrador KRISTAL",
                        "SUPER_USUARIO",
                        "Sargento",
                        "3º",
                        "",
                        "1",
                        self.now(),
                    ),
                )
            conn.commit()

    @staticmethod
    def _ensure_columns(conn: sqlite3.Connection, *, table: str, columns: dict[str, str]) -> None:
        existing = {row["name"] for row in conn.execute(f"PRAGMA table_info({table})").fetchall()}
        for name, column_type in columns.items():
            if name not in existing:
                conn.execute(f"ALTER TABLE {table} ADD COLUMN {name} {column_type}")

    def audit(self, *, usuario: str, acao: str, tabela: str, registro_id: str, detalhes: str) -> None:
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO auditoria (id, usuario, acao, tabela, registro_id, data_hora, detalhes)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (self.new_id("AUD"), usuario, acao, tabela, registro_id, self.now(), detalhes),
            )
            conn.commit()
