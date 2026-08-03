# KRISTAL LABORATORIAL - Matriz Funcional de Producao

## Area operacional

- Modulos: `Pacientes`, `Atendimento`, `Amostras`, `Resultados`.
- Finalidade: cadastro rapido de requisicoes, triagem, coleta, recebimento e liberacao.
- Armazenamento: banco/local store permanente com auditoria.

## Rastreabilidade

- Modulos: `Amostras`, `Codigo de Barras / Etiquetas`, `Leitura de Etiqueta`.
- Finalidade: emissao e leitura de etiquetas por codigo de barras/QR Code, vinculadas a pedido, exame e amostra.

## Interfaceamento

- Modulos: `Worklist ASTM/HL7`, `Equipamentos`, `Financeiro SIRE`, `Servidor / Nuvem`.
- Protocolos suportados no sistema: ASTM, HL7, CSV, TXT, XML, TCP/IP, Serial COM/RS-232 e pasta monitorada.
- Integracao SIRE REST 2025: `GetBeneficiarioByCPF` e `PostCDM`.

## Laudos e entrega

- Modulos: `Laudos PDF`, `Avisos e Entrega`, `Portal do Paciente`, `Usuarios`.
- Recursos: PDF, hash, assinatura profissional, responsavel tecnico, portal web, download/impressao, URL/QR Code e rastreio de aviso por e-mail/SMS.
- Envio e-mail/SMS depende de endpoint/provedor oficial configurado.

## Administrativo

- Modulos: `Financeiro SIRE`, `NFS-e`, `Estoque`, `Reagentes e Lotes`.
- Recursos: faturamento SIRE/CDM, controle fiscal de NFS-e, insumos, lotes, validade e consumo.
- Emissao NFS-e depende de credenciais e endpoint oficial da prefeitura/provedor fiscal.

## Gestao de indicadores

- Modulos: `Relatorios Gerenciais`, `Dashboard`, `PBIL Benchmarking`, `Controle de Qualidade`.
- Recursos: coleta de dados gerenciais, comparacao de indicadores, qualidade operacional e status comparativo.

## Benchmarking PBIL

- Modulo: `PBIL Benchmarking`.
- Finalidade: registrar e comparar indicadores com PBIL/SBPC-ML/Controllab.
- Integracao externa depende de arquivo/API/credenciais oficiais fornecidas pelo programa.

## Regra de producao

O sistema nao usa envio simulado para SIRE, NFS-e, e-mail, SMS, PBIL ou equipamentos. Quando credenciais, endpoint, driver ou acesso de rede oficial nao estiverem configurados, o sistema preserva os registros e retorna erro operacional rastreavel.
