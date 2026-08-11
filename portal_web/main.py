from __future__ import annotations

import os
import uvicorn

from app.config import Settings
from app.database import Database
from app.routes import create_app


def main() -> None:
    settings = Settings.from_env()
    os.makedirs(os.path.dirname(settings.db_path), exist_ok=True)
    os.makedirs(settings.storage_dir, exist_ok=True)
    database = Database(settings.db_path)
    database.initialize(settings)
    app = create_app(settings=settings, database=database)
    cert_file = os.path.abspath(settings.tls_cert_file) if settings.tls_cert_file else ""
    key_file = os.path.abspath(settings.tls_key_file) if settings.tls_key_file else ""
    if bool(cert_file) != bool(key_file):
        raise RuntimeError("KRISTAL_TLS_CERT_FILE e KRISTAL_TLS_KEY_FILE devem ser configurados juntos.")
    if settings.require_tls and not cert_file:
        raise RuntimeError("TLS e obrigatorio em producao. Configure certificado e chave privada.")
    if cert_file and (not os.path.isfile(cert_file) or not os.path.isfile(key_file)):
        raise RuntimeError("Certificado ou chave TLS nao encontrado no servidor.")
    uvicorn.run(
        app,
        host=settings.host,
        port=settings.port,
        log_level="info",
        ssl_certfile=cert_file or None,
        ssl_keyfile=key_file or None,
    )


if __name__ == "__main__":
    main()
