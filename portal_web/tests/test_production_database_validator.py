from __future__ import annotations

import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_ROOT = PROJECT_ROOT / "scripts"
if str(SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_ROOT))

from validar_banco_producao_kristal import DatabaseValidationError, validate_database


class ProductionDatabaseValidatorTests(unittest.TestCase):
    def _create_database(
        self,
        root: Path,
        *,
        source_count: int = 8,
        completed: bool = True,
        omit_last_row: bool = False,
    ) -> Path:
        database = root / "production.db"
        with closing(sqlite3.connect(database)) as conn:
            conn.executescript(
                """
                CREATE TABLE legacy_raw_progress (
                    origem TEXT PRIMARY KEY,
                    status TEXT NOT NULL,
                    linhas_brutas INTEGER NOT NULL,
                    atualizado_em TEXT NOT NULL
                );
                CREATE TABLE legacy_raw_rows (
                    id TEXT PRIMARY KEY,
                    origem TEXT NOT NULL,
                    tabela_legada TEXT NOT NULL,
                    indice_linha INTEGER NOT NULL,
                    dados_json TEXT NOT NULL,
                    hash_integridade TEXT NOT NULL,
                    importado_em TEXT NOT NULL,
                    UNIQUE (origem, indice_linha)
                ) WITHOUT ROWID;
                CREATE INDEX idx_legacy_raw_rows_tabela
                ON legacy_raw_rows(tabela_legada);
                CREATE INDEX idx_legacy_raw_rows_hash
                ON legacy_raw_rows(hash_integridade);
                """
            )
            for source_index in range(source_count):
                origem = f"source-{source_index}"
                status = "CONCLUIDO" if completed or source_index > 0 else "PROCESSANDO"
                conn.execute(
                    "INSERT INTO legacy_raw_progress VALUES (?, ?, 2, '2026-08-11')",
                    (origem, status),
                )
                upper = 1 if omit_last_row and source_index == 0 else 2
                for row_index in range(1, upper + 1):
                    conn.execute(
                        "INSERT INTO legacy_raw_rows VALUES (?, ?, 'pacientes', ?, '{}', ?, '2026-08-11')",
                        (f"{origem}-{row_index}", origem, row_index, f"hash-{origem}-{row_index}"),
                    )
            conn.commit()
        return database

    def test_accepts_complete_consistent_database(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._create_database(Path(temporary))
            result = validate_database(database)
        self.assertEqual(result.completed_sources, 8)
        self.assertEqual(result.total_rows, 16)
        self.assertEqual(result.quick_check, "ok")
        self.assertEqual(result.integrity_check, "ok")

    def test_rejects_missing_database(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(FileNotFoundError):
                validate_database(Path(temporary) / "missing.db")

    def test_rejects_incomplete_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._create_database(Path(temporary), completed=False)
            with self.assertRaisesRegex(DatabaseValidationError, "não concluídas"):
                validate_database(database)

    def test_rejects_row_count_or_continuity_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._create_database(Path(temporary), omit_last_row=True)
            with self.assertRaisesRegex(DatabaseValidationError, "Continuidade inválida"):
                validate_database(database)


if __name__ == "__main__":
    unittest.main()
