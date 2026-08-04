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
    backup_dir: str

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
            admin_password=os.getenv("KRISTAL_SUPERUSER_PASSWORD", ""),
            db_path=os.getenv("KRISTAL_DB_PATH", "data/kristal_portal.db"),
            storage_dir=os.getenv("KRISTAL_STORAGE_DIR", "storage"),
            api_key=os.getenv("KRISTAL_API_KEY", ""),
            sire_base_url=os.getenv("KRISTAL_SIRE_BASE_URL", "https://sire2025.eb.mil.br/P002_SIRE2025_BL/rest/PostCDM"),
            sire_username=os.getenv("KRISTAL_SIRE_USERNAME", ""),
            sire_password=os.getenv("KRISTAL_SIRE_PASSWORD", ""),
            backup_dir=os.getenv("KRISTAL_BACKUP_DIR", "backups"),
        )
