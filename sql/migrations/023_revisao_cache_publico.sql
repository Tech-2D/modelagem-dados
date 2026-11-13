CREATE FUNCTION tech2d.revisao_catalogo_publico(catalogo varchar) RETURNS varchar(32)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE tipos varchar[]; revisao varchar(32);
BEGIN
 CASE catalogo
  WHEN 'agenda' THEN tipos:=ARRAY['activities','agendaClasses','agendaUpdates','announcement'];
  WHEN 'updates' THEN tipos:=ARRAY['agendaClasses','agendaUpdates','announcement'];
  WHEN 'schedules' THEN tipos:=ARRAY['schedules'];
  ELSE RAISE EXCEPTION 'Catálogo inválido' USING ERRCODE='22023';
 END CASE;
 SELECT md5(coalesce(string_agg(id::text || ':' || versao::text, ',' ORDER BY id),'')) INTO revisao
 FROM tech2d.registros_aplicacao WHERE tipo=ANY(tipos);
 RETURN revisao;
END $$;
COMMENT ON FUNCTION tech2d.revisao_catalogo_publico(varchar) IS 'Calcula a revisão dos catálogos públicos para invalidar cópias Redis após inclusões, alterações e exclusões.';
REVOKE ALL ON FUNCTION tech2d.revisao_catalogo_publico(varchar) FROM PUBLIC;
DO $$ BEGIN IF EXISTS(SELECT FROM pg_roles WHERE rolname='tech2d_api') THEN GRANT EXECUTE ON FUNCTION tech2d.revisao_catalogo_publico(varchar) TO tech2d_api; END IF; END $$;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:023_revisao_cache_publico';
