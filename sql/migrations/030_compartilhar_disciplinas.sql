-- Reaproveita disciplinas; apenas a associação entre matéria e série é nova.
-- Executar em transação. A view temporária com o nome antigo mantém a API anterior funcionando.
LOCK TABLE tech2d.pegaki_disciplinas,tech2d.pegaki_notas,tech2d.pegaki_recuperacoes IN ACCESS EXCLUSIVE MODE;
CREATE TEMP TABLE nomes_disciplinas_pegaki(nome_antigo varchar(160) PRIMARY KEY,nome_catalogo varchar(180) NOT NULL) ON COMMIT DROP;
INSERT INTO nomes_disciplinas_pegaki VALUES
('Desenvolvimento e Operações Ágeis','Desenvolvimento e Operações Ágeis'),
('Estatística','Estatística'),
('Sociologia','Sociologia'),
('Desenvolvimento de Aplicativo Móvel','Desenvolvimento de Aplicativo Móvel'),
('Aulas Práticas Estágio - Tecnologia','Aulas Práticas Estágio - Tecnologia'),
('Desenvolvimento','Desenvolvimento'),
('Desenvolvimento Aplicação Dinâmica','Desenvolvimento de Aplicação Dinâmica'),
('Engenharia e Qualidade de Software','Engenharia e Qualidae de Software'),
('Estatística 1-Business Intelligence','Estatística 1-Business Intelligence'),
('Matemática 10-Modelagem de Dados','Matemática 10-Modelagem de Dados'),
('Língua Portuguesa e suas Literaturas','Língua Portuguesa e Suas Literaturas'),
('Matemática 9-Banco de Dados','Matemática 9-Banco de dados'),
('Língua Inglesa','Lingua inglesa'),
('Biologia 2-ESG-Environment, Social and Governance','Biologia 2 - ESG'),
('Língua Portuguesa 2-Chefia e Liderança','Língua Portuguesa 2-Chefia e Liderança'),
('Matemática','Matemática'),
('Matemática 14 - Inteligência Artificial','Matemática 14-Inteligência Artificial'),
('UX','UX');
DO $$ BEGIN
 IF EXISTS(SELECT FROM tech2d.pegaki_disciplinas p LEFT JOIN nomes_disciplinas_pegaki m ON m.nome_antigo=p.nome WHERE m.nome_antigo IS NULL)
 THEN RAISE EXCEPTION 'Disciplina sem correspondência revisada; completar mapeamento antes de migrar'; END IF;
END $$;
INSERT INTO tech2d.disciplinas(nome)
SELECT DISTINCT m.nome_catalogo FROM tech2d.pegaki_disciplinas p JOIN nomes_disciplinas_pegaki m ON m.nome_antigo=p.nome
WHERE NOT EXISTS(SELECT FROM tech2d.disciplinas d WHERE d.nome=m.nome_catalogo)
ON CONFLICT(nome) DO NOTHING;
CREATE TEMP TABLE vinculos_disciplinas_pegaki ON COMMIT DROP AS
SELECT p.id AS id_antigo,d.id AS id_novo,p.ano_serie FROM tech2d.pegaki_disciplinas p
JOIN nomes_disciplinas_pegaki m ON m.nome_antigo=p.nome JOIN tech2d.disciplinas d ON d.nome=m.nome_catalogo;
DO $$ BEGIN
 IF (SELECT count(*) FROM vinculos_disciplinas_pegaki)<>(SELECT count(*) FROM tech2d.pegaki_disciplinas)
 OR EXISTS(SELECT FROM vinculos_disciplinas_pegaki GROUP BY ano_serie,id_novo HAVING count(*)>1)
 THEN RAISE EXCEPTION 'Correspondência de disciplinas incompleta ou ambígua'; END IF;
END $$;
CREATE TABLE tech2d.disciplinas_series (
 id_disciplina bigint NOT NULL REFERENCES tech2d.disciplinas(id),
 ano_serie smallint NOT NULL CHECK(ano_serie BETWEEN 1 AND 3),
 PRIMARY KEY(id_disciplina,ano_serie)
);
INSERT INTO tech2d.disciplinas_series SELECT id_novo,ano_serie FROM vinculos_disciplinas_pegaki;
COMMENT ON TABLE tech2d.disciplinas_series IS 'Vínculo entre o catálogo compartilhado de disciplinas e as séries do Ensino Médio. O Pegaki consulta esse vínculo para validar notas, sem duplicar os nomes das matérias.';
COMMENT ON COLUMN tech2d.disciplinas_series.id_disciplina IS 'Disciplina do catálogo geral, também usado pelos horários. A chave estrangeira impede uma matéria inexistente.';
COMMENT ON COLUMN tech2d.disciplinas_series.ano_serie IS 'Série de 1 a 3 em que a disciplina é oferecida. Compõe a chave para reutilizar a mesma matéria em séries diferentes.';

DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT conrelid::regclass AS tabela,conname FROM pg_constraint WHERE contype='f' AND confrelid='tech2d.pegaki_disciplinas'::regclass
 LOOP EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I',f.tabela,f.conname); END LOOP;
END $$;
DROP VIEW tech2d.visao_pegaki_resultados;
ALTER TABLE tech2d.pegaki_notas DROP CONSTRAINT pegaki_notas_pkey,ALTER COLUMN id_disciplina TYPE bigint;
ALTER TABLE tech2d.pegaki_recuperacoes DROP CONSTRAINT pegaki_recuperacoes_pkey,ALTER COLUMN id_disciplina TYPE bigint;
UPDATE tech2d.pegaki_notas n SET id_disciplina=m.id_novo FROM vinculos_disciplinas_pegaki m WHERE n.id_disciplina=m.id_antigo AND n.ano_serie=m.ano_serie;
UPDATE tech2d.pegaki_recuperacoes r SET id_disciplina=m.id_novo FROM vinculos_disciplinas_pegaki m WHERE r.id_disciplina=m.id_antigo AND r.ano_serie=m.ano_serie;
ALTER TABLE tech2d.pegaki_notas ADD PRIMARY KEY(id_usuario,ano_letivo,id_disciplina,semestre),
 ADD CONSTRAINT pegaki_notas_disciplina_serie_fk FOREIGN KEY(id_disciplina,ano_serie) REFERENCES tech2d.disciplinas_series(id_disciplina,ano_serie);
ALTER TABLE tech2d.pegaki_recuperacoes ADD PRIMARY KEY(id_usuario,ano_letivo,id_disciplina),
 ADD CONSTRAINT pegaki_recuperacoes_disciplina_serie_fk FOREIGN KEY(id_disciplina,ano_serie) REFERENCES tech2d.disciplinas_series(id_disciplina,ano_serie);
DROP TABLE tech2d.pegaki_disciplinas;
CREATE VIEW tech2d.visao_disciplinas_pegaki AS
SELECT d.id,s.ano_serie,(CASE d.nome
 WHEN 'Desenvolvimento de Aplicação Dinâmica' THEN 'Desenvolvimento Aplicação Dinâmica'
 WHEN 'Engenharia e Qualidae de Software' THEN 'Engenharia e Qualidade de Software'
 WHEN 'Língua Portuguesa e Suas Literaturas' THEN 'Língua Portuguesa e suas Literaturas'
 WHEN 'Matemática 9-Banco de dados' THEN 'Matemática 9-Banco de Dados'
 WHEN 'Lingua inglesa' THEN 'Língua Inglesa'
 WHEN 'Biologia 2 - ESG' THEN 'Biologia 2-ESG-Environment, Social and Governance'
 WHEN 'Matemática 14-Inteligência Artificial' THEN 'Matemática 14 - Inteligência Artificial'
 ELSE d.nome END)::varchar(160) AS nome
FROM tech2d.disciplinas_series s JOIN tech2d.disciplinas d ON d.id=s.id_disciplina;
COMMENT ON VIEW tech2d.visao_disciplinas_pegaki IS 'Projeção do catálogo compartilhado para o Pegaki. Conserva os rótulos que o frontend usa como chaves, sem armazenar outro catálogo de nomes.';
CREATE VIEW tech2d.pegaki_disciplinas AS SELECT * FROM tech2d.visao_disciplinas_pegaki;
CREATE VIEW tech2d.visao_pegaki_resultados WITH (security_invoker=true) AS
WITH semestres AS (
 SELECT c.id_usuario,c.ano_letivo,c.ano_serie,c.regra_calculo,c.versao,d.id AS id_disciplina,d.nome,
 CASE WHEN c.modo_primeiro='media' THEN p.media_informada ELSE round((p.n1*p.peso_n1+p.n2*(100-p.peso_n1))/100,2) END AS media_primeiro,
 CASE WHEN c.modo_segundo='media' THEN s.media_informada ELSE round((s.n1*s.peso_n1+s.n2*(100-s.peso_n1))/100,2) END AS media_segundo,
 r.nota AS recuperacao_final
 FROM tech2d.pegaki_cadernos c JOIN tech2d.visao_disciplinas_pegaki d USING(ano_serie)
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

COMMENT ON VIEW tech2d.visao_pegaki_resultados IS 'Médias por conta e disciplina do catálogo compartilhado; aplica as fórmulas tech-2026-v1 e preserva RLS nas tabelas de notas.';
REVOKE ALL ON tech2d.disciplinas_series,tech2d.visao_disciplinas_pegaki,tech2d.pegaki_disciplinas,tech2d.visao_pegaki_resultados FROM PUBLIC;
DO $$ BEGIN IF EXISTS(SELECT FROM pg_roles WHERE rolname='tech2d_api') THEN
 GRANT SELECT ON tech2d.disciplinas_series,tech2d.visao_disciplinas_pegaki,tech2d.pegaki_disciplinas,tech2d.visao_pegaki_resultados TO tech2d_api;
END IF; END $$;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:030_compartilhar_disciplinas';
