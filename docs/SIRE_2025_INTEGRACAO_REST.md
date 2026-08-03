# KRISTAL LABORATORIAL - Integracao REST SIRE 2025

Fonte: arquivos fornecidos `SIRE 01.pdf`, `SIRE 02.pdf` e `SIRE 03.pdf`.

## Ambientes

- Producao: `https://sire2025.eb.mil.br/P002_SIRE2025_BL/rest/PostCDM`
- Homologacao: `https://hom-sire2025.sistemas.eb.mil.br/P002_SIRE2025_BL/rest/PostCDM`

## Autenticacao

Todas as chamadas usam autenticacao basica HTTP.

O sistema exige usuario e senha reais do SIRE para executar consulta ou emissao de CDM. Sem credenciais reais, nenhuma chamada externa e simulada.

## Consulta de beneficiario

`GET /GetBeneficiarioByCPF?CPF={CPF}`

Retorno esperado:

```json
{
  "BeneficiarioId": 1234567891234567,
  "Lista_PI": [
    {
      "PI_Id": 1234567891234567,
      "PI_Sigla": "",
      "PI_Descricao": "",
      "Saldo": 0.1
    }
  ]
}
```

## Emissao de CDM

`POST /PostCDM?BeneficiarioId={BeneficiarioId}&PlanoInternoId={PlanoInternoId}&PercentualDesconto={PercentualDesconto}`

`PercentualDesconto` aceito pelo sistema: `0`, `20` ou `100`.

Corpo JSON:

```json
[
  {
    "Codigo_CBHPM": 1234567891234567,
    "Codigo_SubGrupoCBHMP": 1234567891234567,
    "ValorUnitario": 0.1,
    "Quantidade": 0.1
  }
]
```

Retorno esperado:

```json
{
  "CDMId": 1234567891234567,
  "OutSuccess": false,
  "Message": ""
}
```

## Implementacao no KRISTAL

- Servico: `lib/services/sire_integration_service.dart`
- Tela: `lib/screens/financeiro_sire_screen.dart`
- A tela permite consultar CPF, preencher `BeneficiarioId`, `PlanoInternoId`, percentual de desconto, `Codigo_SubGrupoCBHMP`, valor unitario e enviar `PostCDM`.
- Exportacao CSV/TXT e abertura do executavel SIRE foram preservadas para compatibilidade operacional local.
