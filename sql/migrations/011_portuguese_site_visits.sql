DO $$
BEGIN
  IF EXISTS (SELECT FROM tech2d.schema_migrations WHERE version = '011_portuguese_site_visits') THEN
    RETURN;
  END IF;

  IF to_regclass('tech2d.visitas_aos_sites') IS NOT NULL THEN
    IF obj_description('tech2d.visitas_aos_sites'::regclass, 'pg_class')
      IS DISTINCT FROM 'Tech-2D compatibility view for migration 011' THEN
      RAISE EXCEPTION 'tech2d.visitas_aos_sites already exists';
    END IF;
    DROP VIEW tech2d.visitas_aos_sites;
  END IF;

  ALTER TABLE tech2d.site_visits RENAME TO visitas_aos_sites;
  ALTER TABLE tech2d.visitas_aos_sites RENAME COLUMN day TO dia;
  ALTER TABLE tech2d.visitas_aos_sites RENAME COLUMN half_hour TO intervalo_meia_hora;
  ALTER TABLE tech2d.visitas_aos_sites RENAME COLUMN kind TO tipo_visitante;
  ALTER TABLE tech2d.visitas_aos_sites RENAME COLUMN visitor_key TO chave_visitante;
  ALTER TABLE tech2d.visitas_aos_sites RENAME CONSTRAINT site_visits_pkey TO visitas_aos_sites_pkey;
  INSERT INTO tech2d.schema_migrations(version) VALUES ('011_portuguese_site_visits');
END $$;
