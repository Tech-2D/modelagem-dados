DO $migracao$
DECLARE
  definicao text;
  campo text;
  tabela text;
  coluna text;
  limite integer;
  campos text[];
  verificacoes text[];
  alteracoes text[];
  excedeu boolean;
BEGIN
  SET LOCAL lock_timeout = '5s';

  FOREACH definicao IN ARRAY string_to_array(trim($limites$
acessos_enquetes id_turma:100 situacao:32 email:320 revisado_por:128
anexos_atividades caminho_atividade:512 id:320 nome:180 caminho_storage:1024 tipo_conteudo:127
atividades id_criador:128 tipo:32 titulo:120 id_turma:100 descricao:2000 email_criador:320 disciplina:120 id_recorrencia:320
atualizacoes_agenda descricao:2000 id_criador:128 titulo:120 mensagem_sugerida:2000 id_feedback:320 nome_autor_sugestao:60
bloqueios_whatsapp proprietario:64
comunicados mensagem:500
convites_representantes id_solicitacao:320 email:320 id_turma:100
dias_recorrencias caminho_recorrencia:512
envios_resumo situacao:32
horarios_aula disciplina:150 andar:80 nome_professor:150 nome_turma:150 descricao_sala:500
limites_envio_arquivos
limites_redefinicao_senha
mensagens_representantes id_turma_remetente:100 mensagem:2000 id_remetente:128 papel_remetente:32 email_remetente:320
mensagens_sugestoes mensagem:2000 id_remetente:128 caminho_sugestao:512
perfis_administrativos papel:32 id_turma:100
preferencias_resumo id_turma:100
recorrencias id_criador:128 titulo:120 id_turma:100 descricao:2000 disciplina:120 email_criador:320 tipo:32
sessoes_whatsapp vetor_inicializacao:64 conteudo_cifrado:8192 etiqueta_autenticacao:64
solicitacoes_representantes email:320 situacao:32 id_turma:100
sugestoes_atividades descricao:2000 situacao:32 tipo:32 titulo:120 disciplina:120 id_turma:100
sugestoes_melhoria id_turma:100 mensagem:2000 concluido_por:128 situacao:32 nome_credito_publico:60 email_criador:320 id_criador:128
testes_whatsapp situacao:32
$limites$, E'\n\r'), E'\n') LOOP
    definicao := trim(definicao, E' \r');
    tabela := split_part(definicao, ' ', 1);
    campos := (string_to_array(definicao, ' '))[2:];
    IF tabela NOT IN ('anexos_atividades', 'dias_recorrencias') THEN
      campos := ARRAY['caminho:512', 'id:320'] || campos;
    END IF;

    -- Protege a verificação e a conversão contra gravações concorrentes.
    EXECUTE format('LOCK TABLE legado_firestore.%I IN ACCESS EXCLUSIVE MODE', tabela);
    verificacoes := ARRAY[]::text[];
    alteracoes := ARRAY[]::text[];
    FOREACH campo IN ARRAY campos LOOP
      coluna := split_part(campo, ':', 1);
      limite := split_part(campo, ':', 2)::integer;
      verificacoes := array_append(verificacoes, format('char_length(%I) > %s', coluna, limite));
      alteracoes := array_append(alteracoes, format('ALTER COLUMN %I TYPE varchar(%s)', coluna, limite));
    END LOOP;

    EXECUTE format('SELECT EXISTS (SELECT FROM legado_firestore.%I WHERE %s)',
      tabela, array_to_string(verificacoes, ' OR ')) INTO excedeu;
    IF excedeu THEN
      RAISE EXCEPTION 'Há valores acima dos limites de varchar em legado_firestore.%.', tabela;
    END IF;

    EXECUTE format('ALTER TABLE legado_firestore.%I %s', tabela, array_to_string(alteracoes, ', '));
  END LOOP;

  IF EXISTS (SELECT FROM information_schema.columns WHERE table_schema = 'legado_firestore'
    AND (data_type = 'text' OR (data_type = 'character varying' AND character_maximum_length IS NULL))) THEN
    RAISE EXCEPTION 'O esquema legado_firestore ainda tem colunas sem limite de caracteres.';
  END IF;
END
$migracao$;
