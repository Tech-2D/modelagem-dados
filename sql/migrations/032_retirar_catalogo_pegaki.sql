-- Após publicar a API que consulta visao_disciplinas_pegaki, retira o alias de transição.
DROP VIEW tech2d.pegaki_disciplinas;
COMMENT ON SCHEMA tech2d IS 'Dados da Tech-2D. tech2d-schema-version:032_retirar_catalogo_pegaki';
