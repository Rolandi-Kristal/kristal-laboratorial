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
    uvicorn.run(app, host=settings.host, port=settings.port, log_level="info")


if __name__ == "__main__":
    main()
