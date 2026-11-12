DO $$
BEGIN
  IF EXISTS (SELECT FROM tech2d.schema_migrations WHERE version = '009_rename_site_visits') THEN
    RETURN;
  END IF;

  IF to_regclass('tech2d.site_visits') IS NOT NULL THEN
    IF obj_description('tech2d.site_visits'::regclass, 'pg_class')
      IS DISTINCT FROM 'Tech-2D compatibility view for migration 009' THEN
      RAISE EXCEPTION 'tech2d.site_visits already exists';
    END IF;
    DROP VIEW tech2d.site_visits;
  END IF;

  ALTER TABLE tech2d.agenda_access RENAME TO site_visits;
  ALTER TABLE tech2d.site_visits RENAME CONSTRAINT agenda_access_pkey TO site_visits_pkey;
  INSERT INTO tech2d.schema_migrations(version) VALUES ('009_rename_site_visits');
END $$;
