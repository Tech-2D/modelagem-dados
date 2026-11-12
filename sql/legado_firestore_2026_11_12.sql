DO $migracao$
DECLARE
  definicao text;
  campo text;
  chave text;
  coluna text;
  tipo text;
  colecao text;
  tabela text;
  colunas text;
  expressoes text;
  valor text;
  filtro text;
  chaves text[];
  total bigint;
  conferidos bigint := 0;
  assinatura text;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('tech2d-arquivo-firestore'));
  LOCK TABLE tech2d.documentos_firestore IN SHARE MODE;
  SELECT count(*), encode(sha256(convert_to(string_agg(encode(sha256(convert_to(
    jsonb_build_array(caminho, campos, atualizado_na_origem_em)::text, 'UTF8')), 'hex'),
    '' ORDER BY caminho COLLATE "C"), 'UTF8')), 'hex')
  INTO total, assinatura FROM tech2d.documentos_firestore WHERE id_projeto='d-tech-8555e';
  IF total <> 3684 OR assinatura IS DISTINCT FROM '80d2b5714db50f59597d63fb75be65adea4c71bff1aec4ffecd6be1a748aa521' THEN
    RAISE EXCEPTION 'A cópia SQL diverge do snapshot atual.';
  END IF;
  CREATE SCHEMA legado_firestore;
  REVOKE ALL ON SCHEMA legado_firestore FROM PUBLIC;
  COMMENT ON SCHEMA legado_firestore IS 'Histórico relacional privado do Firestore d-tech-8555e.';
  FOREACH definicao IN ARRAY string_to_array(trim($modelo$
_agendaDigestDeliveries envios_resumo status:situacao: createdAt:criado_em:epoch completedAt:concluido_em:epoch weekStart:inicio_semana:date
_agendaDigestPreferences preferencias_resumo turmaId:id_turma: updatedAt:atualizado_em:epoch enabled:habilitado:boolean
_agendaWhatsAppControl bloqueios_whatsapp owner:proprietario: expiresAt:expira_em:epoch
_agendaWhatsAppSession sessoes_whatsapp iv:vetor_inicializacao: version:versao:bigint ciphertext:conteudo_cifrado: tag:etiqueta_autenticacao:
_agendaWhatsAppTests testes_whatsapp status:situacao: completedAt:concluido_em:epoch createdAt:criado_em:epoch
_passwordResetLimits limites_redefinicao_senha resetAt:renova_em:epoch count:quantidade:bigint
_r2UploadLimits limites_envio_arquivos resetAt:renova_em:epoch count:quantidade:bigint
activities atividades updatedAt:atualizado_em:timestamp createdAt:criado_em:timestamp createdBy:id_criador: time:hora:time date:data:date type:tipo: title:titulo: turmaId:id_turma: description:descricao: createdByEmail:email_criador: subject:disciplina: recurringId:id_recorrencia:
admins perfis_administrativos role:papel: turmaId:id_turma: createdAt:criado_em:timestamp
agendaUpdates atualizacoes_agenda body:descricao: publishedAt:publicado_em:timestamp createdBy:id_criador: title:titulo: sourceMessage:mensagem_sugerida: sourceFeedbackId:id_feedback: sourceName:nome_autor_sugestao:
announcement comunicados message:mensagem: updatedAt:atualizado_em:timestamp
feedback sugestoes_melhoria turmaId:id_turma: message:mensagem: completedBy:concluido_por: completedAt:concluido_em:timestamp createdAt:criado_em:timestamp status:situacao: publicCreditAllowed:permite_credito_publico:boolean publicCreditName:nome_credito_publico: createdByEmail:email_criador: createdBy:id_criador:
feedback/messages mensagens_sugestoes text:mensagem: createdAt:criado_em:timestamp senderId:id_remetente:
pollVoterAccess acessos_enquetes turmaId:id_turma: requestedAt:solicitado_em:timestamp status:situacao: email:email: reviewedAt:revisado_em:timestamp reviewedBy:revisado_por:
recurringActivities recorrencias createdBy:id_criador: active:ativo:boolean title:titulo: endDate:data_fim:date turmaId:id_turma: description:descricao: subject:disciplina: createdByEmail:email_criador: type:tipo: time:hora:time startDate:data_inicio:date createdAt:criado_em:timestamp intervalWeeks:intervalo_semanas:bigint deleted:excluido:boolean
representativeChat mensagens_representantes senderTurma:id_turma_remetente: text:mensagem: senderId:id_remetente: senderRole:papel_remetente: createdAt:criado_em:timestamp senderEmail:email_remetente:
representativeInvites convites_representantes requestId:id_solicitacao: approvedAt:aprovado_em:timestamp email:email: turmaId:id_turma:
representativeRequests solicitacoes_representantes email:email: createdAt:criado_em:timestamp status:situacao: reviewedAt:revisado_em:timestamp turmaId:id_turma:
schedules horarios_aula startTime:hora_inicio:time active:ativo:boolean subject:disciplina: floor:andar: professor:nome_professor: className:nome_turma: roomDescription:descricao_sala: endTime:hora_fim:time dayOfWeek:dia_semana:bigint
suggestions sugestoes_atividades createdAt:criado_em:timestamp description:descricao: status:situacao: type:tipo: time:hora:time title:titulo: subject:disciplina: turmaId:id_turma: date:data:date updatedAt:atualizado_em:timestamp
$modelo$, E'\n'), E'\n') LOOP
    colecao := split_part(definicao, ' ', 1);
    tabela := split_part(definicao, ' ', 2);
    colunas := 'caminho text PRIMARY KEY, id text NOT NULL';
    expressoes := 'a.caminho, regexp_replace(a.caminho, ''.*/'', '''')';
    chaves := '{}';
    FOREACH campo IN ARRAY (string_to_array(definicao, ' '))[3:] LOOP
      chave := split_part(campo, ':', 1);
      coluna := split_part(campo, ':', 2);
      tipo := split_part(campo, ':', 3);
      chaves := array_append(chaves, chave);
      valor := CASE tipo
        WHEN 'epoch' THEN format('to_timestamp((a.campos->%L->>''integerValue'')::numeric / 1000)', chave)
        WHEN 'timestamp' THEN format('(a.campos->%L->>''timestampValue'')::timestamptz', chave)
        WHEN 'boolean' THEN format('(a.campos->%L->>''booleanValue'')::boolean', chave)
        WHEN 'bigint' THEN format('(a.campos->%L->>''integerValue'')::bigint', chave)
        WHEN 'date' THEN format('(a.campos->%L->>''stringValue'')::date', chave)
        WHEN 'time' THEN format('(a.campos->%L->>''stringValue'')::time', chave)
        ELSE format('a.campos->%L->>''stringValue''', chave)
      END;
      colunas := colunas || format(', %I %s', coluna, CASE tipo
        WHEN '' THEN 'text' WHEN 'epoch' THEN 'timestamptz' WHEN 'timestamp' THEN 'timestamptz' ELSE tipo END);
      expressoes := expressoes || ', ' || valor;
    END LOOP;
    IF colecao = 'activities' THEN chaves := array_append(chaves, 'attachments'); END IF;
    IF colecao = 'recurringActivities' THEN chaves := array_append(chaves, 'weekdays'); END IF;
    IF colecao = 'feedback/messages' THEN
      colunas := colunas || ', caminho_sugestao text NOT NULL REFERENCES legado_firestore.sugestoes_melhoria(caminho)';
      expressoes := expressoes || ', regexp_replace(a.caminho, ''/messages/[^/]+$'', '''')';
      filtro := '^feedback/[^/]+/messages/[^/]+$';
    ELSE
      filtro := '^' || colecao || '/[^/]+$';
    END IF;
    IF EXISTS (SELECT FROM tech2d.documentos_firestore a WHERE a.id_projeto='d-tech-8555e'
      AND a.caminho ~ filtro AND a.campos - chaves <> '{}'::jsonb) THEN
      RAISE EXCEPTION 'Campo sem modelagem em %.', colecao;
    END IF;
    EXECUTE format('CREATE TABLE legado_firestore.%I (%s)', tabela, colunas);
    EXECUTE format('COMMENT ON TABLE legado_firestore.%I IS %L', tabela, 'Histórico da coleção Firestore ' || colecao || '.');
    EXECUTE format('INSERT INTO legado_firestore.%I SELECT %s
      FROM tech2d.documentos_firestore a WHERE a.id_projeto=$1 AND a.caminho ~ $2', tabela, expressoes)
      USING 'd-tech-8555e', filtro;
    GET DIAGNOSTICS total = ROW_COUNT;
    conferidos := conferidos + total;
  END LOOP;
  IF conferidos <> 3684 THEN RAISE EXCEPTION 'A cobertura relacional não corresponde ao snapshot.'; END IF;

  CREATE TABLE legado_firestore.anexos_atividades (
    caminho_atividade text REFERENCES legado_firestore.atividades(caminho), ordem integer, id text,
    nome text, caminho_storage text, tipo_conteudo text, tamanho_bytes bigint, enviado_em timestamptz,
    PRIMARY KEY (caminho_atividade, ordem)
  );
  COMMENT ON TABLE legado_firestore.anexos_atividades IS 'Metadados dos arquivos anexados às atividades.';
  INSERT INTO legado_firestore.anexos_atividades
    SELECT a.caminho, (i.ordem-1)::integer, f->'id'->>'stringValue', f->'name'->>'stringValue',
      f->'storagePath'->>'stringValue', f->'contentType'->>'stringValue', (f->'size'->>'integerValue')::bigint,
      COALESCE((f->'uploadedAt'->>'stringValue')::timestamptz, (f->'uploadedAt'->>'timestampValue')::timestamptz,
        to_timestamp((f->'uploadedAt'->>'integerValue')::numeric / 1000))
    FROM tech2d.documentos_firestore a
    CROSS JOIN LATERAL jsonb_array_elements(a.campos->'attachments'->'arrayValue'->'values') WITH ORDINALITY AS i(item, ordem)
    CROSS JOIN LATERAL (SELECT i.item->'mapValue'->'fields') AS valores(f)
    WHERE a.id_projeto='d-tech-8555e' AND a.caminho ~ '^activities/[^/]+$';
  GET DIAGNOSTICS total = ROW_COUNT;
  IF total <> 14 THEN RAISE EXCEPTION 'Quantidade de anexos divergente.'; END IF;

  CREATE TABLE legado_firestore.dias_recorrencias (
    caminho_recorrencia text REFERENCES legado_firestore.recorrencias(caminho), ordem integer,
    dia_semana bigint NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    PRIMARY KEY (caminho_recorrencia, ordem)
  );
  COMMENT ON TABLE legado_firestore.dias_recorrencias IS 'Dias da semana de cada recorrência.';
  INSERT INTO legado_firestore.dias_recorrencias
    SELECT a.caminho, (i.ordem-1)::integer, (i.item->>'integerValue')::bigint
    FROM tech2d.documentos_firestore a
    CROSS JOIN LATERAL jsonb_array_elements(a.campos->'weekdays'->'arrayValue'->'values') WITH ORDINALITY AS i(item, ordem)
    WHERE a.id_projeto='d-tech-8555e' AND a.caminho ~ '^recurringActivities/[^/]+$';
  GET DIAGNOSTICS total = ROW_COUNT;
  IF total <> 6 THEN RAISE EXCEPTION 'Quantidade de dias de recorrências divergente.'; END IF;
  REVOKE ALL ON ALL TABLES IN SCHEMA legado_firestore FROM PUBLIC;
END
$migracao$;
