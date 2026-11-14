---
title: Redis
description: Cache dos catálogos públicos integrado ao PostgreSQL.
---

O Redis acelera as consultas públicas da API SQL. O PostgreSQL armazena os dados e fornece a revisão de cada catálogo, usada para escolher a chave do cache.

**Configuração atual:** o Worker SQL usa `REDIS_CACHE_ENABLED=true`. O resultado de cada consulta aparece no header `X-Catalog-Cache`; em caso de falha ou indisponibilidade do Redis, a API consulta o PostgreSQL. As rotas continuam exigindo a autenticação e as permissões verificadas pelo Worker.

## Catálogos e chaves

| Catálogo | Conteúdo público | TTL |
| --- | --- | --- |
| agenda | Atividades, turmas, atualizações e anúncio | 60 segundos |
| updates | Atualizações, turmas e anúncio | 60 segundos |
| schedules | Horários ativos, com filtros de turma, dia e busca | 300 segundos |

Formato: <code>tech2d:sql:public:v1:CATALOGO:REVISAO:HASH_FILTROS</code>.

A revisão identifica os registros e suas versões. O hash dos filtros separa consultas de turmas, dias e buscas diferentes. As cópias antigas expiram pelo TTL.

## Invalidação após alterações

1. A API verifica acesso e filtros.
2. A função SQL <code>revisao_catalogo_publico</code> calcula a revisão dos registros.
3. A API procura a chave correspondente à revisão e aos filtros no Redis.
4. Se não encontra uma cópia, consulta o SQL e guarda somente a resposta pública no cache.

Inclusões, alterações e exclusões feitas pela interface de gravação da aplicação mudam a revisão. A próxima consulta usa uma chave nova. Alterações diretas nas tabelas devem atualizar a versão do registro; o TTL também limita a retenção de cada cópia.

## Indisponibilidade e acesso

A API usa o PostgreSQL quando o Redis falha. Cada operação de rede do cache tem limite de 700 ms. O header <code>X-Catalog-Cache</code> informa HIT, MISS, BYPASS ou UNAVAILABLE.

Contas, tokens, permissões, mensagens privadas e quadros pessoais não entram no cache. As credenciais ficam nos secrets do Worker SQL; os navegadores acessam somente a API.
