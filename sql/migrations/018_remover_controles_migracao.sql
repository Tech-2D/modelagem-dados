-- Remove only the two retired controls and their compatibility interfaces.
-- Deploy API 018-compatible code before running this on production.
CREATE OR REPLACE FUNCTION tech2d.sync_school_schedule()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  payload jsonb;
  normalized_keys CONSTANT text[] := ARRAY[
    'professor', 'subject', 'className', 'startTime', 'endTime', 'dayOfWeek', 'active'
  ];
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM tech2d.horarios_aula WHERE id = OLD.id;
    RETURN NULL;
  END IF;

  payload := NEW.dados;
  -- The update below removes the normalized fields after the relational row exists.
  IF TG_OP = 'UPDATE' AND pg_trigger_depth() > 1
     AND payload = OLD.dados - normalized_keys THEN
    RETURN NULL;
  END IF;

  IF (jsonb_typeof(payload->'professor') = 'string'
    AND jsonb_typeof(payload->'subject') = 'string'
    AND jsonb_typeof(payload->'className') = 'string'
    AND jsonb_typeof(payload->'dayOfWeek') = 'number'
    AND jsonb_typeof(payload->'active') = 'boolean'
    AND payload->>'dayOfWeek' ~ '^[0-6]$'
    AND payload->>'startTime' ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
    AND payload->>'endTime' ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Invalid schedule projection' USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO tech2d.professores(nome) VALUES (payload->>'professor') ON CONFLICT (nome) DO NOTHING;
  INSERT INTO tech2d.disciplinas(nome) VALUES (payload->>'subject') ON CONFLICT (nome) DO NOTHING;
  INSERT INTO tech2d.turmas(nome) VALUES (payload->>'className') ON CONFLICT (nome) DO NOTHING;
  INSERT INTO tech2d.faixas_horario(hora_inicio, hora_fim)
    VALUES ((payload->>'startTime')::time, (payload->>'endTime')::time)
    ON CONFLICT (hora_inicio, hora_fim) DO NOTHING;

  INSERT INTO tech2d.horarios_aula(id, id_professor, id_disciplina, id_turma, id_faixa_horario, dia_semana, ativo)
  SELECT NEW.id, teacher.id, subject.id, class.id, slot.id, (payload->>'dayOfWeek')::smallint, (payload->>'active')::boolean
  FROM tech2d.professores teacher
  CROSS JOIN tech2d.disciplinas subject
  CROSS JOIN tech2d.turmas class
  CROSS JOIN tech2d.faixas_horario slot
  WHERE teacher.nome = payload->>'professor'
    AND subject.nome = payload->>'subject'
    AND class.nome = payload->>'className'
    AND slot.hora_inicio = (payload->>'startTime')::time
    AND slot.hora_fim = (payload->>'endTime')::time
  ON CONFLICT (id) DO UPDATE SET
    id_professor = excluded.id_professor, id_disciplina = excluded.id_disciplina, id_turma = excluded.id_turma,
    id_faixa_horario = excluded.id_faixa_horario, dia_semana = excluded.dia_semana, ativo = excluded.ativo;

    UPDATE tech2d.documentos_catalogo
    SET dados = payload - normalized_keys
    WHERE colecao = 'schedules' AND id = NEW.id;
  RETURN NULL;
END $$;


DROP VIEW IF EXISTS tech2d.visao_estado_migracao;
DROP VIEW IF EXISTS tech2d.visao_migracoes_esquema;
DROP TABLE IF EXISTS tech2d.estado_migracao;
DROP TABLE IF EXISTS tech2d.migracoes_esquema;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:018_remover_controles_migracao';
