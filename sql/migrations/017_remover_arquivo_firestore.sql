-- Retira a cópia SQL do Firestore após a conferência do snapshot local.
SET LOCAL lock_timeout = '5s';
DROP VIEW IF EXISTS tech2d.visao_documentos_firestore RESTRICT;
DROP TABLE IF EXISTS tech2d.documentos_firestore RESTRICT;
INSERT INTO tech2d.migracoes_esquema(versao) VALUES ('017_remover_arquivo_firestore') ON CONFLICT DO NOTHING;
