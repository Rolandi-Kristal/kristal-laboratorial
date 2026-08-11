from __future__ import annotations

import argparse
import ipaddress
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID


class TlsCertificateError(RuntimeError):
    pass


def _write_private_key(path: Path, key: rsa.RSAPrivateKey) -> None:
    path.write_bytes(
        key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        )
    )


def generate(*, output: Path, server_ip: str, dns_name: str, force: bool) -> dict[str, Path]:
    try:
        ip = ipaddress.ip_address(server_ip)
    except ValueError as error:
        raise TlsCertificateError(f"IP TLS invalido: {server_ip}") from error
    clean_dns = dns_name.strip().lower()
    if not clean_dns or any(char.isspace() for char in clean_dns):
        raise TlsCertificateError("Nome DNS TLS invalido.")

    output.mkdir(parents=True, exist_ok=True)
    paths = {
        "ca_key": output / "KRISTAL_HMR_CA.key.pem",
        "ca_cert": output / "KRISTAL_HMR_CA.cert.pem",
        "ca_der": output / "KRISTAL_HMR_CA.cer",
        "server_key": output / "KRISTAL_HMR_SERVIDOR.key.pem",
        "server_cert": output / "KRISTAL_HMR_SERVIDOR.cert.pem",
    }
    if not force and any(path.exists() for path in paths.values()):
        missing = [name for name, path in paths.items() if not path.is_file()]
        if missing:
            raise TlsCertificateError(
                "Conjunto TLS incompleto; use --force somente apos preservar backup: "
                + ", ".join(missing)
            )
        return paths

    now = datetime.now(timezone.utc)
    ca_key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    ca_name = x509.Name(
        [
            x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Hospital Militar de Resende"),
            x509.NameAttribute(NameOID.COMMON_NAME, "KRISTAL HMR CA"),
        ]
    )
    ca_cert = (
        x509.CertificateBuilder()
        .subject_name(ca_name)
        .issuer_name(ca_name)
        .public_key(ca_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(minutes=5))
        .not_valid_after(now + timedelta(days=3650))
        .add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True)
        .add_extension(
            x509.KeyUsage(
                digital_signature=True,
                content_commitment=False,
                key_encipherment=False,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=True,
                crl_sign=True,
                encipher_only=None,
                decipher_only=None,
            ),
            critical=True,
        )
        .add_extension(
            x509.SubjectKeyIdentifier.from_public_key(ca_key.public_key()),
            critical=False,
        )
        .sign(ca_key, hashes.SHA256())
    )

    server_key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    server_name = x509.Name(
        [
            x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Hospital Militar de Resende"),
            x509.NameAttribute(NameOID.COMMON_NAME, clean_dns),
        ]
    )
    server_cert = (
        x509.CertificateBuilder()
        .subject_name(server_name)
        .issuer_name(ca_cert.subject)
        .public_key(server_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(minutes=5))
        .not_valid_after(now + timedelta(days=825))
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(
            x509.SubjectAlternativeName(
                [
                    x509.IPAddress(ip),
                    x509.IPAddress(ipaddress.ip_address("127.0.0.1")),
                    x509.DNSName(clean_dns),
                    x509.DNSName("localhost"),
                ]
            ),
            critical=False,
        )
        .add_extension(
            x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]),
            critical=False,
        )
        .add_extension(
            x509.KeyUsage(
                digital_signature=True,
                content_commitment=False,
                key_encipherment=True,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=False,
                crl_sign=False,
                encipher_only=None,
                decipher_only=None,
            ),
            critical=True,
        )
        .sign(ca_key, hashes.SHA256())
    )

    _write_private_key(paths["ca_key"], ca_key)
    paths["ca_cert"].write_bytes(ca_cert.public_bytes(serialization.Encoding.PEM))
    paths["ca_der"].write_bytes(ca_cert.public_bytes(serialization.Encoding.DER))
    _write_private_key(paths["server_key"], server_key)
    paths["server_cert"].write_bytes(server_cert.public_bytes(serialization.Encoding.PEM))
    for path in paths.values():
        if not path.is_file() or path.stat().st_size == 0:
            raise TlsCertificateError(f"Arquivo TLS nao foi gerado: {path}")
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description="Gera CA e certificado TLS do servidor KRISTAL HMR.")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--server-ip", default="10.4.169.64")
    parser.add_argument("--dns-name", default="kristal-laboratorial.hmr.local")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    paths = generate(
        output=args.output,
        server_ip=args.server_ip,
        dns_name=args.dns_name,
        force=args.force,
    )
    for name, path in paths.items():
        print(f"{name}={os.path.abspath(path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())