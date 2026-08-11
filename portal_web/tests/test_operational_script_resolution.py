from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from app.routes import _resolve_operational_script


class OperationalScriptResolutionTests(unittest.TestCase):
    def test_resolves_first_existing_operational_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            script = root / "instalar_backup_automatico_windows.ps1"
            script.write_text("Write-Host OK", encoding="utf-8")

            resolved = _resolve_operational_script(script.name, search_roots=(root,))

            self.assertEqual(resolved, script.resolve())

    def test_uses_next_root_when_first_does_not_contain_script(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            script = Path(second) / "instalar_backup_automatico_windows.ps1"
            script.write_text("Write-Host OK", encoding="utf-8")

            resolved = _resolve_operational_script(
                script.name,
                search_roots=(Path(first), Path(second)),
            )

            self.assertEqual(resolved, script.resolve())

    def test_rejects_empty_name_and_path_traversal(self) -> None:
        with self.assertRaises(ValueError):
            _resolve_operational_script("")
        with self.assertRaises(ValueError):
            _resolve_operational_script("../instalar.ps1")

    def test_rejects_missing_script(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(FileNotFoundError):
                _resolve_operational_script(
                    "instalar_backup_automatico_windows.ps1",
                    search_roots=(Path(temporary),),
                )


if __name__ == "__main__":
    unittest.main()