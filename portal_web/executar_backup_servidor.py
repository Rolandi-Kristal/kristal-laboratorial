from __future__ import annotations

import json
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / ".env"


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    if ENV_PATH.exists():
        for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
            clean = line.strip()
            if clean and not clean.startswith("#") and "=" in clean:
                key, value = clean.split("=", 1)
                values[key.strip()] = value.strip()
    return values


def main() -> int:
    values = load_env()
    api_key = values.get("KRISTAL_API_KEY", "").strip()
    host = values.get("KRISTAL_PORTAL_HOST", "127.0.0.1").strip()
    port = values.get("KRISTAL_PORTAL_PORT", "8787").strip()
    if host == "0.0.0.0":
        host = "127.0.0.1"
    if not api_key:
        print("ERRO: KRISTAL_API_KEY ausente no .env.", file=sys.stderr)
        return 2

    require_tls = values.get("KRISTAL_REQUIRE_TLS", "0").strip().lower() in {
        "1",
        "sim",
        "true",
        "yes",
    }
    scheme = "https" if require_tls else "http"
    url = f"{scheme}://{host}:{port}/api/server/backup"
    request = urllib.request.Request(
        url,
        data=b"",
        method="POST",
        headers={"X-API-Key": api_key, "Accept": "application/json"},
    )
    context: ssl.SSLContext | None = None
    if require_tls:
        cert_file = Path(values.get("KRISTAL_TLS_CERT_FILE", "")).expanduser()
        ca_file = cert_file.parent / "KRISTAL_HMR_CA.cert.pem"
        if not ca_file.is_file():
            print(f"ERRO: CA TLS ausente: {ca_file}", file=sys.stderr)
            return 5
        context = ssl.create_default_context(cafile=str(ca_file))

    try:
        with urllib.request.urlopen(request, timeout=16200, context=context) as response:
            payload = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        print(error.read().decode("utf-8", errors="replace"), file=sys.stderr)
        return 3
    except urllib.error.URLError as error:
        print(f"ERRO: falha ao chamar backup: {error.reason}", file=sys.stderr)
        return 4
    print(json.dumps(json.loads(payload), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
