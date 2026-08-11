from __future__ import annotations

import ipaddress
import tempfile
import unittest
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import serialization

from portal_web.gerar_certificado_tls import TlsCertificateError, generate


class TlsCertificateTests(unittest.TestCase):
    def test_generates_ca_and_server_certificate_with_expected_san(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            paths = generate(
                output=Path(temporary),
                server_ip="10.4.169.64",
                dns_name="kristal-laboratorial.hmr.local",
                force=False,
            )
            ca = x509.load_pem_x509_certificate(paths["ca_cert"].read_bytes())
            server = x509.load_pem_x509_certificate(paths["server_cert"].read_bytes())
            san = server.extensions.get_extension_for_class(x509.SubjectAlternativeName).value

            self.assertTrue(ca.extensions.get_extension_for_class(x509.BasicConstraints).value.ca)
            self.assertEqual(server.issuer, ca.subject)
            self.assertIn(ipaddress.ip_address("10.4.169.64"), san.get_values_for_type(x509.IPAddress))
            self.assertIn(ipaddress.ip_address("127.0.0.1"), san.get_values_for_type(x509.IPAddress))
            self.assertIn("kristal-laboratorial.hmr.local", san.get_values_for_type(x509.DNSName))
            self.assertIn("localhost", san.get_values_for_type(x509.DNSName))
            key = serialization.load_pem_private_key(paths["server_key"].read_bytes(), password=None)
            self.assertEqual(key.key_size, 3072)

    def test_preserves_complete_existing_certificate_set(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            first = generate(
                output=Path(temporary),
                server_ip="10.4.169.64",
                dns_name="kristal-laboratorial.hmr.local",
                force=False,
            )
            before = {name: path.read_bytes() for name, path in first.items()}
            second = generate(
                output=Path(temporary),
                server_ip="10.4.169.64",
                dns_name="kristal-laboratorial.hmr.local",
                force=False,
            )
            self.assertEqual(before, {name: path.read_bytes() for name, path in second.items()})

    def test_rejects_incomplete_existing_set(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            (output / "KRISTAL_HMR_CA.key.pem").write_text("incompleto", encoding="utf-8")
            with self.assertRaises(TlsCertificateError):
                generate(
                    output=output,
                    server_ip="10.4.169.64",
                    dns_name="kristal-laboratorial.hmr.local",
                    force=False,
                )

    def test_rejects_invalid_ip_and_dns(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(TlsCertificateError):
                generate(output=Path(temporary), server_ip="999.1.1.1", dns_name="kristal", force=False)
            with self.assertRaises(TlsCertificateError):
                generate(output=Path(temporary), server_ip="10.4.169.64", dns_name="nome invalido", force=False)


if __name__ == "__main__":
    unittest.main()