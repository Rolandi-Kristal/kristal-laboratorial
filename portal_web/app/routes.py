from __future__ import annotations

import hashlib
import json
import os
import shutil
import sqlite3
import urllib.error
import urllib.request
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

from app.config import Settings
from app.database import Database
from app.security import SecurityService


def create_app(*, settings: Settings, database: Database) -> FastAPI:
    app = FastAPI(title="KRISTAL LABORATORIAL Portal Web", version="1.0.0")
    static_dir = Path(__file__).resolve().parent.parent / "static"
    app.mount("/assets", StaticFiles(directory=static_dir / "assets"), name="assets")

    def admin_auth(authorization: Annotated[str | None, Header()] = None) -> dict:
        return _auth(settings=settings, authorization=authorization, roles={"SUPER_USUARIO", "ADMIN", "ADMINISTRADOR"})

    def paciente_auth(authorization: Annotated[str | None, Header()] = None) -> dict:
        return _auth(settings=settings, authorization=authorization, roles={"PACIENTE"})

    def super_auth(authorization: Annotated[str | None, Header()] = None) -> dict:
        return _auth(settings=settings, authorization=authorization, roles={"SUPER_USUARIO"})

    def api_auth(x_api_key: Annotated[str | None, Header(alias="X-API-Key")] = None) -> None:
        _validate_api_key(settings=settings, api_key=x_api_key)

    @app.get("/")
    def index() -> FileResponse:
        return FileResponse(static_dir / "index.html")

    @app.get("/admin.html")
    def admin_page() -> FileResponse:
        return FileResponse(static_dir / "admin.html")

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "app": "KRISTAL LABORATORIAL"}

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

    @app.post("/api/admin/pacientes")
    def cadastrar_paciente(
        nome: Annotated[str, Form()],
        cpf: Annotated[str, Form()],
        codigo_acesso: Annotated[str, Form()],
        auth: dict = Depends(admin_auth),
        preccp: Annotated[str | None, Form()] = None,
        cns: Annotated[str | None, Form()] = None,
        nascimento: Annotated[str | None, Form()] = None,
        telefone: Annotated[str | None, Form()] = None,
        email: Annotated[str | None, Form()] = None,
    ) -> dict[str, str]:
        cpf_clean = _digits(cpf)
        paciente_id = database.new_id("PAC")
        with database.connect() as conn:
            exists = conn.execute("SELECT id FROM pacientes WHERE cpf = ?", (cpf_clean,)).fetchone()
            if exists is not None:
                raise HTTPException(status_code=409, detail="CPF já cadastrado.")
            now = database.now()
            conn.execute(
                """
                INSERT INTO pacientes (
                    id, nome, cpf, preccp, cns, nascimento, telefone, email,
                    codigo_acesso_hash, ativo, ativo_consulta_recente, arquivado,
                    excluido_fisicamente, criado_em, atualizado_em
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    paciente_id, nome.strip(), cpf_clean, preccp or "", cns or "",
                    nascimento or "", telefone or "", email or "",
                    SecurityService.hash_password(codigo_acesso), "1", "1", "0", "0", now, now,
                ),
            )
            conn.commit()
        database.audit(usuario=auth.get("login", "admin"), acao="CADASTRAR_PACIENTE", tabela="pacientes", registro_id=paciente_id, detalhes=nome)
        return {"id": paciente_id, "status": "paciente_cadastrado"}

    @app.get("/api/admin/pacientes")
    def listar_pacientes(auth: dict = Depends(admin_auth), q: str = "") -> list[dict]:
        del auth
        like = f"%{q.strip()}%"
        with database.connect() as conn:
            rows = conn.execute(
                """
                SELECT id, nome, cpf, preccp, cns, telefone, email, criado_em
                FROM pacientes
                WHERE arquivado = '0' AND excluido_fisicamente = '0'
                AND (nome LIKE ? OR cpf LIKE ? OR preccp LIKE ?)
                ORDER BY nome
                """,
                (like, like, like),
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
        exame_id = database.new_id("EXA")
        pdf_path = ""
        if pdf is not None and pdf.filename:
            pdf_path = await _save_pdf(settings=settings, exame_id=exame_id, upload=pdf)
        with database.connect() as conn:
            paciente = conn.execute("SELECT id, nome, cpf, preccp, cns FROM pacientes WHERE id = ?", (paciente_id,)).fetchone()
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
                    exame_id, paciente_id, pedido_id or "", amostra_id or "", exame_nome.strip(),
                    valor.strip(), unidade or "", referencia or "", status_laudo, critico,
                    coletado_em or "", liberado, profissional_responsavel or "", equipamento or "",
                    "KRISTAL", pdf_path, "1", "0", "0", now, now, observacao or "",
                ),
            )
            history_id = f"HIST-{exame_id}"
            conn.execute(
                """
                INSERT INTO historico_exames_pacientes (
                    id, paciente_id, paciente_nome, cpf, preccp, cns, pedido_id, amostra_id,
                    exame_nome, valor, unidade, referencia, status_laudo, critico, coletado_em,
                    liberado_em, profissional_responsavel, equipamento, origem, pdf_path,
                    ativo_consulta_recente, arquivado, excluido_fisicamente, criado_em,
                    atualizado_em, observacao
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    history_id, paciente["id"], paciente["nome"], paciente["cpf"], paciente["preccp"],
                    paciente["cns"], pedido_id or "", amostra_id or "", exame_nome.strip(), valor.strip(),
                    unidade or "", referencia or "", status_laudo, critico, coletado_em or "", liberado,
                    profissional_responsavel or "", equipamento or "", "KRISTAL", pdf_path,
                    "0", "1", "0", now, now, observacao or "",
                ),
            )
            conn.commit()
        database.audit(usuario=auth.get("login", "admin"), acao="CADASTRAR_EXAME", tabela="exames", registro_id=exame_id, detalhes=exame_nome)
        return {"id": exame_id, "historico_id": f"HIST-{exame_id}"}

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
        cns: Annotated[str | None, Form()] = None,
        nascimento: Annotated[str | None, Form()] = None,
        telefone: Annotated[str | None, Form()] = None,
        email: Annotated[str | None, Form()] = None,
    ) -> dict[str, str]:
        cpf_clean = _digits(cpf)
        nome_clean = nome.strip()
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
                "nome = ?", "cpf = ?", "preccp = ?", "cns = ?", "nascimento = ?",
                "telefone = ?", "email = ?", "atualizado_em = ?",
            ]
            values: list[str] = [
                nome_clean, cpf_clean, preccp or "", cns or "", nascimento or "",
                telefone or "", email or "", database.now(),
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
                "UPDATE pacientes SET ativo = '0', ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '1', atualizado_em = ? WHERE id = ?",
                (now, paciente_id),
            )
            conn.execute(
                "UPDATE exames SET ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '1', atualizado_em = ? WHERE paciente_id = ?",
                (now, paciente_id),
            )
            conn.execute(
                "UPDATE historico_exames_pacientes SET ativo_consulta_recente = '0', arquivado = '1', excluido_fisicamente = '1', atualizado_em = ? WHERE paciente_id = ?",
                (now, paciente_id),
            )
            conn.commit()
        database.audit(
            usuario=auth.get("login", "admin"),
            acao="EXCLUIR_PACIENTE",
            tabela="pacientes",
            registro_id=paciente_id,
            detalhes="Exclusão administrativa do paciente e bloqueio dos exames vinculados.",
        )
        return {"id": paciente_id, "status": "paciente_excluido"}

    @app.get("/api/admin/catalogo-exames")
    def listar_catalogo_exames(auth: dict = Depends(admin_auth), q: str = "") -> list[dict]:
        del auth
        like = f"%{q.strip()}%"
        with database.connect() as conn:
            rows = conn.execute(
                """
                SELECT id, mne, codigo_sire, nome, setor, material, metodo, unidade,
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
                        id, mne, codigo_sire, nome, setor, material, metodo, unidade,
                        referencia, valor_cheio, valor_indenizar_20, equipamento, ativo,
                        criado_em, atualizado_em
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        catalogo_id, mne_clean, codigo_sire or "", nome_clean, setor or "",
                        material or "", metodo or "", unidade or "", referencia or "",
                        valor_cheio or "", valor_indenizar_20 or "", equipamento or "",
                        ativo_clean, now, now,
                    ),
                )
                action = "CADASTRAR_CATALOGO_EXAME"
            else:
                conn.execute(
                    """
                    UPDATE catalogo_exames
                    SET mne = ?, codigo_sire = ?, nome = ?, setor = ?, material = ?, metodo = ?,
                        unidade = ?, referencia = ?, valor_cheio = ?, valor_indenizar_20 = ?,
                        equipamento = ?, ativo = ?, atualizado_em = ?
                    WHERE id = ?
                    """,
                    (
                        mne_clean, codigo_sire or "", nome_clean, setor or "", material or "",
                        metodo or "", unidade or "", referencia or "", valor_cheio or "",
                        valor_indenizar_20 or "", equipamento or "", ativo_clean, now, catalogo_id,
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
        if not catalogo_id.strip():
            raise HTTPException(status_code=400, detail="ID do catálogo é obrigatório.")
        with database.connect() as conn:
            row = conn.execute("SELECT id, nome FROM catalogo_exames WHERE id = ?", (catalogo_id,)).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Exame do catálogo não localizado.")
            conn.execute("DELETE FROM catalogo_exames WHERE id = ?", (catalogo_id,))
            conn.commit()
        database.audit(
            usuario=auth.get("login", "admin"),
            acao="EXCLUIR_CATALOGO_EXAME",
            tabela="catalogo_exames",
            registro_id=catalogo_id,
            detalhes="Exclusão administrativa do catálogo de exames.",
        )
        return {"id": catalogo_id, "status": "catalogo_exame_excluido"}

    @app.post("/api/admin/dados/excluir-todos")
    def excluir_todos_dados(
        confirmacao: Annotated[str, Form()],
        auth: dict = Depends(super_auth),
    ) -> dict[str, str]:
        if confirmacao.strip() != "EXCLUIR TODOS OS DADOS":
            raise HTTPException(status_code=400, detail="Confirmação inválida.")
        with database.connect() as conn:
            conn.execute("DELETE FROM exames")
            conn.execute("DELETE FROM historico_exames_pacientes")
            conn.execute("DELETE FROM pacientes")
            conn.execute("DELETE FROM catalogo_exames")
            conn.commit()
        database.audit(
            usuario=auth.get("login", "super"),
            acao="EXCLUIR_TODOS_DADOS_CADASTRADOS",
            tabela="sistema",
            registro_id="TODOS",
            detalhes="Superusuário excluiu pacientes, exames, histórico e catálogo de exames.",
        )
        return {"status": "dados_cadastrados_excluidos"}


    @app.get("/api/server/status")
    def server_status(_: None = Depends(api_auth)) -> dict[str, str]:
        return {
            "status": "ok",
            "app": "KRISTAL LABORATORIAL",
            "fase": "PRODUCAO_CONFIGURAVEL",
            "db_path": settings.db_path,
            "storage_dir": settings.storage_dir,
            "backup_dir": settings.backup_dir,
            "sire_base_url": settings.sire_base_url,
            "sire_configurado": "SIM" if settings.sire_username and settings.sire_password else "NAO",
        }

    @app.post("/api/server/backup")
    def criar_backup_servidor(_: None = Depends(api_auth)) -> dict[str, str]:
        backup_dir = Path(settings.backup_dir)
        backup_dir.mkdir(parents=True, exist_ok=True)
        source = Path(settings.db_path)
        if not source.exists():
            raise HTTPException(status_code=404, detail="Banco do portal ainda não existe.")
        stamp = database.now().replace(":", "-")
        destination = backup_dir / f"kristal_portal_backup_{stamp}.db"
        shutil.copy2(source, destination)
        sha256 = hashlib.sha256(destination.read_bytes()).hexdigest()
        database.audit(
            usuario="API_KEY",
            acao="BACKUP_SERVIDOR_MANUAL",
            tabela="database",
            registro_id=str(destination),
            detalhes=f"SHA256={sha256}",
        )
        return {"status": "backup_criado", "arquivo": str(destination), "sha256": sha256}

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
        for item in procedimentos:
            if not isinstance(item, dict):
                raise HTTPException(status_code=400, detail="Cada procedimento deve ser objeto JSON.")
            for required_key in ("Codigo_CBHPM", "Codigo_SubGrupoCBHMP", "ValorUnitario", "Quantidade"):
                if required_key not in item:
                    raise HTTPException(status_code=400, detail=f"Campo obrigatório ausente: {required_key}.")

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


def _digits(value: str) -> str:
    return "".join(char for char in value if char.isdigit())


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
