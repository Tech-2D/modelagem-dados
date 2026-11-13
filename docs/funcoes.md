---
title: Funções SQL
description: Consulte os parâmetros e o retorno das funções do schema tech2d.
---

{% assign functions = site.data.routines | where: "procedure", false %}
O catálogo tem {{ functions.size }} funções do PostgreSQL. As funções com prefixo <code>ler_</code> consultam dados. As funções com prefixos <code>gravar_</code> e <code>inserir_</code> registram valores nas tabelas.

{% include routine-list.html routines=functions search_label="Buscar função" placeholder="Ex.: arquivar, catálogo, kanban" %}
