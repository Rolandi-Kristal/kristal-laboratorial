from __future__ import annotations

import csv
import hashlib
import io
import json
import logging
import os
import shutil
import sqlite3
import subprocess
import threading
import urllib.error
import urllib.request
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from pathlib import Path
from typing import Annotated, Any

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from app.config import Settings
from app.corporate_sync import CorporateSyncError, CorporateSyncStore
from app.database import Database
from app.portal_projection import PortalProjection, PortalProjectionError
from app.security import SecurityService

LOGGER = logging.getLogger("kristal.portal")

class SyncRecordInput(BaseModel):
    operation_id: str = Field(min_length=1, max_length=200)
    entity: str = Field(min_length=1, max_length=80)
    record_id: str = Field(min_length=1, max_length=200)
    payload: dict[str, Any]
    deleted: bool = False
    client_updated_at: str | None = None


class SyncPushRequest(BaseModel):
    client_id: str = Field(min_length=1, max_length=200)
    records: list[SyncRecordInput] = Field(max_length=500)


def _reject_machine_tombstones(records: list[SyncRecordInput]) -> None:
    if any(item.deleted for item in records):
        raise HTTPException(
            status_code=403,
            detail=(
                "Tombstone recusado: a chave da estação não autoriza exclusão. "
                "Use arquivamento lógico autenticado pelo SUPER_USUARIO."
            ),
        )


class BackupScheduleInput(BaseModel):
    horario: str = Field(min_length=5, max_length=5)


def create_app(*, settings: Settings, database: Database) -> FastAPI:
    app = FastAPI(title="KRISTAL LABORATORIAL Portal Web", version="1.0.0")
    corporate_sync = CorporateSyncStore(settings.corporate_db_path)
    corporate_sync.initialize()
    portal_projection: PortalProjection | None = None
    app.state.portal_reconciliation = {
        "status": "DESABILITADA",
        "projected": 0,
        "error": "",
    }
    if len(settings.api_key.strip()) >= 32:
        portal_projection = PortalProjection(
            database=database,
            api_key=settings.api_key,
            storage_dir=settings.storage_dir,
        )
        portal_projection.initialize()
        app.state.portal_reconciliation = {
            "status": "PROCESSANDO",
            "projected": 0,
            "error": "",
        }

        def reconcile_portal_history() -> None:
            try:
                projected = portal_projection.reconcile_corporate_database(
                    settings.corporate_db_path
                )
            except (PortalProjectionError, sqlite3.Error, OSError, ValueError) as error:
                app.state.portal_reconciliation = {
                    "status": "ERRO",
                    "projected": 0,
                    "error": str(error)[:1000],
                }
                LOGGER.exception(
                    "Falha na reconciliação histórica do portal KRISTAL."
                )
            else:
                app.state.portal_reconciliation = {
                    "status": "CONCLUIDA",
                    "projected": projected,
                    "error": "",
                }

        threading.Thread(
            target=reconcile_portal_history,
            name="kristal-portal-reconciliation",
            daemon=True,
        ).start()
    elif settings.require_tls:
        raise RuntimeError(
            "KRISTAL_API_KEY deve possuir ao menos 32 caracteres no servidor de produção."
        )
    static_dir = Path(__file__).resolve().parent.parent / "static"
    app.mount("/assets", StaticFiles(directory=static_dir / "assets"), name="assets")

    def admin_auth(authorization: Annotated[str | None, Header()] = None) -> dict:
        return _auth(settings=settings, authorization=authorization, roles={"SUPER_USUARIO", "ADMIN", "ADMINISTRADOR"})

    def paciente_auth(authorization: Annotated[str | None, Header()] = None) -> dict:
        return _auth(settings=settings, authorization=authorization, roles={"PACIENTE"})

    def super_auth(authorization: Annotated[str | None, Header()] = None) -> dict:
        return _auth(settings=settings, authorization=authorization, roles={"SUPER_USUARIO"})

    def require_super(auth: dict) -> None:
        if auth.get("role") != "SUPER_USUARIO":
            raise HTTPException(status_code=403, detail="Apenas SUPER_USUARIO pode modificar dados do portal.")
    def api_auth(x_api_key: Annotated[str | None, Header(alias="X-API-Key")] = None) -> None:
        _validate_api_key(settings=settings, api_key=x_api_key)

    @app.get("/")
    def index() -> FileResponse:
        return FileResponse(static_dir / "index.html")

    @app.get("/admin.html")
    def admin_page() -> FileResponse:
        return FileResponse(static_dir / "admin.html")

    @app.get("/health")
    def health() -> dict[str, Any]:
        return {
            "status": "ok",
            "app": "KRISTAL LABORATORIAL",
            "portal_reconciliation": dict(app.state.portal_reconciliation),
        }

    @app.post("/api/admin/login")
    def admin_login(login: Annotated[str, Form()], senha: Annotated[str, Form()]) -> dict[str, str]:
        with database.connect() as conn:
            row = conn.execute(
                "SELECT id, login, senha_hash, perfil, ativo FROM usuarios_admin WHERE login = ?",
                (login,),
            ).fetchone()
        if row is None or row["ativo"] != "1":
            raise HTTPException(status_code=401, detail="Acesso inválido.")
        if not SecurityService.verify_password(senha, row["senha_hash"]):
            raise HTTPException(status_code=401, detail="Acesso inválido.")
        token = SecurityService.create_token(
            secret_key=settings.secret_key,
            subject=row["id"],
            role=row["perfil"],
            expires_seconds=28800,
            extra={"login": row["login"]},
        )
        database.audit(usuario=login, acao="LOGIN_ADMIN", tabela="usuarios_admin", registro_id=row["id"], detalhes="Login administrativo.")
        return {"token": token, "perfil": row["perfil"]}

    @app.post("/api/paciente/login")
    def paciente_login(cpf: Annotated[str, Form()], codigo: Annotated[str, Form()]) -> dict[str, str]:
        cpf_clean = _digits(cpf)
        with database.connect() as conn:
            row = conn.execute(
                "SELECT id, nome, cpf, codigo_acesso_hash, ativo FROM pacientes WHERE cpf = ?",
                (cpf_clean,),
            ).fetchone()
        if row is None or row["ativo"] != "1":
            raise HTTPException(status_code=401, detail="Paciente não localizado.")
        if not SecurityService.verify_password(codigo, row["codigo_acesso_hash"]):
            raise HTTPException(status_code=401, detail="Código inválido.")
        token = SecurityService.create_token(
            secret_key=settings.secret_key,
            subject=row["id"],
            role="PACIENTE",
            expires_seconds=7200,
            extra={"cpf": row["cpf"], "nome": row["nome"]},
        )
        database.audit(usuario=row["cpf"], acao="LOGIN_PACIENTE", tabela="pacientes", registro_id=row["id"], detalhes="Login do paciente.")
        return {"token": token, "nome": row["nome"]}


    @app.get("/api/admin/usuarios")
    def listar_usuarios_admin(auth: dict = Depends(admin_auth), q: str = "") -> list[dict]:
        del auth
        like = f"%{q.strip()}%"
        with database.connect() as conn:
            rows = conn.execute(
                """
                SELECT id, login, nome, perfil, graduacao, posto, identidade_militar, ativo, criado_em
                FROM usuarios_admin
                WHERE login LIKE ? OR nome LIKE ? OR perfil LIKE ? OR identidade_militar LIKE ?
                ORDER BY nome
                """,
                (like, like, like, like),
            ).fetchall()
        return [dict(row) for row in rows]

    @app.post("/api/admin/usuarios")
    def salvar_usuario_admin(
        login: Annotated[str, Form()],
        nome: Annotated[str, Form()],
        perfil: Annotated[str, Form()],
        auth: dict = Depends(admin_auth),
        id: Annotated[str | None, Form()] = None,
        senha: Annotated[str | None, Form()] = None,
        graduacao: Annotated[str | None, Form()] = None,
        posto: Annotated[str | None, Form()] = None,
        identidade_militar: Annotated[str | None, Form()] = None,
        ativo: Annotated[str, Form()] = "1",
    ) -> dict[str, str]:
        require_super(auth)
        login_clean = login.strip()
        nome_clean = nome.strip()
        perfil_clean = _normalize_admin_profile(perfil)
        graduacao_clean, posto_clean = _validate_military_rank(graduacao or "", posto or "")
        identidade_clean = _digits(identidade_militar or "")
        if not login_clean or not nome_clean:
            raise HTTPException(status_code=400, detail="Login e nome são obrigatórios.")
        usuario_id = id.strip() if id is not None and id.strip() else database.new_id("USR")
        ativo_clean = "1" if ativo.strip() in {"1", "SIM", "ATIVO", "true", "TRUE"} else "0"
        with database.connect() as conn:
            duplicate = conn.execute("SELECT id FROM usuarios_admin WHERE login = ? AND id <> ?", (login_clean, usuario_id)).fetchone()
            if duplicate is not None:
                raise HTTPException(status_code=409, detail="Login já cadastrado para outro usuário.")
            exists = conn.execute("SELECT id FROM usuarios_admin WHERE id = ?", (usuario_id,)).fetchone()
            now = database.now()
            if exists is None:
                if not senha or not senha.strip():
                    raise HTTPException(status_code=400, detail="Senha é obrigatória para novo usuário.")
                conn.execute(
                    """
                    INSERT INTO usuarios_admin (
                        id, login, senha_hash, nome, perfil, graduacao, posto,
                        identidade_militar, ativo, criado_em
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        usuario_id, login_clean, SecurityService.hash_password(senha.strip()),
                        nome_clean, perfil_clean, graduacao_clean, posto_clean,
                        identidade_clean, ativo_clean, now,
                    ),
                )
                action = "CADASTRAR_USUARIO_ADMIN"
            else:
                fields = [
                    "login = ?", "nome = ?", "perfil = ?", "graduacao = ?",
                    "posto = ?", "identidade_militar = ?", "ativo = ?",
                ]
                values: list[str] = [
                    login_clean, nome_clean, perfil_clean, graduacao_clean,
                    posto_clean, identidade_clean, ativo_clean,
                ]
                if senha is not None and senha.strip():
                    fields.append("senha_hash = ?")
                    values.append(SecurityService.hash_password(senha.strip()))
                values.append(usuario_id)
                conn.execute(f"UPDATE usuarios_admin SET {', '.join(fields)} WHERE id = ?", values)
                action = "ATUALIZAR_USUARIO_ADMIN"
            conn.commit()
        database.audit(usuario=auth.get("login", "super"), acao=action, tabela="usuarios_admin", registro_id=usuario_id, detalhes=login_clean)
        return {"id": usuario_id, "status": "usuario_admin_salvo"}
    @app.post("/api/admin/pacientes")
    def cadastrar_paciente(
        nome: Annotated[str, Form()],
        cpf: Annotated[str, Form()],
        codigo_acesso: Annotated[str, Form()],
        auth: dict = Depends(admin_auth),
        preccp: Annotated[str | None, Form()] = None,
        identidade_militar: Annotated[str | None, Form()] = None,
        nascimento: Annotated[str | None, Form()] = None,
        telefone: Annotated[str | None, Form()] = None,
        email: Annotated[str | None, Form()] = None,
    ) -> dict[str, str]:
        require_super(auth)
        nome_clean = nome.strip()
        cpf_clean = _valid_cpf_or_400(cpf)
        preccp_clean = _digits(preccp or "")
        identidade_clean = _digits(identidade_militar or "")
        if not nome_clean or not codigo_acesso.strip():
            raise HTTPException(status_code=400, detail="Nome e código de acesso são obrigatórios.")
        paciente_id = database.new_id("PAC")
        with database.connect() as conn:
            exists = conn.execute("SELECT id FROM pacientes WHERE cpf = ?", (cpf_clean,)).fetchone()
            if exists is not None:
                raise HTTPException(status_code=409, detail="CPF já cadastrado. Use o paciente existente para novos exames.")
            now = database.now()
            conn.execute(
                """
                INSERT INTO pacientes (
                    id, nome, cpf, preccp, identidade_militar, cns, nascimento, telefone, email,
                    codigo_acesso_hash, ativo, ativo_consulta_recente, arquivado,
                    excluido_fisicamente, criado_em, atualizado_em
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    paciente_id, nome_clean, cpf_clean, preccp_clean, identidade_clean, "",
                    nascimento or "", _digits(telefone or ""), email or "",
                    SecurityService.hash_password(codigo_acesso.strip()), "1", "1", "0", "0", now, now,
                ),
            )
            conn.commit()
        database.audit(usuario=auth.get("login", "admin"), acao="CADASTRAR_PACIENTE", tabela="pacientes", registro_id=paciente_id, detalhes=nome_clean)
        return {"id": paciente_id, "status": "paciente_cadastrado"}

    @app.get("/api/admin/pacientes")
    def listar_pacientes(auth: dict = Depends(admin_auth), q: str = "") -> list[dict]:
        del auth
        like = f"%{q.strip()}%"
        with database.connect() as conn:
            rows = conn.execute(
                """
                SELECT id, nome, cpf, preccp, identidade_militar, nascimento, telefone, email, criado_em, atualizado_em
                FROM pacientes
                WHERE arquivado = '0' AND excluido_fisicamente = '0'
                AND (nome LIKE ? OR cpf LIKE ? OR preccp LIKE ? OR identidade_militar LIKE ?)
                ORDER BY nome
                """,
                (like, like, like, like),
            ).fetchall()
        return [dict(row) for row in rows]
    @app.post("/api/admin/exames")
    async def cadastrar_exame(
        paciente_id: Annotated[str, Form()],
        exame_nome: Annotated[str, Form()],
        valor: Annotated[str, Form()],
        auth: dict = Depends(admin_auth),
        unidade: Annotated[str | None, Form()] = None,
        referencia: Annotated[str | None, Form()] = None,
        pedido_id: Annotated[str | None, Form()] = None,
        amostra_id: Annotated[str | None, Form()] = None,
        status_laudo: Annotated[str, Form()] = "LIBERADO",
        critico: Annotated[str, Form()] = "NÃO",
        coletado_em: Annotated[str | None, Form()] = None,
        liberado_em: Annotated[str | None, Form()] = None,
        profissional_responsavel: Annotated[str | None, Form()] = None,
        equipamento: Annotated[str | None, Form()] = None,
        observacao: Annotated[str | None, Form()] = None,
        pdf: UploadFile | None = File(default=None),
    ) -> dict[str, str]:
        require_super(auth)
        exame_nome_clean = exame_nome.strip()
        if not exame_nome_clean:
            raise HTTPException(status_code=400, detail="Nome do exame é obrigatório.")
        valor_brl = _normalize_brl_or_400(valor)
        exame_id = database.new_id("EXA")
        pdf_path = ""
        if pdf is not None and pdf.filename:
            pdf_path = await _save_pdf(settings=settings, exame_id=exame_id, upload=pdf)
        with database.connect() as conn:
            paciente = conn.execute(
                "SELECT id, nome, cpf, preccp, identidade_militar FROM pacientes WHERE id = ? AND excluido_fisicamente = '0'",
                (paciente_id,),
            ).fetchone()
            if paciente is None:
                raise HTTPException(status_code=404, detail="Paciente não localizado.")
            now = database.now()
            liberado = liberado_em or now
            conn.execute(
                """
                INSERT INTO exames (
                    id, paciente_id, pedido_id, amostra_id, exame_nome, valor, unidade,
                    referencia, status_laudo, critico, coletado_em, liberado_em,
                    profissional_responsavel, equipamento, origem, pdf_path,
                    ativo_consulta_recente, arquivado, excluido_fisicamente,
                    criado_em, atualizado_em, observacao
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    exame_id, paciente_id, pedido_id or "", amostra_id or "", exame_nome_clean,
                    valor_brl, unidade or "", referencia or "", status_laudo, critico,
                    coletado_em or "", liberado, profissional_responsavel or "", equipamento or "",
                    "KRISTAL", pdf_path, "1", "0", "0", now, now, observacao or "",
                ),
            )
            history_id = f"HIST-{exame_id}"
            conn.execute(
                """
                INSERT INTO historico_exames_pacientes (
                    id, paciente_id, paciente_nome, cpf, preccp, identidade_militar, cns,
                    pedido_id, amostra_id, exame_nome, valor, unidade, referencia,
                    status_laudo, critico, coletado_em, liberado_em, profissional_responsavel,
                    equipamento, origem, pdf_path, ativo_consulta_recente, arquivado,
                    excluido_fisicamente, criado_em, atualizado_em, observacao
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    history_id, paciente["id"], paciente["nome"], paciente["cpf"], paciente["preccp"],
                    paciente["identidade_militar"], "", pedido_id or "", amostra_id or "",
                    exame_nome_clean, valor_brl, unidade or "", referencia or "", status_laudo,
                    critico, coletado_em or "", liberado, profissional_responsavel or "",
                    equipamento or "", "KRISTAL", pdf_path, "0", "1", "0", now, now, observacao or "",
                ),
            )
            conn.commit()
        database.audit(usuario=auth.get("login", "admin"), acao="CADASTRAR_EXAME", tabela="exames", registro_id=exame_id, detalhes=exame_nome_clean)
        cdm_status = _emitir_cdm_automatico_exame(
            settings=settings,
            database=database,
            paciente=dict(paciente),
            pedido_id=pedido_id or "",
            exame_nome=exame_nome_clean,
            valor_brl=valor_brl,
            unidade=unidade or "",
            referencia=referencia or "",
        )
        return {"id": exame_id, "historico_id": f"HIST-{exame_id}", "cdm_automatico": cdm_status}
    @app.get("/api/paciente/exames")
    def paciente_exames(auth: dict = Depends(paciente_auth), historico: bool = True) -> list[dict]:
        table = "historico_exames_pacientes" if historico else "exames"
        with database.connect() as conn:
            rows = conn.execute(
                f"""
                SELECT id, exame_nome, valor, unidade, referencia, status_laudo, critico,
                       coletado_em, liberado_em, equipamento, pdf_path, observacao
                FROM {table}
                WHERE paciente_id = ?
                ORDER BY liberado_em DESC
                """,
                (auth["sub"],),
            ).fetchall()
        return [dict(row) for row in rows]

    @app.get("/api/admin/exames")
    def admin_exames(auth: dict = Depends(admin_auth), q: str = "", historico: bool = True) -> list[dict]:
        del auth
        like = f"%{q.strip()}%"
        if historico:
            sql = """
                SELECT id, paciente_nome, cpf, preccp, exame_nome, valor, unidade, referencia,
                       status_laudo, critico, liberado_em, pdf_path
                FROM historico_exames_pacientes
                WHERE paciente_nome LIKE ? OR cpf LIKE ? OR preccp LIKE ? OR exame_nome LIKE ?
                ORDER BY liberado_em DESC
            """
            params = (like, like, like, like)
        else:
            sql = """
                SELECT e.id, p.nome AS paciente_nome, p.cpf, p.preccp, e.exame_nome, e.valor,
                       e.unidade, e.referencia, e.status_laudo, e.critico, e.liberado_em, e.pdf_path
                FROM exames e JOIN pacientes p ON p.id = e.paciente_id
                WHERE e.arquivado = '0'
                AND (p.nome LIKE ? OR p.cpf LIKE ? OR p.preccp LIKE ? OR e.exame_nome LIKE ?)
                ORDER BY e.liberado_em DESC
            """
            params = (like, like, like, like)
        with database.connect() as conn:
            rows = conn.execute(sql, params).fetchall()
        return [dict(row) for row in rows]

    @app.get("/api/laudos/{exame_id}/download", response_model=None)
    def download_laudo(exame_id: str, authorization: Annotated[str | None, Header()] = None):
        auth = _auth_any(settings=settings, authorization=authorization)
        if auth["role"] == "PACIENTE":
            _validate_patient_owns_exam(database=database, patient_id=auth["sub"], exame_id=exame_id)
        pdf_path = _find_pdf_path(database=database, exame_id=exame_id)
        if pdf_path:
            return FileResponse(pdf_path, media_type="application/pdf", filename=os.path.basename(pdf_path))
        row = _find_exam_row(database=database, exame_id=exame_id)
        if row is None:
            raise HTTPException(status_code=404, detail="Laudo não localizado.")
        return Response(
            content=_minimal_pdf_bytes(_laudo_text(dict(row))),
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="laudo_{exame_id}.pdf"'},
        )

    @app.get("/api/laudos/{exame_id}/print", response_model=None)
    def print_laudo(exame_id: str, authorization: Annotated[str | None, Header()] = None):
        response = download_laudo(exame_id, authorization)
        response.headers["Content-Disposition"] = "inline"
        return response

    @app.post("/api/admin/exames/{exame_id}/arquivar")
    def arquivar_exame(
        exame_id: str,
        auth: dict = Depends(admin_auth),
        motivo: Annotated[str, Form()] = "Arquivamento lógico permanente.",
    ) -> dict[str, str]:
        require_super(auth)
        with database.connect() as conn:
            row = conn.execute("SELECT id FROM exames WHERE id = ?", (exame_id,)).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Exame não localizado.")
            conn.execute(
                "UPDATE exames SET ativo_consulta_recente = '0', arquivado = '1', atualizado_em = ? WHERE id = ?",
                (database.now(), exame_id),
            )
            conn.commit()
        database.audit(usuario=auth.get("login", "admin"), acao="ARQUIVAR_SEM_EXCLUIR", tabela="exames", registro_id=exame_id, detalhes=motivo)
        return {"status": "arquivado_sem_excluir"}


    @app.put("/api/admin/pacientes/{paciente_id}")
    def atualizar_paciente(
        paciente_id: str,
        nome: Annotated[str, Form()],
        cpf: Annotated[str, Form()],
        auth: dict = Depends(admin_auth),
        codigo_acesso: Annotated[str | None, Form()] = None,
        preccp: Annotated[str | None, Form()] = None,
        identidade_militar: Annotated[str | None, Form()] = None,
        nascimento: Annotated[str | None, Form()] = None,
        telefone: Annotated[str | None, Form()] = None,
        email: Annotated[str | None, Form()] = None,
    ) -> dict[str, str]:
        require_super(auth)
        cpf_clean = _valid_cpf_or_400(cpf)
        nome_clean = nome.strip()
        preccp_clean = _digits(preccp or "")
        identidade_clean = _digits(identidade_militar or "")
        if not paciente_id.strip() or not nome_clean or not cpf_clean:
            raise HTTPException(status_code=400, detail="ID, nome e CPF são obrigatórios.")
        with database.connect() as conn:
            row = conn.execute(
                "SELECT id FROM pacientes WHERE id = ? AND excluido_fisicamente = '0'",
                (paciente_id,),
            ).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Paciente não localizado.")
            duplicate = conn.execute(
                "SELECT id FROM pacientes WHERE cpf = ? AND id <> ?",
                (cpf_clean, paciente_id),
            ).fetchone()
            if duplicate is not None:
                raise HTTPException(status_code=409, detail="CPF já pertence a outro paciente.")
            fields = [
                "nome = ?", "cpf = ?", "preccp = ?", "identidade_militar = ?", "nascimento = ?",
                "telefone = ?", "email = ?", "atualizado_em = ?",
            ]
            values: list[str] = [
                nome_clean, cpf_clean, preccp_clean, identidade_clean, nascimento or "",
                _digits(telefone or ""), email or "", database.now(),
            ]
            if codigo_acesso is not None and codigo_acesso.strip():
                fields.append("codigo_acesso_hash = ?")
                values.append(SecurityService.hash_password(codigo_acesso.strip()))
            values.append(paciente_id)
            conn.execute(f"UPDATE pacientes SET {', '.join(fields)} WHERE id = ?", values)
            conn.commit()
        database.audit(
            usuario=auth.get("login", "admin"),
            acao="ATUALIZAR_PACIENTE",
            tabela="pacientes",
            registro_id=paciente_id,
            detalhes=nome_clean,
        )
        return {"id": paciente_id, "status": "paciente_atualizado"}

    @app.delete("/api/admin/pacientes/{paciente_id}")
    def excluir_paciente(paciente_id: str, auth: dict = Depends(admin_auth)) -> dict[str, str]:
        require_super(auth)
        if not paciente_id.strip():
            raise HTTPException(status_code=400, detail="ID do paciente é obrigatório.")
        with database.connect() as conn:
            row = conn.execute(
                "SELECT id, nome FROM pacientes WHERE id = ? AND excluido_fisicamente = '0'",
                (paciente_id,),
            ).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Paciente não localizado.")
            now = database.now()
            conn.execute(
                "UPDATE pacientes SET ativo = '0', ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '0', atualizado_em = ? WHERE id = ?",
                (now, paciente_id),
            )
            conn.execute(
                "UPDATE exames SET ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '0', atualizado_em = ? WHERE paciente_id = ?",
                (now, paciente_id),
            )
            conn.execute(
                "UPDATE historico_exames_pacientes SET ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '0', atualizado_em = ? WHERE paciente_id = ?",
                (now, paciente_id),
            )
            conn.commit()
        database.audit(
            usuario=auth.get("login", "admin"),
            acao="ARQUIVAR_PACIENTE",
            tabela="pacientes",
            registro_id=paciente_id,
            detalhes="Arquivamento lógico do paciente e dos exames vinculados.",
        )
        return {"id": paciente_id, "status": "paciente_arquivado"}

    @app.get("/api/admin/catalogo-exames")
    def listar_catalogo_exames(auth: dict = Depends(admin_auth), q: str = "") -> list[dict]:
        del auth
        like = f"%{q.strip()}%"
        with database.connect() as conn:
            rows = conn.execute(
                """
                SELECT id, mne, codigo_sire, codigo_subgrupo_cbhpm, nome, setor, material, metodo, unidade,
                       referencia, valor_cheio, valor_indenizar_20, equipamento, ativo,
                       criado_em, atualizado_em
                FROM catalogo_exames
                WHERE mne LIKE ? OR codigo_sire LIKE ? OR nome LIKE ? OR setor LIKE ? OR material LIKE ?
                ORDER BY nome
                """,
                (like, like, like, like, like),
            ).fetchall()
        return [dict(row) for row in rows]

    @app.post("/api/admin/catalogo-exames")
    def salvar_catalogo_exame(
        mne: Annotated[str, Form()],
        nome: Annotated[str, Form()],
        auth: dict = Depends(admin_auth),
        id: Annotated[str | None, Form()] = None,
        codigo_sire: Annotated[str | None, Form()] = None,
        codigo_subgrupo_cbhpm: Annotated[str | None, Form()] = None,
        setor: Annotated[str | None, Form()] = None,
        material: Annotated[str | None, Form()] = None,
        metodo: Annotated[str | None, Form()] = None,
        unidade: Annotated[str | None, Form()] = None,
        referencia: Annotated[str | None, Form()] = None,
        valor_cheio: Annotated[str | None, Form()] = None,
        valor_indenizar_20: Annotated[str | None, Form()] = None,
        equipamento: Annotated[str | None, Form()] = None,
        ativo: Annotated[str, Form()] = "1",
    ) -> dict[str, str]:
        require_super(auth)
        mne_clean = mne.strip().upper()
        nome_clean = nome.strip()
        if not mne_clean or not nome_clean:
            raise HTTPException(status_code=400, detail="MNE e nome do exame são obrigatórios.")
        catalogo_id = id.strip() if id is not None and id.strip() else database.new_id("CAT")
        ativo_clean = "1" if ativo.strip() in {"1", "SIM", "ATIVO", "true", "TRUE"} else "0"
        now = database.now()
        with database.connect() as conn:
            exists = conn.execute("SELECT id FROM catalogo_exames WHERE id = ?", (catalogo_id,)).fetchone()
            if exists is None:
                conn.execute(
                    """
                    INSERT INTO catalogo_exames (
                        id, mne, codigo_sire, codigo_subgrupo_cbhpm, nome, setor, material, metodo, unidade,
                        referencia, valor_cheio, valor_indenizar_20, equipamento, ativo,
                        criado_em, atualizado_em
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        catalogo_id, mne_clean, codigo_sire or "", codigo_subgrupo_cbhpm or "", nome_clean, setor or "",
                        material or "", metodo or "", unidade or "", referencia or "",
                        _normalize_brl_or_400(valor_cheio or "0"), _normalize_brl_or_400(valor_indenizar_20 or "0"), equipamento or "",
                        ativo_clean, now, now,
                    ),
                )
                action = "CADASTRAR_CATALOGO_EXAME"
            else:
                conn.execute(
                    """
                    UPDATE catalogo_exames
                    SET mne = ?, codigo_sire = ?, codigo_subgrupo_cbhpm = ?, nome = ?, setor = ?, material = ?, metodo = ?,
                        unidade = ?, referencia = ?, valor_cheio = ?, valor_indenizar_20 = ?,
                        equipamento = ?, ativo = ?, atualizado_em = ?
                    WHERE id = ?
                    """,
                    (
                        mne_clean, codigo_sire or "", codigo_subgrupo_cbhpm or "", nome_clean, setor or "", material or "",
                        metodo or "", unidade or "", referencia or "", _normalize_brl_or_400(valor_cheio or "0"),
                        _normalize_brl_or_400(valor_indenizar_20 or "0"), equipamento or "", ativo_clean, now, catalogo_id,
                    ),
                )
                action = "ATUALIZAR_CATALOGO_EXAME"
            conn.commit()
        database.audit(
            usuario=auth.get("login", "admin"),
            acao=action,
            tabela="catalogo_exames",
            registro_id=catalogo_id,
            detalhes=f"{mne_clean} - {nome_clean}",
        )
        return {"id": catalogo_id, "status": "catalogo_exame_salvo"}

    @app.delete("/api/admin/catalogo-exames/{catalogo_id}")
    def excluir_catalogo_exame(catalogo_id: str, auth: dict = Depends(admin_auth)) -> dict[str, str]:
        require_super(auth)
        if not catalogo_id.strip():
            raise HTTPException(status_code=400, detail="ID do catálogo é obrigatório.")
        with database.connect() as conn:
            row = conn.execute("SELECT id, nome FROM catalogo_exames WHERE id = ?", (catalogo_id,)).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Exame do catálogo não localizado.")
            conn.execute("UPDATE catalogo_exames SET ativo = '0', atualizado_em = ? WHERE id = ?", (database.now(), catalogo_id))
            conn.commit()
        database.audit(
            usuario=auth.get("login", "admin"),
            acao="INATIVAR_CATALOGO_EXAME",
            tabela="catalogo_exames",
            registro_id=catalogo_id,
            detalhes="Inativação lógica do catálogo de exames.",
        )
        return {"id": catalogo_id, "status": "catalogo_exame_inativado"}

    @app.post("/api/admin/dados/excluir-todos")
    def excluir_todos_dados(
        confirmacao: Annotated[str, Form()],
        auth: dict = Depends(super_auth),
    ) -> dict[str, str]:
        if confirmacao.strip() != "EXCLUIR TODOS OS DADOS":
            raise HTTPException(status_code=400, detail="Confirmação inválida.")
        now = database.now()
        with database.connect() as conn:
            conn.execute("UPDATE exames SET ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '0', atualizado_em = ?", (now,))
            conn.execute("UPDATE historico_exames_pacientes SET ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '0', atualizado_em = ?", (now,))
            conn.execute("UPDATE pacientes SET ativo = '0', ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '0', atualizado_em = ?", (now,))
            conn.execute("UPDATE catalogo_exames SET ativo = '0', atualizado_em = ?", (now,))
            conn.commit()
        database.audit(
            usuario=auth.get("login", "super"),
            acao="ARQUIVAR_TODOS_DADOS_CADASTRADOS",
            tabela="sistema",
            registro_id="TODOS",
            detalhes="Superusuário arquivou logicamente pacientes, exames, histórico e catálogo de exames.",
        )
        return {"status": "dados_cadastrados_arquivados"}


    @app.post("/api/admin/exames/importar")
    async def importar_exames_admin(
        arquivo: UploadFile = File(...),
        auth: dict = Depends(admin_auth),
    ) -> dict[str, object]:
        require_super(auth)
        content = await arquivo.read()
        if not content:
            raise HTTPException(status_code=400, detail="Arquivo de importação vazio.")
        suffix = Path(arquivo.filename or "").suffix.lower()
        try:
            text = content.decode("utf-8-sig")
        except UnicodeDecodeError as error:
            raise HTTPException(status_code=400, detail="Arquivo deve estar em texto UTF-8 para importação tabular.") from error
        rows: list[dict[str, object]]
        if suffix == ".json":
            try:
                payload = json.loads(text)
            except json.JSONDecodeError as error:
                raise HTTPException(status_code=400, detail=f"JSON inválido: {error.msg}") from error
            if not isinstance(payload, list):
                raise HTTPException(status_code=400, detail="JSON deve conter uma lista de exames.")
            rows = [item for item in payload if isinstance(item, dict)]
        else:
            sample = text[:2048]
            delimiter = ";" if sample.count(";") >= sample.count(",") else ","
            rows = list(csv.DictReader(io.StringIO(text), delimiter=delimiter))
        if not rows:
            raise HTTPException(status_code=400, detail="Nenhum exame encontrado no arquivo.")
        imported: list[str] = []
        errors: list[str] = []
        with database.connect() as conn:
            now = database.now()
            for index, row in enumerate(rows, start=1):
                paciente_id = str(row.get("paciente_id") or "").strip()
                cpf_value = str(row.get("cpf") or "").strip()
                if not paciente_id and cpf_value:
                    cpf_clean = _valid_cpf_or_400(cpf_value)
                    paciente_row = conn.execute(
                        "SELECT id, nome, cpf, preccp, identidade_militar FROM pacientes WHERE cpf = ? AND excluido_fisicamente = '0'",
                        (cpf_clean,),
                    ).fetchone()
                else:
                    paciente_row = conn.execute(
                        "SELECT id, nome, cpf, preccp, identidade_militar FROM pacientes WHERE id = ? AND excluido_fisicamente = '0'",
                        (paciente_id,),
                    ).fetchone()
                exame_nome = str(row.get("exame_nome") or row.get("exame") or "").strip()
                valor_raw = str(row.get("valor") or "").strip()
                if paciente_row is None or not exame_nome or not valor_raw:
                    errors.append(f"Linha {index}: paciente, exame ou valor ausente/inválido.")
                    continue
                valor_brl = _normalize_brl_or_400(valor_raw)
                exame_id = database.new_id("EXA")
                liberado = str(row.get("liberado_em") or now)
                pedido_id = str(row.get("pedido_id") or "")
                amostra_id = str(row.get("amostra_id") or "")
                unidade = str(row.get("unidade") or "")
                referencia = str(row.get("referencia") or "")
                critico = "SIM" if str(row.get("critico") or "").upper() == "SIM" else "NÃO"
                conn.execute(
                    """
                    INSERT INTO exames (
                        id, paciente_id, pedido_id, amostra_id, exame_nome, valor, unidade,
                        referencia, status_laudo, critico, coletado_em, liberado_em,
                        profissional_responsavel, equipamento, origem, pdf_path,
                        ativo_consulta_recente, arquivado, excluido_fisicamente,
                        criado_em, atualizado_em, observacao
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        exame_id, paciente_row["id"], pedido_id, amostra_id, exame_nome, valor_brl,
                        unidade, referencia, "LIBERADO", critico, str(row.get("coletado_em") or ""),
                        liberado, str(row.get("profissional_responsavel") or ""),
                        str(row.get("equipamento") or ""), "KRISTAL", "", "1", "0", "0",
                        now, now, str(row.get("observacao") or ""),
                    ),
                )
                history_id = f"HIST-{exame_id}"
                conn.execute(
                    """
                    INSERT INTO historico_exames_pacientes (
                        id, paciente_id, paciente_nome, cpf, preccp, identidade_militar, cns,
                        pedido_id, amostra_id, exame_nome, valor, unidade, referencia,
                        status_laudo, critico, coletado_em, liberado_em, profissional_responsavel,
                        equipamento, origem, pdf_path, ativo_consulta_recente, arquivado,
                        excluido_fisicamente, criado_em, atualizado_em, observacao
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        history_id, paciente_row["id"], paciente_row["nome"], paciente_row["cpf"],
                        paciente_row["preccp"], paciente_row["identidade_militar"], "", pedido_id,
                        amostra_id, exame_nome, valor_brl, unidade, referencia, "LIBERADO", critico,
                        str(row.get("coletado_em") or ""), liberado,
                        str(row.get("profissional_responsavel") or ""), str(row.get("equipamento") or ""),
                        "KRISTAL", "", "0", "1", "0", now, now, str(row.get("observacao") or ""),
                    ),
                )
                imported.append(exame_id)
            conn.commit()
        database.audit(usuario=auth.get("login", "admin"), acao="IMPORTAR_EXAMES_PORTAL", tabela="exames", registro_id=str(len(imported)), detalhes=f"Arquivo={arquivo.filename or ''}; Erros={len(errors)}")
        return {"importados": imported, "total_importados": len(imported), "erros": errors}

    @app.get("/api/admin/dados-legados/fontes")
    def listar_fontes_dados_legados(auth: dict = Depends(admin_auth)) -> dict[str, list[dict]]:
        with database.connect() as conn:
            rows = conn.execute(
                """
                SELECT stored_name, sha256, size_bytes, imported_at
                FROM legacy_sources
                ORDER BY imported_at DESC, stored_name ASC
                """
            ).fetchall()
        return {
            "fontes": [
                {
                    "arquivo": row["stored_name"],
                    "sha256": row["sha256"],
                    "tamanho_bytes": int(row["size_bytes"]),
                    "importado_em": row["imported_at"],
                }
                for row in rows
            ]
        }

    @app.get("/api/admin/dados-legados/arquivos")
    def listar_arquivos_dados_legados(auth: dict = Depends(admin_auth)) -> dict[str, list[dict]]:
        with database.connect() as conn:
            rows = conn.execute(
                """
                SELECT original_extension, stored_name, sha256, size_bytes, category, imported_at
                FROM legacy_files
                ORDER BY imported_at DESC, stored_name ASC
                """
            ).fetchall()
        return {
            "arquivos": [
                {
                    "arquivo": row["stored_name"],
                    "extensao": row["original_extension"],
                    "sha256": row["sha256"],
                    "tamanho_bytes": int(row["size_bytes"]),
                    "categoria": row["category"],
                    "importado_em": row["imported_at"],
                }
                for row in rows
            ]
        }
    @app.get("/api/admin/dados-legados/tabelas")
    def listar_tabelas_dados_legados(auth: dict = Depends(admin_auth)) -> dict[str, list[dict]]:
        with database.connect() as conn:
            rows = conn.execute(
                """
                SELECT s.logical_database, s.table_name, s.columns_json, COUNT(r.id) AS total_linhas
                FROM legacy_table_schemas s
                LEFT JOIN legacy_rows r
                  ON r.source_sha256 = s.source_sha256
                 AND r.logical_database = s.logical_database
                 AND r.table_name = s.table_name
                GROUP BY s.source_sha256, s.logical_database, s.table_name, s.columns_json
                ORDER BY s.logical_database ASC, s.table_name ASC
                """
            ).fetchall()
        tabelas: list[dict] = []
        for row in rows:
            try:
                colunas = json.loads(row["columns_json"])
            except json.JSONDecodeError as error:
                raise HTTPException(status_code=500, detail="Metadados de tabela inválidos: " + str(row["table_name"])) from error
            tabelas.append({
                "database": row["logical_database"],
                "tabela": row["table_name"],
                "colunas": colunas,
                "total_linhas": int(row["total_linhas"]),
            })
        return {"tabelas": tabelas}

    @app.get("/api/admin/dados-legados/linhas")
    def consultar_linhas_dados_legados(
        auth: dict = Depends(admin_auth),
        database_logica: Annotated[str | None, Query(alias="database")] = None,
        tabela: str | None = None,
        q: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> dict[str, object]:
        if limit < 1 or limit > 500:
            raise HTTPException(status_code=400, detail="limit deve ficar entre 1 e 500.")
        if offset < 0:
            raise HTTPException(status_code=400, detail="offset não pode ser negativo.")
        filters: list[str] = []
        params: list[object] = []
        if database_logica and database_logica.strip():
            filters.append("logical_database = ?")
            params.append(database_logica.strip())
        if tabela and tabela.strip():
            filters.append("table_name = ?")
            params.append(tabela.strip())
        if q and q.strip():
            filters.append("row_json LIKE ?")
            params.append(f"%{q.strip()}%")
        where_sql = " WHERE " + " AND ".join(filters) if filters else ""
        with database.connect() as conn:
            total = conn.execute(f"SELECT COUNT(*) AS total FROM legacy_rows{where_sql}", params).fetchone()["total"]
            rows = conn.execute(
                f"""
                SELECT logical_database, table_name, row_index, row_json, row_sha256, imported_at
                FROM legacy_rows
                {where_sql}
                ORDER BY logical_database ASC, table_name ASC, row_index ASC
                LIMIT ? OFFSET ?
                """,
                [*params, limit, offset],
            ).fetchall()
        registros: list[dict] = []
        for row in rows:
            try:
                dados = json.loads(row["row_json"])
            except json.JSONDecodeError as error:
                raise HTTPException(status_code=500, detail="Registro importado inválido: " + str(row["row_sha256"])) from error
            registros.append({
                "database": row["logical_database"],
                "tabela": row["table_name"],
                "indice": int(row["row_index"]),
                "dados": dados,
                "sha256": row["row_sha256"],
                "importado_em": row["imported_at"],
            })
        return {"total": int(total), "limit": limit, "offset": offset, "linhas": registros}

    @app.post("/api/server/sync/push")
    def corporate_sync_push(
        request: SyncPushRequest,
        _: None = Depends(api_auth),
    ) -> dict[str, Any]:
        _reject_machine_tombstones(request.records)
        try:
            records = [
                {
                    "operation_id": item.operation_id,
                    "entity": item.entity,
                    "record_id": item.record_id,
                    "payload": item.payload,
                    "deleted": item.deleted,
                    "client_updated_at": item.client_updated_at,
                }
                for item in request.records
            ]
            result = corporate_sync.push(client_id=request.client_id, records=records)
            if portal_projection is None:
                raise PortalProjectionError(
                    "Projeção do portal indisponível: KRISTAL_API_KEY inválida."
                )
            result["portal_projected"] = portal_projection.project(records)
            return result
        except (CorporateSyncError, PortalProjectionError) as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

    @app.get("/api/server/sync/pull")
    def corporate_sync_pull(
        client_id: str = Query(min_length=1, max_length=200),
        since_version: int = Query(default=0, ge=0),
        limit: int = Query(default=500, ge=1, le=1000),
        _: None = Depends(api_auth),
    ) -> dict[str, Any]:
        try:
            return corporate_sync.pull(
                client_id=client_id,
                since_version=since_version,
                limit=limit,
            )
        except (CorporateSyncError, PortalProjectionError) as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

    @app.get("/api/server/sync/status")
    def corporate_sync_status(_: None = Depends(api_auth)) -> dict[str, Any]:
        return corporate_sync.status()

    @app.get("/api/server/sync/history")
    def corporate_sync_history(
        entity: str | None = Query(default=None),
        record_id: str | None = Query(default=None, max_length=200),
        limit: int = Query(default=100, ge=1, le=1000),
        offset: int = Query(default=0, ge=0),
        auth: dict = Depends(admin_auth),
        _: None = Depends(api_auth),
    ) -> dict[str, Any]:
        try:
            result = corporate_sync.history(
                entity=entity,
                record_id=record_id,
                limit=limit,
                offset=offset,
            )
            database.audit(
                usuario=auth.get("login", "admin"),
                acao="CONSULTAR_HISTORICO_SINCRONIZACAO",
                tabela="corporate_sync_history",
                registro_id=record_id or entity or "ALL",
                detalhes=json.dumps(
                    {"total": result["total"], "limit": limit, "offset": offset},
                    ensure_ascii=False,
                    sort_keys=True,
                ),
            )
            return result
        except (CorporateSyncError, PortalProjectionError) as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

    @app.get("/api/server/backup/config")
    def consultar_horario_backup(
        _: dict = Depends(admin_auth),
    ) -> dict[str, str]:
        return {
            "horario": _read_backup_schedule(settings=settings),
            "janela": "18:00-03:59",
            "padrao": "23:00",
        }

    @app.put("/api/server/backup/config")
    def configurar_horario_backup(
        request: BackupScheduleInput,
        auth: dict = Depends(super_auth),
        _: None = Depends(api_auth),
    ) -> dict[str, str]:
        horario = _validate_backup_time(request.horario)
        if os.name != "nt":
            raise HTTPException(
                status_code=501,
                detail="O agendamento automático requer o servidor Windows de produção.",
            )
        try:
            script_path = _resolve_operational_script("instalar_backup_automatico_windows.ps1")
        except FileNotFoundError:
            raise HTTPException(status_code=500, detail="Instalador da tarefa de backup não encontrado.")
        powershell = shutil.which("powershell.exe")
        if not powershell:
            raise HTTPException(status_code=500, detail="Windows PowerShell não encontrado no servidor.")
        try:
            completed = subprocess.run(
                [
                    powershell,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script_path),
                    "-Horario",
                    horario,
                ],
                cwd=str(script_path.parent),
                capture_output=True,
                text=True,
                timeout=60,
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise HTTPException(status_code=504, detail="O Windows excedeu o prazo ao configurar o backup.") from error
        except OSError as error:
            raise HTTPException(status_code=500, detail=f"Falha ao iniciar o agendador: {error}") from error
        if completed.returncode != 0:
            diagnostic = (completed.stderr or completed.stdout or "Falha não detalhada.").strip()
            raise HTTPException(status_code=500, detail=f"Agendador do Windows recusou a configuração: {diagnostic[-800:]}")
        _write_backup_schedule(settings=settings, horario=horario)
        database.audit(
            usuario=str(auth.get("login") or auth.get("sub") or "SUPER_USUARIO"),
            acao="ALTERAR_HORARIO_BACKUP",
            tabela="configuracoes",
            registro_id="backup_automatico",
            detalhes=f"HORARIO={horario};JANELA=18:00-03:59",
        )
        return {"status": "horario_backup_configurado", "horario": horario}

    @app.get("/api/server/status")
    def server_status(_: None = Depends(api_auth)) -> dict[str, str]:
        production_ready = (
            settings.require_tls
            and len(settings.api_key.strip()) >= 32
            and len(settings.secret_key.strip()) >= 64
            and bool(settings.sire_username.strip())
            and bool(settings.sire_password.strip())
            and portal_projection is not None
        )
        return {
            "status": "ok",
            "app": "KRISTAL LABORATORIAL",
            "fase": "PRODUCAO" if production_ready else "PRODUCAO_PENDENTE_CONFIGURACAO",
            "db_path": settings.db_path,
            "storage_dir": settings.storage_dir,
            "backup_dir": settings.backup_dir,
            "sire_base_url": settings.sire_base_url,
            "sire_configurado": "SIM" if settings.sire_username and settings.sire_password else "NAO",
        }

    @app.post("/api/server/backup")
    def criar_backup_servidor(_: None = Depends(api_auth)) -> dict[str, Any]:
        backup_dir = Path(settings.backup_dir)
        backup_dir.mkdir(parents=True, exist_ok=True)
        stamp = database.now().replace(":", "-")
        sources = {
            "portal": Path(settings.db_path),
            "corporativo": Path(settings.corporate_db_path),
            "operacional": Path(settings.operational_db_path),
        }
        backups: list[dict[str, Any]] = []
        for name, source in sources.items():
            if not source.exists():
                if name == "portal":
                    raise HTTPException(status_code=404, detail="Banco do portal ainda não existe.")
                continue
            destination = backup_dir / f"kristal_{name}_backup_{stamp}.db"
            _backup_sqlite(source=source, destination=destination)
            backups.append(
                {
                    "tipo": name,
                    "arquivo": str(destination),
                    "bytes": destination.stat().st_size,
                    "sha256": _sha256_file(destination),
                }
            )

        storage = Path(settings.storage_dir)
        if storage.exists() and any(item.is_file() for item in storage.rglob("*")):
            archive_base = backup_dir / f"kristal_storage_backup_{stamp}"
            archive_path = Path(shutil.make_archive(str(archive_base), "zip", root_dir=storage))
            backups.append(
                {
                    "tipo": "laudos_storage",
                    "arquivo": str(archive_path),
                    "bytes": archive_path.stat().st_size,
                    "sha256": _sha256_file(archive_path),
                }
            )

        manifest = backup_dir / f"kristal_backup_manifest_{stamp}.json"
        manifest.write_text(
            json.dumps(
                {
                    "sistema": "KRISTAL LABORATORIAL",
                    "criado_em": database.now(),
                    "arquivos": backups,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        manifest_sha256 = _sha256_file(manifest)
        database.audit(
            usuario="API_KEY",
            acao="BACKUP_SERVIDOR_COMPLETO",
            tabela="database",
            registro_id=str(manifest),
            detalhes=f"ARQUIVOS={len(backups)};SHA256_MANIFESTO={manifest_sha256}",
        )
        return {
            "status": "backup_completo_criado",
            "manifesto": str(manifest),
            "manifesto_sha256": manifest_sha256,
            "arquivos": backups,
        }

    @app.post("/api/sire/cdm/manual")
    @app.post("/api/sire/cdm/automatico")
    def exportar_cdm_sire_automatico(
        beneficiario_id: Annotated[str, Form()],
        plano_interno_id: Annotated[str, Form()],
        percentual_desconto: Annotated[int, Form()],
        procedimentos_json: Annotated[str, Form()],
        _: None = Depends(api_auth),
        paciente_id: Annotated[str | None, Form()] = None,
        pedido_id: Annotated[str | None, Form()] = None,
    ) -> dict[str, str]:
        if not settings.sire_username or not settings.sire_password:
            raise HTTPException(status_code=503, detail="Credenciais reais do SIRE não configuradas no .env.")
        if not beneficiario_id.strip() or not plano_interno_id.strip():
            raise HTTPException(status_code=400, detail="BeneficiarioId e PlanoInternoId são obrigatórios.")
        if percentual_desconto not in {0, 20, 100}:
            raise HTTPException(status_code=400, detail="PercentualDesconto deve ser 0, 20 ou 100.")
        try:
            procedimentos = json.loads(procedimentos_json)
        except json.JSONDecodeError as error:
            raise HTTPException(status_code=400, detail=f"procedimentos_json inválido: {error.msg}") from error
        if not isinstance(procedimentos, list) or not procedimentos:
            raise HTTPException(status_code=400, detail="procedimentos_json deve ser uma lista não vazia.")
        _validate_cdm_procedures(procedimentos)

        payload_bytes = json.dumps(procedimentos, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        request_url = _sire_post_cdm_url(
            settings.sire_base_url,
            beneficiario_id=beneficiario_id,
            plano_interno_id=plano_interno_id,
            percentual_desconto=percentual_desconto,
        )
        request = urllib.request.Request(
            request_url,
            data=payload_bytes,
            method="POST",
            headers={"Content-Type": "application/json", "Accept": "application/json"},
        )
        credentials = f"{settings.sire_username}:{settings.sire_password}".encode("utf-8")
        request.add_header("Authorization", "Basic " + __import__("base64").b64encode(credentials).decode("ascii"))
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                retorno_text = response.read().decode("utf-8")
        except urllib.error.HTTPError as error:
            retorno_text = error.read().decode("utf-8", errors="replace")
            raise HTTPException(status_code=502, detail=f"SIRE HTTP {error.code}: {retorno_text}") from error
        except urllib.error.URLError as error:
            raise HTTPException(status_code=502, detail=f"Falha de rede ao comunicar com SIRE: {error.reason}") from error
        try:
            retorno = json.loads(retorno_text)
        except json.JSONDecodeError as error:
            raise HTTPException(status_code=502, detail=f"SIRE retornou JSON inválido: {error.msg}") from error
        if not isinstance(retorno, dict):
            raise HTTPException(status_code=502, detail="SIRE retornou estrutura inválida.")
        cdm_id = str(retorno.get("CDMId") or "")
        success = str(retorno.get("OutSuccess") or "").lower() == "true" or bool(retorno.get("OutSuccess") is True)
        hash_integridade = hashlib.sha256(payload_bytes + retorno_text.encode("utf-8")).hexdigest()
        envio_id = database.new_id("CDM")
        with database.connect() as conn:
            conn.execute(
                """
                INSERT INTO sire_cdm_envios (
                    id, paciente_id, pedido_id, beneficiario_id, plano_interno_id,
                    percentual_desconto, payload_json, retorno_json, cdm_id, status,
                    hash_integridade, criado_em
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    envio_id, paciente_id or "", pedido_id or "", beneficiario_id.strip(),
                    plano_interno_id.strip(), str(percentual_desconto), procedimentos_json,
                    retorno_text, cdm_id, "ENVIADO" if success else "RECUSADO",
                    hash_integridade, database.now(),
                ),
            )
            conn.commit()
        database.audit(
            usuario="API_KEY",
            acao="EXPORTAR_CDM_SIRE_AUTOMATICO",
            tabela="sire_cdm_envios",
            registro_id=envio_id,
            detalhes=f"CDMId={cdm_id}; SHA256={hash_integridade}",
        )
        return {
            "status": "enviado" if success else "recusado",
            "id": envio_id,
            "cdm_id": cdm_id,
            "hash_integridade": hash_integridade,
            "mensagem": str(retorno.get("Message") or ""),
        }

    return app


def _emitir_cdm_automatico_exame(
    *,
    settings: Settings,
    database: Database,
    paciente: dict,
    pedido_id: str,
    exame_nome: str,
    valor_brl: str,
    unidade: str,
    referencia: str,
) -> str:
    if not settings.sire_auto_cdm:
        return "DESATIVADO"
    beneficiario_id = str(paciente.get("preccp") or paciente.get("identidade_militar") or "").strip()
    plano_interno_id = settings.sire_default_plano_interno_id.strip()
    if not settings.sire_username or not settings.sire_password or not beneficiario_id or not plano_interno_id:
        _registrar_cdm_pendente(
            database=database,
            paciente_id=str(paciente.get("id") or ""),
            pedido_id=pedido_id,
            beneficiario_id=beneficiario_id,
            plano_interno_id=plano_interno_id,
            motivo="Credenciais SIRE, BeneficiarioId ou PlanoInternoId ausentes.",
            payload={"exame_nome": exame_nome, "valor": valor_brl, "unidade": unidade, "referencia": referencia},
        )
        return "PENDENTE_CONFIGURACAO"
    procedimento = _procedimento_cdm_from_exame(database=database, exame_nome=exame_nome, valor_brl=valor_brl)
    if procedimento is None:
        _registrar_cdm_pendente(
            database=database,
            paciente_id=str(paciente.get("id") or ""),
            pedido_id=pedido_id,
            beneficiario_id=beneficiario_id,
            plano_interno_id=plano_interno_id,
            motivo="Catalogo sem codigo SIRE/CBHPM para o exame.",
            payload={"exame_nome": exame_nome, "valor": valor_brl, "unidade": unidade, "referencia": referencia},
        )
        return "PENDENTE_CODIGO_SIRE"
    percentual = settings.sire_default_percentual_desconto
    if percentual not in {0, 20, 100}:
        _registrar_cdm_pendente(
            database=database,
            paciente_id=str(paciente.get("id") or ""),
            pedido_id=pedido_id,
            beneficiario_id=beneficiario_id,
            plano_interno_id=plano_interno_id,
            motivo="PercentualDesconto configurado invalido.",
            payload=procedimento,
        )
        return "PENDENTE_PERCENTUAL_INVALIDO"
    procedimentos_json = json.dumps([procedimento], ensure_ascii=False, separators=(",", ":"))
    payload_bytes = procedimentos_json.encode("utf-8")
    request_url = _sire_post_cdm_url(settings.sire_base_url, beneficiario_id=beneficiario_id, plano_interno_id=plano_interno_id, percentual_desconto=percentual)
    request = urllib.request.Request(request_url, data=payload_bytes, method="POST", headers={"Content-Type": "application/json", "Accept": "application/json"})
    credentials = f"{settings.sire_username}:{settings.sire_password}".encode("utf-8")
    request.add_header("Authorization", "Basic " + __import__("base64").b64encode(credentials).decode("ascii"))
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            retorno_text = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        retorno_text = error.read().decode("utf-8", errors="replace")
        _registrar_cdm_erro(database=database, paciente_id=str(paciente.get("id") or ""), pedido_id=pedido_id, payload=procedimentos_json, retorno=retorno_text, status=f"ERRO_HTTP_{error.code}")
        return f"ERRO_HTTP_{error.code}"
    except urllib.error.URLError as error:
        _registrar_cdm_erro(database=database, paciente_id=str(paciente.get("id") or ""), pedido_id=pedido_id, payload=procedimentos_json, retorno=str(error.reason), status="ERRO_REDE")
        return "ERRO_REDE"
    try:
        retorno = json.loads(retorno_text)
    except json.JSONDecodeError:
        _registrar_cdm_erro(database=database, paciente_id=str(paciente.get("id") or ""), pedido_id=pedido_id, payload=procedimentos_json, retorno=retorno_text, status="ERRO_JSON_SIRE")
        return "ERRO_JSON_SIRE"
    if not isinstance(retorno, dict):
        _registrar_cdm_erro(database=database, paciente_id=str(paciente.get("id") or ""), pedido_id=pedido_id, payload=procedimentos_json, retorno=retorno_text, status="ERRO_ESTRUTURA_SIRE")
        return "ERRO_ESTRUTURA_SIRE"
    cdm_id = str(retorno.get("CDMId") or "")
    success = str(retorno.get("OutSuccess") or "").lower() == "true" or bool(retorno.get("OutSuccess") is True)
    hash_integridade = hashlib.sha256(payload_bytes + retorno_text.encode("utf-8")).hexdigest()
    envio_id = database.new_id("CDM")
    with database.connect() as conn:
        conn.execute("""
            INSERT INTO sire_cdm_envios (
                id, paciente_id, pedido_id, beneficiario_id, plano_interno_id,
                percentual_desconto, payload_json, retorno_json, cdm_id, status,
                hash_integridade, criado_em
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (envio_id, str(paciente.get("id") or ""), pedido_id, beneficiario_id, plano_interno_id, str(percentual), procedimentos_json, retorno_text, cdm_id, "ENVIADO" if success else "RECUSADO", hash_integridade, database.now()))
        conn.commit()
    database.audit(usuario="SISTEMA", acao="CDM_AUTOMATICO_EXAME", tabela="sire_cdm_envios", registro_id=envio_id, detalhes=f"Status={'ENVIADO' if success else 'RECUSADO'}; CDMId={cdm_id}; SHA256={hash_integridade}")
    return "ENVIADO" if success else "RECUSADO"


def _procedimento_cdm_from_exame(*, database: Database, exame_nome: str, valor_brl: str) -> dict[str, object] | None:
    like = f"%{exame_nome.strip()}%"
    with database.connect() as conn:
        row = conn.execute("""
            SELECT codigo_sire, codigo_subgrupo_cbhpm, valor_cheio
            FROM catalogo_exames
            WHERE ativo = '1' AND (nome LIKE ? OR mne LIKE ?)
            ORDER BY nome
            LIMIT 1
            """, (like, like)).fetchone()
    if (
        row is None
        or not str(row["codigo_sire"] or "").strip()
        or not str(row["codigo_subgrupo_cbhpm"] or "").strip()
    ):
        return None
    valor = _brl_to_float_text(valor_brl or str(row["valor_cheio"] or "0,00"))
    return {
        "Codigo_CBHPM": str(row["codigo_sire"]).strip(),
        "Codigo_SubGrupoCBHMP": str(row["codigo_subgrupo_cbhpm"]).strip(),
        "ValorUnitario": valor,
        "Quantidade": 1,
    }


def _brl_to_float_text(value: str) -> str:
    clean = value.strip().replace("R$", "").replace(" ", "")
    if "," in clean:
        clean = clean.replace(".", "").replace(",", ".")
    try:
        number = Decimal(clean).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except InvalidOperation as error:
        raise ValueError("Valor monetário inválido para o CDM.") from error
    if number <= 0:
        raise ValueError("ValorUnitario do CDM deve ser positivo.")
    return format(number, ".2f")


def _validate_cdm_procedures(procedures: list[object]) -> None:
    for index, item in enumerate(procedures, start=1):
        if not isinstance(item, dict):
            raise HTTPException(status_code=400, detail=f"Procedimento {index} deve ser objeto JSON.")
        for key in ("Codigo_CBHPM", "Codigo_SubGrupoCBHMP"):
            if not str(item.get(key) or "").strip():
                raise HTTPException(status_code=400, detail=f"Procedimento {index}: {key} é obrigatório.")
        try:
            value = Decimal(str(item.get("ValorUnitario") or "").replace(",", "."))
        except InvalidOperation as error:
            raise HTTPException(status_code=400, detail=f"Procedimento {index}: ValorUnitario inválido.") from error
        if not value.is_finite() or value <= 0:
            raise HTTPException(status_code=400, detail=f"Procedimento {index}: ValorUnitario deve ser positivo.")
        quantity = item.get("Quantidade")
        if isinstance(quantity, bool):
            raise HTTPException(status_code=400, detail=f"Procedimento {index}: Quantidade inválida.")
        try:
            parsed_quantity = int(str(quantity))
        except (TypeError, ValueError) as error:
            raise HTTPException(status_code=400, detail=f"Procedimento {index}: Quantidade inválida.") from error
        if parsed_quantity <= 0 or str(quantity).strip() != str(parsed_quantity):
            raise HTTPException(status_code=400, detail=f"Procedimento {index}: Quantidade deve ser inteiro positivo.")


def _registrar_cdm_pendente(*, database: Database, paciente_id: str, pedido_id: str, beneficiario_id: str, plano_interno_id: str, motivo: str, payload: dict[str, object]) -> None:
    payload_json = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    hash_integridade = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
    envio_id = database.new_id("CDM")
    with database.connect() as conn:
        conn.execute("""
            INSERT INTO sire_cdm_envios (
                id, paciente_id, pedido_id, beneficiario_id, plano_interno_id,
                percentual_desconto, payload_json, retorno_json, cdm_id, status,
                hash_integridade, criado_em
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (envio_id, paciente_id, pedido_id, beneficiario_id, plano_interno_id, "", payload_json, motivo, "", "PENDENTE_CONFIGURACAO", hash_integridade, database.now()))
        conn.commit()
    database.audit(usuario="SISTEMA", acao="CDM_AUTOMATICO_PENDENTE", tabela="sire_cdm_envios", registro_id=envio_id, detalhes=f"{motivo}; SHA256={hash_integridade}")


def _registrar_cdm_erro(*, database: Database, paciente_id: str, pedido_id: str, payload: str, retorno: str, status: str) -> None:
    hash_integridade = hashlib.sha256((payload + retorno).encode("utf-8")).hexdigest()
    envio_id = database.new_id("CDM")
    with database.connect() as conn:
        conn.execute("""
            INSERT INTO sire_cdm_envios (
                id, paciente_id, pedido_id, beneficiario_id, plano_interno_id,
                percentual_desconto, payload_json, retorno_json, cdm_id, status,
                hash_integridade, criado_em
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (envio_id, paciente_id, pedido_id, "", "", "", payload, retorno, "", status, hash_integridade, database.now()))
        conn.commit()
    database.audit(usuario="SISTEMA", acao="CDM_AUTOMATICO_ERRO", tabela="sire_cdm_envios", registro_id=envio_id, detalhes=f"Status={status}; SHA256={hash_integridade}")


def _auth(*, settings: Settings, authorization: str | None, roles: set[str]) -> dict:
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token ausente.")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = SecurityService.verify_token(secret_key=settings.secret_key, token=token)
    except ValueError as error:
        raise HTTPException(status_code=401, detail=str(error)) from error
    if payload.get("role", "") not in roles:
        raise HTTPException(status_code=403, detail="Acesso negado.")
    return payload


def _auth_any(*, settings: Settings, authorization: str | None) -> dict:
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token ausente.")
    try:
        return SecurityService.verify_token(
            secret_key=settings.secret_key,
            token=authorization.removeprefix("Bearer ").strip(),
        )
    except ValueError as error:
        raise HTTPException(status_code=401, detail=str(error)) from error


async def _save_pdf(*, settings: Settings, exame_id: str, upload: UploadFile) -> str:
    filename = upload.filename or ""
    if not filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Envie apenas PDF.")
    directory = Path(settings.storage_dir) / "laudos"
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / f"{exame_id}.pdf"
    content = await upload.read()
    if not content.startswith(b"%PDF"):
        raise HTTPException(status_code=400, detail="Arquivo PDF inválido.")
    destination.write_bytes(content)
    return str(destination)


def _find_pdf_path(*, database: Database, exame_id: str) -> str:
    with database.connect() as conn:
        row = conn.execute(
            """
            SELECT pdf_path FROM historico_exames_pacientes WHERE id = ?
            UNION
            SELECT pdf_path FROM exames WHERE id = ?
            UNION
            SELECT pdf_path FROM historico_exames_pacientes WHERE id = ?
            """,
            (exame_id, exame_id, f"HIST-{exame_id}"),
        ).fetchone()
    if row is None:
        return ""
    pdf_path = row["pdf_path"] or ""
    return pdf_path if pdf_path and os.path.exists(pdf_path) else ""


def _find_exam_row(*, database: Database, exame_id: str) -> sqlite3.Row | None:
    with database.connect() as conn:
        return conn.execute(
            """
            SELECT id, paciente_nome, cpf, preccp, exame_nome, valor, unidade, referencia,
                   status_laudo, critico, coletado_em, liberado_em,
                   profissional_responsavel, equipamento, observacao
            FROM historico_exames_pacientes WHERE id = ?
            UNION
            SELECT e.id, p.nome AS paciente_nome, p.cpf, p.preccp, e.exame_nome, e.valor,
                   e.unidade, e.referencia, e.status_laudo, e.critico, e.coletado_em,
                   e.liberado_em, e.profissional_responsavel, e.equipamento, e.observacao
            FROM exames e JOIN pacientes p ON p.id = e.paciente_id
            WHERE e.id = ?
            UNION
            SELECT id, paciente_nome, cpf, preccp, exame_nome, valor, unidade, referencia,
                   status_laudo, critico, coletado_em, liberado_em,
                   profissional_responsavel, equipamento, observacao
            FROM historico_exames_pacientes WHERE id = ?
            """,
            (exame_id, exame_id, f"HIST-{exame_id}"),
        ).fetchone()


def _laudo_text(row: dict) -> str:
    return "\n".join(
        [
            "HOSPITAL MILITAR DE RESENDE",
            "KRISTAL LABORATORIAL",
            "LAUDO LABORATORIAL",
            "",
            f"Paciente: {row.get('paciente_nome', '')}",
            f"CPF: {row.get('cpf', '')}",
            f"PREC-CP: {row.get('preccp', '')}",
            f"Exame: {row.get('exame_nome', '')}",
            f"Resultado: {row.get('valor', '')} {row.get('unidade', '')}",
            f"Referencia: {row.get('referencia', '')}",
            f"Status: {row.get('status_laudo', '')}",
            f"Critico: {row.get('critico', '')}",
            f"Coletado em: {row.get('coletado_em', '')}",
            f"Liberado em: {row.get('liberado_em', '')}",
            f"Equipamento: {row.get('equipamento', '')}",
            f"Profissional responsavel: {row.get('profissional_responsavel', '')}",
            f"Observacao: {row.get('observacao', '')}",
        ]
    )


def _minimal_pdf_bytes(text: str) -> bytes:
    lines = text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)").splitlines()
    content_lines = ["BT", "/F1 12 Tf", "50 790 Td"]
    for index, line in enumerate(lines):
        if index > 0:
            content_lines.append("0 -18 Td")
        content_lines.append(f"({line}) Tj")
    content_lines.append("ET")
    stream = "\n".join(content_lines).encode("latin-1", errors="replace")
    objects = [
        b"1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n",
        b"2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n",
        b"3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj\n",
        b"4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n",
        b"5 0 obj << /Length " + str(len(stream)).encode() + b" >> stream\n" + stream + b"\nendstream endobj\n",
    ]
    pdf = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for obj in objects:
        offsets.append(len(pdf))
        pdf.extend(obj)
    xref = len(pdf)
    pdf.extend(f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode())
    for offset in offsets[1:]:
        pdf.extend(f"{offset:010d} 00000 n \n".encode())
    pdf.extend(
        f"trailer << /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    )
    return bytes(pdf)


def _validate_patient_owns_exam(*, database: Database, patient_id: str, exame_id: str) -> None:
    with database.connect() as conn:
        row = conn.execute(
            """
            SELECT id FROM historico_exames_pacientes WHERE id = ? AND paciente_id = ?
            UNION
            SELECT id FROM exames WHERE id = ? AND paciente_id = ?
            UNION
            SELECT id FROM historico_exames_pacientes WHERE id = ? AND paciente_id = ?
            """,
            (exame_id, patient_id, exame_id, patient_id, f"HIST-{exame_id}", patient_id),
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=403, detail="Laudo não pertence ao paciente.")



def _normalize_admin_profile(value: str) -> str:
    clean = value.strip().upper().replace(" ", "_")
    if clean in {"SUPER", "SUPERUSUARIO", "SUPER_USUARIO"}:
        return "SUPER_USUARIO"
    if clean in {"ADMIN", "ADMINISTRADOR"}:
        return "ADMIN"
    raise HTTPException(status_code=400, detail="Perfil deve ser SUPER_USUARIO ou ADMIN.")


def _validate_military_rank(graduacao: str, posto: str) -> tuple[str, str]:
    graduacao_clean = graduacao.strip()
    posto_clean = posto.strip()
    allowed = {
        "Recruta": set(),
        "Soldado": set(),
        "Cabo": set(),
        "Sargento": {"1º", "2º", "3º"},
        "Subtenente": set(),
        "Aspirante": set(),
        "Tenente": {"1º", "2º"},
        "Capitão": set(),
        "Major": set(),
        "Tenente-Coronel": set(),
        "Coronel": set(),
        "General": {"Brigada", "Divisão", "Exército"},
        "Marechal": set(),
    }
    if not graduacao_clean:
        return "", ""
    if graduacao_clean not in allowed:
        raise HTTPException(status_code=400, detail="Graduação inválida.")
    valid_posts = allowed[graduacao_clean]
    if valid_posts and posto_clean not in valid_posts:
        raise HTTPException(status_code=400, detail="Posto inválido para a graduação informada.")
    if not valid_posts and posto_clean:
        raise HTTPException(status_code=400, detail="Esta graduação não possui posto.")
    return graduacao_clean, posto_clean


def _valid_cpf_or_400(value: str) -> str:
    cpf = _digits(value)
    if len(cpf) != 11 or len(set(cpf)) == 1:
        raise HTTPException(status_code=400, detail="CPF inválido.")
    numbers = [int(char) for char in cpf]
    for digit_index in (9, 10):
        factor = digit_index + 1
        total = sum(numbers[index] * (factor - index) for index in range(digit_index))
        expected = (total * 10) % 11
        if expected == 10:
            expected = 0
        if numbers[digit_index] != expected:
            raise HTTPException(status_code=400, detail="CPF inválido.")
    return cpf


def _validate_backup_time(value: str) -> str:
    clean = value.strip()
    if len(clean) != 5 or clean[2] != ":" or not clean[:2].isdigit() or not clean[3:].isdigit():
        raise HTTPException(status_code=400, detail="Horário inválido. Use HH:mm.")
    hour = int(clean[:2])
    minute = int(clean[3:])
    if hour > 23 or minute > 59:
        raise HTTPException(status_code=400, detail="Horário inválido. Use HH:mm.")
    if 4 <= hour < 18:
        raise HTTPException(status_code=400, detail="O backup deve permanecer entre 18:00 e 03:59.")
    return f"{hour:02d}:{minute:02d}"


def _resolve_operational_script(
    script_name: str,
    *,
    search_roots: tuple[Path, ...] | None = None,
) -> Path:
    clean_name = script_name.strip()
    if not clean_name or Path(clean_name).name != clean_name:
        raise ValueError("Nome de script operacional inválido.")
    roots = search_roots or (Path.cwd(), Path(__file__).resolve().parent.parent)
    for root in roots:
        candidate = root.resolve() / clean_name
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(clean_name)

def _read_backup_schedule(*, settings: Settings) -> str:
    path = Path(settings.backup_schedule_file)
    if not path.is_file():
        return "23:00"
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return "23:00"
    value = raw.get("horario") if isinstance(raw, dict) else None
    if not isinstance(value, str):
        return "23:00"
    try:
        return _validate_backup_time(value)
    except HTTPException:
        return "23:00"


def _write_backup_schedule(*, settings: Settings, horario: str) -> None:
    path = Path(settings.backup_schedule_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(
            {"horario": horario, "janela": "18:00-03:59"},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    os.replace(temporary, path)


def _backup_sqlite(*, source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    source_conn = sqlite3.connect(str(source), timeout=30)
    destination_conn = sqlite3.connect(str(destination), timeout=30)
    try:
        source_conn.execute("PRAGMA busy_timeout = 30000")
        source_conn.backup(destination_conn, pages=4096, sleep=0.05)
        integrity = destination_conn.execute("PRAGMA integrity_check").fetchone()
        if integrity is None or str(integrity[0]).lower() != "ok":
            raise sqlite3.DatabaseError("O backup SQLite falhou na verificação de integridade.")
        destination_conn.commit()
    finally:
        destination_conn.close()
        source_conn.close()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()

def _normalize_brl_or_400(value: str) -> str:
    raw = value.strip()
    if not raw:
        raise HTTPException(status_code=400, detail="Valor monetário é obrigatório.")
    clean = raw.replace("R$", "").replace(" ", "").replace("\u00a0", "")
    if "," in clean:
        clean = clean.replace(".", "").replace(",", ".")
    elif clean.count(".") > 1 or (clean.count(".") == 1 and len(clean.rsplit(".", 1)[1]) == 3):
        clean = clean.replace(".", "")
    try:
        amount = Decimal(clean).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except InvalidOperation as error:
        raise HTTPException(status_code=400, detail="Valor deve ser numérico em Real. Exemplo: 23,35.") from error
    if not amount.is_finite() or amount < 0:
        raise HTTPException(status_code=400, detail="Valor monetário não pode ser negativo.")
    return f"{amount:.2f}"
def _digits(value: str | None) -> str:
    return "".join(char for char in (value or "") if char.isdigit())


def _validate_api_key(*, settings: Settings, api_key: str | None) -> None:
    expected = settings.api_key.strip()
    provided = (api_key or "").strip()
    if not expected:
        raise HTTPException(status_code=503, detail="KRISTAL_API_KEY não configurada no servidor.")
    if not provided or not SecurityService.constant_time_compare(provided, expected):
        raise HTTPException(status_code=403, detail="Chave API inválida.")


def _sire_post_cdm_url(base_url: str, *, beneficiario_id: str, plano_interno_id: str, percentual_desconto: int) -> str:
    clean = base_url.strip().rstrip("/")
    if not clean:
        raise HTTPException(status_code=503, detail="KRISTAL_SIRE_BASE_URL não configurada.")
    if not clean.endswith("/PostCDM"):
        clean = clean + "/PostCDM"
    from urllib.parse import urlencode
    return clean + "?" + urlencode({
        "BeneficiarioId": beneficiario_id.strip(),
        "PlanoInternoId": plano_interno_id.strip(),
        "PercentualDesconto": str(percentual_desconto),
    })
