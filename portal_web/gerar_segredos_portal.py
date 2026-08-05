from __future__ import annotations

import secrets
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / '.env'
SECRET_FILE = ROOT / 'SEGREDOS_INICIAIS_ADMIN.txt'
CONFIG_PASSWORD_FILE = ROOT.parent / 'config' / 'superusuario.env'

DEFAULTS = {
    'KRISTAL_PORTAL_HOST': '0.0.0.0',
    'KRISTAL_PORTAL_PORT': '8787',
    'KRISTAL_ADMIN_LOGIN': 'Kristal',
    'KRISTAL_SUPERUSER_PASSWORD': '',
    'KRISTAL_DB_PATH': 'data/kristal_portal.db',
    'KRISTAL_STORAGE_DIR': 'storage',
    'KRISTAL_BACKUP_DIR': 'backups',
    'KRISTAL_SIRE_BASE_URL': 'https://sire2025.eb.mil.br/P002_SIRE2025_BL/rest/PostCDM',
    'KRISTAL_SIRE_USERNAME': '',
    'KRISTAL_SIRE_PASSWORD': '',
    'KRISTAL_SIRE_AUTO_CDM': '1',
    'KRISTAL_SIRE_PLANO_INTERNO_ID': '',
    'KRISTAL_SIRE_PERCENTUAL_DESCONTO': '20',
}

PLACEHOLDERS = {
    'KRISTAL_SECRET_KEY': {'', 'troque_por_uma_chave_forte_com_64_caracteres'},
    'KRISTAL_API_KEY': {''},
}

ORDER = [
    'KRISTAL_PORTAL_HOST',
    'KRISTAL_PORTAL_PORT',
    'KRISTAL_SECRET_KEY',
    'KRISTAL_ADMIN_LOGIN',
    'KRISTAL_SUPERUSER_PASSWORD',
    'KRISTAL_DB_PATH',
    'KRISTAL_STORAGE_DIR',
    'KRISTAL_API_KEY',
    'KRISTAL_BACKUP_DIR',
    'KRISTAL_SIRE_BASE_URL',
    'KRISTAL_SIRE_USERNAME',
    'KRISTAL_SIRE_PASSWORD',
    'KRISTAL_SIRE_AUTO_CDM',
    'KRISTAL_SIRE_PLANO_INTERNO_ID',
    'KRISTAL_SIRE_PERCENTUAL_DESCONTO',
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



def load_config_password() -> str:
    if not CONFIG_PASSWORD_FILE.exists():
        return ''
    for line in CONFIG_PASSWORD_FILE.read_text(encoding='utf-8').splitlines():
        clean = line.strip()
        if not clean or clean.startswith('#') or '=' not in clean:
            continue
        key, value = clean.split('=', 1)
        if key.strip() == 'KRISTAL_SUPERUSER_PASSWORD':
            return value.strip()
    return ''

def main() -> None:
    values = load_env()
    changed = False
    if values.get('KRISTAL_SECRET_KEY', '') in PLACEHOLDERS['KRISTAL_SECRET_KEY']:
        values['KRISTAL_SECRET_KEY'] = 'ks_' + secrets.token_urlsafe(64)
        changed = True

    config_password = load_config_password()
    if not values.get('KRISTAL_SUPERUSER_PASSWORD', '') and config_password:
        values['KRISTAL_SUPERUSER_PASSWORD'] = config_password
        changed = True

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

    if not SECRET_FILE.exists():
        SECRET_FILE.write_text(
            'KRISTAL LABORATORIAL - SEGREDOS INICIAIS\n'
            'Guarde este arquivo em local seguro e restrito.\n'
            'Nao envie este arquivo por e-mail, chat ou pasta compartilhada.\n\n'
            f'Admin login: {values["KRISTAL_ADMIN_LOGIN"]}\n'
            f'Superusuario senha: {values["KRISTAL_SUPERUSER_PASSWORD"]}\n'
            f'API key: {values["KRISTAL_API_KEY"]}\n',
            encoding='utf-8',
        )

    print('Segredos do portal verificados. Arquivo restrito: ' + str(SECRET_FILE))


if __name__ == '__main__':
    main()
