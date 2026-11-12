---
title: Modelagem
description: Acompanhe o caminho dos dados da aplicação até as tabelas de consulta.
---

## Horários dos professores

A tabela [Horários de aula]({{ '/postgresql.html#obj-school_schedules' | relative_url }}) guarda o dia da semana e o estado ativo da aula. As quatro chaves estrangeiras apontam para nomes e horários reutilizados.

<div class="relation-map" aria-label="Relações dos horários de aula">
  <a class="relation-core" href="{{ '/postgresql.html#obj-school_schedules' | relative_url }}"><strong>Horários de aula</strong><code>school_schedules</code></a>
  <div class="relation-branches">
    {% assign schedules = site.data.schema | where: "name", "school_schedules" | first %}
    {% assign schedule_group = site.data.catalog | where: "id", "horarios" | first %}
    {% for relation in schedules.references %}
    {% assign related = schedule_group.objects | where: "name", relation.table | first %}
    <a href="{{ '/postgresql.html' | relative_url }}#obj-{{ relation.table }}"><strong>{{ related.title }}</strong><code>{{ relation.table }}</code><small><code>{{ relation.column }}</code> → <code>{{ relation.target }}</code></small></a>
    {% endfor %}
  </div>
</div>

A visão [Catálogo de horários]({{ '/postgresql.html#obj-school_schedule_catalog' | relative_url }}) reúne essas referências e os dados complementares de [Catálogos e dados complementares]({{ '/postgresql.html#obj-catalog_documents' | relative_url }}). É a leitura usada para montar o catálogo com professor, turma, disciplina, horário, sala e andar.

## Atividades e enquetes

O documento `activities/{id}` em [Documentos da aplicação]({{ '/postgresql.html#obj-app_documents' | relative_url }}) tem o mesmo ID da linha em [Atividades da Agenda]({{ '/postgresql.html#obj-activities' | relative_url }}). A API atualiza os dois na mesma transação. A projeção facilita buscar por data e turma. Atividades gerais têm `turma_id` nulo.

Enquetes e votos ficam em Documentos da aplicação, nos caminhos `polls/{id}` e `polls/{id}/votes/{uid}`. A API controla o acesso e a permissão de votar.

## Visitas e permissões

- [Visitas aos sites]({{ '/postgresql.html#obj-visitas_aos_sites' | relative_url }}) separa as visitas por site e deduplica acessos dentro de intervalos de 30 minutos.
- [Acessos recentes à Agenda]({{ '/postgresql.html#obj-acessos_recentes_agenda' | relative_url }}) e [Acessos recentes ao Cadê o professor]({{ '/postgresql.html#obj-professor_recent_users' | relative_url }}) guardam o último acesso autenticado em cada site.
- [Perfis de acesso administrativo]({{ '/postgresql.html#obj-admin_profiles' | relative_url }}) guarda uma projeção do papel e da turma. A identidade da conta vem do Firebase Authentication.
- [Bloqueios de acesso à Agenda]({{ '/postgresql.html#obj-agenda_blocks' | relative_url }}) guarda os bloqueios por e-mail ou rede aplicados à Agenda.

Os vínculos de horários usam chaves estrangeiras no PostgreSQL. Os vínculos entre documentos, contas e atividades usam identificadores que a API valida.
