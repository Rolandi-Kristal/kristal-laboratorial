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

from validar_entidades_operacionais_kristal import (
    OperationalEntityValidationError,
    validate_operational_entities,
)


class OperationalEntityValidatorTests(unittest.TestCase):
    def _database(self, root: Path, *, orphan: bool = False) -> Path:
        database = root / "operational.db"
        with closing(sqlite3.connect(database)) as connection:
            connection.executescript(
                """
                CREATE TABLE pacientes (id TEXT PRIMARY KEY);
                CREATE TABLE exames (id TEXT PRIMARY KEY);
                CREATE TABLE pedidos (id TEXT PRIMARY KEY, pacienteId TEXT);
                CREATE TABLE amostras (id TEXT PRIMARY KEY, pacienteId TEXT, pedidoId TEXT);
                CREATE TABLE resultados (
                    id TEXT PRIMARY KEY, pacienteId TEXT, pedidoId TEXT, amostraId TEXT
                );
                CREATE TABLE legacy_operational_manifest (id TEXT PRIMARY KEY);
                INSERT INTO pacientes VALUES ('PAC-1');
                INSERT INTO exames VALUES ('EX-1');
                INSERT INTO pedidos VALUES ('PED-1', 'PAC-1');
                INSERT INTO amostras VALUES ('AMO-1', 'PAC-1', 'PED-1');
                INSERT INTO resultados VALUES ('RES-1', 'PAC-1', 'PED-1', 'AMO-1');
                INSERT INTO legacy_operational_manifest VALUES ('LEG-1');
                """
            )
            if orphan:
                connection.execute(
                    "UPDATE resultados SET pacienteId='AUSENTE' WHERE id='RES-1'"
                )
            connection.commit()
        return database

    def test_accepts_complete_relations_and_counts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result = validate_operational_entities(self._database(Path(temporary)))
        self.assertEqual(len(result.tables), 6)
        self.assertTrue(all(item.rows == 1 for item in result.tables))
        self.assertEqual(result.orphan_results_patients, 0)

    def test_rejects_missing_database(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(FileNotFoundError):
                validate_operational_entities(Path(temporary) / "missing.db")

    def test_rejects_missing_required_table(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._database(Path(temporary))
            with closing(sqlite3.connect(database)) as connection:
                connection.execute("DROP TABLE exames")
                connection.commit()
            with self.assertRaisesRegex(
                OperationalEntityValidationError, "Tabelas operacionais ausentes"
            ):
                validate_operational_entities(database)

    def test_rejects_orphan_relation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._database(Path(temporary), orphan=True)
            with self.assertRaisesRegex(
                OperationalEntityValidationError, "Integridade relacional"
            ):
                validate_operational_entities(database)


if __name__ == "__main__":
    unittest.main()
