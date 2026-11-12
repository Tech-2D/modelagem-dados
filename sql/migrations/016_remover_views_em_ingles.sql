-- Aplicar depois que os serviços estiverem publicados com os nomes em português.
SET LOCAL lock_timeout = '5s';
DROP VIEW IF EXISTS
  tech2d.activities,
  tech2d.activity_audit,
  tech2d.admin_profiles,
  tech2d.agenda_blocks,
  tech2d.app_audit,
  tech2d.app_commits,
  tech2d.app_documents,
  tech2d.catalog_documents,
  tech2d.firestore_documents,
  tech2d.migration_state,
  tech2d.professor_recent_users,
  tech2d.schema_migrations,
  tech2d.school_classes,
  tech2d.school_schedule_catalog,
  tech2d.school_schedules,
  tech2d.school_subjects,
  tech2d.school_teachers,
  tech2d.school_time_slots,
  tech2d.source_revisions
RESTRICT;
INSERT INTO tech2d.migracoes_esquema(versao) VALUES ('016_remover_views_em_ingles') ON CONFLICT DO NOTHING;
