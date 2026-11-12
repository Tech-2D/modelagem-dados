---
title: Histórico do Firestore
description: Como os documentos do antigo Firestore foram preservados e organizados no PostgreSQL.
---

## Onde estão os dados

O esquema `legado_firestore` guardou uma cópia relacional dos documentos do Firestore de 12/11/2026. Suas 22 tabelas foram removidas do Aiven a pedido do projeto. A página registra como o esquema foi organizado. A cópia original fica em `tech2d.documentos_firestore`, com os tipos e os caminhos da origem, para conferência e recuperação.

O esquema tinha 3.684 documentos distribuídos em 20 tabelas por coleção de origem, incluindo uma subcoleção. As duas tabelas auxiliares separavam 14 metadados de anexos e 6 dias de recorrência dos seus registros principais.

## Tabelas por assunto

| Assunto | Tabelas no esquema `legado_firestore` |
| --- | --- |
| Agenda | `atividades`, `anexos_atividades`, `recorrencias`, `dias_recorrencias`, `sugestoes_atividades` |
| Horários | `horarios_aula` |
| Comunicação | `comunicados`, `atualizacoes_agenda`, `sugestoes_melhoria`, `mensagens_sugestoes`, `mensagens_representantes` |
| Permissões | `perfis_administrativos`, `convites_representantes`, `solicitacoes_representantes`, `acessos_enquetes` |
| Resumo semanal | `preferencias_resumo`, `envios_resumo` |
| Limites de uso | `limites_redefinicao_senha`, `limites_envio_arquivos` |
| Integração descontinuada do WhatsApp | `bloqueios_whatsapp`, `sessoes_whatsapp`, `testes_whatsapp` |

## Relacionamentos

- `anexos_atividades.caminho_atividade` aponta para `atividades.caminho`. A coluna `ordem` preserva a posição de cada anexo na lista original.
- `dias_recorrencias.caminho_recorrencia` aponta para `recorrencias.caminho`. A coluna `dia_semana` aceita valores de 0 a 6.
- `mensagens_sugestoes.caminho_sugestao` aponta para `sugestoes_melhoria.caminho`. Cada mensagem mantém o próprio caminho, inclusive o ID da sugestão.

Os nomes das tabelas e das colunas estão em português. Datas, horas, contadores e valores booleanos usam tipos PostgreSQL. O caminho de cada documento é a chave primária nas tabelas de origem. A API utiliza o esquema operacional `tech2d` para as operações atuais. O Firebase Authentication continua responsável pelo login.

## Limites de caracteres

As 113 colunas de texto passaram a usar `varchar(n)`. Nas 20 tabelas que correspondem a coleções, `caminho` é `varchar(512)` e `id` é `varchar(320)`. Os campos de vínculo por caminho também aceitam até 512 caracteres.

| Tabela | Limites além dos campos comuns |
| --- | --- |
| `acessos_enquetes` | `varchar(100)` — `id_turma`<br>`varchar(32)` — `situacao`<br>`varchar(320)` — `email`<br>`varchar(128)` — `revisado_por` |
| `anexos_atividades` | `varchar(512)` — `caminho_atividade`<br>`varchar(320)` — `id`<br>`varchar(180)` — `nome`<br>`varchar(1024)` — `caminho_storage`<br>`varchar(127)` — `tipo_conteudo` |
| `atividades` | `varchar(128)` — `id_criador`<br>`varchar(32)` — `tipo`<br>`varchar(120)` — `titulo`, `disciplina`<br>`varchar(100)` — `id_turma`<br>`varchar(2000)` — `descricao`<br>`varchar(320)` — `email_criador`, `id_recorrencia` |
| `atualizacoes_agenda` | `varchar(2000)` — `descricao`, `mensagem_sugerida`<br>`varchar(128)` — `id_criador`<br>`varchar(120)` — `titulo`<br>`varchar(320)` — `id_feedback`<br>`varchar(60)` — `nome_autor_sugestao` |
| `bloqueios_whatsapp` | `varchar(64)` — `proprietario` |
| `comunicados` | `varchar(500)` — `mensagem` |
| `convites_representantes` | `varchar(320)` — `id_solicitacao`, `email`<br>`varchar(100)` — `id_turma` |
| `dias_recorrencias` | `varchar(512)` — `caminho_recorrencia` |
| `envios_resumo` | `varchar(32)` — `situacao` |
| `horarios_aula` | `varchar(150)` — `disciplina`, `nome_professor`, `nome_turma`<br>`varchar(80)` — `andar`<br>`varchar(500)` — `descricao_sala` |
| `limites_envio_arquivos` | Campos comuns |
| `limites_redefinicao_senha` | Campos comuns |
| `mensagens_representantes` | `varchar(100)` — `id_turma_remetente`<br>`varchar(2000)` — `mensagem`<br>`varchar(128)` — `id_remetente`<br>`varchar(32)` — `papel_remetente`<br>`varchar(320)` — `email_remetente` |
| `mensagens_sugestoes` | `varchar(2000)` — `mensagem`<br>`varchar(128)` — `id_remetente`<br>`varchar(512)` — `caminho_sugestao` |
| `perfis_administrativos` | `varchar(32)` — `papel`<br>`varchar(100)` — `id_turma` |
| `preferencias_resumo` | `varchar(100)` — `id_turma` |
| `recorrencias` | `varchar(128)` — `id_criador`<br>`varchar(120)` — `titulo`, `disciplina`<br>`varchar(100)` — `id_turma`<br>`varchar(2000)` — `descricao`<br>`varchar(320)` — `email_criador`<br>`varchar(32)` — `tipo` |
| `sessoes_whatsapp` | `varchar(64)` — `vetor_inicializacao`, `etiqueta_autenticacao`<br>`varchar(8192)` — `conteudo_cifrado` |
| `solicitacoes_representantes` | `varchar(320)` — `email`<br>`varchar(32)` — `situacao`<br>`varchar(100)` — `id_turma` |
| `sugestoes_atividades` | `varchar(2000)` — `descricao`<br>`varchar(32)` — `situacao`, `tipo`<br>`varchar(120)` — `titulo`, `disciplina`<br>`varchar(100)` — `id_turma` |
| `sugestoes_melhoria` | `varchar(100)` — `id_turma`<br>`varchar(2000)` — `mensagem`<br>`varchar(128)` — `concluido_por`, `id_criador`<br>`varchar(32)` — `situacao`<br>`varchar(60)` — `nome_credito_publico`<br>`varchar(320)` — `email_criador` |
| `testes_whatsapp` | `varchar(32)` — `situacao` |

A conversão verifica o tamanho de cada valor antes de alterar a coluna. Se encontrar um valor acima do limite, a transação é revertida.

[Script SQL dos limites de varchar](https://github.com/Tech-2D/modelagem-dados/blob/main/sql/varchar_legado_firestore.sql)

## Conferência da migração

Depois da conferência, foram excluídos 3.684 documentos da origem. A listagem final do Firestore confirmou zero coleções.

A assinatura SHA-256 da cópia original no Aiven coincidiu com a exportação final, incluindo caminhos, campos e versões dos documentos. A transação verificou a cobertura de todos os documentos e as contagens dos registros auxiliares.

O [SQL da migração histórica](https://github.com/Tech-2D/modelagem-dados/blob/main/sql/legado_firestore_2026_11_12.sql) exige essa mesma cópia original. Ele serve de referência para a migração de 12/11/2026 e fica separado das migrações que montam um banco operacional vazio.
