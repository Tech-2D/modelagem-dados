-- Retira somente o histórico da reconciliação de origem; a auditoria operacional permanece.
SELECT pg_advisory_xact_lock(hashtext('tech2d-application-commit'));
DROP VIEW tech2d.visao_revisoes_origem;
-- ON DELETE CASCADE retira apenas os valores pertencentes às revisões de migração.
DELETE FROM tech2d.revisoes_origem;
ALTER TABLE tech2d.valores_historico DROP COLUMN id_revisao;
ALTER TABLE tech2d.valores_historico ADD CONSTRAINT valores_historico_dono_check CHECK (num_nonnulls(id_auditoria,id_auditoria_legada)=1);
DROP TABLE tech2d.revisoes_origem;
CREATE FUNCTION tech2d.gravar_valor_historico(auditoria bigint, legado bigint,
  pai bigint, campo varchar, posicao integer, objeto jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE
  forma varchar(12) := jsonb_typeof(objeto);
  alvo bigint;
BEGIN
  IF objeto IS NULL THEN RETURN; END IF;
  INSERT INTO tech2d.valores_historico(id_auditoria,id_auditoria_legada,id_pai,chave,ordem,tipo,
    valor_textual,valor_numerico,valor_logico)
  VALUES(auditoria,legado,pai,campo,posicao,forma,
    CASE WHEN forma='string' THEN objeto#>>'{}' END,
    CASE WHEN forma='number' THEN (objeto#>>'{}')::numeric END,
    CASE WHEN forma='boolean' THEN (objeto#>>'{}')::boolean END)
  RETURNING id INTO alvo;
  IF forma='object' THEN
    PERFORM tech2d.gravar_valor_historico(auditoria,legado,alvo,key,0,value) FROM jsonb_each(objeto);
  ELSIF forma='array' THEN
    PERFORM tech2d.gravar_valor_historico(auditoria,legado,alvo,NULL,(ord-1)::integer,value)
    FROM jsonb_array_elements(objeto) WITH ORDINALITY a(value,ord);
  END IF;
END $$;
REVOKE ALL ON FUNCTION tech2d.gravar_valor_historico(bigint,bigint,bigint,varchar,integer,jsonb) FROM PUBLIC;
CREATE OR REPLACE FUNCTION tech2d.inserir_auditoria() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.auditoria_aplicacao(autor,caminho,operacao,alterado_em)
  VALUES(NEW.actor,NEW.path,NEW.operation,coalesce(NEW.changed_at,now())) RETURNING sequencia INTO NEW.sequence;
  PERFORM tech2d.gravar_valor_historico(NEW.sequence,NULL,NULL,NULL,0,NEW.previous_data);
  RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION tech2d.inserir_auditoria_legada() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO tech2d.auditoria_atividades_legada(id_atividade,id_usuario,acao,alterado_em)
  VALUES(NEW.activity_id,NEW.actor_uid,NEW.action,coalesce(NEW.changed_at,now())) RETURNING sequencia INTO NEW.sequence;
  PERFORM tech2d.gravar_valor_historico(NULL,NEW.sequence,NULL,NULL,0,NEW.previous_data);
  RETURN NEW;
END $$;
DROP FUNCTION tech2d.gravar_valor_historico(bigint,bigint,bigint,bigint,varchar,integer,jsonb);
COMMENT ON TABLE tech2d.valores_historico IS 'Campos tipados das auditorias das operações da aplicação, preservados após a exclusão do registro original.';
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:025_remover_revisoes_migracao';
