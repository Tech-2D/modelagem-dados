---
title: Redis
---

O Redis foi usado como cache compartilhado para os catálogos de atividades e horários. O fluxo atual de produção passa pelo **PostgreSQL**. O Worker de compatibilidade também encaminha as leituras ao SQL com `SQL_READS_ENABLED=true`. As chaves abaixo documentam a implementação legada de `consultas-api`.

## Chaves e prazos

A base dos snapshots era `tech2d:public:v1:<catalogo>`, com `agenda` ou `schedules` no lugar de `<catalogo>`.

| Chave | Valor | Expiração |
| --- | --- | --- |
| `<base>` | JSON com os dados, a data de geração e um marcador opcional de invalidação | Até 72 horas de retenção |
| `<base>:lock` | Identificador da renovação em andamento | 30 segundos |
| `<base>:retry` | Marcador de espera após falha de renovação | 5 minutos |
| `<base>:epoch` | Versão usada para detectar invalidação concorrente | Sem TTL definido pelo código |
| `tech2d:public:rate:<hash>` | Contador de requisições por IP representado por hash | 60 segundos |

Os snapshots da Agenda ficavam frescos por **30 minutos** e os de horários por **6 horas**. Após esse prazo, o cache podia servir a cópia anterior, marcada como desatualizada, enquanto tentava renovar. O limite configurado era de **180 consultas por minuto** por chave de rede.

## Ciclo de uma consulta legada

1. A API tenta reutilizar o snapshot no cache local ou no Redis.
2. Se precisa renovar, uma única execução adquire a trava e consulta o Firestore.
3. A publicação confere a versão de invalidação. Se ela mudou durante a renovação, o resultado antigo não é publicado.
4. Em caso de falha, a API pode servir uma cópia anterior válida. Sem cópia disponível, responde com indisponibilidade temporária.

O cache guardava apenas projeções dos catálogos públicos. No fluxo atual, o PostgreSQL mantém os dados de aplicação, as gravações e as estatísticas de acesso.
