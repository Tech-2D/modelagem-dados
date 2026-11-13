-- Remove campos_nulos de todas as tabelas e simplifica o contrato SQL.
-- Campos SQL NULL passam a ser omitidos da representação JSON.
SELECT pg_advisory_xact_lock(hashtext('tech2d-application-commit'));

CREATE OR REPLACE FUNCTION tech2d.remover_nulos_recursivo(valor jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path TO 'pg_catalog' AS $function$
DECLARE resultado jsonb;
BEGIN
  IF valor IS NULL THEN RETURN NULL; END IF;
  CASE jsonb_typeof(valor)
    WHEN 'object' THEN
      SELECT coalesce(jsonb_object_agg(chave, tech2d.remover_nulos_recursivo(conteudo)), '{}'::jsonb)
        INTO resultado FROM jsonb_each(valor) AS item(chave, conteudo)
        WHERE conteudo <> 'null'::jsonb;
      RETURN resultado;
    WHEN 'array' THEN
      SELECT coalesce(jsonb_agg(tech2d.remover_nulos_recursivo(conteudo) ORDER BY ordem), '[]'::jsonb)
        INTO resultado FROM jsonb_array_elements(valor) WITH ORDINALITY AS item(conteudo, ordem);
      RETURN resultado;
    ELSE RETURN valor;
  END CASE;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_acessos_votacao(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.acessos_votacao (id_registro,email,turma,situacao,solicitado_em,revisado_em,revisado_por) VALUES (alvo,objeto->>'email',objeto->>'turmaId',objeto->>'status',objeto->>'requestedAt',objeto->>'reviewedAt',objeto->>'reviewedBy')
  ON CONFLICT(id_registro) DO UPDATE SET email=excluded.email, turma=excluded.turma, situacao=excluded.situacao, solicitado_em=excluded.solicitado_em, revisado_em=excluded.revisado_em, revisado_por=excluded.revisado_por;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_anotacoes(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.anotacoes (id_registro,titulo,conteudo,disciplina,turma,id_autor,email_autor,criado_em,alterado_em) VALUES (alvo,objeto->>'title',objeto->>'content',objeto->>'subject',objeto->>'className',objeto->>'authorUid',objeto->>'authorEmail',objeto->>'createdAt',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, conteudo=excluded.conteudo, disciplina=excluded.disciplina, turma=excluded.turma, id_autor=excluded.id_autor, email_autor=excluded.email_autor, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_anuncios(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.anuncios (id_registro,mensagem,alterado_em) VALUES (alvo,objeto->>'message',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET mensagem=excluded.mensagem, alterado_em=excluded.alterado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_atividades(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.atividades (id_registro,titulo,descricao,tipo,disciplina,data,hora,turma,criado_por,email_criador,referencia_recorrencia,criado_em,alterado_em) VALUES (alvo,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'date')::date,(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'recurringId',objeto->>'createdAt',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, descricao=excluded.descricao, tipo=excluded.tipo, disciplina=excluded.disciplina, data=excluded.data, hora=excluded.hora, turma=excluded.turma, criado_por=excluded.criado_por, email_criador=excluded.email_criador, referencia_recorrencia=excluded.referencia_recorrencia, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em;
  DELETE FROM tech2d.anexos_atividade WHERE id_pai=alvo AND grupo='attachments';
  IF jsonb_typeof(objeto->'attachments')='array' THEN
    PERFORM tech2d.inserir_anexos_atividade(alvo,'attachments',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'attachments') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.atividades SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('attachments') AND jsonb_typeof(value)='array') WHERE id_registro=alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_atividades_arquivadas(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.atividades_arquivadas (id_registro,referencia_atividade,turma,motivo,arquivada_em,dias_retencao,anexos_removidos_em) VALUES (alvo,objeto->>'originalId',objeto->>'turmaId',objeto->>'reason',objeto->>'archivedAt',(objeto->>'retentionDays')::smallint,objeto->>'r2CleanedAt')
  ON CONFLICT(id_registro) DO UPDATE SET referencia_atividade=excluded.referencia_atividade, turma=excluded.turma, motivo=excluded.motivo, arquivada_em=excluded.arquivada_em, dias_retencao=excluded.dias_retencao, anexos_removidos_em=excluded.anexos_removidos_em;
  DELETE FROM tech2d.conteudo_atividade_arquivada WHERE id_pai=alvo AND grupo='originalData';
  IF jsonb_typeof(objeto->'originalData')='object' THEN
    PERFORM tech2d.inserir_conteudo_atividade_arquivada(alvo,'originalData',0,objeto->'originalData');
  END IF;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_atualizacoes_agenda(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.atualizacoes_agenda (id_registro,titulo,conteudo,criado_por,publicado_em,referencia_sugestao,nome_credito,mensagem_sugestao) VALUES (alvo,objeto->>'title',objeto->>'body',objeto->>'createdBy',objeto->>'publishedAt',objeto->>'sourceFeedbackId',objeto->>'sourceName',objeto->>'sourceMessage')
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, conteudo=excluded.conteudo, criado_por=excluded.criado_por, publicado_em=excluded.publicado_em, referencia_sugestao=excluded.referencia_sugestao, nome_credito=excluded.nome_credito, mensagem_sugestao=excluded.mensagem_sugestao;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_avisos_turma(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.avisos_turma (id_registro,turma,titulo,conteudo,tipo,expira_em,expurgo_em,criado_por,email_autor,criado_em,alterado_em) VALUES (alvo,objeto->>'turmaId',objeto->>'title',objeto->>'body',objeto->>'type',objeto->>'expiresAt',objeto->>'purgeAt',objeto->>'createdBy',objeto->>'authorEmail',objeto->>'createdAt',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, titulo=excluded.titulo, conteudo=excluded.conteudo, tipo=excluded.tipo, expira_em=excluded.expira_em, expurgo_em=excluded.expurgo_em, criado_por=excluded.criado_por, email_autor=excluded.email_autor, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_chat_representantes(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.chat_representantes (id_registro,mensagem,remetente,email_remetente,papel_remetente,turma_remetente,criado_em) VALUES (alvo,objeto->>'text',objeto->>'senderId',objeto->>'senderEmail',objeto->>'senderRole',objeto->>'senderTurma',objeto->>'createdAt')
  ON CONFLICT(id_registro) DO UPDATE SET mensagem=excluded.mensagem, remetente=excluded.remetente, email_remetente=excluded.email_remetente, papel_remetente=excluded.papel_remetente, turma_remetente=excluded.turma_remetente, criado_em=excluded.criado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_conteudo(alvo bigint, tipo character varying, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  IF jsonb_typeof(objeto) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Objeto de registro inválido' USING ERRCODE='check_violation';
  END IF;
  CASE tipo
    WHEN 'activities' THEN PERFORM tech2d.gravar_atividades(alvo,objeto);    WHEN 'admins' THEN PERFORM tech2d.gravar_perfis_administrativos(alvo,objeto);    WHEN 'recurringActivities' THEN PERFORM tech2d.gravar_regras_recorrencia(alvo,objeto);    WHEN 'activityRetention' THEN PERFORM tech2d.gravar_regras_retencao(alvo,objeto);    WHEN 'agendaClassRequests' THEN PERFORM tech2d.gravar_pedidos_agenda(alvo,objeto);    WHEN 'agendaClasses' THEN PERFORM tech2d.gravar_turmas_agenda(alvo,objeto);    WHEN 'representativeRequests' THEN PERFORM tech2d.gravar_pedidos_representacao(alvo,objeto);    WHEN 'representativeInvites' THEN PERFORM tech2d.gravar_convites_representacao(alvo,objeto);    WHEN 'representativeChat' THEN PERFORM tech2d.gravar_chat_representantes(alvo,objeto);    WHEN 'polls' THEN PERFORM tech2d.gravar_enquetes(alvo,objeto);    WHEN 'polls/votes' THEN PERFORM tech2d.gravar_votos_enquete(alvo,objeto);    WHEN 'pollVoterAccess' THEN PERFORM tech2d.gravar_acessos_votacao(alvo,objeto);    WHEN 'suggestions' THEN PERFORM tech2d.gravar_sugestoes_atividade(alvo,objeto);    WHEN 'feedback' THEN PERFORM tech2d.gravar_sugestoes_melhoria(alvo,objeto);    WHEN 'feedback/messages' THEN PERFORM tech2d.gravar_mensagens_sugestao(alvo,objeto);    WHEN 'announcement' THEN PERFORM tech2d.gravar_anuncios(alvo,objeto);    WHEN 'agendaUpdates' THEN PERFORM tech2d.gravar_atualizacoes_agenda(alvo,objeto);    WHEN 'boardNotices' THEN PERFORM tech2d.gravar_avisos_turma(alvo,objeto);    WHEN 'schedules' THEN PERFORM tech2d.gravar_horarios_aula(alvo,objeto);    WHEN 'notebookNotes' THEN PERFORM tech2d.gravar_anotacoes(alvo,objeto);    WHEN 'userProfiles' THEN PERFORM tech2d.gravar_perfis_comunidade(alvo,objeto);    WHEN 'purgedActivities' THEN PERFORM tech2d.gravar_atividades_arquivadas(alvo,objeto);    WHEN '_agendaDigestPreferences' THEN PERFORM tech2d.gravar_preferencias_resumo(alvo,objeto);    WHEN '_agendaDigestDeliveries' THEN PERFORM tech2d.gravar_entregas_resumo(alvo,objeto);    WHEN '_agendaUploads' THEN PERFORM tech2d.gravar_envios_anexos(alvo,objeto);    WHEN '_passwordResetLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);    WHEN '_r2UploadLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);    WHEN '_profilePhotoLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);    WHEN 'personalKanban' THEN PERFORM tech2d.gravar_espacos_kanban(alvo,objeto);    WHEN 'sharedKanban' THEN PERFORM tech2d.gravar_espacos_kanban(alvo,objeto);    WHEN 'kanbanMemberships' THEN PERFORM tech2d.gravar_participantes_kanban(alvo,objeto);    WHEN 'kanbanRequests' THEN PERFORM tech2d.gravar_pedidos_kanban(alvo,objeto);    WHEN '_kanbanFileCleanup' THEN PERFORM tech2d.gravar_limpeza_anexos_kanban(alvo,objeto);
    ELSE RAISE EXCEPTION 'Tipo de registro desconhecido' USING ERRCODE='check_violation';
  END CASE;
  IF tech2d.ler_registro(alvo,tipo) IS DISTINCT FROM tech2d.remover_nulos_recursivo(objeto) THEN
    RAISE EXCEPTION 'Registro incompatível com as colunas de %',tipo USING ERRCODE='check_violation';
  END IF;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_convites_representacao(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.convites_representacao (id_registro,email,turma,referencia_pedido,aprovado_em) VALUES (alvo,objeto->>'email',objeto->>'turmaId',objeto->>'requestId',objeto->>'approvedAt')
  ON CONFLICT(id_registro) DO UPDATE SET email=excluded.email, turma=excluded.turma, referencia_pedido=excluded.referencia_pedido, aprovado_em=excluded.aprovado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_enquetes(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.enquetes (id_registro,turma,pergunta,situacao,criado_por,criado_em) VALUES (alvo,objeto->>'turmaId',objeto->>'question',objeto->>'status',objeto->>'createdBy',objeto->>'createdAt')
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, pergunta=excluded.pergunta, situacao=excluded.situacao, criado_por=excluded.criado_por, criado_em=excluded.criado_em;
  DELETE FROM tech2d.opcoes_enquete WHERE id_pai=alvo AND grupo='options';
  IF jsonb_typeof(objeto->'options')='array' THEN
    PERFORM tech2d.inserir_opcoes_enquete(alvo,'options',(pos-1)::integer,jsonb_build_object('valor',value))
    FROM jsonb_array_elements(objeto->'options') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.enquetes SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('options') AND jsonb_typeof(value)='array') WHERE id_registro=alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_entregas_resumo(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.entregas_resumo (id_registro,situacao,inicio_semana,criada_em_ms,concluida_em_ms) VALUES (alvo,objeto->>'status',(objeto->>'weekStart')::date,(objeto->>'createdAt')::bigint,(objeto->>'completedAt')::bigint)
  ON CONFLICT(id_registro) DO UPDATE SET situacao=excluded.situacao, inicio_semana=excluded.inicio_semana, criada_em_ms=excluded.criada_em_ms, concluida_em_ms=excluded.concluida_em_ms;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_envios_anexos(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.envios_anexos (id_registro,referencia_atividade,nome,tipo_mime,tamanho_bytes,chave_arquivo,id_usuario,criado_em_ms) VALUES (alvo,objeto->>'activityId',objeto->>'name',objeto->>'contentType',(objeto->>'size')::bigint,objeto->>'key',objeto->>'uid',(objeto->>'createdAt')::bigint)
  ON CONFLICT(id_registro) DO UPDATE SET referencia_atividade=excluded.referencia_atividade, nome=excluded.nome, tipo_mime=excluded.tipo_mime, tamanho_bytes=excluded.tamanho_bytes, chave_arquivo=excluded.chave_arquivo, id_usuario=excluded.id_usuario, criado_em_ms=excluded.criado_em_ms;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_espacos_kanban(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.espacos_kanban (id_registro,id_proprietario,versao_formato,criado_em,alterado_em) VALUES (alvo,objeto->>'ownerId',(objeto->>'schemaVersion')::smallint,objeto->>'createdAt',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET id_proprietario=excluded.id_proprietario, versao_formato=excluded.versao_formato, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em;
  DELETE FROM tech2d.quadros_kanban WHERE id_pai=alvo AND grupo='boards';
  IF jsonb_typeof(objeto->'boards')='array' THEN
    PERFORM tech2d.inserir_quadros_kanban(alvo,'boards',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'boards') WITH ORDINALITY AS x(value,pos);
  END IF;
  DELETE FROM tech2d.quadros_kanban WHERE id_pai=alvo AND grupo='board';
  IF jsonb_typeof(objeto->'board')='object' THEN
    PERFORM tech2d.inserir_quadros_kanban(alvo,'board',0,objeto->'board');
  END IF;
  UPDATE tech2d.espacos_kanban SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('boards') AND jsonb_typeof(value)='array') WHERE id_registro=alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_horarios_aula(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  chave varchar(320);
  inicio time;
  fim time;
BEGIN
  SELECT referencia INTO STRICT chave FROM tech2d.registros_aplicacao WHERE id=alvo;
  IF ((objeto->>'startTime') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
    AND (objeto->>'endTime') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
    AND (objeto->>'dayOfWeek') ~ '^[0-6]$'
    AND jsonb_typeof(objeto->'active')='boolean') IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Invalid schedule projection' USING ERRCODE='check_violation';
  END IF;
  inicio := (objeto->>'startTime')::time;
  fim := (objeto->>'endTime')::time;
  INSERT INTO tech2d.professores(nome) VALUES(objeto->>'professor') ON CONFLICT(nome) DO NOTHING;
  INSERT INTO tech2d.disciplinas(nome) VALUES(objeto->>'subject') ON CONFLICT(nome) DO NOTHING;
  INSERT INTO tech2d.turmas(nome) VALUES(objeto->>'className') ON CONFLICT(nome) DO NOTHING;
  INSERT INTO tech2d.faixas_horario(hora_inicio,hora_fim) VALUES(inicio,fim) ON CONFLICT(hora_inicio,hora_fim) DO NOTHING;

  INSERT INTO tech2d.horarios_aula(id,id_registro,id_professor,id_disciplina,id_turma,id_faixa_horario,dia_semana,ativo,andar,sala,criado_em,alterado_em)
  SELECT chave,alvo,p.id,d.id,t.id,f.id,(objeto->>'dayOfWeek')::smallint,(objeto->>'active')::boolean,
    objeto->>'floor',objeto->>'roomDescription',objeto->>'createdAt',objeto->>'updatedAt'
  FROM tech2d.professores p,tech2d.disciplinas d,tech2d.turmas t,tech2d.faixas_horario f
  WHERE p.nome=objeto->>'professor' AND d.nome=objeto->>'subject' AND t.nome=objeto->>'className'
    AND f.hora_inicio=inicio AND f.hora_fim=fim
  ON CONFLICT(id) DO UPDATE SET id_registro=excluded.id_registro,id_professor=excluded.id_professor,
    id_disciplina=excluded.id_disciplina,id_turma=excluded.id_turma,id_faixa_horario=excluded.id_faixa_horario,
    dia_semana=excluded.dia_semana,ativo=excluded.ativo,andar=excluded.andar,sala=excluded.sala,
    criado_em=excluded.criado_em,alterado_em=excluded.alterado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_limites_servico(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.limites_servico (id_registro,quantidade,expira_em_ms) VALUES (alvo,(objeto->>'count')::integer,(objeto->>'resetAt')::bigint)
  ON CONFLICT(id_registro) DO UPDATE SET quantidade=excluded.quantidade, expira_em_ms=excluded.expira_em_ms;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_limpeza_anexos_kanban(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.limpeza_anexos_kanban (id_registro,referencia_espaco,referencia_quadro,referencia_cartao) VALUES (alvo,objeto->>'path',objeto->>'board',objeto->>'task')
  ON CONFLICT(id_registro) DO UPDATE SET referencia_espaco=excluded.referencia_espaco, referencia_quadro=excluded.referencia_quadro, referencia_cartao=excluded.referencia_cartao;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_mensagens_sugestao(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.mensagens_sugestao (id_registro,mensagem,remetente,criado_em) VALUES (alvo,objeto->>'text',objeto->>'senderId',objeto->>'createdAt')
  ON CONFLICT(id_registro) DO UPDATE SET mensagem=excluded.mensagem, remetente=excluded.remetente, criado_em=excluded.criado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_participantes_kanban(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.participantes_kanban (id_registro,referencia_quadro,id_usuario,email,nome,criado_em) VALUES (alvo,objeto->>'boardId',objeto->>'userId',objeto->>'userEmail',objeto->>'name',objeto->>'createdAt')
  ON CONFLICT(id_registro) DO UPDATE SET referencia_quadro=excluded.referencia_quadro, id_usuario=excluded.id_usuario, email=excluded.email, nome=excluded.nome, criado_em=excluded.criado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_pedidos_agenda(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.pedidos_agenda (id_registro,nome_turma,email,situacao,criado_em,revisado_em) VALUES (alvo,objeto->>'className',objeto->>'email',objeto->>'status',objeto->>'createdAt',objeto->>'reviewedAt')
  ON CONFLICT(id_registro) DO UPDATE SET nome_turma=excluded.nome_turma, email=excluded.email, situacao=excluded.situacao, criado_em=excluded.criado_em, revisado_em=excluded.revisado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_pedidos_kanban(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.pedidos_kanban (id_registro,referencia_quadro,id_usuario,email,nome,criado_em,situacao,alterado_em) VALUES (alvo,objeto->>'boardId',objeto->>'userId',objeto->>'userEmail',objeto->>'name',objeto->>'createdAt',objeto->>'status',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET referencia_quadro=excluded.referencia_quadro, id_usuario=excluded.id_usuario, email=excluded.email, nome=excluded.nome, criado_em=excluded.criado_em, situacao=excluded.situacao, alterado_em=excluded.alterado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_pedidos_representacao(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.pedidos_representacao (id_registro,turma,email,situacao,criado_em,revisado_em) VALUES (alvo,objeto->>'turmaId',objeto->>'email',objeto->>'status',objeto->>'createdAt',objeto->>'reviewedAt')
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, email=excluded.email, situacao=excluded.situacao, criado_em=excluded.criado_em, revisado_em=excluded.revisado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_perfis_administrativos(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.perfis_administrativos (id_registro,papel,turma,criado_em) VALUES (alvo,objeto->>'role',objeto->>'turmaId',objeto->>'createdAt')
  ON CONFLICT(id_registro) DO UPDATE SET papel=excluded.papel, turma=excluded.turma, criado_em=excluded.criado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_perfis_comunidade(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.perfis_comunidade (id_registro,nome,empresa,turma,sala,andar,url_foto,alterado_em) VALUES (alvo,objeto->>'displayName',objeto->>'company',objeto->>'className',objeto->>'room',objeto->>'floor',objeto->>'photoUrl',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET nome=excluded.nome, empresa=excluded.empresa, turma=excluded.turma, sala=excluded.sala, andar=excluded.andar, url_foto=excluded.url_foto, alterado_em=excluded.alterado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_preferencias_resumo(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.preferencias_resumo (id_registro,ativo,turma,alterada_em_ms) VALUES (alvo,(objeto->>'enabled')::boolean,objeto->>'turmaId',(objeto->>'updatedAt')::bigint)
  ON CONFLICT(id_registro) DO UPDATE SET ativo=excluded.ativo, turma=excluded.turma, alterada_em_ms=excluded.alterada_em_ms;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_regras_recorrencia(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.regras_recorrencia (id_registro,titulo,descricao,tipo,disciplina,hora,turma,criado_por,email_criador,criado_em,inicio,fim,ativa,excluida,intervalo_semanas,dias_semana) VALUES (alvo,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'createdAt',(objeto->>'startDate')::date,(objeto->>'endDate')::date,(objeto->>'active')::boolean,(objeto->>'deleted')::boolean,(objeto->>'intervalWeeks')::smallint,CASE WHEN jsonb_typeof(objeto->'weekdays')='array' THEN ARRAY(SELECT value::smallint FROM jsonb_array_elements_text(objeto->'weekdays') WITH ORDINALITY AS x(value,pos) ORDER BY pos) END)
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, descricao=excluded.descricao, tipo=excluded.tipo, disciplina=excluded.disciplina, hora=excluded.hora, turma=excluded.turma, criado_por=excluded.criado_por, email_criador=excluded.email_criador, criado_em=excluded.criado_em, inicio=excluded.inicio, fim=excluded.fim, ativa=excluded.ativa, excluida=excluded.excluida, intervalo_semanas=excluded.intervalo_semanas, dias_semana=excluded.dias_semana;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_regras_retencao(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.regras_retencao (id_registro,turma,dias,ativa,alterado_por,alterado_em) VALUES (alvo,objeto->>'turmaId',(objeto->>'days')::smallint,(objeto->>'enabled')::boolean,objeto->>'updatedBy',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, dias=excluded.dias, ativa=excluded.ativa, alterado_por=excluded.alterado_por, alterado_em=excluded.alterado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_sugestoes_atividade(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.sugestoes_atividade (id_registro,titulo,descricao,tipo,disciplina,data,hora,turma,criado_em,alterado_em,situacao,resolucao,comentario_revisao,encerrada_em) VALUES (alvo,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'date')::date,(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdAt',objeto->>'updatedAt',objeto->>'status',objeto->>'resolution',objeto->>'reviewComment',objeto->>'closedAt')
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, descricao=excluded.descricao, tipo=excluded.tipo, disciplina=excluded.disciplina, data=excluded.data, hora=excluded.hora, turma=excluded.turma, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em, situacao=excluded.situacao, resolucao=excluded.resolucao, comentario_revisao=excluded.comentario_revisao, encerrada_em=excluded.encerrada_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_sugestoes_melhoria(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.sugestoes_melhoria (id_registro,mensagem,turma,criado_por,email_criador,criado_em,credito_autorizado,nome_credito,situacao,concluida_em,concluida_por) VALUES (alvo,objeto->>'message',objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'createdAt',(objeto->>'publicCreditAllowed')::boolean,objeto->>'publicCreditName',objeto->>'status',objeto->>'completedAt',objeto->>'completedBy')
  ON CONFLICT(id_registro) DO UPDATE SET mensagem=excluded.mensagem, turma=excluded.turma, criado_por=excluded.criado_por, email_criador=excluded.email_criador, criado_em=excluded.criado_em, credito_autorizado=excluded.credito_autorizado, nome_credito=excluded.nome_credito, situacao=excluded.situacao, concluida_em=excluded.concluida_em, concluida_por=excluded.concluida_por;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_turmas_agenda(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.turmas_agenda (id_registro,nome,ativa,referencia_pedido,aprovada_em) VALUES (alvo,objeto->>'name',(objeto->>'active')::boolean,objeto->>'requestId',objeto->>'approvedAt')
  ON CONFLICT(id_registro) DO UPDATE SET nome=excluded.nome, ativa=excluded.ativa, referencia_pedido=excluded.referencia_pedido, aprovada_em=excluded.aprovada_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_votos_enquete(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.votos_enquete (id_registro,indice_opcao,criado_em) VALUES (alvo,(objeto->>'optionIndex')::smallint,objeto->>'createdAt')
  ON CONFLICT(id_registro) DO UPDATE SET indice_opcao=excluded.indice_opcao, criado_em=excluded.criado_em;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.inserir_anexos_atividade(pai bigint, campo character varying, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.anexos_atividade (id_pai,grupo,ordem,referencia,nome,tipo_mime,tamanho_bytes,chave_arquivo,enviado_em,enviado_por) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'name',objeto->>'contentType',(objeto->>'size')::bigint,objeto->>'storagePath',objeto->>'uploadedAt',objeto->>'uploadedBy') RETURNING id INTO alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.inserir_anexos_atividade_arquivada(pai bigint, campo character varying, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.anexos_atividade_arquivada (id_pai,grupo,ordem,referencia,nome,tipo_mime,tamanho_bytes,chave_arquivo,enviado_em,enviado_por) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'name',objeto->>'contentType',(objeto->>'size')::bigint,objeto->>'storagePath',objeto->>'uploadedAt',objeto->>'uploadedBy') RETURNING id INTO alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.inserir_cartoes_kanban(pai bigint, campo character varying, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.cartoes_kanban (id_pai,grupo,ordem,referencia,referencia_coluna,titulo,descricao,prioridade,prazo,id_responsavel,etiquetas,referencias_atividades) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'columnId',objeto->>'title',objeto->>'description',objeto->>'priority',(objeto->>'dueDate')::date,objeto->>'assigneeId',CASE WHEN jsonb_typeof(objeto->'labels')='array' THEN ARRAY(SELECT value::varchar(30) FROM jsonb_array_elements_text(objeto->'labels') WITH ORDINALITY AS x(value,pos) ORDER BY pos) END,CASE WHEN jsonb_typeof(objeto->'activityIds')='array' THEN ARRAY(SELECT value::varchar(128) FROM jsonb_array_elements_text(objeto->'activityIds') WITH ORDINALITY AS x(value,pos) ORDER BY pos) END) RETURNING id INTO alvo;
  DELETE FROM tech2d.itens_checklist WHERE id_pai=alvo AND grupo='checklist';
  IF jsonb_typeof(objeto->'checklist')='array' THEN
    PERFORM tech2d.inserir_itens_checklist(alvo,'checklist',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'checklist') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.cartoes_kanban SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('checklist') AND jsonb_typeof(value)='array') WHERE id=alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.inserir_colunas_kanban(pai bigint, campo character varying, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.colunas_kanban (id_pai,grupo,ordem,referencia,nome,cor,concluida) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'name',objeto->>'color',(objeto->>'done')::boolean) RETURNING id INTO alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.inserir_conteudo_atividade_arquivada(pai bigint, campo character varying, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.conteudo_atividade_arquivada (id_pai,grupo,ordem,titulo,descricao,tipo,disciplina,data,hora,turma,criado_por,email_criador,referencia_recorrencia,criado_em,alterado_em) VALUES (pai,campo,posicao,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'date')::date,(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'recurringId',objeto->>'createdAt',objeto->>'updatedAt') RETURNING id INTO alvo;
  DELETE FROM tech2d.anexos_atividade_arquivada WHERE id_pai=alvo AND grupo='attachments';
  IF jsonb_typeof(objeto->'attachments')='array' THEN
    PERFORM tech2d.inserir_anexos_atividade_arquivada(alvo,'attachments',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'attachments') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.conteudo_atividade_arquivada SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('attachments') AND jsonb_typeof(value)='array') WHERE id=alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.inserir_itens_checklist(pai bigint, campo character varying, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.itens_checklist (id_pai,grupo,ordem,referencia,descricao,concluido) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'text',(objeto->>'done')::boolean) RETURNING id INTO alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.inserir_quadros_kanban(pai bigint, campo character varying, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.quadros_kanban (id_pai,grupo,ordem,referencia,nome,cor,compacto) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'name',objeto->>'color',(objeto->>'compact')::boolean) RETURNING id INTO alvo;
  DELETE FROM tech2d.colunas_kanban WHERE id_pai=alvo AND grupo='columns';
  IF jsonb_typeof(objeto->'columns')='array' THEN
    PERFORM tech2d.inserir_colunas_kanban(alvo,'columns',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'columns') WITH ORDINALITY AS x(value,pos);
  END IF;
  DELETE FROM tech2d.cartoes_kanban WHERE id_pai=alvo AND grupo='tasks';
  IF jsonb_typeof(objeto->'tasks')='array' THEN
    PERFORM tech2d.inserir_cartoes_kanban(alvo,'tasks',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'tasks') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.quadros_kanban SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('columns','tasks') AND jsonb_typeof(value)='array') WHERE id=alvo;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.ler_acessos_votacao(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'email', d.email,
    'turmaId', d.turma,
    'status', d.situacao,
    'requestedAt', d.solicitado_em,
    'reviewedAt', d.revisado_em,
    'reviewedBy', d.revisado_por
  ))
  FROM tech2d.acessos_votacao d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_anexos_atividade(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'name', d.nome,
    'contentType', d.tipo_mime,
    'size', d.tamanho_bytes,
    'storagePath', d.chave_arquivo,
    'uploadedAt', d.enviado_em,
    'uploadedBy', d.enviado_por
  ))
  FROM tech2d.anexos_atividade d WHERE d.id=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_anexos_atividade_arquivada(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'name', d.nome,
    'contentType', d.tipo_mime,
    'size', d.tamanho_bytes,
    'storagePath', d.chave_arquivo,
    'uploadedAt', d.enviado_em,
    'uploadedBy', d.enviado_por
  ))
  FROM tech2d.anexos_atividade_arquivada d WHERE d.id=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_anotacoes(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'title', d.titulo,
    'content', d.conteudo,
    'subject', d.disciplina,
    'className', d.turma,
    'authorUid', d.id_autor,
    'authorEmail', d.email_autor,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em
  ))
  FROM tech2d.anotacoes d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_anuncios(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'message', d.mensagem,
    'updatedAt', d.alterado_em
  ))
  FROM tech2d.anuncios d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_atividades(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'title', d.titulo,
    'description', d.descricao,
    'type', d.tipo,
    'subject', d.disciplina,
    'date', d.data,
    'time', to_char(d.hora,'HH24:MI'),
    'turmaId', d.turma,
    'createdBy', d.criado_por,
    'createdByEmail', d.email_criador,
    'recurringId', d.referencia_recorrencia,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em,
    'attachments', CASE WHEN 'attachments'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_anexos_atividade(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.anexos_atividade r WHERE r.id_pai=d.id_registro AND r.grupo='attachments') END
  ))
  FROM tech2d.atividades d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_atividades_arquivadas(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'originalId', d.referencia_atividade,
    'turmaId', d.turma,
    'reason', d.motivo,
    'archivedAt', d.arquivada_em,
    'retentionDays', d.dias_retencao,
    'r2CleanedAt', d.anexos_removidos_em,
    'originalData', (SELECT tech2d.ler_conteudo_atividade_arquivada(r.id) FROM tech2d.conteudo_atividade_arquivada r WHERE r.id_pai=d.id_registro AND r.grupo='originalData' AND r.ordem=0)
  ))
  FROM tech2d.atividades_arquivadas d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_atualizacoes_agenda(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'title', d.titulo,
    'body', d.conteudo,
    'createdBy', d.criado_por,
    'publishedAt', d.publicado_em,
    'sourceFeedbackId', d.referencia_sugestao,
    'sourceName', d.nome_credito,
    'sourceMessage', d.mensagem_sugestao
  ))
  FROM tech2d.atualizacoes_agenda d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_avisos_turma(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'turmaId', d.turma,
    'title', d.titulo,
    'body', d.conteudo,
    'type', d.tipo,
    'expiresAt', d.expira_em,
    'purgeAt', d.expurgo_em,
    'createdBy', d.criado_por,
    'authorEmail', d.email_autor,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em
  ))
  FROM tech2d.avisos_turma d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_cartoes_kanban(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'columnId', d.referencia_coluna,
    'title', d.titulo,
    'description', d.descricao,
    'priority', d.prioridade,
    'dueDate', d.prazo,
    'assigneeId', d.id_responsavel,
    'labels', d.etiquetas,
    'activityIds', d.referencias_atividades,
    'checklist', CASE WHEN 'checklist'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_itens_checklist(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.itens_checklist r WHERE r.id_pai=d.id AND r.grupo='checklist') END
  ))
  FROM tech2d.cartoes_kanban d WHERE d.id=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_chat_representantes(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'text', d.mensagem,
    'senderId', d.remetente,
    'senderEmail', d.email_remetente,
    'senderRole', d.papel_remetente,
    'senderTurma', d.turma_remetente,
    'createdAt', d.criado_em
  ))
  FROM tech2d.chat_representantes d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_colunas_kanban(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'name', d.nome,
    'color', d.cor,
    'done', d.concluida
  ))
  FROM tech2d.colunas_kanban d WHERE d.id=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_conteudo_atividade_arquivada(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'title', d.titulo,
    'description', d.descricao,
    'type', d.tipo,
    'subject', d.disciplina,
    'date', d.data,
    'time', to_char(d.hora,'HH24:MI'),
    'turmaId', d.turma,
    'createdBy', d.criado_por,
    'createdByEmail', d.email_criador,
    'recurringId', d.referencia_recorrencia,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em,
    'attachments', CASE WHEN 'attachments'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_anexos_atividade_arquivada(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.anexos_atividade_arquivada r WHERE r.id_pai=d.id AND r.grupo='attachments') END
  ))
  FROM tech2d.conteudo_atividade_arquivada d WHERE d.id=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_convites_representacao(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'email', d.email,
    'turmaId', d.turma,
    'requestId', d.referencia_pedido,
    'approvedAt', d.aprovado_em
  ))
  FROM tech2d.convites_representacao d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_enquetes(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'turmaId', d.turma,
    'question', d.pergunta,
    'options', CASE WHEN 'options'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(to_jsonb(r.opcao) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.opcoes_enquete r WHERE r.id_pai=d.id_registro AND r.grupo='options') END,
    'status', d.situacao,
    'createdBy', d.criado_por,
    'createdAt', d.criado_em
  ))
  FROM tech2d.enquetes d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_entregas_resumo(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'status', d.situacao,
    'weekStart', d.inicio_semana,
    'createdAt', d.criada_em_ms,
    'completedAt', d.concluida_em_ms
  ))
  FROM tech2d.entregas_resumo d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_envios_anexos(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'activityId', d.referencia_atividade,
    'name', d.nome,
    'contentType', d.tipo_mime,
    'size', d.tamanho_bytes,
    'key', d.chave_arquivo,
    'uid', d.id_usuario,
    'createdAt', d.criado_em_ms
  ))
  FROM tech2d.envios_anexos d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_espacos_kanban(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'ownerId', d.id_proprietario,
    'schemaVersion', d.versao_formato,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em,
    'boards', CASE WHEN 'boards'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_quadros_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.quadros_kanban r WHERE r.id_pai=d.id_registro AND r.grupo='boards') END,
    'board', (SELECT tech2d.ler_quadros_kanban(r.id) FROM tech2d.quadros_kanban r WHERE r.id_pai=d.id_registro AND r.grupo='board' AND r.ordem=0)
  ))
  FROM tech2d.espacos_kanban d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_horarios_aula(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object('professor',p.nome,'subject',d.nome,'className',t.nome,
    'startTime',to_char(f.hora_inicio,'HH24:MI'),'endTime',to_char(f.hora_fim,'HH24:MI'),'dayOfWeek',h.dia_semana,
    'active',h.ativo,'floor',h.andar,'roomDescription',h.sala,'createdAt',h.criado_em,'updatedAt',h.alterado_em))
  FROM tech2d.horarios_aula h
  JOIN tech2d.professores p ON p.id=h.id_professor JOIN tech2d.disciplinas d ON d.id=h.id_disciplina
  JOIN tech2d.turmas t ON t.id=h.id_turma JOIN tech2d.faixas_horario f ON f.id=h.id_faixa_horario
  WHERE h.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_itens_checklist(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'text', d.descricao,
    'done', d.concluido
  ))
  FROM tech2d.itens_checklist d WHERE d.id=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_limites_servico(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'count', d.quantidade,
    'resetAt', d.expira_em_ms
  ))
  FROM tech2d.limites_servico d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_limpeza_anexos_kanban(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'path', d.referencia_espaco,
    'board', d.referencia_quadro,
    'task', d.referencia_cartao
  ))
  FROM tech2d.limpeza_anexos_kanban d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_mensagens_sugestao(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'text', d.mensagem,
    'senderId', d.remetente,
    'createdAt', d.criado_em
  ))
  FROM tech2d.mensagens_sugestao d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_participantes_kanban(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'boardId', d.referencia_quadro,
    'userId', d.id_usuario,
    'userEmail', d.email,
    'name', d.nome,
    'createdAt', d.criado_em
  ))
  FROM tech2d.participantes_kanban d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_pedidos_agenda(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'className', d.nome_turma,
    'email', d.email,
    'status', d.situacao,
    'createdAt', d.criado_em,
    'reviewedAt', d.revisado_em
  ))
  FROM tech2d.pedidos_agenda d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_pedidos_kanban(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'boardId', d.referencia_quadro,
    'userId', d.id_usuario,
    'userEmail', d.email,
    'name', d.nome,
    'createdAt', d.criado_em,
    'status', d.situacao,
    'updatedAt', d.alterado_em
  ))
  FROM tech2d.pedidos_kanban d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_pedidos_representacao(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'turmaId', d.turma,
    'email', d.email,
    'status', d.situacao,
    'createdAt', d.criado_em,
    'reviewedAt', d.revisado_em
  ))
  FROM tech2d.pedidos_representacao d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_perfis_administrativos(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'role', d.papel,
    'turmaId', d.turma,
    'createdAt', d.criado_em
  ))
  FROM tech2d.perfis_administrativos d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_perfis_comunidade(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'displayName', d.nome,
    'company', d.empresa,
    'className', d.turma,
    'room', d.sala,
    'floor', d.andar,
    'photoUrl', d.url_foto,
    'updatedAt', d.alterado_em
  ))
  FROM tech2d.perfis_comunidade d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_preferencias_resumo(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'enabled', d.ativo,
    'turmaId', d.turma,
    'updatedAt', d.alterada_em_ms
  ))
  FROM tech2d.preferencias_resumo d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_quadros_kanban(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'name', d.nome,
    'color', d.cor,
    'compact', d.compacto,
    'columns', CASE WHEN 'columns'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_colunas_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.colunas_kanban r WHERE r.id_pai=d.id AND r.grupo='columns') END,
    'tasks', CASE WHEN 'tasks'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_cartoes_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.cartoes_kanban r WHERE r.id_pai=d.id AND r.grupo='tasks') END
  ))
  FROM tech2d.quadros_kanban d WHERE d.id=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_regras_recorrencia(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'title', d.titulo,
    'description', d.descricao,
    'type', d.tipo,
    'subject', d.disciplina,
    'time', to_char(d.hora,'HH24:MI'),
    'turmaId', d.turma,
    'createdBy', d.criado_por,
    'createdByEmail', d.email_criador,
    'createdAt', d.criado_em,
    'startDate', d.inicio,
    'endDate', d.fim,
    'active', d.ativa,
    'deleted', d.excluida,
    'intervalWeeks', d.intervalo_semanas,
    'weekdays', d.dias_semana
  ))
  FROM tech2d.regras_recorrencia d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_regras_retencao(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'turmaId', d.turma,
    'days', d.dias,
    'enabled', d.ativa,
    'updatedBy', d.alterado_por,
    'updatedAt', d.alterado_em
  ))
  FROM tech2d.regras_retencao d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_sugestoes_atividade(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'title', d.titulo,
    'description', d.descricao,
    'type', d.tipo,
    'subject', d.disciplina,
    'date', d.data,
    'time', to_char(d.hora,'HH24:MI'),
    'turmaId', d.turma,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em,
    'status', d.situacao,
    'resolution', d.resolucao,
    'reviewComment', d.comentario_revisao,
    'closedAt', d.encerrada_em
  ))
  FROM tech2d.sugestoes_atividade d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_sugestoes_melhoria(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'message', d.mensagem,
    'turmaId', d.turma,
    'createdBy', d.criado_por,
    'createdByEmail', d.email_criador,
    'createdAt', d.criado_em,
    'publicCreditAllowed', d.credito_autorizado,
    'publicCreditName', d.nome_credito,
    'status', d.situacao,
    'completedAt', d.concluida_em,
    'completedBy', d.concluida_por
  ))
  FROM tech2d.sugestoes_melhoria d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_turmas_agenda(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'name', d.nome,
    'active', d.ativa,
    'requestId', d.referencia_pedido,
    'approvedAt', d.aprovada_em
  ))
  FROM tech2d.turmas_agenda d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.ler_votos_enquete(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'optionIndex', d.indice_opcao,
    'createdAt', d.criado_em
  ))
  FROM tech2d.votos_enquete d WHERE d.id_registro=alvo;
$function$;

DO $function$
DECLARE coluna record;
BEGIN
  FOR coluna IN SELECT table_schema, table_name FROM information_schema.columns
    WHERE table_schema='tech2d' AND column_name='campos_nulos' ORDER BY table_name
  LOOP
    EXECUTE format('ALTER TABLE %I.%I DROP COLUMN %I', coluna.table_schema, coluna.table_name, 'campos_nulos');
  END LOOP;
END $function$;

COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:022_remover_campos_nulos';
