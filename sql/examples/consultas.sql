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

-- Horários ativos da turma de exemplo, ligados às referências do catálogo.
SELECT schedule.id, class.name AS turma, teacher.name AS professor,
  subject.name AS disciplina, schedule.day_of_week, slot.start_time, slot.end_time
FROM tech2d.school_schedules AS schedule
JOIN tech2d.school_classes AS class ON class.id = schedule.class_id
JOIN tech2d.school_teachers AS teacher ON teacher.id = schedule.teacher_id
JOIN tech2d.school_subjects AS subject ON subject.id = schedule.subject_id
JOIN tech2d.school_time_slots AS slot ON slot.id = schedule.time_slot_id
WHERE class.name = 'TURMA-EXEMPLO' AND schedule.active
ORDER BY schedule.day_of_week, slot.start_time, schedule.id;

-- Total agregado por site e dia, sem identificadores individuais.
SELECT site, day,
  count(*) FILTER (WHERE kind = 'account') AS com_login,
  count(*) FILTER (WHERE kind = 'anonymous') AS anonimos
FROM tech2d.site_visits
WHERE day >= (now() AT TIME ZONE 'America/Sao_Paulo')::date - 6
GROUP BY site, day
ORDER BY day DESC, site;
