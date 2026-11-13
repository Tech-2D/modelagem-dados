ALTER TABLE tech2d.visitas_aos_sites
  DROP CONSTRAINT agenda_access_site_check,
  ADD CONSTRAINT visitas_aos_sites_site_check CHECK (site IN ('agenda', 'professores', 'pegaki'));

CREATE TABLE tech2d.acessos_recentes_pegaki (
  uid varchar(128) PRIMARY KEY,
  email varchar(320),
  last_seen_at timestamptz NOT NULL
);
CREATE INDEX acessos_recentes_pegaki_ultimo_acesso
  ON tech2d.acessos_recentes_pegaki(last_seen_at DESC, uid);
COMMENT ON TABLE tech2d.acessos_recentes_pegaki IS 'Último acesso com login por conta no Pegaki, com retenção de 90 dias.';
REVOKE ALL ON tech2d.acessos_recentes_pegaki FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'tech2d_api') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON tech2d.acessos_recentes_pegaki TO tech2d_api;
  END IF;
END $$;

COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:026_acessos_pegaki';
