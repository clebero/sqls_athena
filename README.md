# sqls_athena

Consultas SQL e relatórios personalizados do sistema **Solus**, feitos para uso específico da **Athena Saúde**.

O banco do Solus é **Oracle**, então as consultas usam a sintaxe dele (`DECODE`, `NVL`, `SYSDATE`, junções externas com `(+)` etc.).

## Relatórios

| Arquivo | Descrição | Parâmetros |
|---|---|---|
| `REDE - CONSULTA DE REDE DE ATENDIMENTO ANALITICO C.CLIN v2.sql` | Rede de atendimento analítica: prestadores ativos na rede com especialidades, endereço, telefone, e-mail, produção dos últimos 6 meses (valor apresentado e quantidade de guias) e o corpo clínico vinculado a cada hospital. A operadora (Humana NE/SUL/SE) vem da `hssconf`. | `:GRUPO`: grupo do prestador |
| `REDE - CONSULTA DE REDE DE ATENDIMENTO - ANALITICO.SQL` | Rede de atendimento analítica por rede: rede, especialidade, natureza e regime de atendimento, dados do prestador, endereço, telefone, e-mails, forma de contratação, analista responsável, valor apresentado e data do último pagamento. | `:REDE`, `:grupo`, `:idprestador`, `:classificacao`, `:cidade_prestador`, `:codplan`, `:plano` |

> Ao adicionar um novo `.sql`, inclua uma linha nesta tabela.

## Convenções

- **Nome do arquivo:** `MÓDULO - DESCRIÇÃO DO RELATÓRIO vN.sql` (ex.: `REDE - ...`). Quando a mudança quebrar o que já existe, aumente a versão (`v2`, `v3`...). Se não quebrar, altere o próprio arquivo, já que o histórico fica no git.
- **Parâmetros:** use variáveis de ligação (`:NOME`) para os filtros que o usuário informa no Solus.
- **Filtros de tela:** depois da query principal vêm as consultas que alimentam a lista de opções de cada parâmetro. Cada uma fica sob um comentário com o nome do filtro: `--FILTRO--GRUPO` seguido do `SELECT`, ou um cabeçalho `--FILTROS` e depois `--REDE`, `--GRUPO` etc.
- **Comentários:** explique as regras de negócio que não são óbvias (prioridades, fallbacks, exclusões) direto no SQL.

## Codificação e quebras de linha

Todos os arquivos devem estar em **UTF-8** e usar **CRLF** na cópia de trabalho.

- **`.editorconfig`:** faz o editor salvar em UTF-8 com CRLF. O JetBrains lê o arquivo sozinho; no VS Code, instale a extensão *EditorConfig for VS Code*.
- **`.gitattributes`:** cuida das quebras de linha. O git guarda LF no repositório e entrega CRLF no checkout, qualquer que seja o `core.autocrlf` de quem clonar.
- **Codificação:** o git não converte a codificação. Se um `.sql` vier de outro lugar (exportado do Solus, copiado de outro sistema), confira se está em UTF-8 antes do commit. Arquivos em ISO-8859-1/Windows-1252 deixam os acentos quebrados (`�`) no GitHub. Para converter:

  ```sh
  iconv -f ISO-8859-1 -t UTF-8 "arquivo.sql" > tmp.sql && mv tmp.sql "arquivo.sql"
  ```
