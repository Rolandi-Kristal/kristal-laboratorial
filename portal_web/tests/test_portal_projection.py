from __future__ import annotations

import base64
import hashlib
import gc
import json
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.config import Settings
from app.database import Database
from app.portal_projection import PortalProjection, PortalProjectionError, SEALED_PREFIX
from app.security import SecurityService


class PortalProjectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.api_key = "K" * 48
        settings = Settings(
            host="127.0.0.1",
            port=8787,
            secret_key="S" * 64,
            admin_login="Kristal",
            admin_password="senha-forte-exclusiva-de-teste",
            db_path=str(root / "portal.db"),
            storage_dir=str(root / "storage"),
            api_key=self.api_key,
            sire_base_url="https://sire.invalid",
            sire_username="",
            sire_password="",
            sire_auto_cdm=False,
            sire_default_plano_interno_id="",
            sire_default_percentual_desconto=20,
            backup_dir=str(root / "backups"),
            corporate_db_path=str(root / "corporate.db"),
            operational_db_path=str(root / "operational.db"),
            backup_schedule_file=str(root / "backup.json"),
            tls_cert_file="",
            tls_key_file="",
            require_tls=False,
        )
        self.database = Database(settings.db_path)
        self.database.initialize(settings)
        self.projection = PortalProjection(
            database=self.database,
            api_key=self.api_key,
            storage_dir=settings.storage_dir,
        )
        self.projection.initialize()

    def tearDown(self) -> None:
        gc.collect()
        self.temp.cleanup()

    def _seal(self, payload: dict[str, object]) -> dict[str, str]:
        key = hashlib.sha256(
            f"KRISTAL-LAB-SYNC-DATA-V1|{self.api_key}".encode("utf-8")
        ).digest()
        nonce = bytes(range(12))
        encrypted = AESGCM(key).encrypt(
            nonce,
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8"),
            None,
        )
        envelope = {
            "n": base64.b64encode(nonce).decode("ascii"),
            "c": base64.b64encode(encrypted[:-16]).decode("ascii"),
            "m": base64.b64encode(encrypted[-16:]).decode("ascii"),
        }
        return {
            "id": str(payload["id"]),
            "_sealed": SEALED_PREFIX
            + base64.b64encode(json.dumps(envelope).encode("utf-8")).decode("ascii"),
        }

    def test_projects_patient_catalog_result_and_pdf(self) -> None:
        patient = {
            "id": "PAC-1",
            "nome": "Paciente Teste",
            "cpf": "52998224725",
            "preccp": "123",
            "matricula": "987",
            "codigoAcessoPortal": "ACESSO-123",
            "status": "ATIVO",
        }
        catalog = {
            "id": "EX-1",
            "codigo": "GLI",
            "nome": "Glicose",
            "codigoSire": "40302040",
            "codigoSubGrupoCbhpm": "001",
            "valorCheio": "23,35",
            "valorIndenizar20": "4,67",
            "ativo": "1",
        }
        result = {
            "id": "RES-1",
            "pacienteId": "PAC-1",
            "pedidoId": "PED-1",
            "amostraId": "AMO-1",
            "exameId": "EX-1",
            "valor": "98.4",
            "unidade": "mg/dL",
            "referencia": "70-99",
            "status": "LIBERADO",
            "critico": "NÃO",
        }
        pdf = b"%PDF-1.4\n%%EOF\n"
        report = {
            "id": "LAU-1",
            "pedidoId": "PED-1",
            "status": "LIBERADO",
            "pdfBase64": base64.b64encode(pdf).decode("ascii"),
            "pdfSha256": hashlib.sha256(pdf).hexdigest(),
        }
        records = [
            {"entity": "pacientes", "record_id": "PAC-1", "payload": self._seal(patient)},
            {"entity": "exames", "record_id": "EX-1", "payload": self._seal(catalog)},
            {"entity": "resultados", "record_id": "RES-1", "payload": self._seal(result)},
            {"entity": "laudos", "record_id": "LAU-1", "payload": self._seal(report)},
        ]
        self.assertEqual(self.projection.project(records), 4)
        with closing(self.database.connect()) as conn:
            patient_row = conn.execute(
                "SELECT codigo_acesso_hash FROM pacientes WHERE id='PAC-1'"
            ).fetchone()
            catalog_row = conn.execute(
                "SELECT codigo_subgrupo_cbhpm, valor_cheio FROM catalogo_exames WHERE id='EX-1'"
            ).fetchone()
            result_row = conn.execute(
                "SELECT exame_nome, valor, pdf_path FROM exames WHERE id='RES-1'"
            ).fetchone()
        self.assertTrue(SecurityService.verify_password("ACESSO-123", patient_row[0]))
        self.assertEqual((catalog_row[0], catalog_row[1]), ("001", "23,35"))
        self.assertEqual((result_row[0], result_row[1]), ("Glicose", "98.4"))
        self.assertEqual(Path(result_row[2]).read_bytes(), pdf)

    def test_rejects_tampered_envelope(self) -> None:
        payload = self._seal({"id": "PAC-1", "nome": "X", "cpf": "52998224725"})
        payload["_sealed"] = payload["_sealed"][:-2] + "AA"
        with self.assertRaises(PortalProjectionError):
            self.projection.project(
                [{"entity": "pacientes", "record_id": "PAC-1", "payload": payload}]
            )

    def test_rejects_result_without_patient(self) -> None:
        result = {
            "id": "RES-1",
            "pacienteId": "PAC-MISSING",
            "exameId": "EX-1",
            "valor": "1",
        }
        with self.assertRaises(PortalProjectionError):
            self.projection.project(
                [{"entity": "resultados", "record_id": "RES-1", "payload": self._seal(result)}]
            )

    def test_rejects_pdf_with_wrong_hash(self) -> None:
        report = {
            "id": "LAU-1",
            "pedidoId": "PED-1",
            "pdfBase64": base64.b64encode(b"%PDF-1.4\n%%EOF").decode("ascii"),
            "pdfSha256": "0" * 64,
        }
        with self.assertRaises(PortalProjectionError):
            self.projection.project(
                [{"entity": "laudos", "record_id": "LAU-1", "payload": self._seal(report)}]
            )


if __name__ == "__main__":
    unittest.main()
