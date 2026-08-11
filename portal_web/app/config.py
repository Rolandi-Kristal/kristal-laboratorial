from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    host: str
    port: int
    secret_key: str
    admin_login: str
    admin_password: str
    db_path: str
    storage_dir: str
    api_key: str
    sire_base_url: str
    sire_username: str
    sire_password: str
    sire_auto_cdm: bool
    sire_default_plano_interno_id: str
    sire_default_percentual_desconto: int
    backup_dir: str
    corporate_db_path: str
    operational_db_path: str
    backup_schedule_file: str
    tls_cert_file: str
    tls_key_file: str
    require_tls: bool

    @staticmethod
    def _load_env_file(path: str = ".env") -> None:
        if not os.path.exists(path):
            return
        with open(path, "r", encoding="utf-8") as file:
            for line in file:
                clean = line.strip()
                if not clean or clean.startswith("#") or "=" not in clean:
                    continue
                key, value = clean.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())

    @classmethod
    def from_env(cls) -> "Settings":
        cls._load_env_file()
        return cls(
            host=os.getenv("KRISTAL_PORTAL_HOST", "0.0.0.0"),
            port=int(os.getenv("KRISTAL_PORTAL_PORT", "8787")),
            secret_key=os.getenv("KRISTAL_SECRET_KEY", "troque_por_uma_chave_forte_com_64_caracteres"),
            admin_login=os.getenv("KRISTAL_ADMIN_LOGIN", "Kristal"),
            admin_password=os.getenv("KRISTAL_SUPERUSER_PASSWORD", "").strip() or os.getenv("KRISTAL_ADMIN_PASSWORD", "").strip(),
            db_path=os.getenv("KRISTAL_DB_PATH", "data/kristal_portal.db"),
            storage_dir=os.getenv("KRISTAL_STORAGE_DIR", "storage"),
            api_key=os.getenv("KRISTAL_API_KEY", ""),
            sire_base_url=os.getenv("KRISTAL_SIRE_BASE_URL", "https://sire2025.eb.mil.br/P002_SIRE2025_BL/rest/PostCDM"),
            sire_username=os.getenv("KRISTAL_SIRE_USERNAME", ""),
            sire_password=os.getenv("KRISTAL_SIRE_PASSWORD", ""),
            sire_auto_cdm=os.getenv("KRISTAL_SIRE_AUTO_CDM", "1").strip().lower() in {"1", "sim", "true", "yes"},
            sire_default_plano_interno_id=os.getenv("KRISTAL_SIRE_PLANO_INTERNO_ID", ""),
            sire_default_percentual_desconto=int(os.getenv("KRISTAL_SIRE_PERCENTUAL_DESCONTO", "20")),
            backup_dir=os.getenv("KRISTAL_BACKUP_DIR", "backups"),
            corporate_db_path=os.getenv("KRISTAL_CORPORATE_DB_PATH", "../data/kristal_corporativo.db"),
            operational_db_path=os.getenv("KRISTAL_OPERATIONAL_DB_PATH", "../data/kristal_laboratorial.db"),
            backup_schedule_file=os.getenv("KRISTAL_BACKUP_SCHEDULE_FILE", "data/backup_schedule.json"),
            tls_cert_file=os.getenv("KRISTAL_TLS_CERT_FILE", "").strip(),
            tls_key_file=os.getenv("KRISTAL_TLS_KEY_FILE", "").strip(),
            require_tls=os.getenv("KRISTAL_REQUIRE_TLS", "0").strip().lower()
            in {"1", "sim", "true", "yes"},
        )
