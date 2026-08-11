from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = PROJECT_ROOT / "scripts" / "instalar_bancos_seed_servidor.ps1"


class SeedDatabaseInstallerTests(unittest.TestCase):
    def _environment(self, root: Path) -> tuple[Path, Path, Path]:
        package = root / "package"
        data_seed = package / "data_seed"
        destination = root / "server-data"
        backup = root / "backup"
        data_seed.mkdir(parents=True)
        destination.mkdir()
        (backup / "data").mkdir(parents=True)
        files = []
        for name in ("kristal_laboratorial.db", "kristal_corporativo.db"):
            content = f"new-{name}".encode()
            source = data_seed / name
            source.write_bytes(content)
            files.append(
                {
                    "caminho": f"data_seed\\{name}",
                    "tamanho": len(content),
                    "sha256": hashlib.sha256(content).hexdigest().upper(),
                }
            )
        (package / "MANIFESTO_SHA256.json").write_text(
            json.dumps({"total_arquivos": len(files), "arquivos": files}),
            encoding="utf-8",
        )
        return package, destination, backup

    def _run(
        self,
        package: Path,
        destination: Path,
        backup: Path,
        *,
        replace: bool = False,
        corporate_only: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        command = [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SCRIPT),
            "-PacoteRoot",
            str(package),
            "-DestinoData",
            str(destination),
            "-BackupRoot",
            str(backup),
        ]
        if replace:
            command.append("-SubstituirExistentes")
        if corporate_only:
            command.append("-SomenteCorporativo")
        return subprocess.run(command, check=False, capture_output=True, text=True)

    def test_installs_seed_when_database_does_not_exist(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            package, destination, backup = self._environment(Path(temporary))
            result = self._run(package, destination, backup)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                (destination / "kristal_laboratorial.db").read_bytes(),
                b"new-kristal_laboratorial.db",
            )

    def test_preserves_existing_database_without_replace_switch(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            package, destination, backup = self._environment(Path(temporary))
            target = destination / "kristal_laboratorial.db"
            target.write_bytes(b"old")
            result = self._run(package, destination, backup)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(target.read_bytes(), b"old")

    def test_replaces_existing_database_only_with_matching_backup(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            package, destination, backup = self._environment(Path(temporary))
            for name in ("kristal_laboratorial.db", "kristal_corporativo.db"):
                old = f"old-{name}".encode()
                (destination / name).write_bytes(old)
                (backup / "data" / name).write_bytes(old)
            result = self._run(package, destination, backup, replace=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                (destination / "kristal_corporativo.db").read_bytes(),
                b"new-kristal_corporativo.db",
            )
            self.assertFalse((destination / "kristal_corporativo.db.incoming").exists())
            self.assertFalse((destination / "kristal_corporativo.db.rollback").exists())

    def test_rejects_tampered_seed_and_missing_backup(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            package, destination, backup = self._environment(Path(temporary))
            (package / "data_seed" / "kristal_laboratorial.db").write_bytes(b"tampered")
            tampered = self._run(package, destination, backup)
            self.assertNotEqual(tampered.returncode, 0)
            self.assertIn("SHA-256 divergente", tampered.stderr)

        with tempfile.TemporaryDirectory() as temporary:
            package, destination, backup = self._environment(Path(temporary))
            (destination / "kristal_laboratorial.db").write_bytes(b"old")
            missing_backup = self._run(package, destination, backup, replace=True)
            self.assertNotEqual(missing_backup.returncode, 0)
            self.assertIn("Backup obrigatorio", missing_backup.stderr)

    def test_installs_only_corporate_database_when_requested(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            package, destination, backup = self._environment(Path(temporary))
            result = self._run(
                package,
                destination,
                backup,
                corporate_only=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((destination / "kristal_corporativo.db").is_file())
            self.assertFalse((destination / "kristal_laboratorial.db").exists())


if __name__ == "__main__":
    unittest.main()
