---
title: Modelagem de dados
description: Como a Agenda e o Cadê o professor armazenam, consultam e protegem seus dados.
permalink: /
---

<div class="system-flow" aria-label="Caminho de uma consulta">
  <span><strong>Agenda e Cadê o professor</strong><small>Sites</small></span>
  <span class="flow-arrow" aria-hidden="true">→</span>
  <span><strong>Cloudflare Workers</strong><small>API compartilhada</small></span>
  <span class="flow-arrow" aria-hidden="true">→</span>
  <span><strong>PostgreSQL</strong><small>Aiven, via Hyperdrive</small></span>
</div>

{% assign table_count = site.data.schema | where: "kind", "table" | size %}
{% assign functions = site.data.routines | where: "procedure", false %}
{% assign procedures = site.data.routines | where: "procedure", true %}
<div class="workspace-stats" aria-label="Inventário PostgreSQL">
  <a href="{{ '/postgresql.html' | relative_url }}"><strong>{{ table_count }}</strong><span>{% include doc-icon.html name="table" %}Tabelas</span></a>
  <a href="{{ '/views.html' | relative_url }}"><strong>{{ site.data.views.size }}</strong><span>{% include doc-icon.html name="eye" %}Views</span></a>
  <a href="{{ '/funcoes.html' | relative_url }}"><strong>{{ functions.size }}</strong><span>{% include doc-icon.html name="code" %}Funções</span></a>
  <a href="{{ '/procedures.html' | relative_url }}"><strong>{{ procedures.size }}</strong><span>{% include doc-icon.html name="diagram" %}Procedures</span></a>
</div>

## Encontre o que você precisa

<div class="doc-links">
  <a href="{{ '/postgresql.html' | relative_url }}"><strong>Explorar tabelas e colunas</strong><span>Busque pelo nome de uma tabela ou coluna e confira tipos, chaves e finalidade.</span></a>
  <a href="{{ '/schemas.html' | relative_url }}"><strong>Localizar tabelas por área</strong><span>Encontre os dados de cada recurso e veja as simplificações aplicadas ao banco.</span></a>
  <a href="{{ '/views.html' | relative_url }}"><strong>Consultar as views da API</strong><span>Veja a origem dos dados e os nomes dos campos usados pela API.</span></a>
  <a href="{{ '/modelagem.html' | relative_url }}"><strong>Entender a modelagem</strong><span>Busque por tabelas e colunas, veja quem usa cada tabela e percorra as chaves estrangeiras.</span></a>
  <a href="{{ '/consultas.html' | relative_url }}"><strong>Consultar exemplos SQL</strong><span>Copie consultas de atividades, horários e totais de visitas para usar em um banco local.</span></a>
  <a href="{{ '/redis.html' | relative_url }}"><strong>Consultar o Redis</strong><span>Veja as chaves, os prazos e a integração do cache com o PostgreSQL.</span></a>
</div>

## Serviços e dados

| Serviço | O que faz |
| --- | --- |
| PostgreSQL | Armazena atividades, horários, avisos, permissões e estatísticas. |
| Firebase Authentication | Identifica a conta. A API verifica a sessão e aplica as permissões. |
| Cloudflare R2 | Guarda arquivos anexados. A API controla quem pode acessar cada arquivo. |
| Redis | Cache de catálogos integrado à API SQL, com retorno ao PostgreSQL se o cache estiver indisponível. |
| Firestore | Origem histórica dos dados preservados na migração para PostgreSQL. |

[Código da API compartilhada](https://github.com/Tech-2D/api)
