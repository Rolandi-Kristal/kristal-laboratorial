from __future__ import annotations

import secrets
import string
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / '.env'
SECRET_FILE = ROOT / 'SEGREDOS_INICIAIS_ADMIN.txt'

DEFAULTS = {
    'KRISTAL_PORTAL_HOST': '0.0.0.0',
    'KRISTAL_PORTAL_PORT': '8787',
    'KRISTAL_ADMIN_LOGIN': 'Kristal',
    'KRISTAL_DB_PATH': 'data/kristal_portal.db',
    'KRISTAL_STORAGE_DIR': 'storage',
    'KRISTAL_BACKUP_DIR': 'backups',
    'KRISTAL_SIRE_BASE_URL': 'https://sire2025.eb.mil.br/P002_SIRE2025_BL/rest/PostCDM',
    'KRISTAL_SIRE_USERNAME': '',
    'KRISTAL_SIRE_PASSWORD': '',
}

PLACEHOLDERS = {
    'KRISTAL_SECRET_KEY': {'', 'troque_por_uma_chave_forte_com_64_caracteres'},
    'KRISTAL_ADMIN_PASSWORD': {'', 'troque_esta_senha'},
    'KRISTAL_API_KEY': {''},
}

ORDER = [
    'KRISTAL_PORTAL_HOST',
    'KRISTAL_PORTAL_PORT',
    'KRISTAL_SECRET_KEY',
    'KRISTAL_ADMIN_LOGIN',
    'KRISTAL_ADMIN_PASSWORD',
    'KRISTAL_DB_PATH',
    'KRISTAL_STORAGE_DIR',
    'KRISTAL_API_KEY',
    'KRISTAL_BACKUP_DIR',
    'KRISTAL_SIRE_BASE_URL',
    'KRISTAL_SIRE_USERNAME',
    'KRISTAL_SIRE_PASSWORD',
]


def load_env() -> dict[str, str]:
    values: dict[str, str] = dict(DEFAULTS)
    if not ENV_PATH.exists():
        return values
    for line in ENV_PATH.read_text(encoding='utf-8').splitlines():
        clean = line.strip()
        if not clean or clean.startswith('#') or '=' not in clean:
            continue
        key, value = clean.split('=', 1)
        values[key.strip()] = value.strip()
    return values


def strong_password(length: int = 28) -> str:
    alphabet = string.ascii_letters + string.digits + '!@#$%*_-+=?'
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def main() -> None:
    values = load_env()
    changed = False
    generated_password = False

    if values.get('KRISTAL_SECRET_KEY', '') in PLACEHOLDERS['KRISTAL_SECRET_KEY']:
        values['KRISTAL_SECRET_KEY'] = 'ks_' + secrets.token_urlsafe(64)
        changed = True

    if values.get('KRISTAL_ADMIN_PASSWORD', '') in PLACEHOLDERS['KRISTAL_ADMIN_PASSWORD']:
        values['KRISTAL_ADMIN_PASSWORD'] = strong_password()
        changed = True
        generated_password = True

    if values.get('KRISTAL_API_KEY', '') in PLACEHOLDERS['KRISTAL_API_KEY']:
        values['KRISTAL_API_KEY'] = 'klab_' + secrets.token_urlsafe(40)
        changed = True

    for key, value in DEFAULTS.items():
        values.setdefault(key, value)

    if changed or not ENV_PATH.exists():
        lines = [f'{key}={values[key]}' for key in ORDER if key in values]
        for key in sorted(set(values) - set(ORDER)):
            lines.append(f'{key}={values[key]}')
        ENV_PATH.write_text('\n'.join(lines) + '\n', encoding='utf-8')

    if generated_password or not SECRET_FILE.exists():
        SECRET_FILE.write_text(
            'KRISTAL LABORATORIAL - SEGREDOS INICIAIS\n'
            'Guarde este arquivo em local seguro e restrito.\n'
            'Nao envie este arquivo por e-mail, chat ou pasta compartilhada.\n\n'
            f'Admin login: {values["KRISTAL_ADMIN_LOGIN"]}\n'
            f'Admin senha: {values["KRISTAL_ADMIN_PASSWORD"]}\n'
            f'API key: {values["KRISTAL_API_KEY"]}\n',
            encoding='utf-8',
        )

    print('Segredos do portal verificados. Arquivo restrito: ' + str(SECRET_FILE))


if __name__ == '__main__':
    main()
