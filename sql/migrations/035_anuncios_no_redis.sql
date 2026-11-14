-- Run after the API publishes general announcements through Redis.
SELECT pg_advisory_xact_lock(hashtext('tech2d-application-commit'));
LOCK TABLE tech2d.registros_aplicacao IN SHARE ROW EXCLUSIVE MODE;

DO $$
BEGIN
  IF EXISTS (SELECT FROM tech2d.anuncios)
     OR EXISTS (SELECT FROM tech2d.registros_aplicacao WHERE tipo='announcement') THEN
    RAISE EXCEPTION 'Preserve os comunicados existentes antes de retirar a tabela';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION tech2d.ler_registro(alvo bigint, tipo character varying)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT CASE tipo
    WHEN 'activities' THEN tech2d.ler_atividades(alvo)
    WHEN 'admins' THEN tech2d.ler_perfis_administrativos(alvo)
    WHEN 'recurringActivities' THEN tech2d.ler_regras_recorrencia(alvo)
    WHEN 'activityRetention' THEN tech2d.ler_regras_retencao(alvo)
    WHEN 'agendaClassRequests' THEN tech2d.ler_pedidos_agenda(alvo)
    WHEN 'agendaClasses' THEN tech2d.ler_turmas_agenda(alvo)
    WHEN 'representativeRequests' THEN tech2d.ler_pedidos_representacao(alvo)
    WHEN 'representativeInvites' THEN tech2d.ler_convites_representacao(alvo)
    WHEN 'representativeChat' THEN tech2d.ler_chat_representantes(alvo)


    WHEN 'suggestions' THEN tech2d.ler_sugestoes_atividade(alvo)
    WHEN 'feedback' THEN tech2d.ler_sugestoes_melhoria(alvo)
    WHEN 'feedback/messages' THEN tech2d.ler_mensagens_sugestao(alvo)
    WHEN 'agendaUpdates' THEN tech2d.ler_atualizacoes_agenda(alvo)
    WHEN 'boardNotices' THEN tech2d.ler_avisos_turma(alvo)
    WHEN 'schedules' THEN tech2d.ler_horarios_aula(alvo)
    WHEN 'userProfiles' THEN tech2d.ler_perfis_comunidade(alvo)
    WHEN 'purgedActivities' THEN tech2d.ler_atividades_arquivadas(alvo)
    WHEN '_agendaDigestPreferences' THEN tech2d.ler_preferencias_resumo(alvo)
    WHEN '_agendaDigestDeliveries' THEN tech2d.ler_entregas_resumo(alvo)
    WHEN '_agendaUploads' THEN tech2d.ler_envios_anexos(alvo)
    WHEN '_passwordResetLimits' THEN tech2d.ler_limites_servico(alvo)
    WHEN '_r2UploadLimits' THEN tech2d.ler_limites_servico(alvo)
    WHEN '_profilePhotoLimits' THEN tech2d.ler_limites_servico(alvo)
    WHEN 'personalKanban' THEN tech2d.ler_espacos_kanban(alvo)
    WHEN 'sharedKanban' THEN tech2d.ler_espacos_kanban(alvo)
    WHEN 'kanbanMemberships' THEN tech2d.ler_participantes_kanban(alvo)
    WHEN 'kanbanRequests' THEN tech2d.ler_pedidos_kanban(alvo)
    WHEN '_kanbanFileCleanup' THEN tech2d.ler_limpeza_anexos_kanban(alvo)
    ELSE NULL END;
$function$
;

CREATE OR REPLACE FUNCTION tech2d.gravar_conteudo(alvo bigint, tipo character varying, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  IF jsonb_typeof(objeto) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Objeto de registro inválido' USING ERRCODE='check_violation';
  END IF;
  objeto := tech2d.padronizar_listas_registro(tipo,tech2d.remover_nulos_recursivo(objeto));
  CASE tipo
    WHEN 'activities' THEN PERFORM tech2d.gravar_atividades(alvo,objeto);
    WHEN 'admins' THEN PERFORM tech2d.gravar_perfis_administrativos(alvo,objeto);
    WHEN 'recurringActivities' THEN PERFORM tech2d.gravar_regras_recorrencia(alvo,objeto);
    WHEN 'activityRetention' THEN PERFORM tech2d.gravar_regras_retencao(alvo,objeto);
    WHEN 'agendaClassRequests' THEN PERFORM tech2d.gravar_pedidos_agenda(alvo,objeto);
    WHEN 'agendaClasses' THEN PERFORM tech2d.gravar_turmas_agenda(alvo,objeto);
    WHEN 'representativeRequests' THEN PERFORM tech2d.gravar_pedidos_representacao(alvo,objeto);
    WHEN 'representativeInvites' THEN PERFORM tech2d.gravar_convites_representacao(alvo,objeto);
    WHEN 'representativeChat' THEN PERFORM tech2d.gravar_chat_representantes(alvo,objeto);


    WHEN 'suggestions' THEN PERFORM tech2d.gravar_sugestoes_atividade(alvo,objeto);
    WHEN 'feedback' THEN PERFORM tech2d.gravar_sugestoes_melhoria(alvo,objeto);
    WHEN 'feedback/messages' THEN PERFORM tech2d.gravar_mensagens_sugestao(alvo,objeto);
    WHEN 'agendaUpdates' THEN PERFORM tech2d.gravar_atualizacoes_agenda(alvo,objeto);
    WHEN 'boardNotices' THEN PERFORM tech2d.gravar_avisos_turma(alvo,objeto);
    WHEN 'schedules' THEN PERFORM tech2d.gravar_horarios_aula(alvo,objeto);
    WHEN 'userProfiles' THEN PERFORM tech2d.gravar_perfis_comunidade(alvo,objeto);
    WHEN 'purgedActivities' THEN PERFORM tech2d.gravar_atividades_arquivadas(alvo,objeto);
    WHEN '_agendaDigestPreferences' THEN PERFORM tech2d.gravar_preferencias_resumo(alvo,objeto);
    WHEN '_agendaDigestDeliveries' THEN PERFORM tech2d.gravar_entregas_resumo(alvo,objeto);
    WHEN '_agendaUploads' THEN PERFORM tech2d.gravar_envios_anexos(alvo,objeto);
    WHEN '_passwordResetLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);
    WHEN '_r2UploadLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);
    WHEN '_profilePhotoLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);
    WHEN 'personalKanban' THEN PERFORM tech2d.gravar_espacos_kanban(alvo,objeto);
    WHEN 'sharedKanban' THEN PERFORM tech2d.gravar_espacos_kanban(alvo,objeto);
    WHEN 'kanbanMemberships' THEN PERFORM tech2d.gravar_participantes_kanban(alvo,objeto);
    WHEN 'kanbanRequests' THEN PERFORM tech2d.gravar_pedidos_kanban(alvo,objeto);
    WHEN '_kanbanFileCleanup' THEN PERFORM tech2d.gravar_limpeza_anexos_kanban(alvo,objeto);
    ELSE RAISE EXCEPTION 'Tipo de registro desconhecido' USING ERRCODE='check_violation';
  END CASE;
  IF tech2d.ler_registro(alvo,tipo) IS DISTINCT FROM objeto THEN
    RAISE EXCEPTION 'Registro incompatível com as colunas de %',tipo USING ERRCODE='check_violation';
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION tech2d.gravar_registros(lote jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  item record;
  partes text[];
  grupo varchar(40);
  pai varchar(320);
  chave varchar(320);
  alvo bigint;
BEGIN
  FOR item IN SELECT r.path,r.data FROM jsonb_to_recordset(lote) r(path text,data jsonb)
    ORDER BY (data IS NULL),length(path),path
  LOOP
    partes := string_to_array(item.path,'/');
    IF cardinality(partes) NOT IN (2,4) OR array_position(partes,'') IS NOT NULL THEN
      RAISE EXCEPTION 'Referência inválida' USING ERRCODE='check_violation';
    END IF;
    grupo := partes[1];
    pai := '';
    chave := partes[2];
    IF cardinality(partes)=4 THEN
      grupo := grupo || '/' || partes[3];
      pai := partes[2];
      chave := partes[4];
    END IF;
    IF grupo IN ('polls','polls/votes','pollVoterAccess','notebookNotes','announcement') THEN
      RAISE EXCEPTION 'Recurso descontinuado' USING ERRCODE='check_violation';
    END IF;
    IF item.data IS NULL THEN
      DELETE FROM tech2d.registros_aplicacao WHERE tipo=grupo AND referencia_pai=pai AND referencia=chave;
    ELSE
      INSERT INTO tech2d.registros_aplicacao(tipo,referencia_pai,referencia,id_pai)
      VALUES(grupo,pai,chave,(SELECT id FROM tech2d.registros_aplicacao
        WHERE tipo=partes[1] AND referencia_pai='' AND referencia=pai AND pai<>''))
      ON CONFLICT(tipo,referencia_pai,referencia) DO UPDATE
      SET versao=registros_aplicacao.versao+1,atualizado_em=now(),id_pai=excluded.id_pai
      RETURNING id INTO alvo;
      PERFORM tech2d.gravar_conteudo(alvo,grupo,item.data);
      IF pai='' AND grupo='feedback' THEN
        UPDATE tech2d.registros_aplicacao SET id_pai=alvo
        WHERE tipo='feedback/messages'
          AND referencia_pai=chave AND id_pai IS NULL;
      END IF;
    END IF;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION tech2d.consultar_catalogo_agenda(p_turma text, p_incluir_atividades boolean)
 RETURNS TABLE(activities jsonb, documents jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
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
    WHERE collection IN ('agendaClasses', 'agendaUpdates')
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
$function$
;

CREATE OR REPLACE FUNCTION tech2d.revisao_catalogo_publico(catalogo character varying)
 RETURNS character varying
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE tipos varchar[]; revisao varchar(32);
BEGIN
 CASE catalogo
  WHEN 'agenda' THEN tipos:=ARRAY['activities','agendaClasses','agendaUpdates'];
  WHEN 'updates' THEN tipos:=ARRAY['agendaClasses','agendaUpdates'];
  WHEN 'schedules' THEN tipos:=ARRAY['schedules'];
  ELSE RAISE EXCEPTION 'Catálogo inválido' USING ERRCODE='22023';
 END CASE;
 SELECT md5(coalesce(string_agg(id::text || ':' || versao::text, ',' ORDER BY id),'')) INTO revisao
 FROM tech2d.registros_aplicacao WHERE tipo=ANY(tipos);
 RETURN revisao;
END $function$
;

CREATE OR REPLACE VIEW tech2d.visao_documentos_catalogo AS
SELECT tipo AS collection, referencia AS id, tech2d.ler_registro(id,tipo) AS data
FROM tech2d.registros_aplicacao
WHERE tipo IN ('schedules','agendaClasses','agendaUpdates','boardNotices');

ALTER TABLE tech2d.registros_aplicacao DROP CONSTRAINT registros_aplicacao_recursos_ativos_check;
ALTER TABLE tech2d.registros_aplicacao ADD CONSTRAINT registros_aplicacao_recursos_ativos_check
 CHECK (tipo NOT IN ('polls','polls/votes','pollVoterAccess','notebookNotes','announcement'));

DROP FUNCTION tech2d.ler_anuncios(bigint), tech2d.gravar_anuncios(bigint,jsonb);
DROP TABLE tech2d.anuncios;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:035_anuncios_no_redis';
