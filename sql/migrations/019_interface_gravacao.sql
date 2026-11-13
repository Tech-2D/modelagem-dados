
-- Write boundary shared by the existing schema and its relational replacement.
CREATE FUNCTION tech2d.gravar_registros(lote jsonb) RETURNS void
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  DELETE FROM tech2d.documentos_aplicacao d
  USING jsonb_to_recordset(lote) r(path text, data jsonb)
  WHERE d.caminho = r.path AND r.data IS NULL;

  INSERT INTO tech2d.documentos_aplicacao (caminho, colecao, id, dados)
  SELECT path, regexp_replace(path, '/[^/]+$', ''), regexp_replace(path, '^.*/', ''), data
  FROM jsonb_to_recordset(lote) r(path text, data jsonb)
  WHERE data IS NOT NULL
  ON CONFLICT (caminho) DO UPDATE
  SET dados = excluded.dados, versao = documentos_aplicacao.versao + 1, atualizado_em = now();

  DELETE FROM tech2d.atividades a USING jsonb_to_recordset(lote) r(path text, data jsonb)
  WHERE a.id = split_part(r.path,'/',2) AND r.path LIKE 'activities/%' AND r.data IS NULL;

  INSERT INTO tech2d.atividades (id,id_turma,titulo,descricao,tipo,disciplina,data,hora,criado_por,email_criador,id_recorrencia,anexos,criado_em,atualizado_em)
  SELECT split_part(path,'/',2),data->>'turmaId',data->>'title',coalesce(data->>'description',''),data->>'type',data->>'subject',
    data->>'date',data->>'time',data->>'createdBy',data->>'createdByEmail',data->>'recurringId',coalesce(data->'attachments','[]'::jsonb),
    (data->>'createdAt')::timestamptz,(data->>'updatedAt')::timestamptz
  FROM jsonb_to_recordset(lote) r(path text,data jsonb)
  WHERE path LIKE 'activities/%' AND data IS NOT NULL
  ON CONFLICT (id) DO UPDATE SET id_turma=excluded.id_turma,titulo=excluded.titulo,descricao=excluded.descricao,tipo=excluded.tipo,
    disciplina=excluded.disciplina,data=excluded.data,hora=excluded.hora,criado_por=excluded.criado_por,email_criador=excluded.email_criador,
    id_recorrencia=excluded.id_recorrencia,anexos=excluded.anexos,criado_em=excluded.criado_em,atualizado_em=excluded.atualizado_em,
    versao=atividades.versao+1;

  DELETE FROM tech2d.perfis_administrativos a USING jsonb_to_recordset(lote) r(path text, data jsonb)
  WHERE a.id_usuario=split_part(r.path,'/',2) AND r.path LIKE 'admins/%' AND r.data IS NULL;

  INSERT INTO tech2d.perfis_administrativos (id_usuario,papel,id_turma,dados)
  SELECT split_part(path,'/',2),data->>'role',data->>'turmaId',data
  FROM jsonb_to_recordset(lote) r(path text,data jsonb)
  WHERE path LIKE 'admins/%' AND data IS NOT NULL
  ON CONFLICT (id_usuario) DO UPDATE SET papel=excluded.papel,id_turma=excluded.id_turma,dados=excluded.dados;

  DELETE FROM tech2d.documentos_catalogo a USING jsonb_to_recordset(lote) r(path text, data jsonb)
  WHERE a.colecao=split_part(r.path,'/',1) AND a.id=split_part(r.path,'/',2)
    AND cardinality(string_to_array(r.path,'/'))=2 AND r.data IS NULL;

  INSERT INTO tech2d.documentos_catalogo (colecao,id,dados)
  SELECT split_part(path,'/',1),split_part(path,'/',2),data
  FROM jsonb_to_recordset(lote) r(path text,data jsonb)
  WHERE split_part(path,'/',1) IN ('schedules','agendaClasses','agendaUpdates','announcement','boardNotices','polls')
    AND data IS NOT NULL
  ON CONFLICT (colecao,id) DO UPDATE SET dados=excluded.dados;
END $$;

CREATE FUNCTION tech2d.enfileirar_limpeza_kanban(lote jsonb) RETURNS void
LANGUAGE sql SET search_path = pg_catalog AS $$
  INSERT INTO tech2d.documentos_aplicacao (caminho,colecao,id,dados)
  SELECT '_kanbanFileCleanup/' || md5(value::text), '_kanbanFileCleanup', md5(value::text),value
  FROM jsonb_array_elements(lote)
  ON CONFLICT(caminho) DO NOTHING;
$$;

CREATE FUNCTION tech2d.adiar_limpeza_kanban(chave text) RETURNS void
LANGUAGE sql SET search_path = pg_catalog AS $$
  UPDATE tech2d.documentos_aplicacao SET atualizado_em=now()
  WHERE caminho=chave AND colecao='_kanbanFileCleanup';
$$;

REVOKE ALL ON FUNCTION tech2d.gravar_registros(jsonb), tech2d.enfileirar_limpeza_kanban(jsonb), tech2d.adiar_limpeza_kanban(text) FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname='tech2d_api') THEN
    GRANT EXECUTE ON FUNCTION tech2d.gravar_registros(jsonb), tech2d.enfileirar_limpeza_kanban(jsonb), tech2d.adiar_limpeza_kanban(text) TO tech2d_api;
  END IF;
END $$;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:019_interface_gravacao';

