# KRISTAL LABORATORIAL - Instalação

1. Crie projeto limpo quando necessário:

```bat
flutter create --platforms=windows kristal_laboratorial
```

2. Copie o código fonte do repositório para a pasta do projeto.

3. Rode:

```bat
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

4. Para build de produção, defina a senha inicial por variável segura de build ou pelo procedimento de provisionamento do servidor. Não grave senha real em documentação ou Git.

Crédito do sistema:
Desenvolvedor: 3º Sgt Rolandi - H Mil Resende
