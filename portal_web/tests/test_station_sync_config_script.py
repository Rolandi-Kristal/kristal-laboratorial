from pathlib import Path
import unittest


class StationSyncConfigScriptTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = (
            Path(__file__).resolve().parents[2]
            / "scripts"
            / "CONFIGURAR_SINCRONIZACAO_ESTACAO_HMR.ps1"
        ).read_text(encoding="utf-8")

    def test_requires_https_ca_dpapi_and_protected_status(self) -> None:
        for required in (
            "Scheme -ne 'https'",
            "Import-Certificate",
            "DPAPI_LOCAL_MACHINE_V1:",
            "/api/server/sync/status",
            "X-API-Key",
        ):
            self.assertIn(required, self.text)

    def test_never_accepts_api_key_as_command_line_parameter(self) -> None:
        parameter_block = self.text.split(")", 1)[0]
        self.assertNotIn("ApiKey", parameter_block)
        self.assertIn("Read-Host 'Digite a KRISTAL_API_KEY do servidor' -AsSecureString", self.text)

    def test_enables_sync_and_persists_no_plaintext_key(self) -> None:
        self.assertIn("sincronizacaoAtiva = '1'", self.text)
        self.assertIn("apiKeyProtegida = $ProtectedApiKey", self.text)
        self.assertIn("nuvemApiKey = ''", self.text)
        self.assertIn("cloudApiToken = ''", self.text)


if __name__ == "__main__":
    unittest.main()