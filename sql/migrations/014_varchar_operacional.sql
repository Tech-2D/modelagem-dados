DO $migracao$
DECLARE
  definicao text;
  campo text;
  tabela text;
  coluna text;
  limite integer;
  verificacoes text[];
  alteracoes text[];
  excedeu boolean;
  views_atuais text;
  vista record;
  gatilho record;
  permissao record;
  beneficiario text;
BEGIN
  IF EXISTS (SELECT FROM tech2d.migracoes_esquema WHERE versao = '014_varchar_operacional') THEN
    RETURN;
  END IF;

  SET LOCAL lock_timeout = '5s';
  SET LOCAL search_path = pg_catalog, pg_temp;

  CREATE TEMP TABLE vistas_varchar_operacional ON COMMIT DROP AS
    SELECT c.relname AS nome, pg_get_viewdef(c.oid) AS definicao, c.reloptions AS opcoes,
           obj_description(c.oid, 'pg_class') AS comentario, c.relacl AS acl, c.relowner AS proprietario
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'tech2d' AND c.relkind = 'v';

  IF EXISTS (
    SELECT FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'tech2d' AND c.relkind = 'v' AND a.attnum > 0 AND NOT a.attisdropped
      AND (a.attacl IS NOT NULL OR col_description(c.oid, a.attnum) IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'Permissões ou comentários por coluna nas views exigem migração explícita.';
  END IF;

  SELECT string_agg(format('tech2d.%I', nome), ', ' ORDER BY nome) INTO views_atuais
  FROM vistas_varchar_operacional;
  EXECUTE 'DROP VIEW ' || views_atuais || ' RESTRICT';

  CREATE TEMP TABLE gatilhos_varchar_operacional ON COMMIT DROP AS
    SELECT tgname AS nome, pg_get_triggerdef(oid) AS definicao, tgenabled AS estado
    FROM pg_trigger
    WHERE tgrelid = 'tech2d.documentos_catalogo'::regclass AND NOT tgisinternal
      AND tgname IN ('normalize_schedule_write', 'normalize_schedule_delete');
  FOR gatilho IN SELECT * FROM gatilhos_varchar_operacional LOOP
    EXECUTE format('DROP TRIGGER %I ON tech2d.documentos_catalogo', gatilho.nome);
  END LOOP;

  FOREACH definicao IN ARRAY string_to_array(trim($limites$
acessos_recentes_agenda id_usuario:128 email:320 chave_rede:64
acessos_recentes_professores id_usuario:128 email:320
atividades id:320 id_turma:100 titulo:120 descricao:2000 tipo:32 disciplina:120 data:10 hora:5 criado_por:128 email_criador:320 id_recorrencia:320
auditoria_aplicacao autor:256 caminho:512 operacao:32
auditoria_atividades_legada id_atividade:320 id_usuario:128 acao:32
bloqueios_agenda tipo:32 alvo:320 criado_por:128
disciplinas nome:150
documentos_aplicacao caminho:512 colecao:256 id:320
documentos_catalogo colecao:128 id:320
documentos_firestore id_projeto:128 caminho:1024 atualizado_na_origem_em:64
horarios_aula id:320
migracoes_esquema versao:128
perfis_administrativos id_usuario:128 papel:32 id_turma:100
professores nome:150
recibos_gravacao id:128 autor:256 hash_requisicao:64
revisoes_origem id_projeto:128 caminho:1024 atualizado_na_origem_em:64 motivo:128
turmas nome:150
visitas_aos_sites tipo_visitante:32 chave_visitante:128 site:32
$limites$, E'\n\r'), E'\n') LOOP
    definicao := trim(definicao, E' \r');
    tabela := split_part(definicao, ' ', 1);
    verificacoes := ARRAY[]::text[];
    alteracoes := ARRAY[]::text[];
    FOREACH campo IN ARRAY (string_to_array(definicao, ' '))[2:] LOOP
      coluna := split_part(campo, ':', 1);
      limite := split_part(campo, ':', 2)::integer;
      verificacoes := array_append(verificacoes, format('char_length(%I) > %s', coluna, limite));
      alteracoes := array_append(alteracoes, format('ALTER COLUMN %I TYPE varchar(%s)', coluna, limite));
    END LOOP;
    EXECUTE format('LOCK TABLE tech2d.%I IN ACCESS EXCLUSIVE MODE', tabela);
    EXECUTE format('SELECT EXISTS (SELECT FROM tech2d.%I WHERE %s)',
      tabela, array_to_string(verificacoes, ' OR ')) INTO excedeu;
    IF excedeu THEN
      RAISE EXCEPTION 'Há valores acima dos limites de varchar em tech2d.%.', tabela;
    END IF;
    EXECUTE format('ALTER TABLE tech2d.%I %s', tabela, array_to_string(alteracoes, ', '));
  END LOOP;

  FOR gatilho IN SELECT * FROM gatilhos_varchar_operacional LOOP
    EXECUTE gatilho.definicao;
    IF gatilho.estado <> 'O' THEN
      EXECUTE format('ALTER TABLE tech2d.documentos_catalogo %s TRIGGER %I',
        CASE gatilho.estado WHEN 'D' THEN 'DISABLE' WHEN 'R' THEN 'ENABLE REPLICA' ELSE 'ENABLE ALWAYS' END,
        gatilho.nome);
    END IF;
  END LOOP;

  -- school_schedule_catalog depende de catalogo_horarios.
  FOR vista IN SELECT * FROM vistas_varchar_operacional
    ORDER BY CASE nome WHEN 'catalogo_horarios' THEN 0 WHEN 'school_schedule_catalog' THEN 2 ELSE 1 END, nome
  LOOP
    EXECUTE format('CREATE VIEW tech2d.%I%s AS %s', vista.nome,
      CASE WHEN vista.opcoes IS NULL THEN '' ELSE ' WITH (' || array_to_string(vista.opcoes, ', ') || ')' END,
      vista.definicao);
    EXECUTE format('COMMENT ON VIEW tech2d.%I IS %L', vista.nome, vista.comentario);
    -- Descarta permissões padrão da nova view antes de restaurar as anteriores.
    FOR permissao IN
      SELECT DISTINCT a.grantee FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) a
      WHERE c.oid = to_regclass(format('tech2d.%I', vista.nome)) AND a.grantee <> c.relowner
    LOOP
      beneficiario := CASE WHEN permissao.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(permissao.grantee)) END;
      EXECUTE format('REVOKE ALL ON tech2d.%I FROM %s', vista.nome, beneficiario);
    END LOOP;
    EXECUTE format('ALTER VIEW tech2d.%I OWNER TO %I', vista.nome, pg_get_userbyid(vista.proprietario));
    FOR permissao IN SELECT * FROM aclexplode(vista.acl) WHERE grantee <> vista.proprietario LOOP
      beneficiario := CASE WHEN permissao.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(permissao.grantee)) END;
      EXECUTE format('GRANT %s ON tech2d.%I TO %s%s', permissao.privilege_type, vista.nome, beneficiario,
        CASE WHEN permissao.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
    END LOOP;
  END LOOP;

  IF EXISTS (
    SELECT FROM information_schema.columns c
    JOIN information_schema.tables t USING (table_catalog, table_schema, table_name)
    WHERE c.table_schema = 'tech2d' AND t.table_type = 'BASE TABLE' AND c.data_type = 'text'
  ) THEN
    RAISE EXCEPTION 'O esquema tech2d ainda tem colunas text em tabelas.';
  END IF;

  INSERT INTO tech2d.migracoes_esquema(versao) VALUES ('014_varchar_operacional');
END
$migracao$;
