---
title: PostgreSQL
---

O esquema `tech2d` combina **documentos JSONB** com **tabelas de consulta**. Os documentos preservam caminhos e IDs usados pela aplicação. As projeções facilitam filtros de agenda, horários e permissões. A API atualiza o documento e suas projeções na mesma transação.

## Tabelas e responsabilidades

| Tabela | Chave | Uso |
| --- | --- | --- |
| `app_documents` | `path` | Documentos ativos da aplicação. Guarda coleção, ID, JSONB e versão |
| `activities` | `id` | Projeção de atividades, turma, data, horário e referências aos anexos |
| `catalog_documents` | `collection, id` | Dados complementares dos horários e projeções de turmas, atualizações, avisos e enquetes |
| `school_teachers`, `school_subjects`, `school_classes` | `id` | Nomes únicos por catálogo de horários |
| `school_time_slots` | `id` | Pares únicos de hora de início e fim, armazenados como `time` |
| `school_schedules` | `id` | Horários com dia, estado ativo e chaves estrangeiras para professor, disciplina, turma e faixa de horário |
| `admin_profiles` | `uid` | Projeção do papel administrativo e da turma associada |
| `app_commits` | `id` | Recibos que permitem repetir uma gravação sem aplicá-la duas vezes |
| `app_audit` | `sequence` | Histórico de operações sobre os documentos da aplicação |
| `activity_audit` | `sequence` | Auditoria da rota específica de atividades |
| `agenda_access` | `site, day, half_hour, kind, visitor_key` | Visitas da Agenda e do Cadê o professor, deduplicadas por intervalo de 30 minutos |
| `agenda_recent_users` | `uid` | Último acesso autenticado à Agenda e referência de rede para moderação |
| `professor_recent_users` | `uid` | Último acesso autenticado ao Cadê o professor |
| `agenda_blocks` | `id` | Bloqueios da Agenda por e-mail ou rede, com alvo único por tipo |
| `firestore_documents` | `project_id, path` | Arquivo da migração, com os campos tipados da origem |
| `source_revisions` | `sequence` | Versões da origem preservadas durante a reconciliação |
| `migration_state` | `id` | Estado de preparação e ativação da base |
| `schema_migrations` | `version` | Versões de esquema já aplicadas |

## Como os registros se ligam

- **Atividades.** O caminho `activities/{id}` origina a linha com o mesmo `id` em `activities`. Uma atividade geral usa `turma_id` nulo.
- **Horários.** `schedules/{id}` mantém a compatibilidade com a edição existente. Uma função do banco separa as referências em tabelas relacionais. A view `school_schedule_catalog` recompõe a resposta da API com os dados complementares, como andar e sala.
- **Permissões.** A conta no Firebase fornece o UID. O documento `admins/{uid}` e sua projeção em `admin_profiles` registram papel e turma. A API aplica as regras de acesso.
- **Consultas.** As atividades têm índices de data e de turma com data. Os catálogos e documentos têm índices por coleção e por campos do JSONB usados em filtros.

Os horários usam chaves estrangeiras para as quatro tabelas de referência. As relações entre documentos da Agenda usam IDs e caminhos mantidos pela API. Datas e horários em `activities` ficam em texto no formato ISO usado pela aplicação. Os timestamps de auditoria e de último acesso usam `timestamptz`.

## Acesso ao banco

O Worker se conecta com o papel dedicado `tech2d_api`. O provisionamento da API concede as operações necessárias por tabela. A aplicação aplica as permissões por conta, papel e turma antes de ler ou gravar. Os arquivos de migração podem ser executados em um banco local sem criar esse papel.

Os catálogos públicos passam por projeções que selecionam os campos da resposta. Os arquivos da migração, as auditorias e os dados de moderação são acessados pelos fluxos administrativos correspondentes ou pela operação do banco.

## Migrações SQL

| Versão | O que cria ou altera |
| --- | --- |
| 001 | Esquema, arquivo de origem, atividades, perfis, catálogo e auditoria inicial |
| 002 | Documentos de aplicação, recibos, auditoria e estado de migração |
| 003 | Histórico das revisões da origem |
| 004 | Registro de visitas da Agenda |
| 005 | Últimos acessos autenticados e bloqueios da Agenda |
| 006 | Separação das visitas por site e últimos acessos do Cadê o professor |
| 007 | Tabelas relacionais de horários, chaves estrangeiras, migração dos registros existentes e view de leitura |
| 008 | Remoção dos campos já normalizados da projeção JSONB de horários, após a troca de leitura na API |

Em um ambiente em uso, aplique a versão 007, publique a API que lê `school_schedule_catalog` e confira o catálogo. Aplique a versão 008 após confirmar que os consumidores já leem pela nova view. Em um banco local vazio, rode as duas pelo script de instalação.

[Ver arquivos SQL](https://github.com/Tech-2D/modelagem-dados/tree/main/sql/migrations) · [Rodar em um banco local](https://github.com/Tech-2D/modelagem-dados#rodar-o-sql-localmente) · [Consultas de exemplo](https://github.com/Tech-2D/modelagem-dados/blob/main/sql/examples/consultas.sql)
