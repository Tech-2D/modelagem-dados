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

## Conferir a versão instalada

```sql
SELECT obj_description('tech2d'::regnamespace, 'pg_namespace') AS versao_do_schema;
```

## Buscar horários por turma

A view [`catalogo_horarios`]({{ '/views.html#view-catalogo_horarios' | relative_url }}) já reúne as referências dos horários. Filtre pela turma e pelo estado da aula.

```sql
SELECT id, dia_semana, dados
FROM tech2d.catalogo_horarios
WHERE nome_turma = 'TURMA-EXEMPLO' AND ativo
ORDER BY dia_semana, dados->>'startTime', id;
```

## Comparar visitas por site

Esta consulta reúne os registros dos últimos sete dias por site e tipo de visita.

```sql
SELECT site, dia,
  count(*) FILTER (WHERE tipo_visitante = 'account') AS com_login,
  count(*) FILTER (WHERE tipo_visitante = 'anonymous') AS anonimos
FROM tech2d.visitas_aos_sites
WHERE dia >= (now() AT TIME ZONE 'America/Sao_Paulo')::date - 6
GROUP BY site, dia
ORDER BY dia DESC, site;
```

[Arquivo com as consultas completas, incluindo atividades da semana](https://github.com/Tech-2D/modelagem-dados/blob/main/sql/examples/consultas.sql)
