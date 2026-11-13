-- Replace stored application JSON with typed entities. Run under a transaction.
-- API version using gravar_registros must be fully deployed before this migration.
SELECT pg_advisory_xact_lock(hashtext('tech2d-application-commit'));
LOCK TABLE tech2d.documentos_aplicacao, tech2d.atividades, tech2d.documentos_catalogo,
  tech2d.perfis_administrativos, tech2d.auditoria_aplicacao, tech2d.auditoria_atividades_legada,
  tech2d.revisoes_origem, tech2d.horarios_aula IN ACCESS EXCLUSIVE MODE;

DROP VIEW tech2d.visao_documentos_aplicacao, tech2d.visao_atividades, tech2d.visao_documentos_catalogo,
  tech2d.visao_perfis_administrativos, tech2d.visao_catalogo_horarios, tech2d.catalogo_horarios;
ALTER TABLE tech2d.documentos_aplicacao RENAME TO documentos_anteriores;
ALTER TABLE tech2d.atividades RENAME TO atividades_anteriores;
ALTER TABLE tech2d.documentos_catalogo RENAME TO catalogos_anteriores;
ALTER TABLE tech2d.perfis_administrativos RENAME TO perfis_anteriores;

CREATE TABLE tech2d.registros_aplicacao (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tipo varchar(40) NOT NULL,
  referencia varchar(320) NOT NULL,
  referencia_pai varchar(320) NOT NULL DEFAULT '',
  id_pai bigint REFERENCES tech2d.registros_aplicacao(id) ON DELETE SET NULL,
  versao bigint NOT NULL DEFAULT 1 CHECK (versao > 0),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tipo, referencia_pai, referencia),
  CHECK ((tipo IN ('polls/votes','feedback/messages')) = (referencia_pai <> ''))
);
COMMENT ON TABLE tech2d.registros_aplicacao IS 'Identidade numérica e versão dos registros. As referências textuais preservam os identificadores externos da API.';
CREATE INDEX registros_aplicacao_pai ON tech2d.registros_aplicacao(id_pai);
CREATE FUNCTION tech2d.referencia_api(tipo varchar, pai varchar, referencia varchar)
RETURNS text LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $$
  SELECT CASE WHEN pai='' THEN tipo || '/' || referencia
    ELSE split_part(tipo,'/',1) || '/' || pai || '/' || split_part(tipo,'/',2) || '/' || referencia END;
$$;
CREATE UNIQUE INDEX registros_referencia_api ON tech2d.registros_aplicacao(tech2d.referencia_api(tipo,referencia_pai,referencia));

CREATE FUNCTION tech2d.remover_nulos_raiz(objeto jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
  SELECT coalesce(jsonb_object_agg(key,value),'{}'::jsonb)
  FROM jsonb_each(objeto) WHERE value <> 'null'::jsonb;
$$;

CREATE INDEX registros_colecao_referencia ON tech2d.registros_aplicacao(
  (CASE WHEN referencia_pai='' THEN tipo ELSE split_part(tipo,'/',1)||'/'||referencia_pai||'/'||split_part(tipo,'/',2) END),
  referencia
);
CREATE TABLE tech2d.atividades (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  titulo varchar(120),
  descricao varchar(2000),
  tipo varchar(32),
  disciplina varchar(150),
  data date,
  hora time,
  turma varchar(150),
  criado_por varchar(128),
  email_criador varchar(320),
  referencia_recorrencia varchar(320),
  criado_em varchar(40),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.atividades IS 'Atividades da Agenda';

COMMENT ON COLUMN tech2d.atividades.titulo IS 'Campo title no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.descricao IS 'Campo description no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.tipo IS 'Campo type no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.disciplina IS 'Campo subject no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.data IS 'Campo date no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.hora IS 'Campo time no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.criado_por IS 'Campo createdBy no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.email_criador IS 'Campo createdByEmail no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.referencia_recorrencia IS 'Campo recurringId no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.atividades.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.perfis_administrativos (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  papel varchar(32),
  turma varchar(150),
  criado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.perfis_administrativos IS 'Papéis administrativos';

COMMENT ON COLUMN tech2d.perfis_administrativos.papel IS 'Campo role no contrato da API.';

COMMENT ON COLUMN tech2d.perfis_administrativos.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.perfis_administrativos.criado_em IS 'Campo createdAt no contrato da API.';

CREATE TABLE tech2d.regras_recorrencia (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  titulo varchar(120),
  descricao varchar(2000),
  tipo varchar(32),
  disciplina varchar(150),
  hora time,
  turma varchar(150),
  criado_por varchar(128),
  email_criador varchar(320),
  criado_em varchar(40),
  inicio date,
  fim date,
  ativa boolean,
  excluida boolean,
  intervalo_semanas smallint,
  dias_semana smallint[],
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.regras_recorrencia IS 'Regras de repetição';

COMMENT ON COLUMN tech2d.regras_recorrencia.titulo IS 'Campo title no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.descricao IS 'Campo description no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.tipo IS 'Campo type no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.disciplina IS 'Campo subject no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.hora IS 'Campo time no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.criado_por IS 'Campo createdBy no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.email_criador IS 'Campo createdByEmail no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.inicio IS 'Campo startDate no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.fim IS 'Campo endDate no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.ativa IS 'Campo active no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.excluida IS 'Campo deleted no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.intervalo_semanas IS 'Campo intervalWeeks no contrato da API.';

COMMENT ON COLUMN tech2d.regras_recorrencia.dias_semana IS 'Campo weekdays no contrato da API.';

CREATE TABLE tech2d.regras_retencao (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  turma varchar(150),
  dias smallint,
  ativa boolean,
  alterado_por varchar(128),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.regras_retencao IS 'Políticas de expurgo por turma';

COMMENT ON COLUMN tech2d.regras_retencao.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.regras_retencao.dias IS 'Campo days no contrato da API.';

COMMENT ON COLUMN tech2d.regras_retencao.ativa IS 'Campo enabled no contrato da API.';

COMMENT ON COLUMN tech2d.regras_retencao.alterado_por IS 'Campo updatedBy no contrato da API.';

COMMENT ON COLUMN tech2d.regras_retencao.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.pedidos_agenda (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  nome_turma varchar(150),
  email varchar(320),
  situacao varchar(32),
  criado_em varchar(40),
  revisado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.pedidos_agenda IS 'Pedidos de criação de agenda';

COMMENT ON COLUMN tech2d.pedidos_agenda.nome_turma IS 'Campo className no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_agenda.email IS 'Campo email no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_agenda.situacao IS 'Campo status no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_agenda.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_agenda.revisado_em IS 'Campo reviewedAt no contrato da API.';

CREATE TABLE tech2d.turmas_agenda (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  nome varchar(150),
  ativa boolean,
  referencia_pedido varchar(180),
  aprovada_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.turmas_agenda IS 'Turmas habilitadas na Agenda';

COMMENT ON COLUMN tech2d.turmas_agenda.nome IS 'Campo name no contrato da API.';

COMMENT ON COLUMN tech2d.turmas_agenda.ativa IS 'Campo active no contrato da API.';

COMMENT ON COLUMN tech2d.turmas_agenda.referencia_pedido IS 'Campo requestId no contrato da API.';

COMMENT ON COLUMN tech2d.turmas_agenda.aprovada_em IS 'Campo approvedAt no contrato da API.';

CREATE TABLE tech2d.pedidos_representacao (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  turma varchar(150),
  email varchar(320),
  situacao varchar(32),
  criado_em varchar(40),
  revisado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.pedidos_representacao IS 'Solicitações de representantes';

COMMENT ON COLUMN tech2d.pedidos_representacao.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_representacao.email IS 'Campo email no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_representacao.situacao IS 'Campo status no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_representacao.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_representacao.revisado_em IS 'Campo reviewedAt no contrato da API.';

CREATE TABLE tech2d.convites_representacao (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  email varchar(320),
  turma varchar(150),
  referencia_pedido varchar(180),
  aprovado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.convites_representacao IS 'Convites de representantes';

COMMENT ON COLUMN tech2d.convites_representacao.email IS 'Campo email no contrato da API.';

COMMENT ON COLUMN tech2d.convites_representacao.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.convites_representacao.referencia_pedido IS 'Campo requestId no contrato da API.';

COMMENT ON COLUMN tech2d.convites_representacao.aprovado_em IS 'Campo approvedAt no contrato da API.';

CREATE TABLE tech2d.chat_representantes (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  mensagem varchar(2000),
  remetente varchar(128),
  email_remetente varchar(320),
  papel_remetente varchar(32),
  turma_remetente varchar(150),
  criado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.chat_representantes IS 'Mensagens do chat dos representantes';

COMMENT ON COLUMN tech2d.chat_representantes.mensagem IS 'Campo text no contrato da API.';

COMMENT ON COLUMN tech2d.chat_representantes.remetente IS 'Campo senderId no contrato da API.';

COMMENT ON COLUMN tech2d.chat_representantes.email_remetente IS 'Campo senderEmail no contrato da API.';

COMMENT ON COLUMN tech2d.chat_representantes.papel_remetente IS 'Campo senderRole no contrato da API.';

COMMENT ON COLUMN tech2d.chat_representantes.turma_remetente IS 'Campo senderTurma no contrato da API.';

COMMENT ON COLUMN tech2d.chat_representantes.criado_em IS 'Campo createdAt no contrato da API.';

CREATE TABLE tech2d.enquetes (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  turma varchar(150),
  pergunta varchar(160),
  situacao varchar(32),
  criado_por varchar(128),
  criado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.enquetes IS 'Enquetes das turmas';

COMMENT ON COLUMN tech2d.enquetes.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.enquetes.pergunta IS 'Campo question no contrato da API.';

COMMENT ON COLUMN tech2d.enquetes.situacao IS 'Campo status no contrato da API.';

COMMENT ON COLUMN tech2d.enquetes.criado_por IS 'Campo createdBy no contrato da API.';

COMMENT ON COLUMN tech2d.enquetes.criado_em IS 'Campo createdAt no contrato da API.';

CREATE TABLE tech2d.opcoes_enquete (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pai bigint NOT NULL REFERENCES tech2d.enquetes(id_registro) ON DELETE CASCADE,
  grupo varchar(32) NOT NULL,
  ordem integer NOT NULL CHECK (ordem >= 0),
  UNIQUE (id_pai, grupo, ordem),
  opcao varchar(100)
);

COMMENT ON TABLE tech2d.opcoes_enquete IS 'Opções de cada enquete, na ordem exibida';

COMMENT ON COLUMN tech2d.opcoes_enquete.opcao IS 'Campo valor no contrato da API.';

CREATE TABLE tech2d.votos_enquete (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  indice_opcao smallint,
  criado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.votos_enquete IS 'Votos em enquetes';

COMMENT ON COLUMN tech2d.votos_enquete.indice_opcao IS 'Campo optionIndex no contrato da API.';

COMMENT ON COLUMN tech2d.votos_enquete.criado_em IS 'Campo createdAt no contrato da API.';

CREATE TABLE tech2d.acessos_votacao (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  email varchar(320),
  turma varchar(150),
  situacao varchar(32),
  solicitado_em varchar(40),
  revisado_em varchar(40),
  revisado_por varchar(128),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.acessos_votacao IS 'Autorizações para votar';

COMMENT ON COLUMN tech2d.acessos_votacao.email IS 'Campo email no contrato da API.';

COMMENT ON COLUMN tech2d.acessos_votacao.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.acessos_votacao.situacao IS 'Campo status no contrato da API.';

COMMENT ON COLUMN tech2d.acessos_votacao.solicitado_em IS 'Campo requestedAt no contrato da API.';

COMMENT ON COLUMN tech2d.acessos_votacao.revisado_em IS 'Campo reviewedAt no contrato da API.';

COMMENT ON COLUMN tech2d.acessos_votacao.revisado_por IS 'Campo reviewedBy no contrato da API.';

CREATE TABLE tech2d.sugestoes_atividade (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  titulo varchar(120),
  descricao varchar(2000),
  tipo varchar(32),
  disciplina varchar(150),
  data date,
  hora time,
  turma varchar(150),
  criado_em varchar(40),
  alterado_em varchar(40),
  situacao varchar(32),
  resolucao varchar(32),
  comentario_revisao varchar(500),
  encerrada_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.sugestoes_atividade IS 'Sugestões de novas atividades';

COMMENT ON COLUMN tech2d.sugestoes_atividade.titulo IS 'Campo title no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.descricao IS 'Campo description no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.tipo IS 'Campo type no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.disciplina IS 'Campo subject no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.data IS 'Campo date no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.hora IS 'Campo time no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.alterado_em IS 'Campo updatedAt no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.situacao IS 'Campo status no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.resolucao IS 'Campo resolution no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.comentario_revisao IS 'Campo reviewComment no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_atividade.encerrada_em IS 'Campo closedAt no contrato da API.';

CREATE TABLE tech2d.sugestoes_melhoria (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  mensagem varchar(2000),
  turma varchar(150),
  criado_por varchar(128),
  email_criador varchar(320),
  criado_em varchar(40),
  credito_autorizado boolean,
  nome_credito varchar(60),
  situacao varchar(32),
  concluida_em varchar(40),
  concluida_por varchar(128),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.sugestoes_melhoria IS 'Sugestões de melhoria da Agenda';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.mensagem IS 'Campo message no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.criado_por IS 'Campo createdBy no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.email_criador IS 'Campo createdByEmail no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.credito_autorizado IS 'Campo publicCreditAllowed no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.nome_credito IS 'Campo publicCreditName no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.situacao IS 'Campo status no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.concluida_em IS 'Campo completedAt no contrato da API.';

COMMENT ON COLUMN tech2d.sugestoes_melhoria.concluida_por IS 'Campo completedBy no contrato da API.';

CREATE TABLE tech2d.mensagens_sugestao (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  mensagem varchar(2000),
  remetente varchar(128),
  criado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.mensagens_sugestao IS 'Mensagens privadas sobre sugestões';

COMMENT ON COLUMN tech2d.mensagens_sugestao.mensagem IS 'Campo text no contrato da API.';

COMMENT ON COLUMN tech2d.mensagens_sugestao.remetente IS 'Campo senderId no contrato da API.';

COMMENT ON COLUMN tech2d.mensagens_sugestao.criado_em IS 'Campo createdAt no contrato da API.';

CREATE TABLE tech2d.anuncios (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  mensagem varchar(500),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.anuncios IS 'Comunicados gerais';

COMMENT ON COLUMN tech2d.anuncios.mensagem IS 'Campo message no contrato da API.';

COMMENT ON COLUMN tech2d.anuncios.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.atualizacoes_agenda (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  titulo varchar(120),
  conteudo varchar(2000),
  criado_por varchar(128),
  publicado_em varchar(40),
  referencia_sugestao varchar(180),
  nome_credito varchar(60),
  mensagem_sugestao varchar(2000),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.atualizacoes_agenda IS 'Histórico público de atualizações';

COMMENT ON COLUMN tech2d.atualizacoes_agenda.titulo IS 'Campo title no contrato da API.';

COMMENT ON COLUMN tech2d.atualizacoes_agenda.conteudo IS 'Campo body no contrato da API.';

COMMENT ON COLUMN tech2d.atualizacoes_agenda.criado_por IS 'Campo createdBy no contrato da API.';

COMMENT ON COLUMN tech2d.atualizacoes_agenda.publicado_em IS 'Campo publishedAt no contrato da API.';

COMMENT ON COLUMN tech2d.atualizacoes_agenda.referencia_sugestao IS 'Campo sourceFeedbackId no contrato da API.';

COMMENT ON COLUMN tech2d.atualizacoes_agenda.nome_credito IS 'Campo sourceName no contrato da API.';

COMMENT ON COLUMN tech2d.atualizacoes_agenda.mensagem_sugestao IS 'Campo sourceMessage no contrato da API.';

CREATE TABLE tech2d.avisos_turma (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  turma varchar(150),
  titulo varchar(60),
  conteudo varchar(500),
  tipo varchar(32),
  expira_em varchar(40),
  expurgo_em varchar(40),
  criado_por varchar(128),
  email_autor varchar(320),
  criado_em varchar(40),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.avisos_turma IS 'Avisos publicados no quadro da turma';

COMMENT ON COLUMN tech2d.avisos_turma.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.titulo IS 'Campo title no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.conteudo IS 'Campo body no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.tipo IS 'Campo type no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.expira_em IS 'Campo expiresAt no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.expurgo_em IS 'Campo purgeAt no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.criado_por IS 'Campo createdBy no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.email_autor IS 'Campo authorEmail no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.avisos_turma.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.anotacoes (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  titulo varchar(120),
  conteudo varchar(5000),
  disciplina varchar(120),
  turma varchar(80),
  id_autor varchar(128),
  email_autor varchar(320),
  criado_em varchar(40),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.anotacoes IS 'Anotações de estudo';

COMMENT ON COLUMN tech2d.anotacoes.titulo IS 'Campo title no contrato da API.';

COMMENT ON COLUMN tech2d.anotacoes.conteudo IS 'Campo content no contrato da API.';

COMMENT ON COLUMN tech2d.anotacoes.disciplina IS 'Campo subject no contrato da API.';

COMMENT ON COLUMN tech2d.anotacoes.turma IS 'Campo className no contrato da API.';

COMMENT ON COLUMN tech2d.anotacoes.id_autor IS 'Campo authorUid no contrato da API.';

COMMENT ON COLUMN tech2d.anotacoes.email_autor IS 'Campo authorEmail no contrato da API.';

COMMENT ON COLUMN tech2d.anotacoes.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.anotacoes.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.perfis_comunidade (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  nome varchar(80),
  empresa varchar(100),
  turma varchar(80),
  sala varchar(80),
  andar varchar(80),
  url_foto varchar(2048),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.perfis_comunidade IS 'Perfis públicos da comunidade';

COMMENT ON COLUMN tech2d.perfis_comunidade.nome IS 'Campo displayName no contrato da API.';

COMMENT ON COLUMN tech2d.perfis_comunidade.empresa IS 'Campo company no contrato da API.';

COMMENT ON COLUMN tech2d.perfis_comunidade.turma IS 'Campo className no contrato da API.';

COMMENT ON COLUMN tech2d.perfis_comunidade.sala IS 'Campo room no contrato da API.';

COMMENT ON COLUMN tech2d.perfis_comunidade.andar IS 'Campo floor no contrato da API.';

COMMENT ON COLUMN tech2d.perfis_comunidade.url_foto IS 'Campo photoUrl no contrato da API.';

COMMENT ON COLUMN tech2d.perfis_comunidade.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.atividades_arquivadas (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  referencia_atividade varchar(320),
  turma varchar(150),
  motivo varchar(32),
  arquivada_em varchar(40),
  dias_retencao smallint,
  anexos_removidos_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.atividades_arquivadas IS 'Metadados do expurgo de atividades';

COMMENT ON COLUMN tech2d.atividades_arquivadas.referencia_atividade IS 'Campo originalId no contrato da API.';

COMMENT ON COLUMN tech2d.atividades_arquivadas.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.atividades_arquivadas.motivo IS 'Campo reason no contrato da API.';

COMMENT ON COLUMN tech2d.atividades_arquivadas.arquivada_em IS 'Campo archivedAt no contrato da API.';

COMMENT ON COLUMN tech2d.atividades_arquivadas.dias_retencao IS 'Campo retentionDays no contrato da API.';

COMMENT ON COLUMN tech2d.atividades_arquivadas.anexos_removidos_em IS 'Campo r2CleanedAt no contrato da API.';

CREATE TABLE tech2d.conteudo_atividade_arquivada (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pai bigint NOT NULL REFERENCES tech2d.atividades_arquivadas(id_registro) ON DELETE CASCADE,
  grupo varchar(32) NOT NULL,
  ordem integer NOT NULL CHECK (ordem >= 0),
  UNIQUE (id_pai, grupo, ordem),
  titulo varchar(120),
  descricao varchar(2000),
  tipo varchar(32),
  disciplina varchar(150),
  data date,
  hora time,
  turma varchar(150),
  criado_por varchar(128),
  email_criador varchar(320),
  referencia_recorrencia varchar(320),
  criado_em varchar(40),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.conteudo_atividade_arquivada IS 'Conteúdo das atividades arquivadas';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.titulo IS 'Campo title no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.descricao IS 'Campo description no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.tipo IS 'Campo type no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.disciplina IS 'Campo subject no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.data IS 'Campo date no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.hora IS 'Campo time no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.criado_por IS 'Campo createdBy no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.email_criador IS 'Campo createdByEmail no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.referencia_recorrencia IS 'Campo recurringId no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.conteudo_atividade_arquivada.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.anexos_atividade (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pai bigint NOT NULL REFERENCES tech2d.atividades(id_registro) ON DELETE CASCADE,
  grupo varchar(32) NOT NULL,
  ordem integer NOT NULL CHECK (ordem >= 0),
  UNIQUE (id_pai, grupo, ordem),
  referencia varchar(180),
  nome varchar(500),
  tipo_mime varchar(150),
  tamanho_bytes bigint,
  chave_arquivo varchar(1024),
  enviado_em varchar(40),
  enviado_por varchar(128),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.anexos_atividade IS 'Metadados dos arquivos anexados às atividades';

COMMENT ON COLUMN tech2d.anexos_atividade.referencia IS 'Campo id no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade.nome IS 'Campo name no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade.tipo_mime IS 'Campo contentType no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade.tamanho_bytes IS 'Campo size no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade.chave_arquivo IS 'Campo storagePath no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade.enviado_em IS 'Campo uploadedAt no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade.enviado_por IS 'Campo uploadedBy no contrato da API.';

CREATE TABLE tech2d.anexos_atividade_arquivada (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pai bigint NOT NULL REFERENCES tech2d.conteudo_atividade_arquivada(id) ON DELETE CASCADE,
  grupo varchar(32) NOT NULL,
  ordem integer NOT NULL CHECK (ordem >= 0),
  UNIQUE (id_pai, grupo, ordem),
  referencia varchar(180),
  nome varchar(500),
  tipo_mime varchar(150),
  tamanho_bytes bigint,
  chave_arquivo varchar(1024),
  enviado_em varchar(40),
  enviado_por varchar(128),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.anexos_atividade_arquivada IS 'Metadados dos anexos de atividades arquivadas';

COMMENT ON COLUMN tech2d.anexos_atividade_arquivada.referencia IS 'Campo id no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade_arquivada.nome IS 'Campo name no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade_arquivada.tipo_mime IS 'Campo contentType no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade_arquivada.tamanho_bytes IS 'Campo size no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade_arquivada.chave_arquivo IS 'Campo storagePath no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade_arquivada.enviado_em IS 'Campo uploadedAt no contrato da API.';

COMMENT ON COLUMN tech2d.anexos_atividade_arquivada.enviado_por IS 'Campo uploadedBy no contrato da API.';

CREATE TABLE tech2d.preferencias_resumo (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  ativo boolean,
  turma varchar(150),
  alterada_em_ms bigint,
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.preferencias_resumo IS 'Preferências de e-mail por conta';

COMMENT ON COLUMN tech2d.preferencias_resumo.ativo IS 'Campo enabled no contrato da API.';

COMMENT ON COLUMN tech2d.preferencias_resumo.turma IS 'Campo turmaId no contrato da API.';

COMMENT ON COLUMN tech2d.preferencias_resumo.alterada_em_ms IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.entregas_resumo (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  situacao varchar(32),
  inicio_semana date,
  criada_em_ms bigint,
  concluida_em_ms bigint,
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.entregas_resumo IS 'Reservas de envio do resumo semanal';

COMMENT ON COLUMN tech2d.entregas_resumo.situacao IS 'Campo status no contrato da API.';

COMMENT ON COLUMN tech2d.entregas_resumo.inicio_semana IS 'Campo weekStart no contrato da API.';

COMMENT ON COLUMN tech2d.entregas_resumo.criada_em_ms IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.entregas_resumo.concluida_em_ms IS 'Campo completedAt no contrato da API.';

CREATE TABLE tech2d.envios_anexos (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  referencia_atividade varchar(320),
  nome varchar(500),
  tipo_mime varchar(150),
  tamanho_bytes bigint,
  chave_arquivo varchar(1024),
  id_usuario varchar(128),
  criado_em_ms bigint,
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.envios_anexos IS 'Envios pendentes de anexos';

COMMENT ON COLUMN tech2d.envios_anexos.referencia_atividade IS 'Campo activityId no contrato da API.';

COMMENT ON COLUMN tech2d.envios_anexos.nome IS 'Campo name no contrato da API.';

COMMENT ON COLUMN tech2d.envios_anexos.tipo_mime IS 'Campo contentType no contrato da API.';

COMMENT ON COLUMN tech2d.envios_anexos.tamanho_bytes IS 'Campo size no contrato da API.';

COMMENT ON COLUMN tech2d.envios_anexos.chave_arquivo IS 'Campo key no contrato da API.';

COMMENT ON COLUMN tech2d.envios_anexos.id_usuario IS 'Campo uid no contrato da API.';

COMMENT ON COLUMN tech2d.envios_anexos.criado_em_ms IS 'Campo createdAt no contrato da API.';

CREATE TABLE tech2d.limites_servico (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  quantidade integer,
  expira_em_ms bigint,
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.limites_servico IS 'Contadores de solicitações por janela';

COMMENT ON COLUMN tech2d.limites_servico.quantidade IS 'Campo count no contrato da API.';

COMMENT ON COLUMN tech2d.limites_servico.expira_em_ms IS 'Campo resetAt no contrato da API.';

CREATE TABLE tech2d.espacos_kanban (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  id_proprietario varchar(128),
  versao_formato smallint,
  criado_em varchar(40),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.espacos_kanban IS 'Espaços pessoais e compartilhados do Kanban';

COMMENT ON COLUMN tech2d.espacos_kanban.id_proprietario IS 'Campo ownerId no contrato da API.';

COMMENT ON COLUMN tech2d.espacos_kanban.versao_formato IS 'Campo schemaVersion no contrato da API.';

COMMENT ON COLUMN tech2d.espacos_kanban.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.espacos_kanban.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.quadros_kanban (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pai bigint NOT NULL REFERENCES tech2d.espacos_kanban(id_registro) ON DELETE CASCADE,
  grupo varchar(32) NOT NULL,
  ordem integer NOT NULL CHECK (ordem >= 0),
  UNIQUE (id_pai, grupo, ordem),
  referencia varchar(80),
  nome varchar(80),
  cor varchar(16),
  compacto boolean,
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.quadros_kanban IS 'Quadros do Kanban em cada espaço';

COMMENT ON COLUMN tech2d.quadros_kanban.referencia IS 'Campo id no contrato da API.';

COMMENT ON COLUMN tech2d.quadros_kanban.nome IS 'Campo name no contrato da API.';

COMMENT ON COLUMN tech2d.quadros_kanban.cor IS 'Campo color no contrato da API.';

COMMENT ON COLUMN tech2d.quadros_kanban.compacto IS 'Campo compact no contrato da API.';

CREATE TABLE tech2d.colunas_kanban (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pai bigint NOT NULL REFERENCES tech2d.quadros_kanban(id) ON DELETE CASCADE,
  grupo varchar(32) NOT NULL,
  ordem integer NOT NULL CHECK (ordem >= 0),
  UNIQUE (id_pai, grupo, ordem),
  referencia varchar(80),
  nome varchar(60),
  cor varchar(16),
  concluida boolean,
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.colunas_kanban IS 'Colunas dos quadros';

COMMENT ON COLUMN tech2d.colunas_kanban.referencia IS 'Campo id no contrato da API.';

COMMENT ON COLUMN tech2d.colunas_kanban.nome IS 'Campo name no contrato da API.';

COMMENT ON COLUMN tech2d.colunas_kanban.cor IS 'Campo color no contrato da API.';

COMMENT ON COLUMN tech2d.colunas_kanban.concluida IS 'Campo done no contrato da API.';

CREATE TABLE tech2d.cartoes_kanban (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pai bigint NOT NULL REFERENCES tech2d.quadros_kanban(id) ON DELETE CASCADE,
  grupo varchar(32) NOT NULL,
  ordem integer NOT NULL CHECK (ordem >= 0),
  UNIQUE (id_pai, grupo, ordem),
  referencia varchar(80),
  referencia_coluna varchar(80),
  titulo varchar(160),
  descricao varchar(3000),
  prioridade varchar(16),
  prazo date,
  id_responsavel varchar(128),
  etiquetas varchar(30)[],
  referencias_atividades varchar(128)[],
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.cartoes_kanban IS 'Cartões dos quadros';

COMMENT ON COLUMN tech2d.cartoes_kanban.referencia IS 'Campo id no contrato da API.';

COMMENT ON COLUMN tech2d.cartoes_kanban.referencia_coluna IS 'Campo columnId no contrato da API.';

COMMENT ON COLUMN tech2d.cartoes_kanban.titulo IS 'Campo title no contrato da API.';

COMMENT ON COLUMN tech2d.cartoes_kanban.descricao IS 'Campo description no contrato da API.';

COMMENT ON COLUMN tech2d.cartoes_kanban.prioridade IS 'Campo priority no contrato da API.';

COMMENT ON COLUMN tech2d.cartoes_kanban.prazo IS 'Campo dueDate no contrato da API.';

COMMENT ON COLUMN tech2d.cartoes_kanban.id_responsavel IS 'Campo assigneeId no contrato da API.';

COMMENT ON COLUMN tech2d.cartoes_kanban.etiquetas IS 'Campo labels no contrato da API.';

COMMENT ON COLUMN tech2d.cartoes_kanban.referencias_atividades IS 'Campo activityIds no contrato da API.';

CREATE TABLE tech2d.itens_checklist (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pai bigint NOT NULL REFERENCES tech2d.cartoes_kanban(id) ON DELETE CASCADE,
  grupo varchar(32) NOT NULL,
  ordem integer NOT NULL CHECK (ordem >= 0),
  UNIQUE (id_pai, grupo, ordem),
  referencia varchar(80),
  descricao varchar(200),
  concluido boolean,
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.itens_checklist IS 'Itens das listas dos cartões';

COMMENT ON COLUMN tech2d.itens_checklist.referencia IS 'Campo id no contrato da API.';

COMMENT ON COLUMN tech2d.itens_checklist.descricao IS 'Campo text no contrato da API.';

COMMENT ON COLUMN tech2d.itens_checklist.concluido IS 'Campo done no contrato da API.';

CREATE TABLE tech2d.participantes_kanban (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  referencia_quadro varchar(80),
  id_usuario varchar(128),
  email varchar(320),
  nome varchar(80),
  criado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.participantes_kanban IS 'Participantes de quadros compartilhados';

COMMENT ON COLUMN tech2d.participantes_kanban.referencia_quadro IS 'Campo boardId no contrato da API.';

COMMENT ON COLUMN tech2d.participantes_kanban.id_usuario IS 'Campo userId no contrato da API.';

COMMENT ON COLUMN tech2d.participantes_kanban.email IS 'Campo userEmail no contrato da API.';

COMMENT ON COLUMN tech2d.participantes_kanban.nome IS 'Campo name no contrato da API.';

COMMENT ON COLUMN tech2d.participantes_kanban.criado_em IS 'Campo createdAt no contrato da API.';

CREATE TABLE tech2d.pedidos_kanban (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  referencia_quadro varchar(80),
  id_usuario varchar(128),
  email varchar(320),
  nome varchar(80),
  criado_em varchar(40),
  situacao varchar(32),
  alterado_em varchar(40),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.pedidos_kanban IS 'Pedidos de acesso a quadros compartilhados';

COMMENT ON COLUMN tech2d.pedidos_kanban.referencia_quadro IS 'Campo boardId no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_kanban.id_usuario IS 'Campo userId no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_kanban.email IS 'Campo userEmail no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_kanban.nome IS 'Campo name no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_kanban.criado_em IS 'Campo createdAt no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_kanban.situacao IS 'Campo status no contrato da API.';

COMMENT ON COLUMN tech2d.pedidos_kanban.alterado_em IS 'Campo updatedAt no contrato da API.';

CREATE TABLE tech2d.limpeza_anexos_kanban (
  id_registro bigint PRIMARY KEY REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE,
  referencia_espaco varchar(512),
  referencia_quadro varchar(80),
  referencia_cartao varchar(80),
  campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[]
);

COMMENT ON TABLE tech2d.limpeza_anexos_kanban IS 'Fila de limpeza dos anexos de cartões removidos';

COMMENT ON COLUMN tech2d.limpeza_anexos_kanban.referencia_espaco IS 'Campo path no contrato da API.';

COMMENT ON COLUMN tech2d.limpeza_anexos_kanban.referencia_quadro IS 'Campo board no contrato da API.';

COMMENT ON COLUMN tech2d.limpeza_anexos_kanban.referencia_cartao IS 'Campo task no contrato da API.';

ALTER TABLE tech2d.colunas_kanban ADD CONSTRAINT colunas_kanban_referencia_quadro UNIQUE(id_pai,referencia);
ALTER TABLE tech2d.cartoes_kanban ADD CONSTRAINT cartoes_kanban_coluna
  FOREIGN KEY (id_pai,referencia_coluna) REFERENCES tech2d.colunas_kanban(id_pai,referencia)
  DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX atividades_turma_data ON tech2d.atividades(turma,data);
CREATE INDEX atividades_data ON tech2d.atividades(data);
CREATE INDEX atividades_recorrencia ON tech2d.atividades(referencia_recorrencia);
CREATE INDEX perfis_papel_turma ON tech2d.perfis_administrativos(papel,turma);
CREATE INDEX sugestoes_melhoria_autor ON tech2d.sugestoes_melhoria(criado_por);
CREATE INDEX participantes_kanban_quadro ON tech2d.participantes_kanban(referencia_quadro);
CREATE INDEX pedidos_kanban_quadro ON tech2d.pedidos_kanban(referencia_quadro);

ALTER TABLE tech2d.horarios_aula ADD COLUMN id_registro bigint UNIQUE REFERENCES tech2d.registros_aplicacao(id) ON DELETE CASCADE;
ALTER TABLE tech2d.horarios_aula ADD COLUMN andar varchar(80);
ALTER TABLE tech2d.horarios_aula ADD COLUMN sala varchar(500);
ALTER TABLE tech2d.horarios_aula ADD COLUMN criado_em varchar(40);
ALTER TABLE tech2d.horarios_aula ADD COLUMN alterado_em varchar(40);
ALTER TABLE tech2d.horarios_aula ADD COLUMN campos_nulos varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[];
COMMENT ON COLUMN tech2d.horarios_aula.id_registro IS 'Identidade numérica do registro na API.';
COMMENT ON COLUMN tech2d.horarios_aula.andar IS 'Andar informado para a aula.';
COMMENT ON COLUMN tech2d.horarios_aula.sala IS 'Descrição da sala ou localização da aula.';

CREATE FUNCTION tech2d.inserir_anexos_atividade(pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.anexos_atividade (id_pai,grupo,ordem,referencia,nome,tipo_mime,tamanho_bytes,chave_arquivo,enviado_em,enviado_por,campos_nulos) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'name',objeto->>'contentType',(objeto->>'size')::bigint,objeto->>'storagePath',objeto->>'uploadedAt',objeto->>'uploadedBy',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb)) RETURNING id INTO alvo;
END $$;

CREATE FUNCTION tech2d.ler_anexos_atividade(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'name', d.nome,
    'contentType', d.tipo_mime,
    'size', d.tamanho_bytes,
    'storagePath', d.chave_arquivo,
    'uploadedAt', d.enviado_em,
    'uploadedBy', d.enviado_por
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.anexos_atividade d WHERE d.id=alvo;
$$;

ALTER TABLE tech2d.atividades ADD COLUMN listas_presentes varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[];

CREATE FUNCTION tech2d.gravar_atividades(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.atividades (id_registro,titulo,descricao,tipo,disciplina,data,hora,turma,criado_por,email_criador,referencia_recorrencia,criado_em,alterado_em,campos_nulos) VALUES (alvo,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'date')::date,(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'recurringId',objeto->>'createdAt',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, descricao=excluded.descricao, tipo=excluded.tipo, disciplina=excluded.disciplina, data=excluded.data, hora=excluded.hora, turma=excluded.turma, criado_por=excluded.criado_por, email_criador=excluded.email_criador, referencia_recorrencia=excluded.referencia_recorrencia, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em, campos_nulos=excluded.campos_nulos;
  DELETE FROM tech2d.anexos_atividade WHERE id_pai=alvo AND grupo='attachments';
  IF jsonb_typeof(objeto->'attachments')='array' THEN
    PERFORM tech2d.inserir_anexos_atividade(alvo,'attachments',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'attachments') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.atividades SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('attachments') AND jsonb_typeof(value)='array') WHERE id_registro=alvo;
END $$;

CREATE FUNCTION tech2d.ler_atividades(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
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
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.atividades d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_perfis_administrativos(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.perfis_administrativos (id_registro,papel,turma,criado_em,campos_nulos) VALUES (alvo,objeto->>'role',objeto->>'turmaId',objeto->>'createdAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET papel=excluded.papel, turma=excluded.turma, criado_em=excluded.criado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_perfis_administrativos(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'role', d.papel,
    'turmaId', d.turma,
    'createdAt', d.criado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.perfis_administrativos d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_regras_recorrencia(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.regras_recorrencia (id_registro,titulo,descricao,tipo,disciplina,hora,turma,criado_por,email_criador,criado_em,inicio,fim,ativa,excluida,intervalo_semanas,dias_semana,campos_nulos) VALUES (alvo,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'createdAt',(objeto->>'startDate')::date,(objeto->>'endDate')::date,(objeto->>'active')::boolean,(objeto->>'deleted')::boolean,(objeto->>'intervalWeeks')::smallint,CASE WHEN jsonb_typeof(objeto->'weekdays')='array' THEN ARRAY(SELECT value::smallint FROM jsonb_array_elements_text(objeto->'weekdays') WITH ORDINALITY AS x(value,pos) ORDER BY pos) END,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, descricao=excluded.descricao, tipo=excluded.tipo, disciplina=excluded.disciplina, hora=excluded.hora, turma=excluded.turma, criado_por=excluded.criado_por, email_criador=excluded.email_criador, criado_em=excluded.criado_em, inicio=excluded.inicio, fim=excluded.fim, ativa=excluded.ativa, excluida=excluded.excluida, intervalo_semanas=excluded.intervalo_semanas, dias_semana=excluded.dias_semana, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_regras_recorrencia(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
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
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.regras_recorrencia d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_regras_retencao(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.regras_retencao (id_registro,turma,dias,ativa,alterado_por,alterado_em,campos_nulos) VALUES (alvo,objeto->>'turmaId',(objeto->>'days')::smallint,(objeto->>'enabled')::boolean,objeto->>'updatedBy',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, dias=excluded.dias, ativa=excluded.ativa, alterado_por=excluded.alterado_por, alterado_em=excluded.alterado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_regras_retencao(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'turmaId', d.turma,
    'days', d.dias,
    'enabled', d.ativa,
    'updatedBy', d.alterado_por,
    'updatedAt', d.alterado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.regras_retencao d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_pedidos_agenda(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.pedidos_agenda (id_registro,nome_turma,email,situacao,criado_em,revisado_em,campos_nulos) VALUES (alvo,objeto->>'className',objeto->>'email',objeto->>'status',objeto->>'createdAt',objeto->>'reviewedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET nome_turma=excluded.nome_turma, email=excluded.email, situacao=excluded.situacao, criado_em=excluded.criado_em, revisado_em=excluded.revisado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_pedidos_agenda(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'className', d.nome_turma,
    'email', d.email,
    'status', d.situacao,
    'createdAt', d.criado_em,
    'reviewedAt', d.revisado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.pedidos_agenda d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_turmas_agenda(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.turmas_agenda (id_registro,nome,ativa,referencia_pedido,aprovada_em,campos_nulos) VALUES (alvo,objeto->>'name',(objeto->>'active')::boolean,objeto->>'requestId',objeto->>'approvedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET nome=excluded.nome, ativa=excluded.ativa, referencia_pedido=excluded.referencia_pedido, aprovada_em=excluded.aprovada_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_turmas_agenda(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'name', d.nome,
    'active', d.ativa,
    'requestId', d.referencia_pedido,
    'approvedAt', d.aprovada_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.turmas_agenda d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_pedidos_representacao(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.pedidos_representacao (id_registro,turma,email,situacao,criado_em,revisado_em,campos_nulos) VALUES (alvo,objeto->>'turmaId',objeto->>'email',objeto->>'status',objeto->>'createdAt',objeto->>'reviewedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, email=excluded.email, situacao=excluded.situacao, criado_em=excluded.criado_em, revisado_em=excluded.revisado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_pedidos_representacao(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'turmaId', d.turma,
    'email', d.email,
    'status', d.situacao,
    'createdAt', d.criado_em,
    'reviewedAt', d.revisado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.pedidos_representacao d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_convites_representacao(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.convites_representacao (id_registro,email,turma,referencia_pedido,aprovado_em,campos_nulos) VALUES (alvo,objeto->>'email',objeto->>'turmaId',objeto->>'requestId',objeto->>'approvedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET email=excluded.email, turma=excluded.turma, referencia_pedido=excluded.referencia_pedido, aprovado_em=excluded.aprovado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_convites_representacao(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'email', d.email,
    'turmaId', d.turma,
    'requestId', d.referencia_pedido,
    'approvedAt', d.aprovado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.convites_representacao d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_chat_representantes(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.chat_representantes (id_registro,mensagem,remetente,email_remetente,papel_remetente,turma_remetente,criado_em,campos_nulos) VALUES (alvo,objeto->>'text',objeto->>'senderId',objeto->>'senderEmail',objeto->>'senderRole',objeto->>'senderTurma',objeto->>'createdAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET mensagem=excluded.mensagem, remetente=excluded.remetente, email_remetente=excluded.email_remetente, papel_remetente=excluded.papel_remetente, turma_remetente=excluded.turma_remetente, criado_em=excluded.criado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_chat_representantes(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'text', d.mensagem,
    'senderId', d.remetente,
    'senderEmail', d.email_remetente,
    'senderRole', d.papel_remetente,
    'senderTurma', d.turma_remetente,
    'createdAt', d.criado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.chat_representantes d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.inserir_opcoes_enquete(pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.opcoes_enquete (id_pai,grupo,ordem,opcao) VALUES (pai,campo,posicao,objeto->>'valor') RETURNING id INTO alvo;
END $$;

ALTER TABLE tech2d.enquetes ADD COLUMN listas_presentes varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[];

CREATE FUNCTION tech2d.gravar_enquetes(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.enquetes (id_registro,turma,pergunta,situacao,criado_por,criado_em,campos_nulos) VALUES (alvo,objeto->>'turmaId',objeto->>'question',objeto->>'status',objeto->>'createdBy',objeto->>'createdAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, pergunta=excluded.pergunta, situacao=excluded.situacao, criado_por=excluded.criado_por, criado_em=excluded.criado_em, campos_nulos=excluded.campos_nulos;
  DELETE FROM tech2d.opcoes_enquete WHERE id_pai=alvo AND grupo='options';
  IF jsonb_typeof(objeto->'options')='array' THEN
    PERFORM tech2d.inserir_opcoes_enquete(alvo,'options',(pos-1)::integer,jsonb_build_object('valor',value))
    FROM jsonb_array_elements(objeto->'options') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.enquetes SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('options') AND jsonb_typeof(value)='array') WHERE id_registro=alvo;
END $$;

CREATE FUNCTION tech2d.ler_enquetes(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'turmaId', d.turma,
    'question', d.pergunta,
    'options', CASE WHEN 'options'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(to_jsonb(r.opcao) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.opcoes_enquete r WHERE r.id_pai=d.id_registro AND r.grupo='options') END,
    'status', d.situacao,
    'createdBy', d.criado_por,
    'createdAt', d.criado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.enquetes d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_votos_enquete(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.votos_enquete (id_registro,indice_opcao,criado_em,campos_nulos) VALUES (alvo,(objeto->>'optionIndex')::smallint,objeto->>'createdAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET indice_opcao=excluded.indice_opcao, criado_em=excluded.criado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_votos_enquete(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'optionIndex', d.indice_opcao,
    'createdAt', d.criado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.votos_enquete d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_acessos_votacao(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.acessos_votacao (id_registro,email,turma,situacao,solicitado_em,revisado_em,revisado_por,campos_nulos) VALUES (alvo,objeto->>'email',objeto->>'turmaId',objeto->>'status',objeto->>'requestedAt',objeto->>'reviewedAt',objeto->>'reviewedBy',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET email=excluded.email, turma=excluded.turma, situacao=excluded.situacao, solicitado_em=excluded.solicitado_em, revisado_em=excluded.revisado_em, revisado_por=excluded.revisado_por, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_acessos_votacao(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'email', d.email,
    'turmaId', d.turma,
    'status', d.situacao,
    'requestedAt', d.solicitado_em,
    'reviewedAt', d.revisado_em,
    'reviewedBy', d.revisado_por
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.acessos_votacao d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_sugestoes_atividade(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.sugestoes_atividade (id_registro,titulo,descricao,tipo,disciplina,data,hora,turma,criado_em,alterado_em,situacao,resolucao,comentario_revisao,encerrada_em,campos_nulos) VALUES (alvo,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'date')::date,(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdAt',objeto->>'updatedAt',objeto->>'status',objeto->>'resolution',objeto->>'reviewComment',objeto->>'closedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, descricao=excluded.descricao, tipo=excluded.tipo, disciplina=excluded.disciplina, data=excluded.data, hora=excluded.hora, turma=excluded.turma, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em, situacao=excluded.situacao, resolucao=excluded.resolucao, comentario_revisao=excluded.comentario_revisao, encerrada_em=excluded.encerrada_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_sugestoes_atividade(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
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
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.sugestoes_atividade d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_sugestoes_melhoria(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.sugestoes_melhoria (id_registro,mensagem,turma,criado_por,email_criador,criado_em,credito_autorizado,nome_credito,situacao,concluida_em,concluida_por,campos_nulos) VALUES (alvo,objeto->>'message',objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'createdAt',(objeto->>'publicCreditAllowed')::boolean,objeto->>'publicCreditName',objeto->>'status',objeto->>'completedAt',objeto->>'completedBy',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET mensagem=excluded.mensagem, turma=excluded.turma, criado_por=excluded.criado_por, email_criador=excluded.email_criador, criado_em=excluded.criado_em, credito_autorizado=excluded.credito_autorizado, nome_credito=excluded.nome_credito, situacao=excluded.situacao, concluida_em=excluded.concluida_em, concluida_por=excluded.concluida_por, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_sugestoes_melhoria(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
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
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.sugestoes_melhoria d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_mensagens_sugestao(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.mensagens_sugestao (id_registro,mensagem,remetente,criado_em,campos_nulos) VALUES (alvo,objeto->>'text',objeto->>'senderId',objeto->>'createdAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET mensagem=excluded.mensagem, remetente=excluded.remetente, criado_em=excluded.criado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_mensagens_sugestao(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'text', d.mensagem,
    'senderId', d.remetente,
    'createdAt', d.criado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.mensagens_sugestao d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_anuncios(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.anuncios (id_registro,mensagem,alterado_em,campos_nulos) VALUES (alvo,objeto->>'message',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET mensagem=excluded.mensagem, alterado_em=excluded.alterado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_anuncios(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'message', d.mensagem,
    'updatedAt', d.alterado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.anuncios d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_atualizacoes_agenda(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.atualizacoes_agenda (id_registro,titulo,conteudo,criado_por,publicado_em,referencia_sugestao,nome_credito,mensagem_sugestao,campos_nulos) VALUES (alvo,objeto->>'title',objeto->>'body',objeto->>'createdBy',objeto->>'publishedAt',objeto->>'sourceFeedbackId',objeto->>'sourceName',objeto->>'sourceMessage',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, conteudo=excluded.conteudo, criado_por=excluded.criado_por, publicado_em=excluded.publicado_em, referencia_sugestao=excluded.referencia_sugestao, nome_credito=excluded.nome_credito, mensagem_sugestao=excluded.mensagem_sugestao, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_atualizacoes_agenda(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'title', d.titulo,
    'body', d.conteudo,
    'createdBy', d.criado_por,
    'publishedAt', d.publicado_em,
    'sourceFeedbackId', d.referencia_sugestao,
    'sourceName', d.nome_credito,
    'sourceMessage', d.mensagem_sugestao
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.atualizacoes_agenda d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_avisos_turma(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.avisos_turma (id_registro,turma,titulo,conteudo,tipo,expira_em,expurgo_em,criado_por,email_autor,criado_em,alterado_em,campos_nulos) VALUES (alvo,objeto->>'turmaId',objeto->>'title',objeto->>'body',objeto->>'type',objeto->>'expiresAt',objeto->>'purgeAt',objeto->>'createdBy',objeto->>'authorEmail',objeto->>'createdAt',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET turma=excluded.turma, titulo=excluded.titulo, conteudo=excluded.conteudo, tipo=excluded.tipo, expira_em=excluded.expira_em, expurgo_em=excluded.expurgo_em, criado_por=excluded.criado_por, email_autor=excluded.email_autor, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_avisos_turma(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
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
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.avisos_turma d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_anotacoes(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.anotacoes (id_registro,titulo,conteudo,disciplina,turma,id_autor,email_autor,criado_em,alterado_em,campos_nulos) VALUES (alvo,objeto->>'title',objeto->>'content',objeto->>'subject',objeto->>'className',objeto->>'authorUid',objeto->>'authorEmail',objeto->>'createdAt',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET titulo=excluded.titulo, conteudo=excluded.conteudo, disciplina=excluded.disciplina, turma=excluded.turma, id_autor=excluded.id_autor, email_autor=excluded.email_autor, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_anotacoes(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'title', d.titulo,
    'content', d.conteudo,
    'subject', d.disciplina,
    'className', d.turma,
    'authorUid', d.id_autor,
    'authorEmail', d.email_autor,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.anotacoes d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_perfis_comunidade(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.perfis_comunidade (id_registro,nome,empresa,turma,sala,andar,url_foto,alterado_em,campos_nulos) VALUES (alvo,objeto->>'displayName',objeto->>'company',objeto->>'className',objeto->>'room',objeto->>'floor',objeto->>'photoUrl',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET nome=excluded.nome, empresa=excluded.empresa, turma=excluded.turma, sala=excluded.sala, andar=excluded.andar, url_foto=excluded.url_foto, alterado_em=excluded.alterado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_perfis_comunidade(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'displayName', d.nome,
    'company', d.empresa,
    'className', d.turma,
    'room', d.sala,
    'floor', d.andar,
    'photoUrl', d.url_foto,
    'updatedAt', d.alterado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.perfis_comunidade d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.inserir_anexos_atividade_arquivada(pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.anexos_atividade_arquivada (id_pai,grupo,ordem,referencia,nome,tipo_mime,tamanho_bytes,chave_arquivo,enviado_em,enviado_por,campos_nulos) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'name',objeto->>'contentType',(objeto->>'size')::bigint,objeto->>'storagePath',objeto->>'uploadedAt',objeto->>'uploadedBy',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb)) RETURNING id INTO alvo;
END $$;

CREATE FUNCTION tech2d.ler_anexos_atividade_arquivada(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'name', d.nome,
    'contentType', d.tipo_mime,
    'size', d.tamanho_bytes,
    'storagePath', d.chave_arquivo,
    'uploadedAt', d.enviado_em,
    'uploadedBy', d.enviado_por
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.anexos_atividade_arquivada d WHERE d.id=alvo;
$$;

ALTER TABLE tech2d.conteudo_atividade_arquivada ADD COLUMN listas_presentes varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[];

CREATE FUNCTION tech2d.inserir_conteudo_atividade_arquivada(pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.conteudo_atividade_arquivada (id_pai,grupo,ordem,titulo,descricao,tipo,disciplina,data,hora,turma,criado_por,email_criador,referencia_recorrencia,criado_em,alterado_em,campos_nulos) VALUES (pai,campo,posicao,objeto->>'title',objeto->>'description',objeto->>'type',objeto->>'subject',(objeto->>'date')::date,(objeto->>'time')::time,objeto->>'turmaId',objeto->>'createdBy',objeto->>'createdByEmail',objeto->>'recurringId',objeto->>'createdAt',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb)) RETURNING id INTO alvo;
  DELETE FROM tech2d.anexos_atividade_arquivada WHERE id_pai=alvo AND grupo='attachments';
  IF jsonb_typeof(objeto->'attachments')='array' THEN
    PERFORM tech2d.inserir_anexos_atividade_arquivada(alvo,'attachments',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'attachments') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.conteudo_atividade_arquivada SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('attachments') AND jsonb_typeof(value)='array') WHERE id=alvo;
END $$;

CREATE FUNCTION tech2d.ler_conteudo_atividade_arquivada(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
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
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.conteudo_atividade_arquivada d WHERE d.id=alvo;
$$;

CREATE FUNCTION tech2d.gravar_atividades_arquivadas(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.atividades_arquivadas (id_registro,referencia_atividade,turma,motivo,arquivada_em,dias_retencao,anexos_removidos_em,campos_nulos) VALUES (alvo,objeto->>'originalId',objeto->>'turmaId',objeto->>'reason',objeto->>'archivedAt',(objeto->>'retentionDays')::smallint,objeto->>'r2CleanedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET referencia_atividade=excluded.referencia_atividade, turma=excluded.turma, motivo=excluded.motivo, arquivada_em=excluded.arquivada_em, dias_retencao=excluded.dias_retencao, anexos_removidos_em=excluded.anexos_removidos_em, campos_nulos=excluded.campos_nulos;
  DELETE FROM tech2d.conteudo_atividade_arquivada WHERE id_pai=alvo AND grupo='originalData';
  IF jsonb_typeof(objeto->'originalData')='object' THEN
    PERFORM tech2d.inserir_conteudo_atividade_arquivada(alvo,'originalData',0,objeto->'originalData');
  END IF;
END $$;

CREATE FUNCTION tech2d.ler_atividades_arquivadas(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'originalId', d.referencia_atividade,
    'turmaId', d.turma,
    'reason', d.motivo,
    'archivedAt', d.arquivada_em,
    'retentionDays', d.dias_retencao,
    'r2CleanedAt', d.anexos_removidos_em,
    'originalData', (SELECT tech2d.ler_conteudo_atividade_arquivada(r.id) FROM tech2d.conteudo_atividade_arquivada r WHERE r.id_pai=d.id_registro AND r.grupo='originalData' AND r.ordem=0)
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.atividades_arquivadas d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_preferencias_resumo(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.preferencias_resumo (id_registro,ativo,turma,alterada_em_ms,campos_nulos) VALUES (alvo,(objeto->>'enabled')::boolean,objeto->>'turmaId',(objeto->>'updatedAt')::bigint,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET ativo=excluded.ativo, turma=excluded.turma, alterada_em_ms=excluded.alterada_em_ms, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_preferencias_resumo(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'enabled', d.ativo,
    'turmaId', d.turma,
    'updatedAt', d.alterada_em_ms
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.preferencias_resumo d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_entregas_resumo(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.entregas_resumo (id_registro,situacao,inicio_semana,criada_em_ms,concluida_em_ms,campos_nulos) VALUES (alvo,objeto->>'status',(objeto->>'weekStart')::date,(objeto->>'createdAt')::bigint,(objeto->>'completedAt')::bigint,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET situacao=excluded.situacao, inicio_semana=excluded.inicio_semana, criada_em_ms=excluded.criada_em_ms, concluida_em_ms=excluded.concluida_em_ms, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_entregas_resumo(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'status', d.situacao,
    'weekStart', d.inicio_semana,
    'createdAt', d.criada_em_ms,
    'completedAt', d.concluida_em_ms
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.entregas_resumo d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_envios_anexos(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.envios_anexos (id_registro,referencia_atividade,nome,tipo_mime,tamanho_bytes,chave_arquivo,id_usuario,criado_em_ms,campos_nulos) VALUES (alvo,objeto->>'activityId',objeto->>'name',objeto->>'contentType',(objeto->>'size')::bigint,objeto->>'key',objeto->>'uid',(objeto->>'createdAt')::bigint,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET referencia_atividade=excluded.referencia_atividade, nome=excluded.nome, tipo_mime=excluded.tipo_mime, tamanho_bytes=excluded.tamanho_bytes, chave_arquivo=excluded.chave_arquivo, id_usuario=excluded.id_usuario, criado_em_ms=excluded.criado_em_ms, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_envios_anexos(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'activityId', d.referencia_atividade,
    'name', d.nome,
    'contentType', d.tipo_mime,
    'size', d.tamanho_bytes,
    'key', d.chave_arquivo,
    'uid', d.id_usuario,
    'createdAt', d.criado_em_ms
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.envios_anexos d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_limites_servico(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.limites_servico (id_registro,quantidade,expira_em_ms,campos_nulos) VALUES (alvo,(objeto->>'count')::integer,(objeto->>'resetAt')::bigint,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET quantidade=excluded.quantidade, expira_em_ms=excluded.expira_em_ms, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_limites_servico(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'count', d.quantidade,
    'resetAt', d.expira_em_ms
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.limites_servico d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.inserir_colunas_kanban(pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.colunas_kanban (id_pai,grupo,ordem,referencia,nome,cor,concluida,campos_nulos) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'name',objeto->>'color',(objeto->>'done')::boolean,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb)) RETURNING id INTO alvo;
END $$;

CREATE FUNCTION tech2d.ler_colunas_kanban(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'name', d.nome,
    'color', d.cor,
    'done', d.concluida
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.colunas_kanban d WHERE d.id=alvo;
$$;

CREATE FUNCTION tech2d.inserir_itens_checklist(pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.itens_checklist (id_pai,grupo,ordem,referencia,descricao,concluido,campos_nulos) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'text',(objeto->>'done')::boolean,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb)) RETURNING id INTO alvo;
END $$;

CREATE FUNCTION tech2d.ler_itens_checklist(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'text', d.descricao,
    'done', d.concluido
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.itens_checklist d WHERE d.id=alvo;
$$;

ALTER TABLE tech2d.cartoes_kanban ADD COLUMN listas_presentes varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[];

CREATE FUNCTION tech2d.inserir_cartoes_kanban(pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.cartoes_kanban (id_pai,grupo,ordem,referencia,referencia_coluna,titulo,descricao,prioridade,prazo,id_responsavel,etiquetas,referencias_atividades,campos_nulos) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'columnId',objeto->>'title',objeto->>'description',objeto->>'priority',(objeto->>'dueDate')::date,objeto->>'assigneeId',CASE WHEN jsonb_typeof(objeto->'labels')='array' THEN ARRAY(SELECT value::varchar(30) FROM jsonb_array_elements_text(objeto->'labels') WITH ORDINALITY AS x(value,pos) ORDER BY pos) END,CASE WHEN jsonb_typeof(objeto->'activityIds')='array' THEN ARRAY(SELECT value::varchar(128) FROM jsonb_array_elements_text(objeto->'activityIds') WITH ORDINALITY AS x(value,pos) ORDER BY pos) END,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb)) RETURNING id INTO alvo;
  DELETE FROM tech2d.itens_checklist WHERE id_pai=alvo AND grupo='checklist';
  IF jsonb_typeof(objeto->'checklist')='array' THEN
    PERFORM tech2d.inserir_itens_checklist(alvo,'checklist',(pos-1)::integer,value)
    FROM jsonb_array_elements(objeto->'checklist') WITH ORDINALITY AS x(value,pos);
  END IF;
  UPDATE tech2d.cartoes_kanban SET listas_presentes=ARRAY(SELECT key FROM jsonb_each(objeto) WHERE key IN ('checklist') AND jsonb_typeof(value)='array') WHERE id=alvo;
END $$;

CREATE FUNCTION tech2d.ler_cartoes_kanban(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
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
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.cartoes_kanban d WHERE d.id=alvo;
$$;

ALTER TABLE tech2d.quadros_kanban ADD COLUMN listas_presentes varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[];

CREATE FUNCTION tech2d.inserir_quadros_kanban(pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE alvo bigint;
BEGIN
  INSERT INTO tech2d.quadros_kanban (id_pai,grupo,ordem,referencia,nome,cor,compacto,campos_nulos) VALUES (pai,campo,posicao,objeto->>'id',objeto->>'name',objeto->>'color',(objeto->>'compact')::boolean,ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb)) RETURNING id INTO alvo;
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
END $$;

CREATE FUNCTION tech2d.ler_quadros_kanban(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'id', d.referencia,
    'name', d.nome,
    'color', d.cor,
    'compact', d.compacto,
    'columns', CASE WHEN 'columns'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_colunas_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.colunas_kanban r WHERE r.id_pai=d.id AND r.grupo='columns') END,
    'tasks', CASE WHEN 'tasks'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_cartoes_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.cartoes_kanban r WHERE r.id_pai=d.id AND r.grupo='tasks') END
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.quadros_kanban d WHERE d.id=alvo;
$$;

ALTER TABLE tech2d.espacos_kanban ADD COLUMN listas_presentes varchar(64)[] NOT NULL DEFAULT ARRAY[]::varchar[];

CREATE FUNCTION tech2d.gravar_espacos_kanban(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.espacos_kanban (id_registro,id_proprietario,versao_formato,criado_em,alterado_em,campos_nulos) VALUES (alvo,objeto->>'ownerId',(objeto->>'schemaVersion')::smallint,objeto->>'createdAt',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET id_proprietario=excluded.id_proprietario, versao_formato=excluded.versao_formato, criado_em=excluded.criado_em, alterado_em=excluded.alterado_em, campos_nulos=excluded.campos_nulos;
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
END $$;

CREATE FUNCTION tech2d.ler_espacos_kanban(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'ownerId', d.id_proprietario,
    'schemaVersion', d.versao_formato,
    'createdAt', d.criado_em,
    'updatedAt', d.alterado_em,
    'boards', CASE WHEN 'boards'=ANY(d.listas_presentes) THEN (SELECT coalesce(jsonb_agg(tech2d.ler_quadros_kanban(r.id) ORDER BY r.ordem),'[]'::jsonb) FROM tech2d.quadros_kanban r WHERE r.id_pai=d.id_registro AND r.grupo='boards') END,
    'board', (SELECT tech2d.ler_quadros_kanban(r.id) FROM tech2d.quadros_kanban r WHERE r.id_pai=d.id_registro AND r.grupo='board' AND r.ordem=0)
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.espacos_kanban d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_participantes_kanban(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.participantes_kanban (id_registro,referencia_quadro,id_usuario,email,nome,criado_em,campos_nulos) VALUES (alvo,objeto->>'boardId',objeto->>'userId',objeto->>'userEmail',objeto->>'name',objeto->>'createdAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET referencia_quadro=excluded.referencia_quadro, id_usuario=excluded.id_usuario, email=excluded.email, nome=excluded.nome, criado_em=excluded.criado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_participantes_kanban(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'boardId', d.referencia_quadro,
    'userId', d.id_usuario,
    'userEmail', d.email,
    'name', d.nome,
    'createdAt', d.criado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.participantes_kanban d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_pedidos_kanban(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.pedidos_kanban (id_registro,referencia_quadro,id_usuario,email,nome,criado_em,situacao,alterado_em,campos_nulos) VALUES (alvo,objeto->>'boardId',objeto->>'userId',objeto->>'userEmail',objeto->>'name',objeto->>'createdAt',objeto->>'status',objeto->>'updatedAt',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET referencia_quadro=excluded.referencia_quadro, id_usuario=excluded.id_usuario, email=excluded.email, nome=excluded.nome, criado_em=excluded.criado_em, situacao=excluded.situacao, alterado_em=excluded.alterado_em, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_pedidos_kanban(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'boardId', d.referencia_quadro,
    'userId', d.id_usuario,
    'userEmail', d.email,
    'name', d.nome,
    'createdAt', d.criado_em,
    'status', d.situacao,
    'updatedAt', d.alterado_em
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.pedidos_kanban d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_limpeza_anexos_kanban(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.limpeza_anexos_kanban (id_registro,referencia_espaco,referencia_quadro,referencia_cartao,campos_nulos) VALUES (alvo,objeto->>'path',objeto->>'board',objeto->>'task',ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb))
  ON CONFLICT(id_registro) DO UPDATE SET referencia_espaco=excluded.referencia_espaco, referencia_quadro=excluded.referencia_quadro, referencia_cartao=excluded.referencia_cartao, campos_nulos=excluded.campos_nulos;
END $$;

CREATE FUNCTION tech2d.ler_limpeza_anexos_kanban(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object(
    'path', d.referencia_espaco,
    'board', d.referencia_quadro,
    'task', d.referencia_cartao
  )) || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(d.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.limpeza_anexos_kanban d WHERE d.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.gravar_horarios_aula(alvo bigint, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
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

  INSERT INTO tech2d.horarios_aula(id,id_registro,id_professor,id_disciplina,id_turma,id_faixa_horario,dia_semana,ativo,andar,sala,criado_em,alterado_em,campos_nulos)
  SELECT chave,alvo,p.id,d.id,t.id,f.id,(objeto->>'dayOfWeek')::smallint,(objeto->>'active')::boolean,
    objeto->>'floor',objeto->>'roomDescription',objeto->>'createdAt',objeto->>'updatedAt',
    ARRAY(SELECT key FROM jsonb_each(objeto) WHERE value='null'::jsonb)
  FROM tech2d.professores p,tech2d.disciplinas d,tech2d.turmas t,tech2d.faixas_horario f
  WHERE p.nome=objeto->>'professor' AND d.nome=objeto->>'subject' AND t.nome=objeto->>'className'
    AND f.hora_inicio=inicio AND f.hora_fim=fim
  ON CONFLICT(id) DO UPDATE SET id_registro=excluded.id_registro,id_professor=excluded.id_professor,
    id_disciplina=excluded.id_disciplina,id_turma=excluded.id_turma,id_faixa_horario=excluded.id_faixa_horario,
    dia_semana=excluded.dia_semana,ativo=excluded.ativo,andar=excluded.andar,sala=excluded.sala,
    criado_em=excluded.criado_em,alterado_em=excluded.alterado_em,campos_nulos=excluded.campos_nulos;
END $$;
CREATE FUNCTION tech2d.ler_horarios_aula(alvo bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT tech2d.remover_nulos_raiz(jsonb_build_object('professor',p.nome,'subject',d.nome,'className',t.nome,
    'startTime',to_char(f.hora_inicio,'HH24:MI'),'endTime',to_char(f.hora_fim,'HH24:MI'),'dayOfWeek',h.dia_semana,
    'active',h.ativo,'floor',h.andar,'roomDescription',h.sala,'createdAt',h.criado_em,'updatedAt',h.alterado_em))
    || coalesce((SELECT jsonb_object_agg(k,'null'::jsonb) FROM unnest(h.campos_nulos) k),'{}'::jsonb)
  FROM tech2d.horarios_aula h
  JOIN tech2d.professores p ON p.id=h.id_professor JOIN tech2d.disciplinas d ON d.id=h.id_disciplina
  JOIN tech2d.turmas t ON t.id=h.id_turma JOIN tech2d.faixas_horario f ON f.id=h.id_faixa_horario
  WHERE h.id_registro=alvo;
$$;

CREATE FUNCTION tech2d.ler_registro(alvo bigint, tipo varchar) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
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
    WHEN 'polls' THEN tech2d.ler_enquetes(alvo)
    WHEN 'polls/votes' THEN tech2d.ler_votos_enquete(alvo)
    WHEN 'pollVoterAccess' THEN tech2d.ler_acessos_votacao(alvo)
    WHEN 'suggestions' THEN tech2d.ler_sugestoes_atividade(alvo)
    WHEN 'feedback' THEN tech2d.ler_sugestoes_melhoria(alvo)
    WHEN 'feedback/messages' THEN tech2d.ler_mensagens_sugestao(alvo)
    WHEN 'announcement' THEN tech2d.ler_anuncios(alvo)
    WHEN 'agendaUpdates' THEN tech2d.ler_atualizacoes_agenda(alvo)
    WHEN 'boardNotices' THEN tech2d.ler_avisos_turma(alvo)
    WHEN 'schedules' THEN tech2d.ler_horarios_aula(alvo)
    WHEN 'notebookNotes' THEN tech2d.ler_anotacoes(alvo)
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
$$;
CREATE FUNCTION tech2d.gravar_conteudo(alvo bigint, tipo varchar, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF jsonb_typeof(objeto) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Objeto de registro inválido' USING ERRCODE='check_violation';
  END IF;
  CASE tipo
    WHEN 'activities' THEN PERFORM tech2d.gravar_atividades(alvo,objeto);    WHEN 'admins' THEN PERFORM tech2d.gravar_perfis_administrativos(alvo,objeto);    WHEN 'recurringActivities' THEN PERFORM tech2d.gravar_regras_recorrencia(alvo,objeto);    WHEN 'activityRetention' THEN PERFORM tech2d.gravar_regras_retencao(alvo,objeto);    WHEN 'agendaClassRequests' THEN PERFORM tech2d.gravar_pedidos_agenda(alvo,objeto);    WHEN 'agendaClasses' THEN PERFORM tech2d.gravar_turmas_agenda(alvo,objeto);    WHEN 'representativeRequests' THEN PERFORM tech2d.gravar_pedidos_representacao(alvo,objeto);    WHEN 'representativeInvites' THEN PERFORM tech2d.gravar_convites_representacao(alvo,objeto);    WHEN 'representativeChat' THEN PERFORM tech2d.gravar_chat_representantes(alvo,objeto);    WHEN 'polls' THEN PERFORM tech2d.gravar_enquetes(alvo,objeto);    WHEN 'polls/votes' THEN PERFORM tech2d.gravar_votos_enquete(alvo,objeto);    WHEN 'pollVoterAccess' THEN PERFORM tech2d.gravar_acessos_votacao(alvo,objeto);    WHEN 'suggestions' THEN PERFORM tech2d.gravar_sugestoes_atividade(alvo,objeto);    WHEN 'feedback' THEN PERFORM tech2d.gravar_sugestoes_melhoria(alvo,objeto);    WHEN 'feedback/messages' THEN PERFORM tech2d.gravar_mensagens_sugestao(alvo,objeto);    WHEN 'announcement' THEN PERFORM tech2d.gravar_anuncios(alvo,objeto);    WHEN 'agendaUpdates' THEN PERFORM tech2d.gravar_atualizacoes_agenda(alvo,objeto);    WHEN 'boardNotices' THEN PERFORM tech2d.gravar_avisos_turma(alvo,objeto);    WHEN 'schedules' THEN PERFORM tech2d.gravar_horarios_aula(alvo,objeto);    WHEN 'notebookNotes' THEN PERFORM tech2d.gravar_anotacoes(alvo,objeto);    WHEN 'userProfiles' THEN PERFORM tech2d.gravar_perfis_comunidade(alvo,objeto);    WHEN 'purgedActivities' THEN PERFORM tech2d.gravar_atividades_arquivadas(alvo,objeto);    WHEN '_agendaDigestPreferences' THEN PERFORM tech2d.gravar_preferencias_resumo(alvo,objeto);    WHEN '_agendaDigestDeliveries' THEN PERFORM tech2d.gravar_entregas_resumo(alvo,objeto);    WHEN '_agendaUploads' THEN PERFORM tech2d.gravar_envios_anexos(alvo,objeto);    WHEN '_passwordResetLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);    WHEN '_r2UploadLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);    WHEN '_profilePhotoLimits' THEN PERFORM tech2d.gravar_limites_servico(alvo,objeto);    WHEN 'personalKanban' THEN PERFORM tech2d.gravar_espacos_kanban(alvo,objeto);    WHEN 'sharedKanban' THEN PERFORM tech2d.gravar_espacos_kanban(alvo,objeto);    WHEN 'kanbanMemberships' THEN PERFORM tech2d.gravar_participantes_kanban(alvo,objeto);    WHEN 'kanbanRequests' THEN PERFORM tech2d.gravar_pedidos_kanban(alvo,objeto);    WHEN '_kanbanFileCleanup' THEN PERFORM tech2d.gravar_limpeza_anexos_kanban(alvo,objeto);
    ELSE RAISE EXCEPTION 'Tipo de registro desconhecido' USING ERRCODE='check_violation';
  END CASE;
  IF tech2d.ler_registro(alvo,tipo) IS DISTINCT FROM objeto THEN
    RAISE EXCEPTION 'Registro incompatível com as colunas de %',tipo USING ERRCODE='check_violation';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION tech2d.gravar_registros(lote jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
      IF pai='' AND grupo IN ('polls','feedback') THEN
        UPDATE tech2d.registros_aplicacao SET id_pai=alvo
        WHERE tipo=grupo || CASE WHEN grupo='polls' THEN '/votes' ELSE '/messages' END
          AND referencia_pai=chave AND id_pai IS NULL;
      END IF;
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION tech2d.enfileirar_limpeza_kanban(lote jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  item jsonb;
  chave varchar(320);
BEGIN
  FOR item IN SELECT value FROM jsonb_array_elements(lote) LOOP
    chave := md5(item::text);
    IF NOT EXISTS (SELECT FROM tech2d.registros_aplicacao WHERE tipo='_kanbanFileCleanup' AND referencia=chave AND referencia_pai='') THEN
      PERFORM tech2d.gravar_registros(jsonb_build_array(jsonb_build_object('path','_kanbanFileCleanup/'||chave,'data',item)));
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION tech2d.adiar_limpeza_kanban(chave text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  UPDATE tech2d.registros_aplicacao SET atualizado_em=now()
  WHERE tipo='_kanbanFileCleanup' AND referencia_pai='' AND tech2d.referencia_api(tipo,referencia_pai,referencia)=chave;
$$;

CREATE VIEW tech2d.visao_documentos_aplicacao AS
SELECT tech2d.referencia_api(tipo,referencia_pai,referencia) AS path,
  CASE WHEN referencia_pai='' THEN tipo ELSE split_part(tipo,'/',1)||'/'||referencia_pai||'/'||split_part(tipo,'/',2) END AS collection,
  referencia AS id,tech2d.ler_registro(id,tipo) AS data,versao AS version,atualizado_em AS updated_at
FROM tech2d.registros_aplicacao;
COMMENT ON VIEW tech2d.visao_documentos_aplicacao IS 'Contrato de leitura da API. Reconstrói os objetos a partir das tabelas tipadas.';
CREATE VIEW tech2d.visao_perfis_administrativos AS
SELECT r.referencia AS uid,p.papel AS role,p.turma AS turma_id,tech2d.ler_registro(r.id,r.tipo) AS data
FROM tech2d.perfis_administrativos p JOIN tech2d.registros_aplicacao r ON r.id=p.id_registro;
CREATE VIEW tech2d.visao_atividades AS
SELECT r.referencia AS id,a.turma AS turma_id,a.titulo AS title,coalesce(a.descricao,'') AS description,
  a.tipo AS type,a.disciplina AS subject,a.data::varchar(10) AS date,to_char(a.hora,'HH24:MI') AS time,
  a.criado_por AS created_by,a.email_criador AS created_by_email,a.referencia_recorrencia AS recurring_id,
  coalesce((SELECT jsonb_agg(tech2d.ler_anexos_atividade(f.id) ORDER BY f.ordem)
    FROM tech2d.anexos_atividade f WHERE f.id_pai=r.id),'[]'::jsonb) AS attachments,
  a.criado_em::timestamptz AS created_at,a.alterado_em::timestamptz AS updated_at,r.versao AS version
FROM tech2d.atividades a JOIN tech2d.registros_aplicacao r ON r.id=a.id_registro;
CREATE VIEW tech2d.catalogo_horarios AS
SELECT h.id,h.dia_semana,h.ativo,t.nome AS nome_turma,tech2d.ler_registro(h.id_registro,'schedules') AS dados
FROM tech2d.horarios_aula h JOIN tech2d.turmas t ON t.id=h.id_turma;
CREATE VIEW tech2d.visao_catalogo_horarios AS
SELECT id,dia_semana AS day_of_week,ativo AS active,nome_turma AS class_name,dados AS data FROM tech2d.catalogo_horarios;
CREATE VIEW tech2d.visao_documentos_catalogo AS
SELECT tipo AS collection,referencia AS id,tech2d.ler_registro(id,tipo) AS data
FROM tech2d.registros_aplicacao WHERE tipo IN ('schedules','agendaClasses','agendaUpdates','announcement','boardNotices','polls');
COMMENT ON VIEW tech2d.visao_documentos_catalogo IS 'Catálogo calculado a partir das tabelas tipadas.';

COMMENT ON VIEW tech2d.visao_atividades IS 'Atividades com seus anexos, para o calendário e os links diretos.';
COMMENT ON VIEW tech2d.visao_perfis_administrativos IS 'Papéis e turmas administrativas no formato consumido pela API.';
COMMENT ON VIEW tech2d.catalogo_horarios IS 'Reúne professor, disciplina, turma, faixa de horário, andar e sala.';
COMMENT ON VIEW tech2d.visao_catalogo_horarios IS 'Apelidos de colunas usados pela API do Cadê o professor.';
CREATE TEMP TABLE normalizacao_entrada (
  caminho varchar(512) PRIMARY KEY, dados jsonb NOT NULL, versao bigint NOT NULL, atualizado_em timestamptz NOT NULL
) ON COMMIT DROP;
INSERT INTO pg_temp.normalizacao_entrada SELECT caminho,dados,versao,atualizado_em FROM tech2d.documentos_anteriores;
INSERT INTO pg_temp.normalizacao_entrada
SELECT 'activities/'||a.id,jsonb_build_object('title',titulo,'description',descricao,'type',tipo,'subject',disciplina,'date',data,'time',hora,
  'turmaId',id_turma,'createdBy',criado_por,'createdByEmail',email_criador,'recurringId',id_recorrencia,'attachments',anexos,
  'createdAt',to_char(criado_em AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'updatedAt',to_char(atualizado_em AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')),versao,coalesce(atualizado_em,now())
FROM tech2d.atividades_anteriores a ON CONFLICT(caminho) DO NOTHING;
INSERT INTO pg_temp.normalizacao_entrada
SELECT 'admins/'||id_usuario,dados || jsonb_strip_nulls(jsonb_build_object('role',papel,'turmaId',id_turma)),1,now()
FROM tech2d.perfis_anteriores ON CONFLICT(caminho) DO NOTHING;
INSERT INTO pg_temp.normalizacao_entrada
SELECT c.colecao||'/'||c.id,
  CASE WHEN c.colecao='schedules' THEN c.dados || jsonb_build_object('professor',p.nome,'subject',d.nome,'className',t.nome,
    'startTime',to_char(f.hora_inicio,'HH24:MI'),'endTime',to_char(f.hora_fim,'HH24:MI'),'dayOfWeek',h.dia_semana,'active',h.ativo)
    ELSE c.dados END,1,now()
FROM tech2d.catalogos_anteriores c
LEFT JOIN tech2d.horarios_aula h ON c.colecao='schedules' AND h.id=c.id
LEFT JOIN tech2d.professores p ON p.id=h.id_professor LEFT JOIN tech2d.disciplinas d ON d.id=h.id_disciplina
LEFT JOIN tech2d.turmas t ON t.id=h.id_turma LEFT JOIN tech2d.faixas_horario f ON f.id=h.id_faixa_horario
ON CONFLICT(caminho) DO NOTHING;

-- Refuse a cutover if a projection disagrees with its source in a user-facing field.
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM tech2d.atividades_anteriores a JOIN pg_temp.normalizacao_entrada d ON d.caminho='activities/'||a.id
    WHERE ROW(a.titulo,a.descricao,a.tipo,a.disciplina,a.data,a.hora,a.id_turma,a.criado_por,a.email_criador,a.id_recorrencia,
      a.anexos,a.criado_em,a.atualizado_em)
      IS DISTINCT FROM ROW(d.dados->>'title',coalesce(d.dados->>'description',''),d.dados->>'type',d.dados->>'subject',d.dados->>'date',
        d.dados->>'time',d.dados->>'turmaId',d.dados->>'createdBy',d.dados->>'createdByEmail',d.dados->>'recurringId',
        coalesce(d.dados->'attachments','[]'::jsonb),(d.dados->>'createdAt')::timestamptz,(d.dados->>'updatedAt')::timestamptz)
  ) OR EXISTS (
    SELECT FROM tech2d.perfis_anteriores a JOIN pg_temp.normalizacao_entrada d ON d.caminho='admins/'||a.id_usuario
    WHERE ROW(a.papel,a.id_turma) IS DISTINCT FROM ROW(d.dados->>'role',d.dados->>'turmaId')
  ) OR EXISTS (
    SELECT FROM tech2d.catalogos_anteriores c JOIN pg_temp.normalizacao_entrada d ON d.caminho=c.colecao||'/'||c.id
    WHERE c.colecao<>'schedules' AND c.dados IS DISTINCT FROM d.dados
  ) OR EXISTS (
    SELECT FROM tech2d.catalogos_anteriores c JOIN pg_temp.normalizacao_entrada d ON d.caminho='schedules/'||c.id
    JOIN tech2d.horarios_aula h ON h.id=c.id
    JOIN tech2d.professores p ON p.id=h.id_professor JOIN tech2d.disciplinas ds ON ds.id=h.id_disciplina
    JOIN tech2d.turmas t ON t.id=h.id_turma JOIN tech2d.faixas_horario f ON f.id=h.id_faixa_horario
    WHERE c.colecao='schedules' AND (
      ROW(p.nome,ds.nome,t.nome,to_char(f.hora_inicio,'HH24:MI'),to_char(f.hora_fim,'HH24:MI'),h.dia_semana,h.ativo)
      IS DISTINCT FROM ROW(d.dados->>'professor',d.dados->>'subject',d.dados->>'className',d.dados->>'startTime',d.dados->>'endTime',
        (d.dados->>'dayOfWeek')::smallint,(d.dados->>'active')::boolean)
      OR c.dados->'floor' IS DISTINCT FROM d.dados->'floor'
      OR c.dados->'roomDescription' IS DISTINCT FROM d.dados->'roomDescription'
    )
  ) THEN RAISE EXCEPTION 'Divergência entre registros e projeções'; END IF;
END $$;

SELECT tech2d.gravar_registros(jsonb_agg(jsonb_build_object('path',caminho,'data',dados)))
FROM pg_temp.normalizacao_entrada;
UPDATE tech2d.registros_aplicacao r SET versao=e.versao,atualizado_em=e.atualizado_em
FROM pg_temp.normalizacao_entrada e WHERE tech2d.referencia_api(r.tipo,r.referencia_pai,r.referencia)=e.caminho;
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_temp.normalizacao_entrada e FULL JOIN tech2d.visao_documentos_aplicacao v ON e.caminho=v.path
    WHERE e.caminho IS NULL OR v.path IS NULL OR e.dados IS DISTINCT FROM v.data OR e.versao IS DISTINCT FROM v.version
      OR e.atualizado_em IS DISTINCT FROM v.updated_at) THEN RAISE EXCEPTION 'Falha na conferência da normalização'; END IF;
END $$;
ALTER TABLE tech2d.horarios_aula ALTER COLUMN id_registro SET NOT NULL;
DROP TABLE tech2d.documentos_anteriores,tech2d.atividades_anteriores,tech2d.catalogos_anteriores,tech2d.perfis_anteriores;
DROP FUNCTION tech2d.sync_school_schedule();

-- Histories can describe any business entity and must survive its deletion.
-- A row per node preserves structure, nulls, array order and scalar types.
CREATE TABLE tech2d.valores_historico (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_auditoria bigint REFERENCES tech2d.auditoria_aplicacao(sequencia) ON DELETE CASCADE,
  id_auditoria_legada bigint REFERENCES tech2d.auditoria_atividades_legada(sequencia) ON DELETE CASCADE,
  id_revisao bigint REFERENCES tech2d.revisoes_origem(sequencia) ON DELETE CASCADE,
  id_pai bigint REFERENCES tech2d.valores_historico(id) ON DELETE CASCADE,
  chave varchar(1024),
  ordem integer NOT NULL CHECK (ordem >= 0),
  tipo varchar(12) NOT NULL CHECK (tipo IN ('object','array','null','string','number','boolean')),
  valor_textual varchar(1048576),
  valor_numerico numeric,
  valor_logico boolean,
  CHECK (num_nonnulls(id_auditoria,id_auditoria_legada,id_revisao)=1),
  CHECK (num_nonnulls(valor_textual,valor_numerico,valor_logico)
    = CASE WHEN tipo IN ('string','number','boolean') THEN 1 ELSE 0 END),
  CHECK ((valor_textual IS NOT NULL)=(tipo='string') AND
    (valor_numerico IS NOT NULL)=(tipo='number') AND (valor_logico IS NOT NULL)=(tipo='boolean'))
);
CREATE INDEX valores_historico_pai ON tech2d.valores_historico(id_pai,ordem);
CREATE INDEX valores_historico_auditoria ON tech2d.valores_historico(id_auditoria) WHERE id_pai IS NULL;
CREATE INDEX valores_historico_legado ON tech2d.valores_historico(id_auditoria_legada) WHERE id_pai IS NULL;
CREATE INDEX valores_historico_revisao ON tech2d.valores_historico(id_revisao) WHERE id_pai IS NULL;
COMMENT ON TABLE tech2d.valores_historico IS 'Campos tipados das versões históricas, ligados à auditoria ou revisão e preservados após a exclusão do registro original.';

CREATE FUNCTION tech2d.gravar_valor_historico(auditoria bigint, legado bigint, revisao bigint,
  pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE
  forma varchar(12) := jsonb_typeof(objeto);
  alvo bigint;
BEGIN
  IF objeto IS NULL THEN RETURN; END IF;
  INSERT INTO tech2d.valores_historico(id_auditoria,id_auditoria_legada,id_revisao,id_pai,chave,ordem,tipo,
    valor_textual,valor_numerico,valor_logico)
  VALUES(auditoria,legado,revisao,pai,campo,posicao,forma,
    CASE WHEN forma='string' THEN objeto#>>'{}' END,
    CASE WHEN forma='number' THEN (objeto#>>'{}')::numeric END,
    CASE WHEN forma='boolean' THEN (objeto#>>'{}')::boolean END)
  RETURNING id INTO alvo;
  IF forma='object' THEN
    PERFORM tech2d.gravar_valor_historico(auditoria,legado,revisao,alvo,key,0,value) FROM jsonb_each(objeto);
  ELSIF forma='array' THEN
    PERFORM tech2d.gravar_valor_historico(auditoria,legado,revisao,alvo,NULL,(ord-1)::integer,value)
    FROM jsonb_array_elements(objeto) WITH ORDINALITY a(value,ord);
  END IF;
END $$;

CREATE FUNCTION tech2d.ler_valor_historico(alvo bigint) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE item tech2d.valores_historico%ROWTYPE;
BEGIN
  SELECT * INTO item FROM tech2d.valores_historico WHERE id=alvo;
  CASE item.tipo
    WHEN 'string' THEN RETURN to_jsonb(item.valor_textual);
    WHEN 'number' THEN RETURN to_jsonb(item.valor_numerico);
    WHEN 'boolean' THEN RETURN to_jsonb(item.valor_logico);
    WHEN 'null' THEN RETURN 'null'::jsonb;
    WHEN 'array' THEN RETURN (SELECT coalesce(jsonb_agg(tech2d.ler_valor_historico(v.id) ORDER BY v.ordem),'[]'::jsonb)
      FROM tech2d.valores_historico v WHERE v.id_pai=alvo);
    WHEN 'object' THEN RETURN (SELECT coalesce(jsonb_object_agg(v.chave,tech2d.ler_valor_historico(v.id)),'{}'::jsonb)
      FROM tech2d.valores_historico v WHERE v.id_pai=alvo);
    ELSE RETURN NULL;
  END CASE;
END $$;

SELECT tech2d.gravar_valor_historico(sequencia,NULL,NULL,NULL,NULL,0,dados_anteriores) FROM tech2d.auditoria_aplicacao;
SELECT tech2d.gravar_valor_historico(NULL,sequencia,NULL,NULL,NULL,0,dados_anteriores) FROM tech2d.auditoria_atividades_legada;
SELECT tech2d.gravar_valor_historico(NULL,NULL,sequencia,NULL,NULL,0,campos) FROM tech2d.revisoes_origem;
DO $$
BEGIN
  IF EXISTS (SELECT FROM tech2d.auditoria_aplicacao a LEFT JOIN tech2d.valores_historico v
    ON v.id_auditoria=a.sequencia AND v.id_pai IS NULL WHERE a.dados_anteriores IS DISTINCT FROM tech2d.ler_valor_historico(v.id))
  OR EXISTS (SELECT FROM tech2d.auditoria_atividades_legada a LEFT JOIN tech2d.valores_historico v
    ON v.id_auditoria_legada=a.sequencia AND v.id_pai IS NULL WHERE a.dados_anteriores IS DISTINCT FROM tech2d.ler_valor_historico(v.id))
  OR EXISTS (SELECT FROM tech2d.revisoes_origem a LEFT JOIN tech2d.valores_historico v
    ON v.id_revisao=a.sequencia AND v.id_pai IS NULL WHERE a.campos IS DISTINCT FROM tech2d.ler_valor_historico(v.id)) THEN
    RAISE EXCEPTION 'Falha na conferência do histórico';
  END IF;
END $$;

DROP VIEW tech2d.visao_auditoria_aplicacao, tech2d.visao_auditoria_atividades_legada, tech2d.visao_revisoes_origem;
ALTER TABLE tech2d.auditoria_aplicacao DROP COLUMN dados_anteriores;
ALTER TABLE tech2d.auditoria_atividades_legada DROP COLUMN dados_anteriores;
ALTER TABLE tech2d.revisoes_origem DROP COLUMN campos;
CREATE VIEW tech2d.visao_auditoria_aplicacao AS
SELECT a.sequencia AS sequence,a.autor AS actor,a.caminho AS path,a.operacao AS operation,
  tech2d.ler_valor_historico(v.id) AS previous_data,a.alterado_em AS changed_at
FROM tech2d.auditoria_aplicacao a LEFT JOIN tech2d.valores_historico v ON v.id_auditoria=a.sequencia AND v.id_pai IS NULL;
CREATE VIEW tech2d.visao_auditoria_atividades_legada AS
SELECT a.sequencia AS sequence,a.id_atividade AS activity_id,a.id_usuario AS actor_uid,a.acao AS action,
  tech2d.ler_valor_historico(v.id) AS previous_data,a.alterado_em AS changed_at
FROM tech2d.auditoria_atividades_legada a LEFT JOIN tech2d.valores_historico v ON v.id_auditoria_legada=a.sequencia AND v.id_pai IS NULL;
CREATE VIEW tech2d.visao_revisoes_origem AS
SELECT a.sequencia AS sequence,a.id_projeto AS project_id,a.caminho AS path,tech2d.ler_valor_historico(v.id) AS fields,
  a.atualizado_na_origem_em AS source_updated_at,a.motivo AS reason,a.salvo_em AS saved_at
FROM tech2d.revisoes_origem a LEFT JOIN tech2d.valores_historico v ON v.id_revisao=a.sequencia AND v.id_pai IS NULL;

CREATE FUNCTION tech2d.inserir_auditoria() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.auditoria_aplicacao(autor,caminho,operacao,alterado_em)
  VALUES(NEW.actor,NEW.path,NEW.operation,coalesce(NEW.changed_at,now())) RETURNING sequencia INTO NEW.sequence;
  PERFORM tech2d.gravar_valor_historico(NEW.sequence,NULL,NULL,NULL,NULL,0,NEW.previous_data);
  RETURN NEW;
END $$;
CREATE TRIGGER gravar_auditoria INSTEAD OF INSERT ON tech2d.visao_auditoria_aplicacao
FOR EACH ROW EXECUTE FUNCTION tech2d.inserir_auditoria();
CREATE FUNCTION tech2d.inserir_auditoria_legada() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.auditoria_atividades_legada(id_atividade,id_usuario,acao,alterado_em)
  VALUES(NEW.activity_id,NEW.actor_uid,NEW.action,coalesce(NEW.changed_at,now())) RETURNING sequencia INTO NEW.sequence;
  PERFORM tech2d.gravar_valor_historico(NULL,NEW.sequence,NULL,NULL,NULL,0,NEW.previous_data);
  RETURN NEW;
END $$;
CREATE TRIGGER gravar_auditoria_legada INSTEAD OF INSERT ON tech2d.visao_auditoria_atividades_legada
FOR EACH ROW EXECUTE FUNCTION tech2d.inserir_auditoria_legada();

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA tech2d FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname='tech2d_api') THEN
    GRANT SELECT ON tech2d.visao_documentos_aplicacao,tech2d.visao_atividades,
      tech2d.visao_perfis_administrativos,tech2d.visao_documentos_catalogo,
      tech2d.catalogo_horarios,tech2d.visao_catalogo_horarios TO tech2d_api;
    GRANT INSERT ON tech2d.visao_auditoria_aplicacao,tech2d.visao_auditoria_atividades_legada TO tech2d_api;
    GRANT EXECUTE ON FUNCTION tech2d.referencia_api(varchar,varchar,varchar),tech2d.ler_registro(bigint,varchar),
      tech2d.ler_anexos_atividade(bigint),tech2d.remover_nulos_raiz(jsonb) TO tech2d_api;
    REVOKE INSERT ON tech2d.auditoria_aplicacao,tech2d.auditoria_atividades_legada FROM tech2d_api;
  END IF;
  IF EXISTS (SELECT FROM information_schema.columns c JOIN information_schema.tables t USING(table_schema,table_name)
    WHERE c.table_schema='tech2d' AND t.table_type='BASE TABLE' AND c.data_type IN ('json','jsonb')) THEN
    RAISE EXCEPTION 'Ainda há colunas JSON nas tabelas da aplicação';
  END IF;
END $$;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:020_normalizar_dados';

