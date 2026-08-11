from __future__ import annotations

import unittest

from fastapi import HTTPException

from app.routes import _validate_cdm_procedures


class CdmValidationTests(unittest.TestCase):
    def test_accepts_complete_procedure(self) -> None:
        _validate_cdm_procedures(
            [
                {
                    "Codigo_CBHPM": "40302040",
                    "Codigo_SubGrupoCBHMP": "001",
                    "ValorUnitario": "23.35",
                    "Quantidade": 1,
                }
            ]
        )

    def test_rejects_missing_subgroup(self) -> None:
        with self.assertRaises(HTTPException):
            _validate_cdm_procedures(
                [
                    {
                        "Codigo_CBHPM": "40302040",
                        "Codigo_SubGrupoCBHMP": "",
                        "ValorUnitario": "23.35",
                        "Quantidade": 1,
                    }
                ]
            )

    def test_rejects_non_positive_value(self) -> None:
        with self.assertRaises(HTTPException):
            _validate_cdm_procedures(
                [
                    {
                        "Codigo_CBHPM": "40302040",
                        "Codigo_SubGrupoCBHMP": "001",
                        "ValorUnitario": "0",
                        "Quantidade": 1,
                    }
                ]
            )

    def test_rejects_fractional_quantity(self) -> None:
        with self.assertRaises(HTTPException):
            _validate_cdm_procedures(
                [
                    {
                        "Codigo_CBHPM": "40302040",
                        "Codigo_SubGrupoCBHMP": "001",
                        "ValorUnitario": "23.35",
                        "Quantidade": "1.5",
                    }
                ]
            )


if __name__ == "__main__":
    unittest.main()
