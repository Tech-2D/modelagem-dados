-- Rename the real relations and preserve the existing SQL interface through invoker views.
DO $$
DECLARE
  item record;
  source_oid oid;
  original_columns text[];
  column_name text;
  column_list text;
  permission record;
  grantee_name text;
BEGIN
  IF EXISTS (SELECT FROM tech2d.schema_migrations WHERE version = '013_portuguese_schema') THEN
    RETURN;
  END IF;

  FOR item IN SELECT * FROM (VALUES
    ('activities', 'atividades', 'TABLE', '{"id":"id","turma_id":"id_turma","title":"titulo","description":"descricao","type":"tipo","subject":"disciplina","date":"data","time":"hora","created_by":"criado_por","created_by_email":"email_criador","recurring_id":"id_recorrencia","attachments":"anexos","created_at":"criado_em","updated_at":"atualizado_em","version":"versao"}'::jsonb),
    ('activity_audit', 'auditoria_atividades_legada', 'TABLE', '{"sequence":"sequencia","activity_id":"id_atividade","actor_uid":"id_usuario","action":"acao","previous_data":"dados_anteriores","changed_at":"alterado_em"}'::jsonb),
    ('admin_profiles', 'perfis_administrativos', 'TABLE', '{"uid":"id_usuario","role":"papel","turma_id":"id_turma","data":"dados"}'::jsonb),
    ('agenda_blocks', 'bloqueios_agenda', 'TABLE', '{"id":"id","kind":"tipo","target":"alvo","created_at":"criado_em","created_by":"criado_por"}'::jsonb),
    ('app_audit', 'auditoria_aplicacao', 'TABLE', '{"sequence":"sequencia","actor":"autor","path":"caminho","operation":"operacao","previous_data":"dados_anteriores","changed_at":"alterado_em"}'::jsonb),
    ('app_commits', 'recibos_gravacao', 'TABLE', '{"id":"id","actor":"autor","digest":"hash_requisicao","committed_at":"confirmado_em"}'::jsonb),
    ('app_documents', 'documentos_aplicacao', 'TABLE', '{"path":"caminho","collection":"colecao","id":"id","data":"dados","version":"versao","updated_at":"atualizado_em"}'::jsonb),
    ('catalog_documents', 'documentos_catalogo', 'TABLE', '{"collection":"colecao","id":"id","data":"dados"}'::jsonb),
    ('firestore_documents', 'documentos_firestore', 'TABLE', '{"project_id":"id_projeto","path":"caminho","fields":"campos","source_updated_at":"atualizado_na_origem_em","imported_at":"importado_em"}'::jsonb),
    ('migration_state', 'estado_migracao', 'TABLE', '{"id":"id","application_seeded":"aplicacao_preparada","production_enabled":"producao_ativa","source_exported_at":"origem_exportada_em"}'::jsonb),
    ('professor_recent_users', 'acessos_recentes_professores', 'TABLE', '{"uid":"id_usuario","email":"email","last_seen_at":"ultimo_acesso_em"}'::jsonb),
    ('schema_migrations', 'migracoes_esquema', 'TABLE', '{"version":"versao","applied_at":"aplicada_em"}'::jsonb),
    ('school_classes', 'turmas', 'TABLE', '{"id":"id","name":"nome"}'::jsonb),
    ('school_schedule_catalog', 'catalogo_horarios', 'VIEW', '{"id":"id","day_of_week":"dia_semana","active":"ativo","class_name":"nome_turma","data":"dados"}'::jsonb),
    ('school_schedules', 'horarios_aula', 'TABLE', '{"id":"id","teacher_id":"id_professor","subject_id":"id_disciplina","class_id":"id_turma","time_slot_id":"id_faixa_horario","day_of_week":"dia_semana","active":"ativo"}'::jsonb),
    ('school_subjects', 'disciplinas', 'TABLE', '{"id":"id","name":"nome"}'::jsonb),
    ('school_teachers', 'professores', 'TABLE', '{"id":"id","name":"nome"}'::jsonb),
    ('school_time_slots', 'faixas_horario', 'TABLE', '{"id":"id","start_time":"hora_inicio","end_time":"hora_fim"}'::jsonb),
    ('source_revisions', 'revisoes_origem', 'TABLE', '{"sequence":"sequencia","project_id":"id_projeto","path":"caminho","fields":"campos","source_updated_at":"atualizado_na_origem_em","reason":"motivo","saved_at":"salvo_em"}'::jsonb)
  ) AS names(old_name, new_name, object_type, columns)
  LOOP
    source_oid := to_regclass(format('tech2d.%I', item.old_name));
    IF source_oid IS NULL OR to_regclass(format('tech2d.%I', item.new_name)) IS NOT NULL THEN
      RAISE EXCEPTION 'Unexpected relation while renaming %', item.old_name;
    END IF;

    SELECT array_agg(attname::text ORDER BY attnum) INTO original_columns
    FROM pg_attribute
    WHERE attrelid = source_oid AND attnum > 0 AND NOT attisdropped;

    IF original_columns IS NULL OR NOT (item.columns ?& original_columns) OR
       cardinality(original_columns) <> (SELECT count(*) FROM jsonb_object_keys(item.columns)) THEN
      RAISE EXCEPTION 'Unexpected columns on %', item.old_name;
    END IF;

    EXECUTE format('ALTER %s tech2d.%I RENAME TO %I', item.object_type, item.old_name, item.new_name);
    FOREACH column_name IN ARRAY original_columns
    LOOP
      IF column_name <> item.columns->>column_name THEN
        EXECUTE format('ALTER %s tech2d.%I RENAME COLUMN %I TO %I',
          item.object_type, item.new_name, column_name, item.columns->>column_name);
      END IF;
    END LOOP;

    SELECT string_agg(format('%I AS %I', item.columns->>column_info.name, column_info.name), ', ' ORDER BY column_info.position)
    INTO column_list
    FROM unnest(original_columns) WITH ORDINALITY AS column_info(name, position);

    EXECUTE format('CREATE VIEW tech2d.%I WITH (security_invoker = true) AS SELECT %s FROM tech2d.%I',
      item.old_name, column_list, item.new_name);
    EXECUTE format('COMMENT ON VIEW tech2d.%I IS %L', item.old_name,
      'Interface SQL de compatibilidade para ' || item.new_name);
    EXECUTE format('REVOKE ALL ON tech2d.%I FROM PUBLIC', item.old_name);

    FOR permission IN
      SELECT acl.grantee, acl.privilege_type, acl.is_grantable
      FROM pg_class source
      CROSS JOIN LATERAL aclexplode(source.relacl) acl
      WHERE source.oid = source_oid AND acl.grantee <> source.relowner
        AND acl.privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
    LOOP
      grantee_name := CASE WHEN permission.grantee = 0 THEN 'PUBLIC'
        ELSE quote_ident(pg_get_userbyid(permission.grantee)) END;
      EXECUTE format('GRANT %s ON tech2d.%I TO %s%s', permission.privilege_type, item.old_name,
        grantee_name, CASE WHEN permission.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
    END LOOP;
  END LOOP;
END $$;

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

  IF EXISTS (SELECT FROM tech2d.migracoes_esquema WHERE versao = '008_compact_schedule_catalog') THEN
    UPDATE tech2d.documentos_catalogo
    SET dados = payload - normalized_keys
    WHERE colecao = 'schedules' AND id = NEW.id;
  END IF;
  RETURN NULL;
END $$;

INSERT INTO tech2d.migracoes_esquema(versao) VALUES ('013_portuguese_schema') ON CONFLICT DO NOTHING;
