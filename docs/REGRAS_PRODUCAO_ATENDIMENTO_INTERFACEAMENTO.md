# Regras de Produção - Atendimento, Pacientes, Etiquetas e Interfaceamento

## Atendimento puxa pacientes cadastrados

A tela `Novo Atendimento` consulta a tabela local `pacientes` e oferece busca por:

- Nome
- CPF
- PREC-CP

Ao selecionar o paciente, o atendimento preenche os dados disponíveis no cadastro: CPF, telefone, celular, e-mail, peso, altura, endereço, dados familiares e CADBENS quando existentes.

## Importação de pacientes

A área `Pacientes` possui importação de arquivo.

Regra técnica:

- Qualquer arquivo selecionado é aceito e arquivado com HASH SHA-256.
- Integração automática ocorre para arquivos estruturados legíveis: JSON, CSV, TSV e TXT delimitado.
- Arquivos binários ou sem estrutura de paciente não geram dados inventados; são arquivados com HASH e o sistema informa que não havia dados estruturados.

Campos reconhecidos:

- `nome`, `paciente`, `nome_paciente`
- `cpf`
- `preccp`, `prec_cp`, `prec`
- `cns`
- `nascimento`
- `telefone`, `celular`
- `endereco`
- `status`, `situacao`

## Etiquetas

A numeração da etiqueta deve ser exatamente a mesma do atendimento/pedido.

Regra aplicada:

```text
atendimento.id == pedido.id == amostra.id == codigoBarras == codigoManual
```

Se a etiqueta informada for diferente do número do atendimento/pedido, o sistema recusa o vínculo.

## Interfaceamento de equipamentos

O resultado recebido por ASTM/HL7 é preservado sem alteração de valor.

Campos mantidos:

- `valor`: valor recebido do equipamento
- `valorBrutoEquipamento`: cópia exata do valor recebido
- `mensagemBrutaEquipamento`: mensagem original recebida do equipamento

O sistema não arredonda, não mascara e não reinterpreta resultado de equipamento como sucesso fictício.

## Servidor de produção

Servidor definido:

- IP: `10.4.169.64`
- Pasta: `D:\kristal_laboratorial`
- Portal: `http://10.4.169.64:8787`
- Admin: `http://10.4.169.64:8787/admin.html`

## Chave API

A chave API é configurada no primeiro start de produção pelo script:

```text
D:\kristal_laboratorial\portal_web\gerar_segredos_portal.py
```

Arquivo gerado no servidor:

```text
D:\kristal_laboratorial\portal_web\.env
```

Campo obrigatório:

```env
KRISTAL_API_KEY=klab_...
```

O valor também fica no arquivo restrito:

```text
D:\kristal_laboratorial\portal_web\SEGREDOS_INICIAIS_ADMIN.txt
```
