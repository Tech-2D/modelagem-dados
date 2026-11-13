---
title: Funções e procedures
description: Assinaturas e responsabilidades das rotinas cadastradas no schema tech2d.
---

Este inventário contém {{ site.data.routines.size }} rotinas do PostgreSQL. Funções retornam valores ou executam operações usadas pela API. Procedures são chamadas com `CALL`; atualmente não há procedures cadastradas neste schema.

As rotinas `ler_` reconstroem a resposta da API a partir das colunas tipadas. As rotinas `gravar_` e `inserir_` distribuem os valores recebidos nas tabelas correspondentes. Consulte o objeto pelo menu ou pela busca abaixo.

<div class="catalog-controls" data-catalog-controls hidden>
  <label for="routine-search">Buscar rotina<input id="routine-search" type="search" placeholder="Ex.: arquivar, catálogo, kanban" autocomplete="off"></label>
  <div class="catalog-actions"><p class="catalog-status" data-catalog-status role="status"></p><button type="button" data-catalog-toggle>Abrir resultados</button></div>
</div>
<section class="catalog-group" data-catalog-group="routines" aria-label="Rotinas SQL">
{% for routine in site.data.routines %}
<details class="catalog-object" id="{{ routine.anchor }}" data-catalog-object>
  <summary><span><strong><code>{{ routine.name | escape }}</code></strong><span class="object-description">{% if routine.comment %}{{ routine.comment | escape }}{% elsif routine.name contains 'ler_' %}Leitura e composição dos dados usados pela API.{% elsif routine.name contains 'gravar_' or routine.name contains 'inserir_' %}Gravação dos valores nas tabelas tipadas.{% else %}Rotina auxiliar de transformação ou manutenção dos dados.{% endif %}</span></span><span class="object-kind">{% if routine.procedure %}Procedure{% else %}Função{% endif %}</span></summary>
  <div class="object-body"><p><strong>Schema</strong> <code>tech2d</code> · <strong>Linguagem</strong> <code>{{ routine.language | escape }}</code></p><p><strong>Parâmetros</strong> <code>{{ routine.arguments | default: 'Sem parâmetros' | escape }}</code></p><p><strong>Retorno</strong> <code>{{ routine.result | default: 'Sem retorno' | escape }}</code></p></div>
</details>
{% endfor %}
</section>
