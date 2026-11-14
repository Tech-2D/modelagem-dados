---
title: Tabelas e colunas
description: Consulte tabelas, colunas, chaves e relações do esquema tech2d.
wide: true
---

Todas as tabelas ficam no schema `tech2d`. As áreas desta página agrupam os recursos para consulta, sem separar fisicamente o banco. As tabelas usam colunas tipadas e chaves estrangeiras. A tabela `registros_aplicacao` guarda a identidade numérica, a versão e a referência externa de cada registro. As views preparam o formato que a API entrega aos sites.

## Tabelas por área

{% assign tables = site.data.schema | where: "kind", "table" %}
<p class="catalog-overview"><strong>{{ tables.size }} tabelas</strong> no schema <code>tech2d</code> · <a href="{{ '/views.html' | relative_url }}">{{ site.data.views.size }} views</a> · <a href="{{ '/schemas.html' | relative_url }}">Organização por áreas</a></p>

Busque por tabela, coluna ou tipo, ou filtre por área. Cada card explica onde a tabela é usada no sistema; abaixo de cada campo está sua finalidade e por que ele é necessário.

<div class="catalog-controls" data-catalog-controls hidden>
  <label for="catalog-search"><span class="catalog-label-icon">{% include doc-icon.html name="search" %}Buscar no catálogo</span><input id="catalog-search" type="search" placeholder="Ex.: visitas, id_turma ou jsonb" autocomplete="off"></label>
  <label for="catalog-group">Área<select id="catalog-group"><option value="">Todas as áreas</option>{% for group in site.data.catalog %}<option value="{{ group.id }}">{{ group.name }}</option>{% endfor %}</select></label>
  <div class="catalog-actions">
    <p class="catalog-status" data-catalog-status role="status"></p>
  </div>
</div>

{% for group in site.data.catalog %}
<section class="catalog-group schema-card-group" data-catalog-group="{{ group.id }}" aria-labelledby="{{ group.id }}">
  <h3 id="{{ group.id }}">{{ group.name }}</h3>
  {% for item in group.objects %}
  {% assign object = site.data.schema | where: "name", item.name | first %}
  {% assign usage = site.data.table_usage[item.name] %}
  <article class="schema-card" id="obj-{{ item.name }}" data-catalog-object>
    <header class="schema-card-header">
      {% include doc-icon.html name="table" %}
      <div><h4>{{ item.name }}</h4><p>tech2d · {{ object.columns.size }} colunas</p></div>
      {% if object.foreign_key_count > 0 %}<span class="schema-tag schema-tag-fk" title="Total de chaves estrangeiras">{{ object.foreign_key_count }} FK</span>{% endif %}
    </header>
    <p class="schema-feature">{% include doc-icon.html name="layers" %}{{ usage.feature | escape }}</p>
    <p class="schema-card-description">{{ usage.description | default: object.comment | default: item.title | escape }}</p>
    <ul class="schema-columns" aria-label="Colunas de {{ item.name }}">
      {% for column in object.columns %}
      {% assign refs = object.references | where: "column", column.name %}
      <li class="schema-column">
        <span class="schema-column-name">{% if object.primary_key contains column.name %}<span class="column-key">{% include doc-icon.html name="key" %}</span>{% elsif refs.size > 0 %}<span class="column-link">{% include doc-icon.html name="link" %}</span>{% endif %}<code>{{ column.name }}</code></span>
        <span class="schema-column-properties">
          <code class="schema-column-type">{{ column.type | replace: "character varying", "varchar" | replace: "timestamp with time zone", "timestamptz" | escape }}</code>
          {% if object.primary_key contains column.name %}<span class="schema-tag schema-tag-pk" title="Chave primária">PK</span>{% endif %}
          {% if refs.size > 0 %}<span class="schema-tag schema-tag-fk" title="Chave estrangeira">FK</span>{% endif %}
          {% if column.unique %}<span class="schema-tag schema-tag-unique">UNIQUE</span>{% endif %}
          {% if column.check %}<span class="schema-tag schema-tag-check">CHECK</span>{% endif %}
          {% if column.generated %}<span class="schema-tag schema-tag-identity">IDENTITY</span>{% endif %}
          {% unless column.nullable %}<span class="schema-tag schema-tag-required">NOT NULL</span>{% endunless %}
        </span>
        {% assign note = site.data.column_notes[item.name][column.name] | default: column.comment %}
        <small class="schema-column-note">{{ note | escape }}</small>
      </li>
      {% endfor %}
    </ul>
  </article>
  {% endfor %}
</section>
{% endfor %}

<p id="obj-catalogo_horarios">A definição de <a href="{{ '/views.html' | relative_url }}#view-catalogo_horarios"><code>catalogo_horarios</code></a> fica na página de views.</p>

## Como os registros se ligam

Abra a [modelagem]({{ '/modelagem.html' | relative_url }}) para seguir os vínculos de horários, atividades e contas.

`atividades.data` usa `date` e `atividades.hora` usa `time`. O horário é opcional. Cada anexo fica em uma linha de `anexos_atividade`, com posição, nome, tamanho e referência ao arquivo no R2.

## Acesso ao banco

O Worker se conecta com o papel dedicado `tech2d_api`. O provisionamento da API concede as operações necessárias por tabela. A aplicação aplica as permissões por conta, papel e turma antes de ler ou gravar. Os arquivos de migração podem ser executados em um banco local sem criar esse papel.

Os catálogos públicos passam por projeções que selecionam os campos da resposta. Os arquivos da migração, as auditorias e os dados de moderação são acessados pelos fluxos administrativos correspondentes ou pela operação do banco.

## Migrações SQL

| Versão | O que cria ou altera |
| --- | --- |
| 001 | Esquema, arquivo de origem, atividades, perfis, catálogo e auditoria inicial |
| 002 | Documentos de aplicação, recibos, auditoria e estado de migração |
| 003 | Histórico das revisões da origem |
| 004 | Registro de visitas da Agenda |
| 005 | Últimos acessos autenticados e bloqueios da Agenda |
| 006 | Separação das visitas por site e últimos acessos do Cadê o professor |
| 007 | Tabelas relacionais de horários, chaves estrangeiras, migração dos registros existentes e view de leitura |
| 008 | Remoção dos campos já normalizados da projeção JSONB de horários, após a troca de leitura na API |
| 009 | Renomeia `agenda_access` para `site_visits` e padroniza o nome da chave primária |
| 010 | Documenta em português a função de cada tabela e da visão de horários |
| 011 | Renomeia `site_visits` e suas colunas para português |
| 012 | Renomeia `agenda_recent_users` e suas colunas para português |
| 013 | Renomeia as tabelas e colunas restantes e a visão de horários. Mantém as visões de compatibilidade da API |
| 014 | Define tamanhos de `varchar` nas 51 colunas de texto das tabelas operacionais |
| 015 | Cria as views de compatibilidade com prefixo `visao_` |
| 016 | Retira os nomes em inglês após a atualização dos serviços |
| 017 | Remove a cópia bruta do Firestore e sua view |
| 018 | Remove os controles de migração e registra a versão no comentário do schema |
| 019 | Instala a interface de gravação usada pela API durante a troca |
| 020 | Usa chaves numéricas e colunas tipadas. Separa anexos, votos, Kanban e dados históricos |
| 021 | Centraliza o catálogo e o arquivamento de atividades em funções e cria a view usada pelos jobs |
| 022 | Remove `campos_nulos` das tabelas e ajusta a serialização dos registros |
| 023 | Expõe a revisão restrita dos catálogos públicos para o cache Redis |
| 024 | Adiciona cadernos privados de notas do Pegaki |
| 025 | Remove a tabela e a view de revisões da migração para PostgreSQL |
| 026 | Adiciona o registro de acessos autenticados ao Pegaki |
| 027 | Consolida os acessos recentes da Agenda e dos professores por site e conta |
| 028 | Unifica o arquivo de atividades, remove marcadores de listas e aposenta a auditoria antiga |
| 029–032 | Unifica os acessos dos três sites e faz o Pegaki reutilizar o catálogo geral de disciplinas |
| 033 | Retira enquetes, opções, votos, autorizações de eleitores e as funções exclusivas do recurso |
| 034 | Retira a tabela de anotações do antigo Caderno Infinito e o contrato notebookNotes da API |
| 035 | Retira a tabela de comunicados gerais após a mudança para Redis |
| 036 | Retira as tabelas de arquivo após a adoção do expurgo direto |
| 037 | Move o histórico público de atualizações para o Redis com prazo de 14 dias por publicação |

Em um banco local vazio, siga os passos em [Consultas SQL]({{ '/consultas.html' | relative_url }}). O script de instalação aplica as migrações na ordem acima.

[Ver arquivos SQL](https://github.com/Tech-2D/database/tree/main/sql/migrations) · [Rodar em um banco local](https://github.com/Tech-2D/database#rodar-o-sql-localmente) · [Consultas de exemplo](https://github.com/Tech-2D/database/blob/main/sql/examples/consultas.sql)
