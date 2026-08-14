from __future__ import annotations

import json
import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from types import SimpleNamespace
from pathlib import Path

from fastapi import HTTPException

PORTAL_ROOT = Path(__file__).resolve().parent.parent
PROJECT_ROOT = PORTAL_ROOT.parent
if str(PORTAL_ROOT) not in sys.path:
    sys.path.insert(0, str(PORTAL_ROOT))
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
from app.corporate_sync import CorporateSyncError, CorporateSyncStore
from app.routes import (
    SyncRecordInput,
    _backup_sqlite,
    _normalize_brl_or_400,
    _read_backup_schedule,
    _reject_machine_tombstones,
    _validate_api_key,
    _validate_backup_time,
    _write_backup_schedule,
)
from scripts.preparar_banco_corporativo_kristal import seed


class ApiKeyValidationTests(unittest.TestCase):
    def test_rejects_missing_key_as_unauthenticated(self) -> None:
        with self.assertRaises(HTTPException) as raised:
            _validate_api_key(
                settings=SimpleNamespace(api_key="a" * 32),
                api_key=None,
            )
        self.assertEqual(raised.exception.status_code, 401)

    def test_rejects_wrong_key_as_forbidden(self) -> None:
        with self.assertRaises(HTTPException) as raised:
            _validate_api_key(
                settings=SimpleNamespace(api_key="a" * 32),
                api_key="b" * 32,
            )
        self.assertEqual(raised.exception.status_code, 403)

    def test_rejects_unconfigured_server_key(self) -> None:
        with self.assertRaises(HTTPException) as raised:
            _validate_api_key(
                settings=SimpleNamespace(api_key=""),
                api_key="a" * 32,
            )
        self.assertEqual(raised.exception.status_code, 503)


class CorporateSyncStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db_path = Path(self.temp.name) / "corporate.db"
        self.store = CorporateSyncStore(str(self.db_path))
        self.store.initialize()

    def _record(self, *, operation: str = "OP-1", name: str = "Paciente") -> dict:
        return {
            "operation_id": operation,
            "entity": "pacientes",
            "record_id": "PAC-1",
            "payload": {"id": "PAC-1", "nome": name, "cpf": "52998224725"},
            "deleted": False,
            "client_updated_at": "2026-08-05T12:00:00Z",
        }

    def test_push_pull_and_hash_are_deterministic(self) -> None:
        pushed = self.store.push(client_id="ESTACAO-1", records=[self._record()])
        self.assertEqual(pushed["accepted"], 1)
        self.assertEqual(pushed["server_version"], 1)

        pulled = self.store.pull(client_id="ESTACAO-2", since_version=0, limit=500)
        self.assertEqual(len(pulled["records"]), 1)
        record = pulled["records"][0]
        self.assertEqual(record["payload"]["nome"], "Paciente")
        self.assertEqual(len(record["sha256"]), 64)
        self.assertEqual(pulled["next_version"], 1)

    def test_duplicate_operation_is_idempotent(self) -> None:
        first = self.store.push(client_id="ESTACAO-1", records=[self._record()])
        second = self.store.push(client_id="ESTACAO-1", records=[self._record()])
        self.assertEqual(first["versions"], second["versions"])
        self.assertEqual(self.store.current_version(), 1)

    def test_batch_preserves_order_and_duplicate_operation_idempotency(self) -> None:
        result = self.store.push(
            client_id="ESTACAO-1",
            records=[
                self._record(operation="OP-1", name="Primeiro"),
                self._record(operation="OP-2", name="Segundo"),
                self._record(operation="OP-2", name="Não deve substituir"),
            ],
        )
        self.assertEqual(
            [item["version"] for item in result["versions"]],
            [1, 2, 2],
        )
        current = self.store.pull(
            client_id="LEITOR",
            since_version=0,
            limit=10,
        )
        self.assertEqual(
            current["records"][0]["payload"]["nome"],
            "Segundo",
        )
        self.assertEqual(
            self.store.history(entity="pacientes")["total"],
            2,
        )
    def test_rejects_unauthorized_entity(self) -> None:
        record = self._record()
        record["entity"] = "segredos"
        with self.assertRaises(CorporateSyncError):
            self.store.push(client_id="ESTACAO-1", records=[record])

    def test_rejects_payload_with_divergent_id(self) -> None:
        record = self._record()
        record["payload"]["id"] = "PAC-OUTRO"
        with self.assertRaises(CorporateSyncError):
            self.store.push(client_id="ESTACAO-1", records=[record])


    def test_history_preserves_every_changed_version(self) -> None:
        self.store.push(client_id="ESTACAO-1", records=[self._record()])
        self.store.push(
            client_id="ESTACAO-1",
            records=[self._record(operation="OP-2", name="Paciente Atualizado")],
        )

        status = self.store.status()
        self.assertEqual(status["records"], 1)
        self.assertEqual(status["history_records"], 2)
        history = self.store.history(entity="pacientes", record_id="PAC-1")
        self.assertEqual(history["total"], 2)
        self.assertEqual(
            [item["payload"]["nome"] for item in history["records"]],
            ["Paciente Atualizado", "Paciente"],
        )

    def test_history_is_immutable_at_database_level(self) -> None:
        self.store.push(client_id="ESTACAO-1", records=[self._record()])
        with closing(self.store.connect()) as conn:
            with self.assertRaises(sqlite3.IntegrityError):
                conn.execute(
                    "UPDATE corporate_sync_history SET deleted = 1 WHERE version = 1"
                )
            with self.assertRaises(sqlite3.IntegrityError):
                conn.execute(
                    "DELETE FROM corporate_sync_history WHERE version = 1"
                )

    def test_machine_api_rejects_tombstone_without_superuser_authorization(self) -> None:
        record = SyncRecordInput(
            operation_id="OP-DELETE-1",
            entity="pacientes",
            record_id="PAC-1",
            payload={"id": "PAC-1"},
            deleted=True,
        )

        with self.assertRaises(HTTPException) as raised:
            _reject_machine_tombstones([record])

        self.assertEqual(raised.exception.status_code, 403)
        self.assertIn("não autoriza exclusão", str(raised.exception.detail))

    def test_machine_api_accepts_regular_upsert(self) -> None:
        record = SyncRecordInput(
            operation_id="OP-UPSERT-1",
            entity="pacientes",
            record_id="PAC-1",
            payload={"id": "PAC-1", "nome": "Paciente"},
            deleted=False,
        )

        _reject_machine_tombstones([record])

    def test_machine_api_accepts_empty_batch(self) -> None:
        _reject_machine_tombstones([])


class CorporateSeedTests(unittest.TestCase):
    def test_seed_uses_all_records_and_is_idempotent_across_batches(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            operational = Path(directory) / "operational.db"
            corporate = Path(directory) / "corporate.db"
            with closing(sqlite3.connect(operational)) as connection:
                connection.execute(
                    "CREATE TABLE pacientes (id TEXT PRIMARY KEY, nome TEXT NOT NULL)"
                )
                connection.executemany(
                    "INSERT INTO pacientes VALUES (?, ?)",
                    [
                        (f"PAC-{index:04d}", f"Paciente {index}")
                        for index in range(1001)
                    ],
                )
                connection.commit()

            first = seed(
                operational_db=operational,
                corporate_db=corporate,
                batch_size=500,
            )
            second = seed(
                operational_db=operational,
                corporate_db=corporate,
                batch_size=500,
            )
            store = CorporateSyncStore(str(corporate))
            self.assertEqual(first["pacientes"], 1001)
            self.assertEqual(second["pacientes"], 1001)
            self.assertEqual(store.status()["records"], 1001)
            self.assertEqual(store.current_version(), 1001)

class BackupAndCurrencyTests(unittest.TestCase):
    def test_backup_window_accepts_evening_and_overnight(self) -> None:
        self.assertEqual(_validate_backup_time("23:00"), "23:00")
        self.assertEqual(_validate_backup_time("18:00"), "18:00")
        self.assertEqual(_validate_backup_time("03:59"), "03:59")

    def test_backup_window_rejects_business_hours_and_bad_format(self) -> None:
        for value in ("04:00", "17:59", "24:00", "9:00", "23:60"):
            with self.subTest(value=value), self.assertRaises(HTTPException):
                _validate_backup_time(value)

    def test_brl_normalization_is_exact_and_rounded_half_up(self) -> None:
        self.assertEqual(_normalize_brl_or_400("R$ 1.234,56"), "1234.56")
        self.assertEqual(_normalize_brl_or_400("23,35"), "23.35")
        self.assertEqual(_normalize_brl_or_400("23,355"), "23.36")

    def test_brl_rejects_negative_and_invalid_values(self) -> None:
        for value in ("-1,00", "abc", "", "NaN", "Infinity"):
            with self.subTest(value=value), self.assertRaises(HTTPException):
                _normalize_brl_or_400(value)

    def test_schedule_file_defaults_persists_and_recovers_from_invalid_json(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            schedule = Path(directory) / "backup_schedule.json"

            class SettingsStub:
                backup_schedule_file = str(schedule)

            self.assertEqual(_read_backup_schedule(settings=SettingsStub()), "23:00")
            _write_backup_schedule(settings=SettingsStub(), horario="22:30")
            self.assertEqual(_read_backup_schedule(settings=SettingsStub()), "22:30")
            content = json.loads(schedule.read_text(encoding="utf-8"))
            self.assertEqual(content["janela"], "18:00-03:59")
            schedule.write_text("{invalido", encoding="utf-8")
            self.assertEqual(_read_backup_schedule(settings=SettingsStub()), "23:00")

    def test_sqlite_backup_is_integral(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.db"
            destination = Path(directory) / "backup.db"
            with closing(sqlite3.connect(source)) as conn:
                conn.execute("CREATE TABLE dados (id INTEGER PRIMARY KEY, valor TEXT NOT NULL)")
                conn.executemany(
                    "INSERT INTO dados(valor) VALUES (?)",
                    [("um",), ("dois",), ("três",)],
                )
                conn.commit()
            _backup_sqlite(source=source, destination=destination)
            with closing(sqlite3.connect(destination)) as conn:
                self.assertEqual(conn.execute("PRAGMA integrity_check").fetchone()[0], "ok")
                self.assertEqual(conn.execute("SELECT COUNT(*) FROM dados").fetchone()[0], 3)


if __name__ == "__main__":
    unittest.main()