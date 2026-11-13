---
title: Tabelas e colunas
description: Consulte tabelas, colunas, chaves e relações do esquema tech2d.
---

O schema `tech2d` separa os dados por assunto. As tabelas usam colunas tipadas e chaves estrangeiras. A tabela `registros_aplicacao` guarda a identidade numérica, a versão e a referência externa de cada registro. As views preparam o formato que a API entrega aos sites.

## Tabelas por área

{% assign tables = site.data.schema | where: "kind", "table" %}
<p class="catalog-overview"><strong>{{ tables.size }} tabelas</strong> no schema <code>tech2d</code> · <a href="{{ '/views.html' | relative_url }}">{{ site.data.views.size }} views</a> · <a href="{{ '/schemas.html' | relative_url }}">Schemas do banco</a></p>

Busque pelo nome da tabela, pela coluna ou pelo tipo. Abra uma tabela para consultar o que cada campo guarda, as chaves e os vínculos.

<div class="catalog-controls" data-catalog-controls hidden>
  <label for="catalog-search">Buscar no catálogo<input id="catalog-search" type="search" placeholder="Ex.: visitas, id_turma ou jsonb" autocomplete="off"></label>
  <label for="catalog-group">Área<select id="catalog-group"><option value="">Todas as áreas</option>{% for group in site.data.catalog %}<option value="{{ group.id }}">{{ group.name }}</option>{% endfor %}</select></label>
  <div class="catalog-actions">
    <p class="catalog-status" data-catalog-status role="status"></p>
    <button type="button" data-catalog-toggle>Abrir resultados</button>
  </div>
</div>

{% for group in site.data.catalog %}
<section class="catalog-group" data-catalog-group="{{ group.id }}" aria-labelledby="{{ group.id }}">
  <h3 id="{{ group.id }}">{{ group.name }}</h3>
  {% for item in group.objects %}
  {% assign object = site.data.schema | where: "name", item.name | first %}
  {% assign column_notes = site.data.column_notes[item.name] %}
  <details class="catalog-object" id="obj-{{ item.name }}" data-catalog-object>
    <summary><span><strong>{{ item.title }}</strong> <code class="object-identifier">{{ item.name }}</code><span class="object-description">{{ object.comment | escape }}</span></span><span class="object-kind">{{ object.columns.size }} colunas</span></summary>
    <div class="object-body">
      {% if object.primary_key.size > 0 %}<p><strong>Chave primária</strong> <code>{{ object.primary_key | join: ", " }}</code></p>{% endif %}
      {% if object.references.size > 0 %}<ul class="object-relations" aria-label="Chaves estrangeiras">{% for relation in object.references %}<li><code>{{ relation.column }}</code> <span aria-hidden="true">→</span> <a href="#obj-{{ relation.table }}"><code>{{ relation.table }}.{{ relation.target }}</code></a></li>{% endfor %}</ul>{% endif %}
      <table class="dictionary-table">
        <caption class="visually-hidden">Colunas de {{ item.name }}</caption>
        <thead><tr><th scope="col">Coluna</th><th scope="col">Tipo</th><th scope="col">Finalidade</th></tr></thead>
        <tbody>
          {% for column in object.columns %}
          <tr>
            <th scope="row"><code>{{ column.name }}</code><small class="column-null">{% if object.primary_key contains column.name %}Chave primária · {% endif %}{% if column.generated %}Gerada pelo banco · {% endif %}{% if column.nullable %}Aceita nulo{% else %}Obrigatória{% endif %}</small></th>
            <td><code>{{ column.type | replace: "character varying", "varchar" | replace: "timestamp with time zone", "timestamptz" | escape }}</code></td>
            <td>{{ column_notes[column.name] | escape }}</td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>
  </details>
  {% endfor %}
</section>
{% endfor %}

<p id="obj-catalogo_horarios">A definição de <a href="{{ '/views.html' | relative_url }}#view-catalogo_horarios"><code>catalogo_horarios</code></a> fica na página de views.</p>

## Como os registros se ligam

Abra a [modelagem]({{ '/modelagem.html' | relative_url }}) para seguir os vínculos de horários, atividades e contas. No catálogo, as chaves estrangeiras levam diretamente à tabela relacionada.

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

Em um banco local vazio, siga os passos em [Consultas SQL]({{ '/consultas.html' | relative_url }}). O script de instalação aplica as migrações na ordem acima.

[Ver arquivos SQL](https://github.com/Tech-2D/modelagem-dados/tree/main/sql/migrations) · [Rodar em um banco local](https://github.com/Tech-2D/modelagem-dados#rodar-o-sql-localmente) · [Consultas de exemplo](https://github.com/Tech-2D/modelagem-dados/blob/main/sql/examples/consultas.sql)
