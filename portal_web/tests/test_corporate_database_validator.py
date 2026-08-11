from __future__ import annotations

import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from app.corporate_sync import CorporateSyncStore


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_ROOT = PROJECT_ROOT / "scripts"
if str(SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_ROOT))

from validar_banco_corporativo_kristal import (
    CorporateDatabaseValidationError,
    validate_corporate_database,
)


class CorporateDatabaseValidatorTests(unittest.TestCase):
    def _create_database(self, root: Path) -> Path:
        database = root / "corporate.db"
        store = CorporateSyncStore(str(database))
        store.initialize()
        result = store.push(
            client_id="TESTE",
            records=[
                {
                    "operation_id": "OP-1",
                    "entity": "pacientes",
                    "record_id": "PAC-1",
                    "payload": {"id": "PAC-1", "nome": "Paciente Teste"},
                    "deleted": False,
                },
                {
                    "operation_id": "OP-2",
                    "entity": "exames",
                    "record_id": "EX-1",
                    "payload": {"id": "EX-1", "nome": "Hemograma"},
                    "deleted": False,
                },
            ],
        )
        self.assertEqual(result["accepted"], 2)
        return database

    def test_accepts_complete_corporate_database(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._create_database(Path(temporary))
            result = validate_corporate_database(database)
            self.assertEqual(result.quick_check, "ok")
            self.assertEqual(result.integrity_check, "ok")
            self.assertEqual(result.current_records, 2)
            self.assertEqual(result.history_records, 2)
            self.assertEqual(result.payload_hashes_validated, 4)
            self.assertEqual(result.entities, {"exames": 1, "pacientes": 1})

    def test_rejects_missing_required_table(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._create_database(Path(temporary))
            with closing(sqlite3.connect(database)) as connection:
                connection.execute("DROP TABLE corporate_sync_clients")
                connection.commit()
            with self.assertRaisesRegex(
                CorporateDatabaseValidationError, "table obrigatorios ausentes"
            ):
                validate_corporate_database(database)

    def test_rejects_tampered_payload_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._create_database(Path(temporary))
            with closing(sqlite3.connect(database)) as connection:
                connection.execute(
                    "UPDATE corporate_sync_records SET sha256 = ? WHERE record_id = ?",
                    ("0" * 64, "PAC-1"),
                )
                connection.commit()
            with self.assertRaisesRegex(
                CorporateDatabaseValidationError,
                "Registros atuais sem historico correspondente",
            ):
                validate_corporate_database(database)

    def test_rejects_invalid_version_sequence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._create_database(Path(temporary))
            with closing(sqlite3.connect(database)) as connection:
                connection.execute(
                    "UPDATE corporate_sync_sequence SET next_version = 99 WHERE id = 1"
                )
                connection.commit()
            with self.assertRaisesRegex(
                CorporateDatabaseValidationError, "Continuidade de versoes invalida"
            ):
                validate_corporate_database(database)

    def test_rejects_unknown_entity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = self._create_database(Path(temporary))
            with closing(sqlite3.connect(database)) as connection:
                connection.execute(
                    "UPDATE corporate_sync_records SET entity = ? WHERE record_id = ?",
                    ("nao_autorizada", "PAC-1"),
                )
                connection.execute("DROP TRIGGER trg_corporate_history_no_update")
                connection.execute(
                    "UPDATE corporate_sync_history SET entity = ? WHERE record_id = ?",
                    ("nao_autorizada", "PAC-1"),
                )
                connection.execute(
                    """
                    CREATE TRIGGER trg_corporate_history_no_update
                    BEFORE UPDATE ON corporate_sync_history
                    BEGIN
                        SELECT RAISE(ABORT, 'corporate_sync_history is immutable');
                    END
                    """
                )
                connection.commit()
            with self.assertRaisesRegex(
                CorporateDatabaseValidationError,
                "Entidades corporativas nao autorizadas",
            ):
                validate_corporate_database(database)


if __name__ == "__main__":
    unittest.main()
