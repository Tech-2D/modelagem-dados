---
title: Modelagem
description: Acompanhe o caminho dos dados da aplicação até as tabelas de consulta.
---

## Horários dos professores

A tabela [`school_schedules`]({{ '/postgresql.html#obj-school_schedules' | relative_url }}) guarda o dia da semana e o estado ativo da aula. As quatro chaves estrangeiras apontam para nomes e horários reutilizados.

<div class="relation-map" aria-label="Relações de school_schedules">
  <a class="relation-core" href="{{ '/postgresql.html#obj-school_schedules' | relative_url }}"><code>school_schedules</code><small>Uma linha por aula</small></a>
  <div class="relation-branches">
    {% assign schedules = site.data.schema | where: "name", "school_schedules" | first %}
    {% for relation in schedules.references %}
    <a href="{{ '/postgresql.html' | relative_url }}#obj-{{ relation.table }}"><span><code>{{ relation.column }}</code> → <code>{{ relation.target }}</code></span><strong>{{ relation.table }}</strong></a>
    {% endfor %}
  </div>
</div>

A view [`school_schedule_catalog`]({{ '/postgresql.html#obj-school_schedule_catalog' | relative_url }}) reúne essas referências e os dados complementares de [`catalog_documents`]({{ '/postgresql.html#obj-catalog_documents' | relative_url }}). É a leitura usada para montar o catálogo com professor, turma, disciplina, horário, sala e andar.

## Atividades e enquetes

O documento `activities/{id}` em [`app_documents`]({{ '/postgresql.html#obj-app_documents' | relative_url }}) tem o mesmo ID da linha em [`activities`]({{ '/postgresql.html#obj-activities' | relative_url }}). A API atualiza os dois na mesma transação. A projeção facilita buscar por data e turma. Atividades gerais têm `turma_id` nulo.

Enquetes e votos ficam em `app_documents`, nos caminhos `polls/{id}` e `polls/{id}/votes/{uid}`. A API controla o acesso e a permissão de votar.

## Visitas e permissões

- [`site_visits`]({{ '/postgresql.html#obj-site_visits' | relative_url }}) separa as visitas por site e deduplica acessos dentro de intervalos de 30 minutos.
- [`agenda_recent_users`]({{ '/postgresql.html#obj-agenda_recent_users' | relative_url }}) e [`professor_recent_users`]({{ '/postgresql.html#obj-professor_recent_users' | relative_url }}) guardam o último acesso autenticado em cada site.
- [`admin_profiles`]({{ '/postgresql.html#obj-admin_profiles' | relative_url }}) guarda uma projeção do papel e da turma. A identidade da conta vem do Firebase Authentication.
- [`agenda_blocks`]({{ '/postgresql.html#obj-agenda_blocks' | relative_url }}) guarda os bloqueios por e-mail ou rede aplicados à Agenda.

Os vínculos de horários usam chaves estrangeiras no PostgreSQL. Os vínculos entre documentos, contas e atividades usam identificadores que a API valida.
