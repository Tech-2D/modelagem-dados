-- Versões registradas no banco.
SELECT version, applied_at
FROM tech2d.schema_migrations
ORDER BY version;

-- Atividades da turma de exemplo e atividades gerais nos próximos sete dias.
-- A coluna date guarda texto ISO no esquema atual.
WITH period AS (
  SELECT (now() AT TIME ZONE 'America/Sao_Paulo')::date AS start_date
)
SELECT a.date, a.time, a.title, a.type, a.turma_id
FROM tech2d.activities AS a
CROSS JOIN period AS p
WHERE (a.turma_id = 'TURMA-EXEMPLO' OR a.turma_id IS NULL)
  AND a.date >= to_char(p.start_date, 'YYYY-MM-DD')
  AND a.date < to_char(p.start_date + 7, 'YYYY-MM-DD')
ORDER BY a.date, a.time NULLS LAST, a.id;

-- Catálogo dos horários ativos da turma de exemplo, lido da projeção JSONB.
SELECT id, data->>'className' AS turma, data->>'startTime' AS inicio
FROM tech2d.catalog_documents
WHERE collection = 'schedules'
  AND data->>'className' = 'TURMA-EXEMPLO'
  AND data @> '{"active":true}'::jsonb
ORDER BY data->>'dayOfWeek', data->>'startTime', id;

-- Total agregado por site e dia, sem identificadores individuais.
SELECT site, day,
  count(*) FILTER (WHERE kind = 'account') AS com_login,
  count(*) FILTER (WHERE kind = 'anonymous') AS anonimos
FROM tech2d.agenda_access
WHERE day >= (now() AT TIME ZONE 'America/Sao_Paulo')::date - 6
GROUP BY site, day
ORDER BY day DESC, site;
