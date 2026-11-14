-- Prepara a tabela consolidada e replica as gravações da versão anterior da API.
CREATE TABLE tech2d.acessos_recentes (
  site varchar(16) NOT NULL CHECK (site IN ('agenda','professores')),
  id_usuario varchar(128) NOT NULL,
  email varchar(320),
  ultimo_acesso_em timestamptz NOT NULL,
  chave_rede varchar(64) CHECK (chave_rede IS NULL OR (site='agenda' AND chave_rede ~ '^[0-9a-f]{64}$')),
  PRIMARY KEY (site,id_usuario)
);
CREATE INDEX acessos_recentes_por_site ON tech2d.acessos_recentes(site,ultimo_acesso_em DESC,id_usuario);
COMMENT ON TABLE tech2d.acessos_recentes IS 'Último acesso autenticado por site e conta. A chave de rede só é usada na Agenda.';
COMMENT ON COLUMN tech2d.acessos_recentes.site IS 'Site em que a conta foi vista.';
COMMENT ON COLUMN tech2d.acessos_recentes.id_usuario IS 'UID da conta autenticada.';
COMMENT ON COLUMN tech2d.acessos_recentes.email IS 'E-mail da conta, quando disponível.';
COMMENT ON COLUMN tech2d.acessos_recentes.ultimo_acesso_em IS 'Momento do último acesso autenticado ao site.';
COMMENT ON COLUMN tech2d.acessos_recentes.chave_rede IS 'Identificador de rede derivado para moderação da Agenda.';

LOCK TABLE tech2d.acessos_recentes_agenda,tech2d.acessos_recentes_professores IN SHARE ROW EXCLUSIVE MODE;
INSERT INTO tech2d.acessos_recentes
SELECT 'agenda', id_usuario,email,ultimo_acesso_em,chave_rede FROM tech2d.acessos_recentes_agenda
UNION ALL
SELECT 'professores',id_usuario,email,ultimo_acesso_em,NULL FROM tech2d.acessos_recentes_professores;

CREATE FUNCTION tech2d.sincronizar_acesso_recente() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF TG_OP='DELETE' THEN
    DELETE FROM tech2d.acessos_recentes WHERE site=TG_ARGV[0] AND id_usuario=OLD.id_usuario
      AND ultimo_acesso_em<=OLD.ultimo_acesso_em;
    RETURN OLD;
  END IF;
  INSERT INTO tech2d.acessos_recentes AS recent(site,id_usuario,email,ultimo_acesso_em,chave_rede)
  VALUES (TG_ARGV[0],NEW.id_usuario,NEW.email,NEW.ultimo_acesso_em,to_jsonb(NEW)->>'chave_rede')
  ON CONFLICT(site,id_usuario) DO UPDATE SET email=excluded.email,
    ultimo_acesso_em=excluded.ultimo_acesso_em,chave_rede=excluded.chave_rede
  WHERE recent.ultimo_acesso_em<=excluded.ultimo_acesso_em;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION tech2d.sincronizar_acesso_recente() FROM PUBLIC;
CREATE TRIGGER replicar_acesso_recente AFTER INSERT OR UPDATE OR DELETE ON tech2d.acessos_recentes_agenda
FOR EACH ROW EXECUTE FUNCTION tech2d.sincronizar_acesso_recente('agenda');
CREATE TRIGGER replicar_acesso_recente AFTER INSERT OR UPDATE OR DELETE ON tech2d.acessos_recentes_professores
FOR EACH ROW EXECUTE FUNCTION tech2d.sincronizar_acesso_recente('professores');
DO $$ BEGIN
  IF EXISTS(SELECT FROM pg_roles WHERE rolname='tech2d_api') THEN
    GRANT SELECT,INSERT,UPDATE,DELETE ON tech2d.acessos_recentes TO tech2d_api;
  END IF;
END $$;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:027_unificar_acessos';
