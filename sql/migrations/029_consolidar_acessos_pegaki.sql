-- Expansão: a API anterior ainda pode gravar no registro separado do Pegaki.
ALTER TABLE tech2d.acessos_recentes DROP CONSTRAINT acessos_recentes_site_check;
ALTER TABLE tech2d.acessos_recentes ADD CONSTRAINT acessos_recentes_site_check
  CHECK (site IN ('agenda','professores','pegaki'));
LOCK TABLE tech2d.acessos_recentes_pegaki IN SHARE ROW EXCLUSIVE MODE;
INSERT INTO tech2d.acessos_recentes AS recent(site,id_usuario,email,ultimo_acesso_em)
SELECT 'pegaki',uid,email,last_seen_at FROM tech2d.acessos_recentes_pegaki
ON CONFLICT(site,id_usuario) DO UPDATE SET email=excluded.email,ultimo_acesso_em=excluded.ultimo_acesso_em
WHERE recent.ultimo_acesso_em<=excluded.ultimo_acesso_em;

CREATE FUNCTION tech2d.sincronizar_acesso_pegaki() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF TG_OP='DELETE' THEN
    DELETE FROM tech2d.acessos_recentes WHERE site='pegaki' AND id_usuario=OLD.uid
      AND ultimo_acesso_em<=OLD.last_seen_at;
    RETURN OLD;
  END IF;
  INSERT INTO tech2d.acessos_recentes AS recent(site,id_usuario,email,ultimo_acesso_em)
  VALUES ('pegaki',NEW.uid,NEW.email,NEW.last_seen_at)
  ON CONFLICT(site,id_usuario) DO UPDATE SET email=excluded.email,ultimo_acesso_em=excluded.ultimo_acesso_em
  WHERE recent.ultimo_acesso_em<=excluded.ultimo_acesso_em;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION tech2d.sincronizar_acesso_pegaki() FROM PUBLIC;
CREATE TRIGGER replicar_acesso_pegaki AFTER INSERT OR UPDATE OR DELETE ON tech2d.acessos_recentes_pegaki
FOR EACH ROW EXECUTE FUNCTION tech2d.sincronizar_acesso_pegaki();
COMMENT ON TABLE tech2d.acessos_recentes IS 'Último acesso autenticado por site e conta: Agenda, Cadê o professor e Pegaki. Retenção de 90 dias; chave de rede apenas para moderação da Agenda.';
COMMENT ON COLUMN tech2d.acessos_recentes.site IS 'Origem do acesso: agenda, professores ou pegaki. Compõe a chave com id_usuario para preservar acessos da mesma conta em sites diferentes.';
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:029_consolidar_acessos_pegaki';
