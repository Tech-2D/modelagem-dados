-- Contratação: aplicar somente após publicar a API que usa acessos_recentes.
LOCK TABLE tech2d.acessos_recentes_pegaki IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
  IF EXISTS (
    SELECT FROM tech2d.acessos_recentes_pegaki p
    LEFT JOIN tech2d.acessos_recentes r ON r.site='pegaki' AND r.id_usuario=p.uid
    WHERE r.id_usuario IS NULL OR r.ultimo_acesso_em<p.last_seen_at
      OR (r.ultimo_acesso_em=p.last_seen_at AND r.email IS DISTINCT FROM p.email)
  ) THEN RAISE EXCEPTION 'Existem acessos do Pegaki ainda não consolidados'; END IF;
END $$;
DROP TABLE tech2d.acessos_recentes_pegaki;
DROP FUNCTION tech2d.sincronizar_acesso_pegaki();
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:031_retirar_acessos_pegaki';
