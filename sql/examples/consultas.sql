-- Versões registradas no banco.
SELECT versao, aplicada_em
FROM tech2d.migracoes_esquema
ORDER BY versao;

-- Atividades gerais e da turma de exemplo nos próximos sete dias.
WITH periodo AS (
  SELECT (now() AT TIME ZONE 'America/Sao_Paulo')::date AS data_inicio
)
SELECT a.data, a.hora, a.titulo, a.tipo, a.id_turma
FROM tech2d.atividades AS a
CROSS JOIN periodo AS p
WHERE (a.id_turma = 'TURMA-EXEMPLO' OR a.id_turma IS NULL)
  AND a.data >= to_char(p.data_inicio, 'YYYY-MM-DD')
  AND a.data < to_char(p.data_inicio + 7, 'YYYY-MM-DD')
ORDER BY a.data, a.hora NULLS LAST, a.id;

-- Horários ativos da turma de exemplo e suas referências.
SELECT h.id, turma.nome AS turma, professor.nome AS professor,
  disciplina.nome AS disciplina, h.dia_semana, faixa.hora_inicio, faixa.hora_fim
FROM tech2d.horarios_aula AS h
JOIN tech2d.turmas AS turma ON turma.id = h.id_turma
JOIN tech2d.professores AS professor ON professor.id = h.id_professor
JOIN tech2d.disciplinas AS disciplina ON disciplina.id = h.id_disciplina
JOIN tech2d.faixas_horario AS faixa ON faixa.id = h.id_faixa_horario
WHERE turma.nome = 'TURMA-EXEMPLO' AND h.ativo
ORDER BY h.dia_semana, faixa.hora_inicio, h.id;

-- Total agregado por site e dia, sem identificadores individuais.
SELECT site, dia,
  count(*) FILTER (WHERE tipo_visitante = 'account') AS com_login,
  count(*) FILTER (WHERE tipo_visitante = 'anonymous') AS anonimos
FROM tech2d.visitas_aos_sites
WHERE dia >= (now() AT TIME ZONE 'America/Sao_Paulo')::date - 6
GROUP BY site, dia
ORDER BY dia DESC, site;
