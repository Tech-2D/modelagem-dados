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

## Encontre o que você precisa

<div class="doc-links">
  <a href="{{ '/postgresql.html' | relative_url }}"><strong>Explorar tabelas e colunas</strong><span>Busque objetos do PostgreSQL, veja os tipos das colunas e abra as relações entre tabelas.</span></a>
  <a href="{{ '/modelagem.html' | relative_url }}"><strong>Entender a modelagem</strong><span>Veja de onde vêm as atividades, como os horários se ligam e o que é registrado nas visitas.</span></a>
  <a href="{{ '/consultas.html' | relative_url }}"><strong>Consultar exemplos SQL</strong><span>Copie consultas de atividades, horários e totais de visitas para usar em um banco local.</span></a>
  <a href="{{ '/redis.html' | relative_url }}"><strong>Consultar o Redis legado</strong><span>Conheça as chaves, os prazos e a renovação usados pelo cache anterior.</span></a>
</div>

## Serviços e dados

| Serviço | O que faz |
| --- | --- |
| PostgreSQL | Armazena atividades, horários, avisos, permissões e estatísticas. |
| Firebase Authentication | Identifica a conta. A API verifica a sessão e aplica as permissões. |
| Cloudflare R2 | Guarda arquivos anexados. A API controla quem pode acessar cada arquivo. |
| Redis | Guardava cópias temporárias dos catálogos na implementação anterior. |
| Firestore | Origem histórica dos dados preservados na migração para PostgreSQL. |

[Código da API compartilhada](https://github.com/Tech-2D/api)
