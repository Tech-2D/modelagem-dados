-- Finaliza a troca da API após a versão 026 e simplifica listas e arquivos.
SELECT pg_advisory_xact_lock(hashtext('tech2d-application-commit'));
DROP VIEW tech2d.visao_acessos_recentes_professores;
DROP TABLE tech2d.acessos_recentes_agenda,tech2d.acessos_recentes_professores;
DROP FUNCTION tech2d.sincronizar_acesso_recente();

DO $$ BEGIN
  IF EXISTS (SELECT FROM tech2d.auditoria_atividades_legada) THEN
    RAISE EXCEPTION 'A auditoria antiga contém registros; revisar antes de remover';
  END IF;
  IF EXISTS (SELECT FROM tech2d.conteudo_atividade_arquivada WHERE grupo<>'originalData' OR ordem<>0)
    OR EXISTS (SELECT FROM tech2d.conteudo_atividade_arquivada GROUP BY id_pai HAVING count(*)>1) THEN
    RAISE EXCEPTION 'Mais de um conteúdo ou posição incompatível por atividade arquivada';
  END IF;
  IF EXISTS (SELECT FROM tech2d.anexos_atividade WHERE grupo<>'attachments') THEN RAISE EXCEPTION 'Grupo inesperado em anexos_atividade'; END IF;
  IF EXISTS (SELECT FROM tech2d.anexos_atividade_arquivada WHERE grupo<>'attachments') THEN RAISE EXCEPTION 'Grupo inesperado em anexos_atividade_arquivada'; END IF;
  IF EXISTS (SELECT FROM tech2d.opcoes_enquete WHERE grupo<>'options') THEN RAISE EXCEPTION 'Grupo inesperado em opcoes_enquete'; END IF;
  IF EXISTS (SELECT FROM tech2d.cartoes_kanban WHERE grupo<>'tasks') THEN RAISE EXCEPTION 'Grupo inesperado em cartoes_kanban'; END IF;
  IF EXISTS (SELECT FROM tech2d.colunas_kanban WHERE grupo<>'columns') THEN RAISE EXCEPTION 'Grupo inesperado em colunas_kanban'; END IF;
  IF EXISTS (SELECT FROM tech2d.itens_checklist WHERE grupo<>'checklist') THEN RAISE EXCEPTION 'Grupo inesperado em itens_checklist'; END IF;
  IF EXISTS (SELECT FROM tech2d.quadros_kanban q JOIN tech2d.registros_aplicacao r ON r.id=q.id_pai
    WHERE (r.tipo='personalKanban' AND q.grupo<>'boards') OR
          (r.tipo='sharedKanban' AND (q.grupo<>'board' OR q.ordem<>0)) OR
          r.tipo NOT IN ('personalKanban','sharedKanban')) THEN
    RAISE EXCEPTION 'Formato inesperado em quadros_kanban';
  END IF;
END $$;

DROP VIEW tech2d.visao_auditoria_atividades_legada;
DROP FUNCTION tech2d.inserir_auditoria_legada();
ALTER TABLE tech2d.valores_historico DROP COLUMN id_auditoria_legada, ALTER COLUMN id_auditoria SET NOT NULL;
DROP TABLE tech2d.auditoria_atividades_legada;
CREATE FUNCTION tech2d.gravar_valor_historico(auditoria bigint,
  pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE
  forma varchar(12) := jsonb_typeof(objeto);
  alvo bigint;
BEGIN
  IF objeto IS NULL THEN RETURN; END IF;
  INSERT INTO tech2d.valores_historico(id_auditoria,id_pai,chave,ordem,tipo,
    valor_textual,valor_numerico,valor_logico)
  VALUES(auditoria,pai,campo,posicao,forma,
    CASE WHEN forma='string' THEN objeto#>>'{}' END,
    CASE WHEN forma='number' THEN (objeto#>>'{}')::numeric END,
    CASE WHEN forma='boolean' THEN (objeto#>>'{}')::boolean END)
  RETURNING id INTO alvo;
  IF forma='object' THEN
    PERFORM tech2d.gravar_valor_historico(auditoria,alvo,key,0,value) FROM jsonb_each(objeto);
  ELSIF forma='array' THEN
    PERFORM tech2d.gravar_valor_historico(auditoria,alvo,NULL,(ord-1)::integer,value)
    FROM jsonb_array_elements(objeto) WITH ORDINALITY a(value,ord);
  END IF;
END $$;
REVOKE ALL ON FUNCTION tech2d.gravar_valor_historico(bigint,bigint,varchar,integer,jsonb) FROM PUBLIC;
CREATE OR REPLACE FUNCTION tech2d.inserir_auditoria() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.auditoria_aplicacao(autor,caminho,operacao,alterado_em)
  VALUES(NEW.actor,NEW.path,NEW.operation,coalesce(NEW.changed_at,now())) RETURNING sequencia INTO NEW.sequence;
  PERFORM tech2d.gravar_valor_historico(NEW.sequence,NULL,NULL,0,NEW.previous_data);
  RETURN NEW;
END $$;
DROP FUNCTION tech2d.gravar_valor_historico(bigint,bigint,bigint,varchar,integer,jsonb);

ALTER TABLE tech2d.atividades_arquivadas
  ADD COLUMN tem_conteudo boolean NOT NULL DEFAULT false,
  ADD COLUMN titulo varchar(120),
  ADD COLUMN descricao varchar(2000),
  ADD COLUMN tipo varchar(32),
  ADD COLUMN disciplina varchar(150),
  ADD COLUMN data date,
  ADD COLUMN hora time,
  ADD COLUMN turma_original varchar(150),
  ADD COLUMN criado_por varchar(128),
  ADD COLUMN email_criador varchar(320),
  ADD COLUMN referencia_recorrencia varchar(320),
  ADD COLUMN criado_em varchar(40),
  ADD COLUMN alterado_em varchar(40);
COMMENT ON COLUMN tech2d.atividades_arquivadas.tem_conteudo IS 'Indica se o arquivo inclui a cópia dos dados originais.';
COMMENT ON COLUMN tech2d.atividades_arquivadas.turma_original IS 'Turma na cópia original, preservada independentemente dos metadados de arquivamento.';
UPDATE tech2d.atividades_arquivadas a SET tem_conteudo=true,
  titulo=d.titulo,
  descricao=d.descricao,
  tipo=d.tipo,
  disciplina=d.disciplina,
  data=d.data,
  hora=d.hora,
  turma_original=d.turma,
  criado_por=d.criado_por,
  email_criador=d.email_criador,
  referencia_recorrencia=d.referencia_recorrencia,
  criado_em=d.criado_em,
  alterado_em=d.alterado_em
FROM tech2d.conteudo_atividade_arquivada d WHERE d.id_pai=a.id_registro;

ALTER TABLE tech2d.anexos_atividade DROP COLUMN grupo;
ALTER TABLE tech2d.anexos_atividade ADD UNIQUE (id_pai,ordem);
ALTER TABLE tech2d.anexos_atividade_arquivada DROP COLUMN grupo;
ALTER TABLE tech2d.opcoes_enquete DROP COLUMN grupo;
ALTER TABLE tech2d.opcoes_enquete ADD UNIQUE (id_pai,ordem);
ALTER TABLE tech2d.cartoes_kanban DROP COLUMN grupo;
ALTER TABLE tech2d.cartoes_kanban ADD UNIQUE (id_pai,ordem);
ALTER TABLE tech2d.colunas_kanban DROP COLUMN grupo;
ALTER TABLE tech2d.colunas_kanban ADD UNIQUE (id_pai,ordem);
ALTER TABLE tech2d.itens_checklist DROP COLUMN grupo;
ALTER TABLE tech2d.itens_checklist ADD UNIQUE (id_pai,ordem);
ALTER TABLE tech2d.quadros_kanban DROP COLUMN grupo;
ALTER TABLE tech2d.quadros_kanban ADD UNIQUE (id_pai,ordem);
ALTER TABLE tech2d.anexos_atividade_arquivada DROP CONSTRAINT anexos_atividade_arquivada_id_pai_fkey;
UPDATE tech2d.anexos_atividade_arquivada a SET id_pai=d.id_pai FROM tech2d.conteudo_atividade_arquivada d WHERE d.id=a.id_pai;
ALTER TABLE tech2d.anexos_atividade_arquivada ADD UNIQUE (id_pai,ordem),
  ADD FOREIGN KEY (id_pai) REFERENCES tech2d.atividades_arquivadas(id_registro) ON DELETE CASCADE;
ALTER TABLE tech2d.atividades DROP COLUMN listas_presentes;
ALTER TABLE tech2d.enquetes DROP COLUMN listas_presentes;
ALTER TABLE tech2d.cartoes_kanban DROP COLUMN listas_presentes;
ALTER TABLE tech2d.quadros_kanban DROP COLUMN listas_presentes;
ALTER TABLE tech2d.espacos_kanban DROP COLUMN listas_presentes;

CREATE FUNCTION tech2d.inserir_anexos_atividade(pai bigint, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.anexos_atividade (id_pai,ordem,referencia,nome,tipo_mime,tamanho_bytes,chave_arquivo,enviado_em,enviado_por) VALUES (pai,posicao,objeto->>'id',objeto->>'name',objeto->>'contentType',(objeto->>'size')::bigint,objeto->>'storagePath',objeto->>'uploadedAt',objeto->>'uploadedBy') RETURNING id INTO alvo;
END $function$;
REVOKE ALL ON FUNCTION tech2d.inserir_anexos_atividade(bigint,integer,jsonb) FROM PUBLIC;
DROP FUNCTION tech2d.inserir_anexos_atividade(bigint,varchar,integer,jsonb);

CREATE FUNCTION tech2d.inserir_anexos_atividade_arquivada(pai bigint, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.anexos_atividade_arquivada (id_pai,ordem,referencia,nome,tipo_mime,tamanho_bytes,chave_arquivo,enviado_em,enviado_por) VALUES (pai,posicao,objeto->>'id',objeto->>'name',objeto->>'contentType',(objeto->>'size')::bigint,objeto->>'storagePath',objeto->>'uploadedAt',objeto->>'uploadedBy') RETURNING id INTO alvo;
END $function$;
REVOKE ALL ON FUNCTION tech2d.inserir_anexos_atividade_arquivada(bigint,integer,jsonb) FROM PUBLIC;
DROP FUNCTION tech2d.inserir_anexos_atividade_arquivada(bigint,varchar,integer,jsonb);

CREATE FUNCTION tech2d.inserir_opcoes_enquete(pai bigint, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.opcoes_enquete (id_pai,ordem,opcao) VALUES (pai,posicao,objeto->>'valor') RETURNING id INTO alvo;
END $$;
REVOKE ALL ON FUNCTION tech2d.inserir_opcoes_enquete(bigint,integer,jsonb) FROM PUBLIC;
DROP FUNCTION tech2d.inserir_opcoes_enquete(bigint,varchar,integer,jsonb);

CREATE FUNCTION tech2d.inserir_cartoes_kanban(pai bigint, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.cartoes_kanban (id_pai,ordem,referencia,referencia_coluna,titulo,descricao,prioridade,prazo,id_responsavel,etiquetas,referencias_atividades) VALUES (pai,posicao,objeto->>'id',objeto->>'columnId',objeto->>'title',objeto->>'description',objeto->>'priority',(objeto->>'dueDate')::date,objeto->>'assigneeId',CASE WHEN jsonb_typeof(objeto->'labels')='array' THEN ARRAY(SELECT value::varchar(30) FROM jsonb_array_elements_text(objeto->'labels') WITH ORDINALITY AS x(value,pos) ORDER BY pos) END,CASE WHEN jsonb_typeof(objeto->'activityIds')='array' THEN ARRAY(SELECT value::varchar(128) FROM jsonb_array_elements_text(objeto->'activityIds') WITH ORDINALITY AS x(value,pos) ORDER BY pos) END) RETURNING id INTO alvo;
  DELETE FROM tech2d.itens_checklist WHERE id_pai=alvo;
  IF jsonb_typeof(objeto->'checklist')='array' THEN
    PERFORM tech2d.inserir_itens_checklist(alvo,(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'checklist') WITH ORDINALITY AS x(value,pos);
  END IF;
END $function$;
REVOKE ALL ON FUNCTION tech2d.inserir_cartoes_kanban(bigint,integer,jsonb) FROM PUBLIC;
DROP FUNCTION tech2d.inserir_cartoes_kanban(bigint,varchar,integer,jsonb);

CREATE FUNCTION tech2d.inserir_colunas_kanban(pai bigint, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.colunas_kanban (id_pai,ordem,referencia,nome,cor,concluida) VALUES (pai,posicao,objeto->>'id',objeto->>'name',objeto->>'color',(objeto->>'done')::boolean) RETURNING id INTO alvo;
END $function$;
REVOKE ALL ON FUNCTION tech2d.inserir_colunas_kanban(bigint,integer,jsonb) FROM PUBLIC;
DROP FUNCTION tech2d.inserir_colunas_kanban(bigint,varchar,integer,jsonb);

CREATE FUNCTION tech2d.inserir_itens_checklist(pai bigint, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.itens_checklist (id_pai,ordem,referencia,descricao,concluido) VALUES (pai,posicao,objeto->>'id',objeto->>'text',(objeto->>'done')::boolean) RETURNING id INTO alvo;
END $function$;
REVOKE ALL ON FUNCTION tech2d.inserir_itens_checklist(bigint,integer,jsonb) FROM PUBLIC;
DROP FUNCTION tech2d.inserir_itens_checklist(bigint,varchar,integer,jsonb);

CREATE FUNCTION tech2d.inserir_quadros_kanban(pai bigint, posicao integer, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.quadros_kanban (id_pai,ordem,referencia,nome,cor,compacto) VALUES (pai,posicao,objeto->>'id',objeto->>'name',objeto->>'color',(objeto->>'compact')::boolean) RETURNING id INTO alvo;
  DELETE FROM tech2d.colunas_kanban WHERE id_pai=alvo;
  IF jsonb_typeof(objeto->'columns')='array' THEN
    PERFORM tech2d.inserir_colunas_kanban(alvo,(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'columns') WITH ORDINALITY AS x(value,pos);
  END IF;
  DELETE FROM tech2d.cartoes_kanban WHERE id_pai=alvo;
  IF jsonb_typeof(objeto->'tasks')='array' THEN
    PERFORM tech2d.inserir_cartoes_kanban(alvo,(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'tasks') WITH ORDINALITY AS x(value,pos);
  END IF;
END $function$;
REVOKE ALL ON FUNCTION tech2d.inserir_quadros_kanban(bigint,integer,jsonb) FROM PUBLIC;
DROP FUNCTION tech2d.inserir_quadros_kanban(bigint,varchar,integer,jsonb);

CREATE OR REPLACE FUNCTION tech2d.gravar_atividades(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.atividades (id_registro,titulo,descricao,tipo,disciplina,data,hora,turma,criado_por,email_criador,referencia_recorrencia,criado_em,alterado_em) VALUES (alvo,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'date')::date,(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'recurringId',objeto->>'createdAt',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, descricao=excluded.descricao, tipo=excluded.tipo, disciplina=excluded.disciplina, data=excluded.data, hora=excluded.hora, turma=excluded.turma, criado_por=excluded.criado_por, email_criador=excluded.email_criador, referencia_recorrencia=excluded.referencia_recorrencia, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em;
  DELETE FROM tech2d.anexos_atividade WHERE id_pai=alvo;
  IF jsonb_typeof(objeto->'attachments')='array' THEN
    PERFORM tech2d.inserir_anexos_atividade(alvo,(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'attachments') WITH ORDINALITY AS x(value,pos);
  END IF;
END $function$;

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
    'attachments', (SELECT coalesce(jsonb_agg(tech2d.ler_anexos_atividade(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.anexos_atividade r WHERE r.id_pai=d.id_registro)
  ))
  FROM tech2d.atividades d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_enquetes(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.enquetes (id_registro,turma,pergunta,situacao,criado_por,criado_em) VALUES (alvo,objeto->>'turmaId',objeto->>'question',objeto->>'status',objeto->>'createdBy',objeto->>'createdAt')
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, pergunta=excluded.pergunta, situacao=excluded.situacao, criado_por=excluded.criado_por, criado_em=excluded.criado_em;
  DELETE FROM tech2d.opcoes_enquete WHERE id_pai=alvo;
  IF jsonb_typeof(objeto->'options')='array' THEN
    PERFORM tech2d.inserir_opcoes_enquete(alvo,(pos-1)::integer,jsonb_build_object('valor',value))
    FROM jsonb_array_elements(objeto->'options') WITH ORDINALITY AS x(value,pos);
  END IF;
END $function$;

CREATE OR REPLACE FUNCTION tech2d.ler_enquetes(alvo bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'turmaId', d.turma,
    'question', d.pergunta,
    'options', (SELECT coalesce(jsonb_agg(to_jsonb(r.opcao) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.opcoes_enquete r WHERE r.id_pai=d.id_registro),
    'status', d.situacao,
    'createdBy', d.criado_por,
    'createdAt', d.criado_em
  ))
  FROM tech2d.enquetes d WHERE d.id_registro=alvo;
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
    'checklist', (SELECT coalesce(jsonb_agg(tech2d.ler_itens_checklist(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.itens_checklist r WHERE r.id_pai=d.id)
  ))
  FROM tech2d.cartoes_kanban d WHERE d.id=alvo;
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
    'columns', (SELECT coalesce(jsonb_agg(tech2d.ler_colunas_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.colunas_kanban r WHERE r.id_pai=d.id),
    'tasks', (SELECT coalesce(jsonb_agg(tech2d.ler_cartoes_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.cartoes_kanban r WHERE r.id_pai=d.id)
  ))
  FROM tech2d.quadros_kanban d WHERE d.id=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_espacos_kanban(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  INSERT INTO tech2d.espacos_kanban (id_registro,id_proprietario,versao_formato,criado_em,alterado_em) VALUES (alvo,objeto->>'ownerId',(objeto->>'schemaVersion')::smallint,objeto->>'createdAt',objeto->>'updatedAt')
  ON CONFLICT(id_registro) DO UPDATE SET id_proprietario=excluded.id_proprietario, versao_formato=excluded.versao_formato, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em;
  DELETE FROM tech2d.quadros_kanban WHERE id_pai=alvo;
  IF jsonb_typeof(objeto->'boards')='array' THEN
    PERFORM tech2d.inserir_quadros_kanban(alvo,(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'boards') WITH ORDINALITY AS x(value,pos);
  END IF;
  IF jsonb_typeof(objeto->'board')='object' THEN
    PERFORM tech2d.inserir_quadros_kanban(alvo,0,objeto->'board');
  END IF;
END $function$;

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
    'boards', CASE WHEN r.tipo='personalKanban' THEN (SELECT coalesce(jsonb_agg(tech2d.ler_quadros_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.quadros_kanban r WHERE r.id_pai=d.id_registro) END,
    'board', CASE WHEN r.tipo='sharedKanban' THEN (SELECT tech2d.ler_quadros_kanban(r.id) FROM tech2d.quadros_kanban r WHERE r.id_pai=d.id_registro AND r.ordem=0) END
  ))
  FROM tech2d.espacos_kanban d JOIN tech2d.registros_aplicacao r ON r.id=d.id_registro WHERE d.id_registro=alvo;
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
    'turmaId', d.turma_original,
    'createdBy', d.criado_por,
    'createdByEmail', d.email_criador,
    'recurringId', d.referencia_recorrencia,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em,
    'attachments', (SELECT coalesce(jsonb_agg(tech2d.ler_anexos_atividade_arquivada(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.anexos_atividade_arquivada r WHERE r.id_pai=d.id_registro)
  ))
  FROM tech2d.atividades_arquivadas d WHERE d.id_registro=alvo AND d.tem_conteudo;
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
    'originalData', tech2d.ler_conteudo_atividade_arquivada(d.id_registro)
  ))
  FROM tech2d.atividades_arquivadas d WHERE d.id_registro=alvo;
$function$;

CREATE OR REPLACE FUNCTION tech2d.gravar_atividades_arquivadas(alvo bigint, objeto jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE original jsonb := objeto->'originalData';
BEGIN
  INSERT INTO tech2d.atividades_arquivadas (id_registro,referencia_atividade,turma,motivo,arquivada_em,dias_retencao,anexos_removidos_em) VALUES (alvo,objeto->>'originalId',objeto->>'turmaId',objeto->>'reason',objeto->>'archivedAt',(objeto->>'retentionDays')::smallint,objeto->>'r2CleanedAt')
  ON CONFLICT(id_registro) DO UPDATE SET referencia_atividade=excluded.referencia_atividade, turma=excluded.turma, motivo=excluded.motivo, arquivada_em=excluded.arquivada_em, dias_retencao=excluded.dias_retencao, anexos_removidos_em=excluded.anexos_removidos_em;

  UPDATE tech2d.atividades_arquivadas SET tem_conteudo=coalesce(jsonb_typeof(original)='object',false),
    (titulo,descricao,tipo,disciplina,data,hora,turma_original,criado_por,email_criador,referencia_recorrencia,criado_em,alterado_em)=(original->>'title',original->>'description',original->>'type',original->>'subject',(original->>'date')::date,(original->>'time')::time,original->>'turmaId',original->>'createdBy',original->>'createdByEmail',original->>'recurringId',original->>'createdAt',original->>'updatedAt')
    WHERE id_registro=alvo;
  DELETE FROM tech2d.anexos_atividade_arquivada WHERE id_pai=alvo;
  IF jsonb_typeof(original->'attachments')='array' THEN
    PERFORM tech2d.inserir_anexos_atividade_arquivada(alvo,(pos-1)::integer,value)
    FROM jsonb_array_elements(original->'attachments') WITH ORDINALITY AS x(value,pos);
  END IF;
END $function$;
DROP FUNCTION tech2d.inserir_conteudo_atividade_arquivada(bigint,varchar,integer,jsonb);
DROP TABLE tech2d.conteudo_atividade_arquivada;

CREATE FUNCTION tech2d.padronizar_listas_registro(tipo varchar, objeto jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE lista jsonb; chave varchar;
BEGIN
  IF jsonb_typeof(objeto) IS DISTINCT FROM 'object' THEN RETURN objeto; END IF;
  CASE tipo
    WHEN 'activities', 'originalData' THEN objeto := jsonb_build_object('attachments','[]'::jsonb) || objeto;
    WHEN 'polls' THEN objeto := jsonb_build_object('options','[]'::jsonb) || objeto;
    WHEN 'task' THEN objeto := jsonb_build_object('checklist','[]'::jsonb) || objeto;
    WHEN 'purgedActivities' THEN
      IF objeto ? 'originalData' THEN objeto := jsonb_set(objeto,'{originalData}',tech2d.padronizar_listas_registro('originalData',objeto->'originalData')); END IF;
    WHEN 'sharedKanban' THEN
      IF objeto ? 'board' THEN objeto := jsonb_set(objeto,'{board}',tech2d.padronizar_listas_registro('board',objeto->'board')); END IF;
    WHEN 'personalKanban', 'board' THEN
      IF tipo='board' THEN
        objeto := jsonb_build_object('columns','[]'::jsonb,'tasks','[]'::jsonb) || objeto;
        chave := 'tasks';
      ELSE
        objeto := jsonb_build_object('boards','[]'::jsonb) || objeto;
        chave := 'boards';
      END IF;
      IF jsonb_typeof(objeto->chave)='array' THEN
        SELECT coalesce(jsonb_agg(tech2d.padronizar_listas_registro(CASE WHEN chave='tasks' THEN 'task' ELSE 'board' END,v) ORDER BY n),'[]'::jsonb)
        INTO lista FROM jsonb_array_elements(objeto->chave) WITH ORDINALITY AS item(v,n);
        objeto := jsonb_set(objeto,ARRAY[chave]::text[],lista);
      END IF;
    ELSE NULL;
  END CASE;
  RETURN objeto;
END $$;
REVOKE ALL ON FUNCTION tech2d.padronizar_listas_registro(varchar,jsonb) FROM PUBLIC;
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
    WHEN 'polls' THEN PERFORM tech2d.gravar_enquetes(alvo,objeto);
    WHEN 'polls/votes' THEN PERFORM tech2d.gravar_votos_enquete(alvo,objeto);
    WHEN 'pollVoterAccess' THEN PERFORM tech2d.gravar_acessos_votacao(alvo,objeto);
    WHEN 'suggestions' THEN PERFORM tech2d.gravar_sugestoes_atividade(alvo,objeto);
    WHEN 'feedback' THEN PERFORM tech2d.gravar_sugestoes_melhoria(alvo,objeto);
    WHEN 'feedback/messages' THEN PERFORM tech2d.gravar_mensagens_sugestao(alvo,objeto);
    WHEN 'announcement' THEN PERFORM tech2d.gravar_anuncios(alvo,objeto);
    WHEN 'agendaUpdates' THEN PERFORM tech2d.gravar_atualizacoes_agenda(alvo,objeto);
    WHEN 'boardNotices' THEN PERFORM tech2d.gravar_avisos_turma(alvo,objeto);
    WHEN 'schedules' THEN PERFORM tech2d.gravar_horarios_aula(alvo,objeto);
    WHEN 'notebookNotes' THEN PERFORM tech2d.gravar_anotacoes(alvo,objeto);
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
END $function$;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:028_simplificar_modelagem';
