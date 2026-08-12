from __future__ import annotations

import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_ROOT = PROJECT_ROOT / "scripts"


class ServerDatabaseExportScriptTests(unittest.TestCase):
    def setUp(self) -> None:
        self.generator = (
            SCRIPTS_ROOT / "GERAR_RAR_BANCOS_COMPLETOS_HMR.ps1"
        ).read_text(encoding="utf-8")
        self.installer = (
            SCRIPTS_ROOT / "INSTALAR_BANCOS_COMPLETOS_SERVIDOR.ps1"
        ).read_text(encoding="utf-8")

    def test_generator_requires_both_validated_databases(self) -> None:
        for required in (
            "kristal_laboratorial.db",
            "kristal_corporativo.db",
            "MANIFESTO_INTEGRIDADE_BANCO_PRODUCAO.json",
            "MANIFESTO_ENTIDADES_OPERACIONAIS.json",
            "MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json",
            "quick_check",
            "integrity_check",
            "35385785",
        ):
            self.assertIn(required, self.generator)

    def test_package_and_installer_require_materialized_entities(self) -> None:
        for content in (self.generator, self.installer):
            for required in (
                "MANIFESTO_ENTIDADES_OPERACIONAIS.json",
                "legacy_operational_manifest",
                "orphan_orders",
                "orphan_results_samples",
                "empty_ids",
            ):
                self.assertIn(required, content)
        self.assertIn("validar_entidades_operacionais_kristal.py", self.generator)

    def test_generator_encrypts_data_and_headers_without_embedded_password(self) -> None:
        self.assertIn("-hp", self.generator)
        self.assertIn("Rar.exe", self.generator)
        self.assertIn("win.rar GmbH", self.generator)
        self.assertNotRegex(self.generator, r"-hp[^\s'\"]+")
        self.assertNotIn("SecureStringToBSTR", self.generator)

    def test_generator_rejects_sqlite_transaction_files(self) -> None:
        self.assertIn("'-wal'", self.generator)
        self.assertIn("'-shm'", self.generator)
        self.assertIn("Arquivo transacional pendente", self.generator)

    def test_installer_has_backup_rollback_autostart_and_https_health(self) -> None:
        for required in (
            "pre_bancos_completos_",
            "Get-Sha256",
            "instalar_bancos_seed_servidor.ps1",
            "KRISTAL LABORATORIAL Servidor HMR",
            "Start-ScheduledTask",
            "https",
            "/health",
            "Rollback",
        ):
            self.assertIn(required, self.installer)


if __name__ == "__main__":
    unittest.main()
