from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
from contextlib import closing
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from pathlib import Path
from typing import Any, Iterable, Mapping

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.database import Database
from app.security import SecurityService


SEALED_PREFIX = "KRISTAL_SYNC_AES_GCM_V1:"
MAX_PDF_BYTES = 15 * 1024 * 1024


class PortalProjectionError(ValueError):
    pass


class PortalProjection:
    def __init__(self, *, database: Database, api_key: str, storage_dir: str) -> None:
        self.database = database
        self.api_key = api_key.strip()
        self.storage_dir = Path(storage_dir).resolve()
        if len(self.api_key) < 32:
            raise PortalProjectionError(
                "KRISTAL_API_KEY deve possuir ao menos 32 caracteres para a projeção corporativa."
            )

    def initialize(self) -> None:
        with closing(self.database.connect()) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS portal_projection_state (
                    entity TEXT NOT NULL,
                    record_id TEXT NOT NULL,
                    access_code_fingerprint TEXT,
                    projected_sha256 TEXT NOT NULL,
                    projected_at TEXT NOT NULL,
                    PRIMARY KEY (entity, record_id)
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS portal_projection_checkpoint (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    last_version INTEGER NOT NULL
                )
                """
            )
            conn.execute(
                "INSERT OR IGNORE INTO portal_projection_checkpoint (id, last_version) VALUES (1, 0)"
            )
            conn.commit()

    def project(self, records: Iterable[Mapping[str, Any]]) -> int:
        normalized = list(records)
        if not normalized:
            return 0
        with closing(self.database.connect()) as conn:
            conn.execute("BEGIN IMMEDIATE")
            try:
                for record in normalized:
                    self._project_record(conn, record)
                conn.commit()
            except (KeyError, TypeError, ValueError, sqlite3.Error, OSError) as error:
                conn.rollback()
                if isinstance(error, PortalProjectionError):
                    raise
                raise PortalProjectionError(
                    f"Falha ao projetar dados corporativos no portal: {error}"
                ) from error
        return len(normalized)

    def reconcile_corporate_database(self, corporate_db_path: str) -> int:
        path = os.path.abspath(corporate_db_path.strip())
        if not os.path.isfile(path):
            return 0
        total = 0
        with closing(self.database.connect()) as portal:
            checkpoint_row = portal.execute(
                "SELECT last_version FROM portal_projection_checkpoint WHERE id=1"
            ).fetchone()
            checkpoint = 0 if checkpoint_row is None else int(checkpoint_row["last_version"])
        with sqlite3.connect(path, timeout=30) as source:
            source.row_factory = sqlite3.Row
            while True:
                rows = source.execute(
                    """
                    SELECT entity, record_id, payload_json, deleted, sha256, version
                    FROM corporate_sync_records
                    WHERE version > ?
                      AND entity IN ('pacientes', 'exames', 'resultados', 'laudos')
                    ORDER BY version ASC LIMIT 500
                    """,
                    (checkpoint,),
                ).fetchall()
                if not rows:
                    break
                records = [
                    {
                        "entity": row["entity"],
                        "record_id": row["record_id"],
                        "payload": json.loads(row["payload_json"]),
                        "deleted": bool(row["deleted"]),
                        "sha256": row["sha256"],
                    }
                    for row in rows
                ]
                total += self.project(records)
                checkpoint = int(rows[-1]["version"])
                with closing(self.database.connect()) as portal:
                    portal.execute(
                        "UPDATE portal_projection_checkpoint SET last_version=? WHERE id=1",
                        (checkpoint,),
                    )
                    portal.commit()
        return total
    def _project_record(self, conn: sqlite3.Connection, record: Mapping[str, Any]) -> None:
        entity = str(record.get("entity", "")).strip()
        record_id = str(record.get("record_id", "")).strip()
        payload = record.get("payload")
        if not record_id or not isinstance(payload, Mapping):
            raise PortalProjectionError("Registro corporativo inválido para projeção.")
        opened = self._open(record_id=record_id, payload=payload)
        deleted = bool(record.get("deleted", False))
        if entity == "pacientes":
            self._patient(conn, record_id, opened, deleted)
        elif entity == "exames":
            self._catalog(conn, record_id, opened, deleted)
        elif entity == "resultados":
            self._result(conn, record_id, opened, deleted)
        elif entity == "laudos":
            self._report(conn, record_id, opened, deleted)
        else:
            return
        digest = str(record.get("sha256", "")).strip() or hashlib.sha256(
            json.dumps(opened, ensure_ascii=False, sort_keys=True).encode("utf-8")
        ).hexdigest()
        conn.execute(
            """
            INSERT INTO portal_projection_state (
                entity, record_id, projected_sha256, projected_at
            ) VALUES (?, ?, ?, ?)
            ON CONFLICT(entity, record_id) DO UPDATE SET
                projected_sha256 = excluded.projected_sha256,
                projected_at = excluded.projected_at
            """,
            (entity, record_id, digest, self.database.now()),
        )

    def _open(self, *, record_id: str, payload: Mapping[str, Any]) -> dict[str, Any]:
        sealed_value = payload.get("_sealed")
        if sealed_value is None:
            opened = dict(payload)
        else:
            sealed = str(sealed_value)
            if not sealed.startswith(SEALED_PREFIX):
                raise PortalProjectionError("Versão do envelope corporativo inválida.")
            try:
                envelope = json.loads(
                    base64.b64decode(sealed[len(SEALED_PREFIX) :], validate=True).decode("utf-8")
                )
                nonce = base64.b64decode(str(envelope["n"]), validate=True)
                ciphertext = base64.b64decode(str(envelope["c"]), validate=True)
                mac = base64.b64decode(str(envelope["m"]), validate=True)
                key = hashlib.sha256(
                    f"KRISTAL-LAB-SYNC-DATA-V1|{self.api_key}".encode("utf-8")
                ).digest()
                clear = AESGCM(key).decrypt(nonce, ciphertext + mac, None)
                decoded = json.loads(clear.decode("utf-8"))
            except (KeyError, TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
                raise PortalProjectionError("Envelope corporativo corrompido ou não autenticado.") from error
            if not isinstance(decoded, dict):
                raise PortalProjectionError("Conteúdo corporativo descriptografado inválido.")
            opened = decoded
        if str(opened.get("id", "")) != record_id:
            raise PortalProjectionError("ID corporativo divergente após descriptografia.")
        return opened

    def _patient(
        self, conn: sqlite3.Connection, record_id: str, row: Mapping[str, Any], deleted: bool
    ) -> None:
        if deleted:
            conn.execute(
                "UPDATE pacientes SET ativo='0', ativo_consulta_recente='0', arquivado='1', atualizado_em=? WHERE id=?",
                (self.database.now(), record_id),
            )
            return
        name = self._required(row, "nome", 250)
        cpf = self._digits(row.get("cpf"))
        if len(cpf) != 11:
            raise PortalProjectionError(f"Paciente {record_id} possui CPF inválido para o portal.")
        now = self.database.now()
        existing = conn.execute(
            "SELECT codigo_acesso_hash FROM pacientes WHERE id=?", (record_id,)
        ).fetchone()
        access_code = str(row.get("codigoAcessoPortal") or "").strip()
        access_hash = existing["codigo_acesso_hash"] if existing is not None else SecurityService.hash_password(
            secrets.token_urlsafe(32)
        )
        if access_code:
            fingerprint = hmac.new(
                self.api_key.encode("utf-8"), access_code.encode("utf-8"), hashlib.sha256
            ).hexdigest()
            state = conn.execute(
                "SELECT access_code_fingerprint FROM portal_projection_state WHERE entity='pacientes' AND record_id=?",
                (record_id,),
            ).fetchone()
            if state is None or state["access_code_fingerprint"] != fingerprint:
                access_hash = SecurityService.hash_password(access_code)
            conn.execute(
                """
                INSERT INTO portal_projection_state (
                    entity, record_id, access_code_fingerprint, projected_sha256, projected_at
                ) VALUES ('pacientes', ?, ?, '', ?)
                ON CONFLICT(entity, record_id) DO UPDATE SET
                    access_code_fingerprint=excluded.access_code_fingerprint
                """,
                (record_id, fingerprint, now),
            )
        active = "0" if str(row.get("status", "")).upper() in {"INATIVO", "ARQUIVADO"} else "1"
        conn.execute(
            """
            INSERT INTO pacientes (
                id, nome, cpf, preccp, identidade_militar, cns, nascimento,
                telefone, email, codigo_acesso_hash, ativo, ativo_consulta_recente,
                arquivado, excluido_fisicamente, criado_em, atualizado_em
            ) VALUES (?, ?, ?, ?, ?, '', ?, ?, ?, ?, ?, ?, ?, '0', ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                nome=excluded.nome, cpf=excluded.cpf, preccp=excluded.preccp,
                identidade_militar=excluded.identidade_militar,
                nascimento=excluded.nascimento, telefone=excluded.telefone,
                email=excluded.email, codigo_acesso_hash=excluded.codigo_acesso_hash,
                ativo=excluded.ativo, ativo_consulta_recente=excluded.ativo_consulta_recente,
                arquivado=excluded.arquivado, atualizado_em=excluded.atualizado_em
            """,
            (
                record_id,
                name,
                cpf,
                self._digits(row.get("preccp")),
                self._digits(row.get("identidadeMilitar") or row.get("matricula")),
                str(row.get("nascimento") or "").strip(),
                self._digits(row.get("telefone") or row.get("celular")),
                str(row.get("email") or "").strip()[:320],
                access_hash,
                active,
                active,
                "0" if active == "1" else "1",
                str(row.get("criadoEm") or now),
                now,
            ),
        )

    def _catalog(
        self, conn: sqlite3.Connection, record_id: str, row: Mapping[str, Any], deleted: bool
    ) -> None:
        now = self.database.now()
        active = "0" if deleted or str(row.get("ativo", "1")).lower() in {"0", "false", "nao", "não"} else "1"
        name = self._required(row, "nome", 300)
        code = str(row.get("codigo") or record_id).strip().upper()[:80]
        conn.execute(
            """
            INSERT INTO catalogo_exames (
                id, mne, codigo_sire, codigo_subgrupo_cbhpm, nome, setor,
                material, metodo, unidade, referencia, valor_cheio,
                valor_indenizar_20, equipamento, ativo, criado_em, atualizado_em
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                mne=excluded.mne, codigo_sire=excluded.codigo_sire,
                codigo_subgrupo_cbhpm=excluded.codigo_subgrupo_cbhpm,
                nome=excluded.nome, setor=excluded.setor, material=excluded.material,
                metodo=excluded.metodo, unidade=excluded.unidade,
                referencia=excluded.referencia, valor_cheio=excluded.valor_cheio,
                valor_indenizar_20=excluded.valor_indenizar_20,
                equipamento=excluded.equipamento, ativo=excluded.ativo,
                atualizado_em=excluded.atualizado_em
            """,
            (
                record_id,
                code,
                str(row.get("codigoSire") or row.get("codigo_sire") or "").strip(),
                str(row.get("codigoSubGrupoCbhpm") or row.get("codigo_subgrupo_cbhpm") or "").strip(),
                name,
                str(row.get("setor") or "").strip(),
                str(row.get("material") or "").strip(),
                str(row.get("metodo") or "").strip(),
                str(row.get("unidade") or "").strip(),
                str(row.get("referencia") or "").strip(),
                self._money(row.get("valorCheio")),
                self._money(row.get("valorIndenizar20")),
                str(row.get("equipamento") or "").strip(),
                active,
                str(row.get("criadoEm") or now),
                now,
            ),
        )

    def _result(
        self, conn: sqlite3.Connection, record_id: str, row: Mapping[str, Any], deleted: bool
    ) -> None:
        if deleted:
            conn.execute(
                "UPDATE exames SET ativo_consulta_recente='0', arquivado='1', atualizado_em=? WHERE id=?",
                (self.database.now(), record_id),
            )
            return
        patient_id = self._required(row, "pacienteId", 200)
        patient = conn.execute("SELECT id FROM pacientes WHERE id=?", (patient_id,)).fetchone()
        if patient is None:
            raise PortalProjectionError(
                f"Resultado {record_id} referencia paciente ainda não projetado: {patient_id}."
            )
        exam_id = str(row.get("exameId") or "").strip()
        catalog = conn.execute("SELECT nome FROM catalogo_exames WHERE id=?", (exam_id,)).fetchone()
        exam_name = str(catalog["nome"] if catalog is not None else exam_id or "Exame laboratorial")
        now = self.database.now()
        status = str(row.get("status") or "PENDENTE").strip().upper()
        conn.execute(
            """
            INSERT INTO exames (
                id, paciente_id, pedido_id, amostra_id, exame_nome, valor,
                unidade, referencia, status_laudo, critico, coletado_em,
                liberado_em, profissional_responsavel, equipamento, origem,
                pdf_path, ativo_consulta_recente, arquivado,
                excluido_fisicamente, criado_em, atualizado_em, observacao
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '', ?, '', '', 'KRISTAL',
                      '', '1', '0', '0', ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                paciente_id=excluded.paciente_id, pedido_id=excluded.pedido_id,
                amostra_id=excluded.amostra_id, exame_nome=excluded.exame_nome,
                valor=excluded.valor, unidade=excluded.unidade,
                referencia=excluded.referencia, status_laudo=excluded.status_laudo,
                critico=excluded.critico, liberado_em=excluded.liberado_em,
                ativo_consulta_recente='1', arquivado='0', atualizado_em=excluded.atualizado_em,
                observacao=excluded.observacao
            """,
            (
                record_id,
                patient_id,
                str(row.get("pedidoId") or "").strip(),
                str(row.get("amostraId") or "").strip(),
                exam_name,
                str(row.get("valor") or "").strip(),
                str(row.get("unidade") or "").strip(),
                str(row.get("referencia") or "").strip(),
                status,
                str(row.get("critico") or "NÃO").strip(),
                str(row.get("liberadoEm") or "").strip(),
                str(row.get("criadoEm") or now),
                now,
                str(row.get("observacao") or "").strip(),
            ),
        )

    def _report(
        self, conn: sqlite3.Connection, record_id: str, row: Mapping[str, Any], deleted: bool
    ) -> None:
        order_id = str(row.get("pedidoId") or "").strip()
        if not order_id:
            raise PortalProjectionError(f"Laudo {record_id} sem pedido vinculado.")
        if deleted:
            conn.execute(
                "UPDATE exames SET pdf_path='', atualizado_em=? WHERE pedido_id=?",
                (self.database.now(), order_id),
            )
            return
        encoded = str(row.get("pdfBase64") or "").strip()
        expected_hash = str(row.get("pdfSha256") or row.get("hash") or "").strip().lower()
        if not encoded:
            return
        try:
            content = base64.b64decode(encoded, validate=True)
        except ValueError as error:
            raise PortalProjectionError(f"Laudo {record_id} contém PDF Base64 inválido.") from error
        if not content.startswith(b"%PDF-") or len(content) > MAX_PDF_BYTES:
            raise PortalProjectionError(f"Laudo {record_id} não contém um PDF válido dentro do limite.")
        digest = hashlib.sha256(content).hexdigest()
        if expected_hash and not hmac.compare_digest(digest, expected_hash):
            raise PortalProjectionError(f"Hash do PDF do laudo {record_id} é divergente.")
        target_dir = self.storage_dir / "laudos_sincronizados"
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / f"{record_id}.pdf"
        temporary = target.with_suffix(".pdf.tmp")
        temporary.write_bytes(content)
        os.replace(temporary, target)
        conn.execute(
            """
            UPDATE exames
            SET pdf_path=?, status_laudo='LIBERADO', liberado_em=?, atualizado_em=?
            WHERE pedido_id=?
            """,
            (
                str(target),
                str(row.get("liberadoEm") or self.database.now()),
                self.database.now(),
                order_id,
            ),
        )

    @staticmethod
    def _required(row: Mapping[str, Any], key: str, limit: int) -> str:
        value = str(row.get(key) or "").strip()
        if not value or len(value) > limit:
            raise PortalProjectionError(f"Campo obrigatório inválido: {key}.")
        return value

    @staticmethod
    def _digits(value: Any) -> str:
        return "".join(character for character in str(value or "") if character.isdigit())

    @staticmethod
    def _money(value: Any) -> str:
        clean = str(value or "0").strip().replace("R$", "").replace(" ", "")
        if "," in clean:
            clean = clean.replace(".", "").replace(",", ".")
        try:
            number = Decimal(clean).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        except InvalidOperation as error:
            raise PortalProjectionError(f"Valor monetário inválido: {value}.") from error
        if number < 0:
            raise PortalProjectionError("Valor monetário não pode ser negativo.")
        return format(number, ".2f").replace(".", ",")
