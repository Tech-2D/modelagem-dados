---
title: PostgreSQL
---

O esquema `tech2d` combina **documentos JSONB** com **tabelas de consulta**. Os documentos preservam caminhos e IDs usados pela aplicação. As projeções facilitam filtros de agenda, horários e permissões. A API atualiza o documento e suas projeções na mesma transação.

## Visão geral das tabelas

O esquema tem **20 tabelas** e uma view de horários. A maior parte sustenta os sites ou a operação do banco. As tabelas de migração têm uma função separada, e há dois pontos em que vale simplificar o modelo.

### Agenda e dados da aplicação

| Tabela | Para que serve |
| --- | --- |
| `app_documents` | Fonte dos documentos ativos, com ID, caminho e versão. Inclui atividades, avisos, enquetes e seus votos. |
| `activities` | Projeção para consultar atividades por data e turma e executar recorrências e expurgo. |
| `catalog_documents` | Projeções de catálogo e campos complementares de horários, como andar e sala. |
| `admin_profiles` | Projeção de papel e turma para consultas da API. |
| `app_commits` | Recibos que impedem que uma tentativa repetida aplique a mesma gravação duas vezes. |
| `app_audit` | Histórico das alterações do fluxo atual de gravação. |

### Horários dos professores

| Tabela | Para que serve |
| --- | --- |
| `school_schedules` | Liga professor, disciplina, turma e faixa de horário a um dia da semana. |
| `school_teachers`, `school_subjects`, `school_classes` | Referências reutilizadas por várias aulas. Permitem manter nomes consistentes por entidade. |
| `school_time_slots` | Reutiliza pares de início e fim. Os horários têm tipo SQL `time`. |

A view `school_schedule_catalog` reúne esses dados para a API de horários. Ela é uma consulta salva, sem uma cópia própria dos registros.

### Acessos e moderação

| Tabela | Para que serve |
| --- | --- |
| `agenda_access` | Registra visitas dos **dois sites**. A chave inclui site, dia, intervalo de 30 minutos, tipo e identificador da visita. |
| `agenda_recent_users` | Guarda o último acesso autenticado à Agenda e a referência de rede para moderação. |
| `professor_recent_users` | Guarda o último acesso autenticado ao Cadê o professor. |
| `agenda_blocks` | Mantém os bloqueios por e-mail ou rede aplicados à Agenda. |

### Auditoria legada e operação do banco

| Tabela | Para que serve |
| --- | --- |
| `activity_audit` | Histórico de um endpoint antigo de gravação de atividades. As gravações desse endpoint estão desativadas em produção. |
| `firestore_documents` | Arquivo da migração com os documentos tipados da origem. |
| `source_revisions` | Histórico das versões preservadas durante a reconciliação com a origem. |
| `migration_state` | Guarda os indicadores de preparação e ativação do SQL que a API e os jobs consultam em produção. |
| `schema_migrations` | Registra quais versões do esquema já foram aplicadas. |

## Simplificações propostas

1. **Unificar últimos acessos.** Consolidar `agenda_recent_users` e `professor_recent_users` em `site_recent_users` com chave `(site, uid)`. A referência de rede fica restrita às linhas da Agenda. A troca deve preservar o último acesso por site, os prazos de retenção e as permissões de cada painel.
2. **Alinhar os nomes ao escopo.** Usar `site_visits` para a tabela hoje chamada `agenda_access`, que já atende os dois sites. Para novas tabelas, manter nomes em inglês, no plural e em `snake_case`. Usar prefixos como `school_` e `site_` quando indicarem a responsabilidade da tabela. `agenda_blocks` já segue esse critério porque o bloqueio é específico da Agenda.
3. **Separar a auditoria antiga.** Depois de retirar a rota antiga e conferir a retenção necessária, arquivar `activity_audit` com acesso restrito. A auditoria das gravações atuais continua em `app_audit`.

As projeções são usadas pela API, os recibos evitam gravações duplicadas e as tabelas de referência preservam a integridade dos horários. A separação entre o arquivo do Firestore e os dados ativos também preserva as permissões de acesso. Essas simplificações são propostas para uma migração posterior. Os nomes das tabelas acima descrevem o esquema atual.

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
