---
title: Views da API
description: Consulte as colunas usadas pela API e as tabelas que fornecem os dados.
---

O schema `tech2d` tem {{ site.data.views.size }} views. `catalogo_horarios` reúne professor, disciplina, turma, horário e localização. As views com prefixo `visao_` mantêm os nomes de colunas esperados pela API, incluindo nomes em inglês. O catálogo de tabelas apresenta os nomes físicos em português. As colunas JSONB das views são calculadas na consulta para montar as respostas da API. Os valores persistidos nas tabelas são tipados.

## Funções usadas pela API

| Função | Responsabilidade |
| --- | --- |
| `consultar_catalogo_agenda(turma, incluir_atividades)` | Seleciona as atividades gerais e da turma, reúne turmas e atualizações e devolve o catálogo em uma consulta. |
| `arquivar_atividade(id, motivo, arquivada_em, dias_retencao)` | Cria a cópia de uma atividade da turma, remove o registro ativo e grava a auditoria na mesma operação. |

O Worker autentica a conta, verifica as permissões das rotas e seleciona os campos das respostas públicas. Os jobs calculam as datas das recorrências e decidem quais políticas de retenção estão vigentes. Eles consultam `visao_atividades_automacao` para filtrar pelas colunas de turma, data e regra de recorrência. O Worker cuida da limpeza dos arquivos no R2.

## Colunas e origem

<div class="catalog-controls" data-catalog-controls hidden>
  <label for="view-search">Buscar nas views<input id="view-search" type="search" placeholder="Ex.: horários, teacher_id ou dados" autocomplete="off"></label>
  <div class="catalog-actions">
    <p class="catalog-status" data-catalog-status role="status"></p>
    <button type="button" data-catalog-toggle>Abrir resultados</button>
  </div>
</div>

<section class="catalog-group" data-catalog-group="views" aria-label="Views do schema tech2d">
{% for view in site.data.views %}
<details class="catalog-object" id="view-{{ view.name }}" data-catalog-object>
  <summary><span><strong><code>{{ view.name }}</code></strong><span class="object-description">{{ view.comment | escape }}</span></span><span class="object-kind">{{ view.columns.size }} colunas</span></summary>
  <div class="object-body">
    <p><strong>Origem dos dados</strong></p>
    <ul class="object-relations">
    {% for dependency in view.dependencies %}
      {% if dependency == 'catalogo_horarios' %}
        <li><a href="#view-catalogo_horarios"><code>catalogo_horarios</code></a></li>
      {% else %}
        <li><a href="{{ '/postgresql.html' | relative_url }}#obj-{{ dependency }}"><code>{{ dependency }}</code></a></li>
      {% endif %}
    {% endfor %}
    </ul>
    <table class="dictionary-table">
      <caption class="visually-hidden">Colunas de {{ view.name }}</caption>
      <thead><tr><th scope="col">Coluna</th><th scope="col">Tipo</th><th scope="col">Finalidade</th></tr></thead>
      <tbody>
      {% for column in view.columns %}
        <tr>
          <th scope="row"><code>{{ column.name }}</code>{% if column.source != column.name %}<small class="column-null">Origem <code>{{ column.source }}</code></small>{% endif %}</th>
          <td><code>{{ column.type | replace: "character varying", "varchar" | replace: "timestamp with time zone", "timestamptz" | escape }}</code></td>
          <td>{{ column.note | escape }}</td>
        </tr>
      {% endfor %}
      </tbody>
    </table>
  </div>
</details>
{% endfor %}
</section>
