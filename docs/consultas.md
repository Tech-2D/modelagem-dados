---
title: Consultas SQL
description: Exemplos de leitura para explorar o esquema em um PostgreSQL local.
---

## Preparar o banco local

Execute os comandos na raiz do clone de [Tech-2D/modelagem-dados](https://github.com/Tech-2D/modelagem-dados). Use um PostgreSQL local com `createdb` e `psql`.

```sh
createdb tech2d_local
psql -d tech2d_local -v ON_ERROR_STOP=1 --single-transaction -f sql/migrate.psql
```

O banco começa vazio. Para consultar atividades e horários, insira dados de teste e troque `TURMA-EXEMPLO` pelo nome da turma que você cadastrou.

## Conferir as migrações

```sql
SELECT version, applied_at
FROM tech2d.schema_migrations
ORDER BY version;
```

## Buscar horários por turma

A view [`school_schedule_catalog`]({{ '/postgresql.html#obj-school_schedule_catalog' | relative_url }}) já reúne as referências dos horários. Filtre pela turma e pelo estado da aula.

```sql
SELECT id, day_of_week, data
FROM tech2d.school_schedule_catalog
WHERE class_name = 'TURMA-EXEMPLO' AND active
ORDER BY day_of_week, data->>'startTime', id;
```

## Comparar visitas por site

Esta consulta reúne os registros dos últimos sete dias por site e tipo de visita.

```sql
SELECT site, day,
  count(*) FILTER (WHERE kind = 'account') AS com_login,
  count(*) FILTER (WHERE kind = 'anonymous') AS anonimos
FROM tech2d.site_visits
WHERE day >= (now() AT TIME ZONE 'America/Sao_Paulo')::date - 6
GROUP BY site, day
ORDER BY day DESC, site;
```

[Arquivo com as consultas completas, incluindo atividades da semana](https://github.com/Tech-2D/modelagem-dados/blob/main/sql/examples/consultas.sql)
