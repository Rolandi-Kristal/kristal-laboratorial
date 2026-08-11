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

from checkpoint_sqlite_kristal import SqliteCheckpointError, checkpoint_database


class SqliteCheckpointTests(unittest.TestCase):
    def test_checkpoints_valid_wal_database(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "database.db"
            with closing(sqlite3.connect(database)) as connection:
                connection.execute("PRAGMA journal_mode = WAL")
                connection.execute("CREATE TABLE dados (id INTEGER PRIMARY KEY, valor TEXT)")
                connection.execute("INSERT INTO dados (valor) VALUES ('KRISTAL')")
                connection.commit()
            result = checkpoint_database(database)
            self.assertEqual(result["quick_check"], "ok")
            self.assertEqual(result["wal_bytes"], 0)

    def test_rejects_missing_database(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(FileNotFoundError):
                checkpoint_database(Path(temporary) / "missing.db")

    def test_rejects_empty_database(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "empty.db"
            database.touch()
            with self.assertRaisesRegex(SqliteCheckpointError, "vazio"):
                checkpoint_database(database)

    def test_rejects_corrupted_database(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "corrupted.db"
            database.write_bytes(b"not-a-sqlite-database")
            with self.assertRaises(sqlite3.DatabaseError):
                checkpoint_database(database)


if __name__ == "__main__":
    unittest.main()
