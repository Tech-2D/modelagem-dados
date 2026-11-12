---
title: Schemas do PostgreSQL
description: Entenda onde ficam os dados da Tech-2D e os metadados do banco defaultdb.
---

Um schema organiza objetos de um mesmo banco. Em `tech2d.atividades`, `tech2d` é o schema e `atividades` é a tabela. Use o nome completo nas consultas para indicar qual objeto você quer acessar.

## Schemas do defaultdb

{% assign tables = site.data.schema | where: "kind", "table" %}

| Schema | Responsável | O que contém |
| --- | --- | --- |
| `tech2d` | Tech-2D | Dados da Agenda e do Cadê o professor. São {{ tables.size }} tabelas, {{ site.data.views.size }} views e a função que sincroniza os horários. |
| `public` | PostgreSQL | Schema padrão do banco. Na conferência do Aiven estava vazio. |
| `information_schema` | PostgreSQL | Metadados padronizados sobre tabelas, colunas, tipos e permissões visíveis à conta conectada. |
| `pg_catalog` | PostgreSQL | Catálogos internos com definições de tipos, funções, índices e outros objetos do servidor. |
| `_avnadmin_monitor` | Aiven | Função interna usada no monitoramento do serviço gerenciado. |

Inventário conferido no Aiven em 12/11/2026. Schemas internos de armazenamento e de sessões temporárias, como `pg_toast` e `pg_temp_*`, ficam fora do catálogo.

## Onde consultar a estrutura

<div class="doc-links">
  <a href="{{ '/postgresql.html' | relative_url }}"><strong>Tabelas e colunas</strong><span>Tipos, limites, chaves e finalidade dos campos do schema tech2d.</span></a>
  <a href="{{ '/views.html' | relative_url }}"><strong>Views da API</strong><span>Colunas que a API consulta e tabelas que fornecem os dados.</span></a>
</div>

## Estruturas aposentadas

O schema `legado_firestore` e a cópia bruta `tech2d.documentos_firestore` foram retirados. A migração 018 também removeu `estado_migracao` e `migracoes_esquema` com suas views. Os arquivos SQL no Git guardam o histórico, e o comentário de `tech2d` informa a versão instalada.
