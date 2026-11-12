DO $migracao$
DECLARE
  vista record;
  permissao record;
  beneficiario text;
BEGIN
  IF EXISTS (SELECT FROM tech2d.migracoes_esquema WHERE versao = '015_views_em_portugues') THEN
    RETURN;
  END IF;
  SET LOCAL search_path = pg_catalog, pg_temp;

  FOR vista IN
    SELECT nomes.destino, c.oid, c.relowner, c.relacl
    FROM (VALUES
    ('activities', 'visao_atividades'),
    ('activity_audit', 'visao_auditoria_atividades_legada'),
    ('admin_profiles', 'visao_perfis_administrativos'),
    ('agenda_blocks', 'visao_bloqueios_agenda'),
    ('app_audit', 'visao_auditoria_aplicacao'),
    ('app_commits', 'visao_recibos_gravacao'),
    ('app_documents', 'visao_documentos_aplicacao'),
    ('catalog_documents', 'visao_documentos_catalogo'),
    ('firestore_documents', 'visao_documentos_firestore'),
    ('migration_state', 'visao_estado_migracao'),
    ('professor_recent_users', 'visao_acessos_recentes_professores'),
    ('schema_migrations', 'visao_migracoes_esquema'),
    ('school_classes', 'visao_turmas'),
    ('school_schedule_catalog', 'visao_catalogo_horarios'),
    ('school_schedules', 'visao_horarios_aula'),
    ('school_subjects', 'visao_disciplinas'),
    ('school_teachers', 'visao_professores'),
    ('school_time_slots', 'visao_faixas_horario'),
    ('source_revisions', 'visao_revisoes_origem')
    ) AS nomes(origem, destino)
    JOIN pg_namespace n ON n.nspname = 'tech2d'
    JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = nomes.origem AND c.relkind = 'v'
  LOOP
    EXECUTE format('CREATE VIEW tech2d.%I WITH (security_invoker = true) AS %s',
      vista.destino, pg_get_viewdef(vista.oid));
    EXECUTE format('COMMENT ON VIEW tech2d.%I IS %L',
      vista.destino, obj_description(vista.oid, 'pg_class'));
    EXECUTE format('REVOKE ALL ON tech2d.%I FROM PUBLIC', vista.destino);
    EXECUTE format('ALTER VIEW tech2d.%I OWNER TO %I', vista.destino, pg_get_userbyid(vista.relowner));
    FOR permissao IN SELECT * FROM aclexplode(vista.relacl) WHERE grantee <> vista.relowner LOOP
      beneficiario := CASE WHEN permissao.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(permissao.grantee)) END;
      EXECUTE format('GRANT %s ON tech2d.%I TO %s%s', permissao.privilege_type, vista.destino, beneficiario,
        CASE WHEN permissao.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
    END LOOP;
  END LOOP;

  IF (SELECT count(*) FROM pg_views WHERE schemaname = 'tech2d' AND left(viewname, 6) = 'visao_') <> 19 THEN
    RAISE EXCEPTION 'Quantidade inesperada de views em português.';
  END IF;
  INSERT INTO tech2d.migracoes_esquema(versao) VALUES ('015_views_em_portugues');
END
$migracao$;
