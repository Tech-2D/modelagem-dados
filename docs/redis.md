---
title: Redis
description: Cache de catálogos, comunicado geral e histórico de atualizações da Agenda.
---

O Redis acelera as consultas públicas da API SQL. O PostgreSQL fornece a revisão dos catálogos de atividades, turmas e horários, usada para escolher a chave do cache. O comunicado geral e as publicações de atualização ficam no Redis com prazos próprios.

**Configuração atual:** o Worker SQL usa `REDIS_CACHE_ENABLED=true`. O resultado de cada consulta aparece no header `X-Catalog-Cache`; em caso de falha ou indisponibilidade do Redis, a API consulta o PostgreSQL. As rotas continuam exigindo a autenticação e as permissões verificadas pelo Worker.

## Catálogos e chaves

| Catálogo | Conteúdo público | TTL |
| --- | --- | --- |
| agenda | Atividades e turmas | 60 segundos |
| updates | Turmas | 60 segundos |
| schedules | Horários ativos, com filtros de turma, dia e busca | 300 segundos |

Formato: <code>tech2d:sql:public:v2:CATALOGO:REVISAO:HASH_FILTROS</code>.

A revisão identifica os registros e suas versões. O hash dos filtros separa consultas de turmas, dias e buscas diferentes. As cópias antigas expiram pelo TTL.

## Invalidação após alterações

1. A API verifica acesso e filtros.
2. A função SQL <code>revisao_catalogo_publico</code> calcula a revisão dos registros.
3. A API procura a chave correspondente à revisão e aos filtros no Redis.
4. Se não encontra uma cópia, consulta o SQL e guarda somente a resposta pública no cache.

Inclusões, alterações e exclusões feitas pela interface de gravação da aplicação mudam a revisão. A próxima consulta usa uma chave nova. Alterações diretas nas tabelas devem atualizar a versão do registro; o TTL também limita a retenção de cada cópia.

## Indisponibilidade e acesso

Os catálogos continuam disponíveis pelo PostgreSQL quando o Redis falha. Cada operação de rede do cache tem limite de 700 ms. O header <code>X-Catalog-Cache</code> informa HIT, MISS, BYPASS ou UNAVAILABLE.

Contas, tokens, permissões, mensagens privadas e quadros pessoais não entram no cache. As credenciais ficam nos secrets do Worker SQL; os navegadores acessam somente a API.


## Comunicado geral da Agenda

Quando um superadministrador usa **Aviso para todos**, a API substitui o comunicado atual e reinicia o prazo de sete dias (604.800 segundos). A chave `tech2d:{announcement}:latest` guarda a mensagem, a data da publicação e a versão usada na remoção. O Redis remove a chave ao fim do prazo. O superadministrador também pode remover o aviso manualmente.

Os endpoints de Agenda e atualizações leem essa chave separadamente do cache de catálogos. Se o Redis estiver indisponível, o calendário carrega sem o comunicado e a API informa falha ao tentar publicar ou remover. Os recibos de publicação e remoção também expiram em sete dias e permitem repetir a mesma requisição sem republicar um aviso.

## Atualizações da Agenda

Os avisos publicados em **Atualizações** aparecem no histórico e no aviso de novidades por 14 dias (1.209.600 segundos), contados da publicação. O prazo é individual: publicar outro aviso, abrir o histórico ou repetir uma requisição já concluída mantém a expiração original.

| Chave | Conteúdo |
| --- | --- |
| tech2d:{agenda-updates}:item:ID | Título, descrição, data e crédito público autorizado, quando informado |
| tech2d:{agenda-updates}:index | Índice ordenado pelos prazos de expiração dos avisos |
| tech2d:{agenda-updates}:commit:ID | Recibo de publicação para repetir a requisição sem duplicar o aviso |

A API lê os avisos ativos diretamente do Redis nas rotas de catálogo da Agenda e de atualizações. O PostgreSQL continua a validar a permissão de publicação e a autorização de crédito de uma sugestão. Se o Redis ficar indisponível, o calendário continua carregando as atividades e turmas, e a interface indica falha ao tentar publicar.
