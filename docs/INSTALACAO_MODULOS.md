# KRISTAL LABORATORIAL - módulos funcionais reais

Copie a pasta `lib` deste pacote para dentro do projeto Flutter `D:\kristal_laboratorial`.

## Dependências necessárias no pubspec.yaml

```yaml
dependencies:
  uuid: ^4.5.1
  crypto: ^3.0.6
  path: ^1.9.1
  path_provider: ^2.1.5
  sqflite_common_ffi: ^2.3.6
```

## Telas incluídas

- Etiquetas por exame.
- Leitura laser/USB.
- Backup manual e automático.
- Portal Web do Paciente.
- Equipamentos e drivers laboratoriais.

## Equipamentos mapeados da imagem

- Audmax
- BC5380
- BH-5390
- BS360E
- Coagmaster
- LabmaxPremium
- Urivision720

Compatibilidade real depende do protocolo disponibilizado pelo fabricante/driver: ASTM, HL7, CSV, TCP/IP, Serial COM/RS-232 ou arquivo exportado.
