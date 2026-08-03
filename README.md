# KRISTAL LABORATORIAL

Sistema laboratorial exclusivo para Windows com módulos de pacientes, exames, pedidos, amostras, resultados, laudos, estoque, qualidade, equipamentos, worklist, reagentes, calibrações, indicadores, exportação CSV e integrações ASTM/HL7.

## Segurança

Credenciais, bancos, backups, certificados privados, `.env`, chaves API e arquivos de produção não devem ser versionados.

A senha inicial do superusuário deve ser definida no ambiente de implantação ou no build seguro, por exemplo:

```bat
flutter build windows --release --dart-define=KRISTAL_DEFAULT_SUPER_PASSWORD=SENHA_FORTE_LOCAL
```

## Compilar no Windows

```bat
flutter pub get
flutter create --platforms=windows .
flutter analyze
flutter test
flutter build windows --release
```

Crédito do sistema: **Desenvolvedor: 3º Sgt Rolandi - H Mil Resende**.
