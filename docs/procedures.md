---
title: Procedures SQL
description: Consulte as procedures do schema tech2d e seus parâmetros.
---

{% assign procedures = site.data.routines | where: "procedure", true %}
Procedures são rotinas executadas com <code>CALL</code>.

{% if procedures.size > 0 %}
{% include routine-list.html routines=procedures search_label="Buscar procedure" placeholder="Nome ou parâmetro da procedure" %}
{% else %}
<p class="catalog-overview">Nenhuma procedure cadastrada no schema <code>tech2d</code>.</p>
{% endif %}
