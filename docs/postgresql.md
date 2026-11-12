---
title: Catálogo PostgreSQL
description: Consulte tabelas, colunas, chaves e relações do esquema tech2d.
---

O esquema `tech2d` combina **documentos JSONB** com **tabelas de consulta**. Os documentos preservam caminhos e IDs usados pela aplicação. As projeções facilitam filtros de agenda, horários e permissões. A API atualiza o documento e suas projeções na mesma transação.

## Visão geral das tabelas

<div class="catalog-controls" data-catalog-controls hidden>
  <label for="catalog-search">Buscar no catálogo<input id="catalog-search" type="search" placeholder="Ex.: site_visits, turma_id ou jsonb" autocomplete="off"></label>
  <label for="catalog-group">Área<select id="catalog-group"><option value="">Todas as áreas</option>{% for group in site.data.catalog %}<option value="{{ group.id }}">{{ group.name }}</option>{% endfor %}</select></label>
  <p class="catalog-status" data-catalog-status role="status"></p>
</div>

{% for group in site.data.catalog %}
<section class="catalog-group" data-catalog-group="{{ group.id }}" aria-labelledby="{{ group.id }}">
  <h3 id="{{ group.id }}">{{ group.name }}</h3>
  {% for item in group.objects %}
  {% assign object = site.data.schema | where: "name", item.name | first %}
  <details class="catalog-object" id="obj-{{ item.name }}" data-catalog-object>
    <summary><span><code>{{ item.name }}</code><span class="object-description">{{ item.description }}</span></span><span class="object-kind">{% if object.kind == "view" %}View{% else %}Tabela{% endif %}</span></summary>
    <div class="object-body">
      {% if object.primary_key.size > 0 %}<p><strong>Chave primária</strong> <code>{{ object.primary_key | join: ", " }}</code></p>{% endif %}
      {% if object.references.size > 0 %}<ul class="object-relations" aria-label="Chaves estrangeiras">{% for relation in object.references %}<li><code>{{ relation.column }}</code> <span aria-hidden="true">→</span> <a href="#obj-{{ relation.table }}"><code>{{ relation.table }}.{{ relation.target }}</code></a></li>{% endfor %}</ul>{% endif %}
      <table>
        <caption class="visually-hidden">Colunas de {{ item.name }}</caption>
        <thead><tr><th scope="col">Coluna</th><th scope="col">Tipo</th><th scope="col">Aceita nulo</th></tr></thead>
        <tbody>{% for column in object.columns %}<tr><th scope="row"><code>{{ column.name }}</code></th><td><code>{{ column.type | escape }}</code></td><td>{% if column.nullable %}Sim{% else %}Não{% endif %}</td></tr>{% endfor %}</tbody>
      </table>
    </div>
  </details>
  {% endfor %}
</section>
{% endfor %}

## Simplificações propostas

1. **Unificar últimos acessos.** Consolidar `agenda_recent_users` e `professor_recent_users` em `site_recent_users` com chave `(site, uid)`. A referência de rede fica restrita às linhas da Agenda. A troca deve preservar o último acesso por site, os prazos de retenção e as permissões de cada painel.
2. **Alinhar os nomes ao escopo.** A tabela `site_visits` registra as visitas dos dois sites. Para novas tabelas, manter nomes em inglês, no plural e em `snake_case`. Usar prefixos como `school_` e `site_` quando indicarem a responsabilidade da tabela. `agenda_blocks` já segue esse critério porque o bloqueio é específico da Agenda.
3. **Separar a auditoria antiga.** Depois de retirar a rota antiga e conferir a retenção necessária, arquivar `activity_audit` com acesso restrito. A auditoria das gravações atuais continua em `app_audit`.

As projeções são usadas pela API, os recibos evitam gravações duplicadas e as tabelas de referência preservam a integridade dos horários. A separação entre o arquivo do Firestore e os dados ativos também preserva as permissões de acesso. A unificação dos últimos acessos e o arquivamento da auditoria antiga ficam para migrações posteriores.

## Como os registros se ligam

Abra a [modelagem]({{ '/modelagem.html' | relative_url }}) para seguir os vínculos de horários, atividades e contas. No catálogo, as chaves estrangeiras levam diretamente à tabela relacionada.

Datas e horários em `activities` ficam em texto no formato ISO usado pela aplicação. Horários de aula em `school_time_slots` usam `time`, e timestamps de auditoria e último acesso usam `timestamptz`.

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

Em um banco local vazio, siga os passos em [Consultas SQL]({{ '/consultas.html' | relative_url }}). O script de instalação aplica as migrações na ordem acima.

[Ver arquivos SQL](https://github.com/Tech-2D/modelagem-dados/tree/main/sql/migrations) · [Rodar em um banco local](https://github.com/Tech-2D/modelagem-dados#rodar-o-sql-localmente) · [Consultas de exemplo](https://github.com/Tech-2D/modelagem-dados/blob/main/sql/examples/consultas.sql)
