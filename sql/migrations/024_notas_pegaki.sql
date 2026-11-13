-- Notas privadas do Pegaki, organizadas para cálculos e análise futura.
CREATE TABLE tech2d.pegaki_disciplinas (
  id smallint PRIMARY KEY, ano_serie smallint NOT NULL CHECK (ano_serie BETWEEN 1 AND 3), nome varchar(160) NOT NULL,
  UNIQUE(id,ano_serie), UNIQUE(ano_serie,nome)
);
CREATE TABLE tech2d.pegaki_cadernos (
  id_usuario varchar(128) NOT NULL, ano_letivo smallint NOT NULL CHECK (ano_letivo BETWEEN 2020 AND 2100),
  ano_serie smallint NOT NULL CHECK (ano_serie BETWEEN 1 AND 3),
  modo_primeiro varchar(5) NOT NULL CHECK (modo_primeiro IN ('notas','media')),
  modo_segundo varchar(5) NOT NULL CHECK (modo_segundo IN ('notas','media')),
  versao bigint NOT NULL DEFAULT 0 CHECK (versao>=0), regra_calculo varchar(32) NOT NULL DEFAULT 'tech-2026-v1',
  criado_em timestamptz NOT NULL DEFAULT now(), alterado_em timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(id_usuario,ano_letivo), UNIQUE(id_usuario,ano_letivo,ano_serie)
);
CREATE TABLE tech2d.pegaki_notas (
  id_usuario varchar(128) NOT NULL, ano_letivo smallint NOT NULL, ano_serie smallint NOT NULL, id_disciplina smallint NOT NULL,
  semestre smallint NOT NULL CHECK (semestre IN (1,2)),
  n1 numeric(4,2) CHECK(n1 BETWEEN 0 AND 10), n2 numeric(4,2) CHECK(n2 BETWEEN 0 AND 10),
  media_informada numeric(4,2) CHECK(media_informada BETWEEN 0 AND 10),
  peso_n1 smallint NOT NULL DEFAULT 50 CHECK(peso_n1 BETWEEN 10 AND 90 AND peso_n1%5=0),
  PRIMARY KEY(id_usuario,ano_letivo,id_disciplina,semestre),
  FOREIGN KEY(id_usuario,ano_letivo,ano_serie) REFERENCES tech2d.pegaki_cadernos(id_usuario,ano_letivo,ano_serie) ON DELETE CASCADE,
  FOREIGN KEY(id_disciplina,ano_serie) REFERENCES tech2d.pegaki_disciplinas(id,ano_serie)
);
CREATE TABLE tech2d.pegaki_recuperacoes (
  id_usuario varchar(128) NOT NULL, ano_letivo smallint NOT NULL, ano_serie smallint NOT NULL, id_disciplina smallint NOT NULL,
  nota numeric(4,2) CHECK(nota BETWEEN 0 AND 10), PRIMARY KEY(id_usuario,ano_letivo,id_disciplina),
  FOREIGN KEY(id_usuario,ano_letivo,ano_serie) REFERENCES tech2d.pegaki_cadernos(id_usuario,ano_letivo,ano_serie) ON DELETE CASCADE,
  FOREIGN KEY(id_disciplina,ano_serie) REFERENCES tech2d.pegaki_disciplinas(id,ano_serie)
);

CREATE VIEW tech2d.visao_pegaki_resultados WITH (security_invoker=true) AS
WITH semestres AS (
 SELECT c.id_usuario,c.ano_letivo,c.ano_serie,c.regra_calculo,c.versao,d.id AS id_disciplina,d.nome,
 CASE WHEN c.modo_primeiro='media' THEN p.media_informada ELSE round((p.n1*p.peso_n1+p.n2*(100-p.peso_n1))/100,2) END AS media_primeiro,
 CASE WHEN c.modo_segundo='media' THEN s.media_informada ELSE round((s.n1*s.peso_n1+s.n2*(100-s.peso_n1))/100,2) END AS media_segundo,
 r.nota AS recuperacao_final
 FROM tech2d.pegaki_cadernos c JOIN tech2d.pegaki_disciplinas d USING(ano_serie)
 LEFT JOIN tech2d.pegaki_notas p ON p.id_usuario=c.id_usuario AND p.ano_letivo=c.ano_letivo AND p.id_disciplina=d.id AND p.semestre=1
 LEFT JOIN tech2d.pegaki_notas s ON s.id_usuario=c.id_usuario AND s.ano_letivo=c.ano_letivo AND s.id_disciplina=d.id AND s.semestre=2
 LEFT JOIN tech2d.pegaki_recuperacoes r ON r.id_usuario=c.id_usuario AND r.ano_letivo=c.ano_letivo AND r.id_disciplina=d.id
), recuperadas AS (
 SELECT *, CASE WHEN media_segundo>coalesce(media_primeiro,0) AND round(least((coalesce(media_primeiro,0)+media_segundo)/2,7),2)>coalesce(media_primeiro,0)
 THEN round(least((coalesce(media_primeiro,0)+media_segundo)/2,7),2) END AS media_recuperada FROM semestres
), anuais AS (
 SELECT *,CASE WHEN media_segundo IS NULL THEN media_primeiro ELSE round((coalesce(media_recuperada,media_primeiro,0)+media_segundo*2)/3,2) END AS media_anual FROM recuperadas
)
SELECT *,CASE WHEN media_segundo IS NOT NULL AND media_anual<7 THEN greatest(0,12-media_anual) END AS nota_necessaria,
 CASE WHEN media_segundo IS NOT NULL AND media_anual<7 AND recuperacao_final IS NOT NULL THEN round((media_anual+recuperacao_final)/2,2) END AS media_final,
 CASE WHEN media_primeiro IS NULL AND media_segundo IS NULL THEN 'sem-notas' WHEN media_segundo IS NULL THEN 'andamento'
 WHEN media_anual>=7 THEN 'aprovado' WHEN recuperacao_final IS NULL THEN 'recuperacao'
 WHEN round((media_anual+recuperacao_final)/2,2)>=6 THEN 'aprovado-rec' ELSE 'reprovado' END AS situacao FROM anuais;

COMMENT ON TABLE tech2d.pegaki_disciplinas IS 'Catálogo de disciplinas por série; IDs estáveis para as notas e futuras análises.';
COMMENT ON TABLE tech2d.pegaki_cadernos IS 'Caderno privado da conta Firebase por ano letivo, série, modos de entrada e versão otimista.';
COMMENT ON TABLE tech2d.pegaki_notas IS 'Notas N1/N2, média informada e pesos por disciplina e semestre. Nota vazia é NULL.';
COMMENT ON TABLE tech2d.pegaki_recuperacoes IS 'Nota de recuperação final por conta, ano letivo e disciplina.';
COMMENT ON VIEW tech2d.visao_pegaki_resultados IS 'Médias e situação pela regra tech-2026-v1, protegidas por RLS; preparadas para análises autenticadas e futura IA.';
COMMENT ON COLUMN tech2d.pegaki_cadernos.id_usuario IS 'UID validado no Firebase Authentication, nunca escolhido pelo cliente.';
COMMENT ON COLUMN tech2d.pegaki_cadernos.regra_calculo IS 'Versão da fórmula, para rastreabilidade dos cálculos.';
COMMENT ON COLUMN tech2d.pegaki_cadernos.versao IS 'Versão usada para impedir sobrescrita por outra aba ou dispositivo.';
ALTER TABLE tech2d.pegaki_cadernos ENABLE ROW LEVEL SECURITY;
ALTER TABLE tech2d.pegaki_notas ENABLE ROW LEVEL SECURITY;
ALTER TABLE tech2d.pegaki_recuperacoes ENABLE ROW LEVEL SECURITY;
CREATE POLICY pegaki_cadernos_conta ON tech2d.pegaki_cadernos USING(id_usuario=current_setting('tech2d.uid',true)) WITH CHECK(id_usuario=current_setting('tech2d.uid',true));
CREATE POLICY pegaki_notas_conta ON tech2d.pegaki_notas USING(id_usuario=current_setting('tech2d.uid',true)) WITH CHECK(id_usuario=current_setting('tech2d.uid',true));
CREATE POLICY pegaki_recuperacoes_conta ON tech2d.pegaki_recuperacoes USING(id_usuario=current_setting('tech2d.uid',true)) WITH CHECK(id_usuario=current_setting('tech2d.uid',true));
REVOKE ALL ON tech2d.pegaki_cadernos,tech2d.pegaki_notas,tech2d.pegaki_recuperacoes,tech2d.pegaki_disciplinas,tech2d.visao_pegaki_resultados FROM PUBLIC;
DO $$ BEGIN IF EXISTS(SELECT FROM pg_roles WHERE rolname='tech2d_api') THEN
 GRANT USAGE ON SCHEMA tech2d TO tech2d_api;
 GRANT SELECT,INSERT,UPDATE,DELETE ON tech2d.pegaki_cadernos,tech2d.pegaki_notas,tech2d.pegaki_recuperacoes TO tech2d_api;
 GRANT SELECT ON tech2d.pegaki_disciplinas,tech2d.visao_pegaki_resultados TO tech2d_api;
END IF; END $$;


INSERT INTO tech2d.pegaki_disciplinas(id,ano_serie,nome) VALUES
(1,2,'Desenvolvimento e Operações Ágeis'),
(2,2,'Estatística'),
(3,2,'Sociologia'),
(4,2,'Desenvolvimento de Aplicativo Móvel'),
(5,2,'Aulas Práticas Estágio - Tecnologia'),
(6,2,'Desenvolvimento'),
(7,2,'Desenvolvimento Aplicação Dinâmica'),
(8,2,'Engenharia e Qualidade de Software'),
(9,2,'Estatística 1-Business Intelligence'),
(10,2,'Matemática 10-Modelagem de Dados'),
(11,2,'Língua Portuguesa e suas Literaturas'),
(12,2,'Matemática 9-Banco de Dados'),
(13,2,'Língua Inglesa'),
(14,2,'Biologia 2-ESG-Environment, Social and Governance'),
(15,2,'Língua Portuguesa 2-Chefia e Liderança'),
(16,2,'Matemática'),
(17,2,'Matemática 14 - Inteligência Artificial'),
(18,2,'UX');
