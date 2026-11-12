DO $$
BEGIN
  IF EXISTS (SELECT FROM tech2d.schema_migrations WHERE version = '012_portuguese_agenda_recent_users') THEN
    RETURN;
  END IF;

  IF to_regclass('tech2d.acessos_recentes_agenda') IS NOT NULL THEN
    IF obj_description('tech2d.acessos_recentes_agenda'::regclass, 'pg_class')
      IS DISTINCT FROM 'Tech-2D compatibility view for migration 012' THEN
      RAISE EXCEPTION 'tech2d.acessos_recentes_agenda already exists';
    END IF;
    DROP VIEW tech2d.acessos_recentes_agenda;
  END IF;

  ALTER TABLE tech2d.agenda_recent_users RENAME TO acessos_recentes_agenda;
  ALTER TABLE tech2d.acessos_recentes_agenda RENAME COLUMN uid TO id_usuario;
  ALTER TABLE tech2d.acessos_recentes_agenda RENAME COLUMN last_seen_at TO ultimo_acesso_em;
  ALTER TABLE tech2d.acessos_recentes_agenda RENAME COLUMN network_key TO chave_rede;
  ALTER TABLE tech2d.acessos_recentes_agenda RENAME CONSTRAINT agenda_recent_users_pkey TO acessos_recentes_agenda_pkey;
  ALTER TABLE tech2d.acessos_recentes_agenda RENAME CONSTRAINT agenda_recent_users_network_key_check TO acessos_recentes_agenda_chave_rede_check;
  ALTER INDEX tech2d.agenda_recent_users_last_seen RENAME TO acessos_recentes_agenda_ultimo_acesso;
  INSERT INTO tech2d.schema_migrations(version) VALUES ('012_portuguese_agenda_recent_users');
END $$;
