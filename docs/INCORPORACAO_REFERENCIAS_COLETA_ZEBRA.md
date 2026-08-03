# Incorporação de Referências de Coleta e Zebra/ZD5

## Origem

- `WhatsApp Unknown 2026-08-03 at 19.26.28.zip`: imagens de referência da interface de informações dos exames/coleta.
- Referência documental KRISTAL: documentação HTML de rotinas laboratoriais, exames, amostras e gerenciamento.
- `ZD5-1-17-7415.rar`: pacote de driver Zebra/ZD5 para impressão de etiquetas.

## Decisão técnica

As imagens de WhatsApp foram usadas como referência de campos e fluxo, mas não foram embutidas no aplicativo para evitar carregar dados visuais potencialmente sensíveis. A tela `Amostras / Coleta de Exames` foi ampliada com os campos operacionais necessários.

A referência documental foi normalizada para o padrão KRISTAL. O sistema mantém somente identidade KRISTAL em telas, manifestos e documentação.

O pacote Zebra/ZD5 foi tratado como driver externo controlado. O script `scripts/install_zebra_zd5_driver.ps1` instala o INF via `pnputil` e só executa instalador EXE quando autorizado.

## Arquivos criados

- `config/coleta/exames_interface_referencia_manifest.json`
- `config/coleta/referencia_laboratorial_externa_manifest.json`
- `config/drivers/impressoras/zebra_zd5_manifest.json`
- `scripts/install_zebra_zd5_driver.ps1`

## Produção

Para instalar driver da impressora de etiquetas no servidor/estação:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_zebra_zd5_driver.ps1 -DriverRoot "D:\kristal_laboratorial\drivers\impressoras\zebra_zd5\ZD5-1-17-7415"
```

Para executar o instalador Zebra interativo, acrescente:

```powershell
-AllowPrinterInstaller
```
