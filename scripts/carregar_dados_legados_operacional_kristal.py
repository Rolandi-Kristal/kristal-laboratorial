from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sqlite3
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


TARGET_TABLES = {
    "pacsec",
    "paciente",
    "pacientes",
    "exames",
    "pedidos",
    "resultados",
    "amostras",
}


class OperationalLoadError(RuntimeError):
    pass


@dataclass
class LoadStats:
    sql_files: int = 0
    pacientes: int = 0
    exames_catalogo: int = 0
    pedidos: int = 0
    amostras: int = 0
    resultados: int = 0
    ignored_rows: int = 0


def now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")


def stable_id(prefix: str, *parts: object) -> str:
    raw = "|".join("" if part is None else str(part) for part in parts)
    digest = hashlib.sha256(raw.encode("utf-8", errors="replace")).hexdigest()[:24]
    return f"{prefix}-{digest}"


def only_digits(value: object | None) -> str:
    if value is None:
        return ""
    return "".join(ch for ch in str(value) if ch.isdigit())


def text(value: object | None) -> str:
    if value is None:
        return ""
    return str(value).strip()


def normalize_money(value: object | None) -> str:
    raw = text(value)
    if not raw:
        return ""
    digits = re.sub(r"[^0-9,.-]", "", raw).replace(".", "").replace(",", ".")
    try:
        amount = float(digits)
    except ValueError:
        return raw
    return f"{amount:.2f}".replace(".", ",")


def split_insert_values(values: str) -> Iterator[list[str | None]]:
    in_string = False
    escaped = False
    in_tuple = False
    current: list[str] = []
    row: list[str | None] = []

    for char in values:
        if not in_tuple:
            if char == "(":
                in_tuple = True
                current = []
                row = []
            continue

        if in_string:
            if escaped:
                current.append({
                    "n": "\n",
                    "r": "\r",
                    "t": "\t",
                    "0": "\0",
                    "\\": "\\",
                    "'": "'",
                    '"': '"',
                }.get(char, char))
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == "'":
                in_string = False
            else:
                current.append(char)
            continue

        if char == "'":
            in_string = True
        elif char == ",":
            row.append(normalize_sql_token("".join(current)))
            current = []
        elif char == ")":
            row.append(normalize_sql_token("".join(current)))
            yield row
            in_tuple = False
            current = []
            row = []
        else:
            current.append(char)


def normalize_sql_token(raw: str) -> str | None:
    value = raw.strip()
    if value.upper() == "NULL":
        return None
    return value


def iter_target_inserts(sql_path: Path) -> Iterator[tuple[str, list[str], list[str | None]]]:
    insert_re = re.compile(
        r"INSERT\s+INTO\s+`?([^`\s(]+)`?\s*(?:\((.*?)\))?\s+VALUES\s*(.*)\s*;\s*$",
        re.IGNORECASE | re.DOTALL,
    )
    create_re = re.compile(
        r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([^`\s(]+)`?\s*\((.*)\)\s*[^;]*;\s*$",
        re.IGNORECASE | re.DOTALL,
    )
    statement: list[str] = []
    columns_by_table: dict[str, list[str]] = {}

    with sql_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            stripped = line.strip()
            upper = stripped.upper()
            if not statement and not (upper.startswith("INSERT INTO") or upper.startswith("CREATE TABLE")):
                continue
            statement.append(line.rstrip("\n"))
            if not stripped.endswith(";"):
                continue

            sql = "\n".join(statement)
            statement.clear()
            create_match = create_re.match(sql)
            if create_match is not None:
                table = create_match.group(1).lower()
                if table in TARGET_TABLES:
                    columns_by_table[table] = extract_create_columns(create_match.group(2))
                continue

            match = insert_re.match(sql)
            if match is None:
                continue

            table = match.group(1).lower()
            if table not in TARGET_TABLES:
                continue

            columns_raw = match.group(2) or ""
            values_raw = match.group(3)
            columns = [
                part.strip().strip("`")
                for part in columns_raw.split(",")
                if part.strip()
            ] or columns_by_table.get(table, [])
            for row in split_insert_values(values_raw):
                yield table, columns, row


def extract_create_columns(body: str) -> list[str]:
    columns: list[str] = []
    for raw_part in split_ddl_parts(body):
        part = raw_part.strip()
        if not part.startswith("`"):
            continue
        end = part.find("`", 1)
        if end > 1:
            columns.append(part[1:end])
    return columns


def split_ddl_parts(body: str) -> list[str]:
    parts: list[str] = []
    current: list[str] = []
    depth = 0
    in_string = False
    escaped = False
    for char in body:
        if in_string:
            current.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == "'":
                in_string = False
            continue
        if char == "'":
            in_string = True
            current.append(char)
        elif char == "(":
            depth += 1
            current.append(char)
        elif char == ")":
            depth = max(0, depth - 1)
            current.append(char)
        elif char == "," and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)
    if current:
        parts.append("".join(current))
    return parts


def row_to_dict(columns: list[str], values: list[str | None]) -> dict[str, str | None]:
    if not columns:
        return {str(index): value for index, value in enumerate(values)}
    return {column: values[index] if index < len(values) else None for index, column in enumerate(columns)}


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS pacientes (
            id TEXT PRIMARY KEY,
            nome TEXT,
            cpf TEXT,
            cns TEXT,
            preccp TEXT,
            nascimento TEXT,
            telefone TEXT,
            endereco TEXT,
            criadoEm TEXT,
            status TEXT,
            sexo TEXT,
            email TEXT,
            celular TEXT,
            peso TEXT,
            altura TEXT,
            nomeMae TEXT,
            nomePai TEXT,
            cep TEXT,
            bairro TEXT,
            cidade TEXT,
            uf TEXT,
            matricula TEXT,
            identidadeMilitar TEXT,
            cadebensNumero TEXT,
            cadebensSituacao TEXT,
            codigoAcessoPortal TEXT
        );
        CREATE TABLE IF NOT EXISTS exames (
            id TEXT PRIMARY KEY,
            codigo TEXT,
            nome TEXT,
            setor TEXT,
            material TEXT,
            metodo TEXT,
            referencia TEXT,
            ativo TEXT,
            criadoEm TEXT
        );
        CREATE TABLE IF NOT EXISTS pedidos (
            id TEXT PRIMARY KEY,
            pacienteId TEXT,
            medicoSolicitante TEXT,
            prioridade TEXT,
            status TEXT,
            criadoEm TEXT,
            observacao TEXT
        );
        CREATE TABLE IF NOT EXISTS amostras (
            id TEXT PRIMARY KEY,
            pacienteId TEXT,
            pedidoId TEXT,
            exameId TEXT,
            codigoBarras TEXT UNIQUE,
            codigoManual TEXT,
            tipoLeitura TEXT,
            imagemPath TEXT,
            status TEXT,
            coletadoEm TEXT,
            criadoEm TEXT,
            criadoPor TEXT,
            observacao TEXT
        );
        CREATE TABLE IF NOT EXISTS resultados (
            id TEXT PRIMARY KEY,
            pacienteId TEXT,
            pedidoId TEXT,
            amostraId TEXT,
            exameId TEXT,
            valor TEXT,
            unidade TEXT,
            referencia TEXT,
            critico TEXT,
            status TEXT,
            liberadoEm TEXT,
            criadoEm TEXT,
            observacao TEXT,
            hashIntegridade TEXT
        );
        CREATE TABLE IF NOT EXISTS legacy_operational_manifest (
            id TEXT PRIMARY KEY,
            origem TEXT NOT NULL,
            tabela_legada TEXT NOT NULL,
            registro_legado TEXT NOT NULL,
            tabela_operacional TEXT NOT NULL,
            registro_operacional TEXT NOT NULL,
            hash_integridade TEXT NOT NULL,
            importado_em TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_pacientes_cpf ON pacientes(cpf);
        CREATE INDEX IF NOT EXISTS idx_pedidos_paciente ON pedidos(pacienteId);
        CREATE INDEX IF NOT EXISTS idx_amostras_pedido ON amostras(pedidoId);
        CREATE INDEX IF NOT EXISTS idx_resultados_paciente ON resultados(pacienteId);
        CREATE INDEX IF NOT EXISTS idx_legacy_operational_tabela ON legacy_operational_manifest(tabela_legada, tabela_operacional);
        """
    )
    conn.commit()


def manifest_insert(
    conn: sqlite3.Connection,
    *,
    origem: str,
    tabela_legada: str,
    registro_legado: str,
    tabela_operacional: str,
    registro_operacional: str,
    payload: dict[str, object],
) -> None:
    payload_json = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    digest = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
    conn.execute(
        """
        INSERT OR REPLACE INTO legacy_operational_manifest (
            id, origem, tabela_legada, registro_legado, tabela_operacional,
            registro_operacional, hash_integridade, importado_em
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            stable_id("LOM", origem, tabela_legada, registro_legado, tabela_operacional),
            origem,
            tabela_legada,
            registro_legado,
            tabela_operacional,
            registro_operacional,
            digest,
            now_iso(),
        ),
    )


def import_patient(conn: sqlite3.Connection, origem: str, table: str, row: dict[str, str | None]) -> bool:
    nome = text(row.get("Nome") or row.get("nome"))
    if not nome:
        return False

    cpf = only_digits(row.get("CPF") or row.get("cpf") or row.get("Doc") or row.get("doc"))
    preccp = only_digits(row.get("PREC-CP") or row.get("preccp") or row.get("prontuario") or row.get("RegHos"))
    identidade = only_digits(row.get("IdentidadeMilitar") or row.get("identidade_militar") or row.get("Matricula") or row.get("matricula"))
    legado = text(row.get("NumUnico") or row.get("paciente") or row.get("NumPac") or cpf or preccp or nome)
    paciente_id = stable_id("PAC", cpf or preccp or identidade or legado, nome)

    payload = {
        "id": paciente_id,
        "nome": nome,
        "cpf": cpf,
        "cns": "",
        "preccp": preccp,
        "nascimento": text(row.get("Nasc") or row.get("nascto") or row.get("Nascimento")),
        "telefone": only_digits(row.get("Telefone") or row.get("telefone")),
        "endereco": text(row.get("Endereco") or row.get("endereco")),
        "criadoEm": text(row.get("DataCadastro") or row.get("data") or now_iso()),
        "status": text(row.get("status") or "ATIVO"),
        "sexo": text(row.get("Sexo") or row.get("sexo")),
        "email": text(row.get("Email") or row.get("email")),
        "celular": only_digits(row.get("Celular") or row.get("celular")),
        "peso": text(row.get("Peso") or row.get("peso")),
        "altura": text(row.get("Altura") or row.get("altura")),
        "nomeMae": text(row.get("NomeMae") or row.get("NomeMae") or row.get("nomeMae")),
        "nomePai": text(row.get("NomePai") or row.get("nomePai")),
        "cep": only_digits(row.get("Cep") or row.get("CEP") or row.get("cep")),
        "bairro": text(row.get("Bairro") or row.get("bairro")),
        "cidade": text(row.get("Cidade") or row.get("cidade")),
        "uf": text(row.get("Estado") or row.get("uf")),
        "matricula": identidade,
        "identidadeMilitar": identidade,
        "cadebensNumero": text(row.get("Convenio") or row.get("Titular")),
        "cadebensSituacao": text(row.get("status") or "IMPORTADO"),
        "codigoAcessoPortal": text(row.get("ChaveAcessoWEB") or row.get("SenhaAcessoWEB")),
    }
    conn.execute(
        """
        INSERT OR REPLACE INTO pacientes (
            id, nome, cpf, cns, preccp, nascimento, telefone, endereco, criadoEm,
            status, sexo, email, celular, peso, altura, nomeMae, nomePai, cep,
            bairro, cidade, uf, matricula, identidadeMilitar, cadebensNumero,
            cadebensSituacao, codigoAcessoPortal
        ) VALUES (
            :id, :nome, :cpf, :cns, :preccp, :nascimento, :telefone, :endereco,
            :criadoEm, :status, :sexo, :email, :celular, :peso, :altura,
            :nomeMae, :nomePai, :cep, :bairro, :cidade, :uf, :matricula,
            :identidadeMilitar, :cadebensNumero, :cadebensSituacao, :codigoAcessoPortal
        )
        """,
        payload,
    )
    manifest_insert(
        conn,
        origem=origem,
        tabela_legada=table,
        registro_legado=legado,
        tabela_operacional="pacientes",
        registro_operacional=paciente_id,
        payload=payload,
    )
    return True


def import_exam_catalog(conn: sqlite3.Connection, origem: str, table: str, row: dict[str, str | None]) -> bool:
    code = text(row.get("exame") or row.get("Exame") or row.get("codigo") or row.get("Codigo"))
    nome = text(row.get("nome") or row.get("Nome") or row.get("titulo") or row.get("Titulo"))
    if not code or not nome:
        return False
    exame_id = stable_id("EXA", code, nome)
    payload = {
        "id": exame_id,
        "codigo": code,
        "nome": nome,
        "setor": text(row.get("setor") or row.get("Setor")),
        "material": text(row.get("material") or row.get("Material")),
        "metodo": text(row.get("metodo") or row.get("Metodo")),
        "referencia": text(row.get("referencia") or row.get("Referencia")),
        "ativo": "1",
        "criadoEm": now_iso(),
    }
    conn.execute(
        """
        INSERT OR REPLACE INTO exames (id, codigo, nome, setor, material, metodo, referencia, ativo, criadoEm)
        VALUES (:id, :codigo, :nome, :setor, :material, :metodo, :referencia, :ativo, :criadoEm)
        """,
        payload,
    )
    manifest_insert(
        conn,
        origem=origem,
        tabela_legada=table,
        registro_legado=code,
        tabela_operacional="exames",
        registro_operacional=exame_id,
        payload=payload,
    )
    return True


def import_order(conn: sqlite3.Connection, origem: str, table: str, row: dict[str, str | None]) -> bool:
    order_code = text(row.get("Numero") or row.get("pedido") or row.get("NumPac"))
    patient_legacy = text(row.get("NumPac") or row.get("paciente") or row.get("RegHos"))
    patient_name = text(row.get("Nome"))
    if not order_code:
        return False
    paciente_id = stable_id("PAC", patient_legacy or patient_name, patient_name)
    pedido_id = stable_id("PED", order_code, patient_legacy, patient_name)
    payload = {
        "id": pedido_id,
        "pacienteId": paciente_id,
        "medicoSolicitante": text(row.get("Medico") or row.get("MedicoCRM")),
        "prioridade": text(row.get("prioridade") or "ROTINA"),
        "status": text(row.get("Status") or row.get("status") or "IMPORTADO"),
        "criadoEm": text(row.get("Data") or row.get("data") or now_iso()),
        "observacao": f"Importado de {table}",
    }
    conn.execute(
        """
        INSERT OR REPLACE INTO pedidos (id, pacienteId, medicoSolicitante, prioridade, status, criadoEm, observacao)
        VALUES (:id, :pacienteId, :medicoSolicitante, :prioridade, :status, :criadoEm, :observacao)
        """,
        payload,
    )
    manifest_insert(
        conn,
        origem=origem,
        tabela_legada=table,
        registro_legado=order_code,
        tabela_operacional="pedidos",
        registro_operacional=pedido_id,
        payload=payload,
    )
    return True


def import_sample(conn: sqlite3.Connection, origem: str, table: str, row: dict[str, str | None]) -> bool:
    patient = text(row.get("Paciente") or row.get("paciente"))
    exam = text(row.get("Exame") or row.get("exame"))
    sample = text(row.get("Amostra") or row.get("amostra"))
    if not patient and not sample:
        return False
    pedido_id = stable_id("PED", patient, exam)
    amostra_id = stable_id("AMO", patient, exam, sample)
    payload = {
        "id": amostra_id,
        "pacienteId": stable_id("PAC", patient, ""),
        "pedidoId": pedido_id,
        "exameId": stable_id("EXA", exam, exam),
        "codigoBarras": sample or amostra_id,
        "codigoManual": sample,
        "tipoLeitura": "IMPORTACAO_SQL_LEGADO",
        "imagemPath": "",
        "status": "IMPORTADO",
        "coletadoEm": now_iso(),
        "criadoEm": now_iso(),
        "criadoPor": "IMPORTACAO_LEGADA",
        "observacao": f"Importado de {table}",
    }
    conn.execute(
        """
        INSERT OR REPLACE INTO amostras (
            id, pacienteId, pedidoId, exameId, codigoBarras, codigoManual,
            tipoLeitura, imagemPath, status, coletadoEm, criadoEm, criadoPor, observacao
        ) VALUES (
            :id, :pacienteId, :pedidoId, :exameId, :codigoBarras, :codigoManual,
            :tipoLeitura, :imagemPath, :status, :coletadoEm, :criadoEm, :criadoPor, :observacao
        )
        """,
        payload,
    )
    manifest_insert(
        conn,
        origem=origem,
        tabela_legada=table,
        registro_legado=sample or amostra_id,
        tabela_operacional="amostras",
        registro_operacional=amostra_id,
        payload=payload,
    )
    return True


def import_result(conn: sqlite3.Connection, origem: str, table: str, row: dict[str, str | None]) -> bool:
    patient = text(row.get("NumUnico") or row.get("NumPac") or row.get("paciente"))
    sample = text(row.get("amostra") or row.get("Amostra"))
    exam = text(row.get("Exame") or row.get("exame") or row.get("SubExame"))
    value = text(row.get("Valor") or row.get("resultado") or row.get("Resultado"))
    if not exam or not value:
        return False
    result_id = stable_id("RES", patient, sample, exam, value, row.get("DataLaudo") or row.get("data"))
    payload = {
        "id": result_id,
        "pacienteId": stable_id("PAC", patient, ""),
        "pedidoId": stable_id("PED", patient, exam),
        "amostraId": stable_id("AMO", patient, exam, sample),
        "exameId": stable_id("EXA", exam, exam),
        "valor": normalize_money(value),
        "unidade": text(row.get("Unidade") or row.get("unidade")),
        "referencia": text(row.get("Referencia") or row.get("referencia")),
        "critico": text(row.get("critico") or "NÃO"),
        "status": "IMPORTADO",
        "liberadoEm": text(row.get("DataLaudo") or row.get("data") or now_iso()),
        "criadoEm": now_iso(),
        "observacao": f"Importado de {table}",
    }
    payload["hashIntegridade"] = hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    ).hexdigest()
    conn.execute(
        """
        INSERT OR REPLACE INTO resultados (
            id, pacienteId, pedidoId, amostraId, exameId, valor, unidade,
            referencia, critico, status, liberadoEm, criadoEm, observacao, hashIntegridade
        ) VALUES (
            :id, :pacienteId, :pedidoId, :amostraId, :exameId, :valor, :unidade,
            :referencia, :critico, :status, :liberadoEm, :criadoEm, :observacao, :hashIntegridade
        )
        """,
        payload,
    )
    manifest_insert(
        conn,
        origem=origem,
        tabela_legada=table,
        registro_legado=result_id,
        tabela_operacional="resultados",
        registro_operacional=result_id,
        payload=payload,
    )
    return True


def load_sql_files(legacy_root: Path, operational_db: Path) -> LoadStats:
    if not legacy_root.exists():
        raise OperationalLoadError(f"Pasta de dados legados nao encontrada: {legacy_root}")
    sql_files = sorted((legacy_root / "sql_extraido").rglob("*.sql"))
    if not sql_files:
        raise OperationalLoadError(f"Nenhum SQL extraido encontrado em: {legacy_root / 'sql_extraido'}")

    operational_db.parent.mkdir(parents=True, exist_ok=True)
    stats = LoadStats(sql_files=len(sql_files))
    with sqlite3.connect(operational_db) as conn:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")
        ensure_schema(conn)
        for sql_path in sql_files:
            origem = str(sql_path.relative_to(legacy_root))
            for table, columns, values in iter_target_inserts(sql_path):
                row = row_to_dict(columns, values)
                imported = False
                if table in {"pacsec", "paciente", "pacientes"}:
                    imported = import_patient(conn, origem, table, row)
                    stats.pacientes += int(imported)
                elif table == "exames" and ("nome" in row or "Nome" in row or "titulo" in row):
                    imported = import_exam_catalog(conn, origem, table, row)
                    stats.exames_catalogo += int(imported)
                elif table == "pedidos":
                    imported = import_order(conn, origem, table, row)
                    stats.pedidos += int(imported)
                elif table == "amostras":
                    imported = import_sample(conn, origem, table, row)
                    stats.amostras += int(imported)
                elif table == "resultados":
                    imported = import_result(conn, origem, table, row)
                    stats.resultados += int(imported)
                if not imported:
                    stats.ignored_rows += 1
            conn.commit()
    return stats


def write_manifest(path: Path, stats: LoadStats, operational_db: Path) -> None:
    manifest = {
        "sistema": "KRISTAL LABORATORIAL",
        "banco_operacional": str(operational_db),
        "arquivos_sql_processados": stats.sql_files,
        "pacientes_importados_ou_atualizados": stats.pacientes,
        "exames_catalogo_importados_ou_atualizados": stats.exames_catalogo,
        "pedidos_importados_ou_atualizados": stats.pedidos,
        "amostras_importadas_ou_atualizadas": stats.amostras,
        "resultados_importados_ou_atualizados": stats.resultados,
        "linhas_ignoradas_sem_mapeamento_operacional": stats.ignored_rows,
        "gerado_em": now_iso(),
    }
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def export_counts_csv(operational_db: Path, output: Path) -> None:
    tables = ["pacientes", "exames", "pedidos", "amostras", "resultados", "legacy_operational_manifest"]
    with sqlite3.connect(operational_db) as conn, output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, delimiter=";")
        writer.writerow(["tabela", "total"])
        for table in tables:
            total = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            writer.writerow([table, total])


def main() -> int:
    parser = argparse.ArgumentParser(description="Carrega SQL legado KRISTAL no banco operacional SQLite.")
    parser.add_argument("--legacy-root", required=True, help="Pasta dados_legados_kristal.")
    parser.add_argument("--operational-db", required=True, help="Banco SQLite operacional KRISTAL.")
    args = parser.parse_args()

    legacy_root = Path(args.legacy_root)
    operational_db = Path(args.operational_db)
    stats = load_sql_files(legacy_root, operational_db)
    write_manifest(legacy_root / "manifesto_carga_operacional_kristal.json", stats, operational_db)
    export_counts_csv(operational_db, legacy_root / "contadores_operacionais_kristal.csv")
    print(json.dumps(stats.__dict__, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

