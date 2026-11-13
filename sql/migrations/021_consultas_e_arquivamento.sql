-- Keep the HTTP response and its public field allowlist in the Worker.
CREATE FUNCTION tech2d.consultar_catalogo_agenda(p_turma text, p_incluir_atividades boolean)
RETURNS TABLE (activities jsonb, documents jsonb)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = pg_catalog AS $$
  WITH atividades_selecionadas AS (
    SELECT *
    FROM tech2d.visao_atividades
    WHERE p_incluir_atividades
      AND (p_turma IS NULL OR turma_id = p_turma OR turma_id IS NULL)
    ORDER BY date, time, id
    LIMIT 10001
  ), documentos_selecionados AS (
    SELECT collection, id, data
    FROM tech2d.visao_documentos_catalogo
    WHERE collection IN ('agendaClasses', 'agendaUpdates', 'announcement')
    ORDER BY data->>'publishedAt' DESC NULLS LAST
    LIMIT 10001
  )
  SELECT
    coalesce((SELECT jsonb_agg(
      to_jsonb(a) || jsonb_build_object('version', a.version::text)
      ORDER BY a.date, a.time, a.id
    ) FROM atividades_selecionadas a), '[]'::jsonb),
    coalesce((SELECT jsonb_agg(
      to_jsonb(d) ORDER BY d.data->>'publishedAt' DESC NULLS LAST
    ) FROM documentos_selecionados d), '[]'::jsonb);
$$;
COMMENT ON FUNCTION tech2d.consultar_catalogo_agenda(text, boolean)
IS 'Seleciona atividades gerais e da turma e reúne os documentos do catálogo em uma consulta limitada.';

CREATE VIEW tech2d.visao_atividades_automacao AS
SELECT r.referencia AS id, tech2d.referencia_api(r.tipo, r.referencia_pai, r.referencia) AS caminho,
  a.turma, a.data, a.referencia_recorrencia,
  tech2d.ler_registro(r.id, r.tipo) AS conteudo
FROM tech2d.atividades a
JOIN tech2d.registros_aplicacao r ON r.id = a.id_registro
WHERE r.tipo = 'activities';
COMMENT ON VIEW tech2d.visao_atividades_automacao
IS 'Atividades com turma, data e recorrência tipadas para os jobs. O conteúdo é reconstruído apenas para uso no arquivamento.';

CREATE FUNCTION tech2d.arquivar_atividade(
  p_id text, p_motivo text, p_arquivada_em text, p_dias_retencao integer
) RETURNS boolean
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog AS $$
DECLARE
  origem record;
  destino text;
  arquivo jsonb;
BEGIN
  IF NOT coalesce(
    (p_motivo = 'recurrence' AND p_dias_retencao IS NULL)
    OR (p_motivo = 'retention' AND p_dias_retencao BETWEEN 30 AND 730), false
  ) OR p_arquivada_em IS NULL THEN
    RAISE EXCEPTION 'Parâmetros de arquivamento inválidos' USING ERRCODE = '22023';
  END IF;

  -- Share the lock used by edits and automations. These changes commit together.
  PERFORM pg_advisory_xact_lock(hashtext('tech2d-application-commit'));
  SELECT caminho, turma, conteudo INTO origem
  FROM tech2d.visao_atividades_automacao
  WHERE id = p_id AND turma IS NOT NULL;
  IF NOT FOUND THEN RETURN false; END IF;

  destino := 'purgedActivities/' || p_id;
  -- A reactivated recurrence may reuse an ID. Keep each archived version.
  IF EXISTS (SELECT 1 FROM tech2d.visao_documentos_aplicacao WHERE path = destino) THEN
    destino := destino || '_' || gen_random_uuid();
  END IF;

  arquivo := jsonb_build_object('originalId', p_id, 'turmaId', origem.turma,
    'originalData', origem.conteudo, 'reason', p_motivo, 'archivedAt', p_arquivada_em);
  IF p_dias_retencao IS NOT NULL THEN
    arquivo := arquivo || jsonb_build_object('retentionDays', p_dias_retencao);
  END IF;

  PERFORM tech2d.gravar_registros(jsonb_build_array(
    jsonb_build_object('path', destino, 'data', arquivo),
    jsonb_build_object('path', origem.caminho, 'data', NULL)
  ));
  INSERT INTO tech2d.visao_auditoria_aplicacao(actor, path, operation, previous_data)
  VALUES ('job:' || p_motivo, origem.caminho, 'archive-delete', origem.conteudo);
  RETURN true;
END $$;
COMMENT ON FUNCTION tech2d.arquivar_atividade(text, text, text, integer)
IS 'Arquiva uma atividade da turma, retira a linha ativa e grava auditoria em uma única operação.';

REVOKE ALL ON FUNCTION tech2d.consultar_catalogo_agenda(text, boolean),
  tech2d.arquivar_atividade(text, text, text, integer) FROM PUBLIC;
REVOKE ALL ON tech2d.visao_atividades_automacao FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'tech2d_api') THEN
    GRANT SELECT ON tech2d.visao_atividades_automacao TO tech2d_api;
    GRANT EXECUTE ON FUNCTION tech2d.consultar_catalogo_agenda(text, boolean),
      tech2d.arquivar_atividade(text, text, text, integer) TO tech2d_api;
  END IF;
END $$;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:021_consultas_e_arquivamento';
