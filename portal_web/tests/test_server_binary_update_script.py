from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "ATUALIZAR_SERVIDOR_PRODUCAO_HMR.ps1"


class ServerUpdateScriptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = SCRIPT.read_text(encoding="utf-8")

    def test_preserves_all_three_databases_by_hash(self) -> None:
        for name in (
            "KRISTAL_DB_PATH",
            "KRISTAL_OPERATIONAL_DB_PATH",
            "KRISTAL_CORPORATE_DB_PATH",
        ):
            self.assertIn(name, self.text)
        self.assertIn("databaseEvidence", self.text)
        self.assertIn("foi alterado durante a atualizacao", self.text)

    def test_updates_only_binary_and_service_scripts(self) -> None:
        self.assertIn("KRISTAL_SERVIDOR", self.text)
        self.assertIn("scripts_servidor", self.text)
        self.assertNotIn("Remove-Item", self.text)
        self.assertNotIn("/MIR", self.text)

    def test_requires_signature_https_health_and_autostart(self) -> None:
        self.assertIn("Get-AuthenticodeSignature", self.text)
        self.assertIn("41A4507029802AC7A0BADBA496F7BD532E03748A", self.text)
        self.assertIn("instalar_autostart_windows.ps1", self.text)
        self.assertIn("instalar_backup_automatico_windows.ps1", self.text)
        self.assertIn("BackupHorario = '23:00'", self.text)
        self.assertIn("/health", self.text)
        self.assertIn("Scheme -ne 'https'", self.text)


if __name__ == "__main__":
    unittest.main()
