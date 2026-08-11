from __future__ import annotations

import importlib.util
import json
import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from types import ModuleType


PROJECT_ROOT = Path(__file__).resolve().parents[2]


def load_script(name: str) -> ModuleType:
    path = PROJECT_ROOT / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Nao foi possivel carregar {path}.")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class LegacyLoaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.operational = load_script("carregar_dados_legados_operacional_kristal")
        cls.raw = load_script("carregar_todos_dados_brutos_legados_kristal")

    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name) / "dados_legados_kristal"
        self.sql_root = self.root / "sql_extraido" / "fonte"
        self.sql_root.mkdir(parents=True)
        self.database = Path(self.temp_dir.name) / "kristal_laboratorial.db"

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def write_sql(self, content: str) -> None:
        (self.sql_root / "dados.sql").write_text(content, encoding="utf-8")

    def test_split_insert_values_preserves_escapes_and_null(self) -> None:
        rows = list(
            self.raw.split_insert_values(
                "('1','Nome, Completo','linha\\nseguinte',NULL),"
                "('2','D\\'Ávila','texto','')"
            )
        )
        self.assertEqual(rows[0], ["1", "Nome, Completo", "linha\nseguinte", None])
        self.assertEqual(rows[1], ["2", "D'Ávila", "texto", ""])

    def test_raw_schema_migration_preserves_latest_unique_line(self) -> None:
        with closing(sqlite3.connect(self.database)) as connection:
            connection.execute(
                "CREATE TABLE legacy_raw_rows (id TEXT PRIMARY KEY, origem TEXT, "
                "tabela_legada TEXT, indice_linha INTEGER, dados_json TEXT, "
                "hash_integridade TEXT, importado_em TEXT)"
            )
            connection.executemany(
                "INSERT INTO legacy_raw_rows VALUES (?, ?, ?, ?, ?, ?, ?)",
                [
                    ("ANTIGO", "fonte", "dados", 1, "{}", "h1", "2026-08-10"),
                    ("NOVO", "fonte", "dados", 1, "{}", "h2", "2026-08-11"),
                ],
            )
            connection.commit()
            self.raw.ensure_schema(connection)
            table_sql = connection.execute(
                "SELECT sql FROM sqlite_master WHERE name = 'legacy_raw_rows'"
            ).fetchone()[0]
            rows = connection.execute(
                "SELECT id, hash_integridade FROM legacy_raw_rows"
            ).fetchall()
        self.assertIn("WITHOUT ROWID", table_sql.upper())
        self.assertEqual(rows, [("NOVO", "h2")])

    def test_operational_load_maps_patient_and_is_idempotent(self) -> None:
        self.write_sql(
            "CREATE TABLE `pacientes` (`Nome` text, `CPF` text, `RegHos` text);\n"
            "INSERT INTO `pacientes` VALUES ('PACIENTE TESTE','123.456.789-09','42');\n"
            "CREATE TABLE `resultados` (`NumPac` text, `Exame` text, `Valor` text);\n"
            "INSERT INTO `resultados` VALUES ('42','GLI','5.3'),('42','CULT','NEGATIVO');\n"
        )
        first = self.operational.load_sql_files(self.root, self.database)
        second = self.operational.load_sql_files(self.root, self.database)

        self.assertEqual(first.pacientes, 1)
        self.assertEqual(first.resultados, 2)
        self.assertEqual(second.pacientes, 1)
        self.assertEqual(second.resultados, 2)
        with closing(sqlite3.connect(self.database)) as connection:
            row = connection.execute(
                "SELECT nome, cpf, preccp FROM pacientes"
            ).fetchone()
            total = connection.execute("SELECT COUNT(*) FROM pacientes").fetchone()[0]
            result_values = connection.execute(
                "SELECT valor FROM resultados ORDER BY valor"
            ).fetchall()
        self.assertEqual(row, ("PACIENTE TESTE", "12345678909", "42"))
        self.assertEqual(total, 1)
        self.assertEqual(result_values, [("5.3",), ("NEGATIVO",)])
    def test_raw_load_preserves_unknown_table_and_does_not_duplicate(self) -> None:
        self.write_sql(
            "CREATE TABLE `tabela_sem_mapeamento` (`id` int, `conteudo` text);\n"
            "INSERT INTO `tabela_sem_mapeamento` VALUES (1,'A'),(2,NULL);\n"
        )
        first = self.raw.load_raw_rows(self.root, self.database)
        second = self.raw.load_raw_rows(self.root, self.database)

        self.assertEqual(first.raw_rows, 2)
        self.assertEqual(second.raw_rows, 0)
        with closing(sqlite3.connect(self.database)) as connection:
            total = connection.execute("SELECT COUNT(*) FROM legacy_raw_rows").fetchone()[0]
            status = connection.execute(
                "SELECT status, linhas_brutas FROM legacy_raw_progress"
            ).fetchone()
        self.assertEqual(total, 2)
        self.assertEqual(status, ("CONCLUIDO", 2))

    def test_raw_load_resumes_an_interrupted_source(self) -> None:
        self.write_sql(
            "CREATE TABLE dados (id int, valor text);\n"
            "INSERT INTO dados VALUES (1,'A'),(2,'B'),(3,'C');\n"
        )
        origem = str((self.sql_root / "dados.sql").relative_to(self.root))
        with closing(sqlite3.connect(self.database)) as connection:
            self.raw.ensure_schema(connection)
            connection.execute(
                "INSERT INTO legacy_raw_rows VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    "RAW-PRESERVADO",
                    origem,
                    "dados",
                    1,
                    '{"id":"1","valor":"A"}',
                    "hash",
                    "2026-08-11T00:00:00",
                ),
            )
            connection.execute(
                "INSERT INTO legacy_raw_progress VALUES (?, 'PROCESSANDO', 1, ?)",
                (origem, "2026-08-11T00:00:00"),
            )
            connection.commit()

        stats = self.raw.load_raw_rows(self.root, self.database)
        with closing(sqlite3.connect(self.database)) as connection:
            total = connection.execute(
                "SELECT COUNT(*) FROM legacy_raw_rows"
            ).fetchone()[0]
            status = connection.execute(
                "SELECT status, linhas_brutas FROM legacy_raw_progress"
            ).fetchone()
        self.assertEqual(stats.raw_rows, 2)
        self.assertEqual(total, 3)
        self.assertEqual(status, ("CONCLUIDO", 3))
        with closing(sqlite3.connect(self.database)) as connection:
            with self.assertRaises(sqlite3.IntegrityError):
                connection.execute(
                    "INSERT INTO legacy_raw_rows VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (
                        "OUTRO-ID",
                        origem,
                        "dados",
                        1,
                        "{}",
                        "outro",
                        "2026-08-11",
                    ),
                )

    def test_raw_load_uses_indexed_column_names_for_data_only_sql(self) -> None:
        source_key = "fonte12345678901"
        self.sql_root.rename(self.sql_root.parent / source_key)
        self.sql_root = self.sql_root.parent / source_key
        self.write_sql("INSERT INTO `pacsec` VALUES ('42','PACIENTE TESTE');\n")
        index_path = self.root / "kristal_dados_legados.sqlite3"
        with closing(sqlite3.connect(index_path)) as connection:
            connection.execute(
                "CREATE TABLE legacy_table_schemas ("
                "id INTEGER PRIMARY KEY, source_sha256 TEXT, table_name TEXT, columns_json TEXT)"
            )
            connection.execute(
                "INSERT INTO legacy_table_schemas "
                "(source_sha256, table_name, columns_json) VALUES (?, ?, ?)",
                (source_key + "0" * 59, "pacsec", json.dumps(["RegHos", "Nome"])),
            )
            connection.commit()

        stats = self.raw.load_raw_rows(self.root, self.database)
        with closing(sqlite3.connect(self.database)) as connection:
            payload = connection.execute(
                "SELECT dados_json FROM legacy_raw_rows"
            ).fetchone()[0]
        self.assertEqual(stats.raw_rows, 1)
        self.assertEqual(json.loads(payload), {"Nome": "PACIENTE TESTE", "RegHos": "42"})
    def test_raw_load_selects_schema_variant_by_row_width(self) -> None:
        source_key = "fonte12345678901"
        self.sql_root.rename(self.sql_root.parent / source_key)
        self.sql_root = self.sql_root.parent / source_key
        self.write_sql(
            "INSERT INTO `log` VALUES ('TIPO','2026-08-11','DESCRICAO');\n"
            "INSERT INTO `log` VALUES ('1','LOCAL','USR','42','DATA','TEXTO','RASTRO','JUST');\n"
        )
        index_path = self.root / "kristal_dados_legados.sqlite3"
        variants = [
            ["comp", "ip", "arquivo", "tipo", "ant", "nova", "erro", "descr", "data"],
            ["tipo", "data", "descricao"],
            ["SequenciaLog", "LocalLog", "CodigoUsuario", "NumPac", "DataCadastroLog", "TextoLog", "LocalRastreabilidade", "JustificativaID"],
        ]
        with closing(sqlite3.connect(index_path)) as connection:
            connection.execute(
                "CREATE TABLE legacy_table_schemas ("
                "id INTEGER PRIMARY KEY, source_sha256 TEXT, table_name TEXT, columns_json TEXT)"
            )
            connection.executemany(
                "INSERT INTO legacy_table_schemas "
                "(source_sha256, table_name, columns_json) VALUES (?, 'log', ?)",
                [(source_key + "0" * 59, json.dumps(columns)) for columns in variants],
            )
            connection.commit()

        self.raw.load_raw_rows(self.root, self.database)
        with closing(sqlite3.connect(self.database)) as connection:
            payloads = [
                json.loads(row[0])
                for row in connection.execute(
                    "SELECT dados_json FROM legacy_raw_rows ORDER BY indice_linha"
                ).fetchall()
            ]
        self.assertEqual(payloads[0]["descricao"], "DESCRICAO")
        self.assertEqual(payloads[1]["NumPac"], "42")
        self.assertEqual(payloads[1]["JustificativaID"], "JUST")

    def test_raw_load_uses_positional_keys_for_ambiguous_equal_width_schemas(self) -> None:
        source_key = "fonte12345678901"
        self.sql_root.rename(self.sql_root.parent / source_key)
        self.sql_root = self.sql_root.parent / source_key
        self.write_sql("INSERT INTO `log` VALUES ('A','B');\n")
        index_path = self.root / "kristal_dados_legados.sqlite3"
        with closing(sqlite3.connect(index_path)) as connection:
            connection.execute(
                "CREATE TABLE legacy_table_schemas ("
                "id INTEGER PRIMARY KEY, source_sha256 TEXT, table_name TEXT, columns_json TEXT)"
            )
            connection.executemany(
                "INSERT INTO legacy_table_schemas "
                "(source_sha256, table_name, columns_json) VALUES (?, 'log', ?)",
                [
                    (source_key + "0" * 59, json.dumps(["primeiro", "segundo"])),
                    (source_key + "0" * 59, json.dumps(["campo_a", "campo_b"])),
                ],
            )
            connection.commit()

        self.raw.load_raw_rows(self.root, self.database)
        with closing(sqlite3.connect(self.database)) as connection:
            payload = json.loads(
                connection.execute("SELECT dados_json FROM legacy_raw_rows").fetchone()[0]
            )
        self.assertEqual(payload, {"0": "A", "1": "B"})
    def test_loaders_reject_missing_or_empty_sources(self) -> None:
        missing = self.root / "inexistente"
        with self.assertRaises(self.operational.OperationalLoadError):
            self.operational.load_sql_files(missing, self.database)
        with self.assertRaises(self.raw.RawLoadError):
            self.raw.load_raw_rows(self.root, self.database)


if __name__ == "__main__":
    unittest.main()
