---
title: Modelagem
description: Acompanhe o caminho dos dados da aplicação até as tabelas de consulta.
---

## Horários dos professores

A tabela [Horários de aula]({{ '/postgresql.html#obj-horarios_aula' | relative_url }}) guarda o dia da semana e o estado ativo da aula. As quatro chaves estrangeiras apontam para nomes e horários reutilizados.

<div class="relation-map" aria-label="Relações dos horários de aula">
  <a class="relation-core" href="{{ '/postgresql.html#obj-horarios_aula' | relative_url }}"><strong>Horários de aula</strong><code>horarios_aula</code></a>
  <div class="relation-branches">
    {% assign schedules = site.data.schema | where: "name", "horarios_aula" | first %}
    {% assign schedule_group = site.data.catalog | where: "id", "horarios" | first %}
    {% for relation in schedules.references %}
    {% assign related = schedule_group.objects | where: "name", relation.table | first %}
    <a href="{{ '/postgresql.html' | relative_url }}#obj-{{ relation.table }}"><strong>{{ related.title }}</strong><code>{{ relation.table }}</code><small><code>{{ relation.column }}</code> → <code>{{ relation.target }}</code></small></a>
    {% endfor %}
  </div>
</div>

A visão [Catálogo de horários]({{ '/views.html#view-catalogo_horarios' | relative_url }}) reúne os nomes das referências, os horários e as colunas `andar` e `sala` da própria aula.

## Identidade e links

`registros_aplicacao.id` é um `bigint` gerado pelo banco. As tabelas de negócio usam `id_registro` para referenciá-lo. A API continua aceitando uma referência como `activities/ABC` para localizar uma atividade aberta por um link antigo. O banco separa o tipo `activities` e a referência `ABC` em colunas.

## Atividades e anexos

`atividades` guarda título, descrição, disciplina, turma, data e hora. Uma turma nula indica atividade geral. `anexos_atividade` guarda os metadados dos arquivos e sua ordem. Cada anexo aponta para a atividade por chave estrangeira.

`atividades.turma` usa a chave de turma da Agenda. `horarios_aula.id_turma` aponta para o identificador numérico do catálogo de aulas.

## Enquetes e conversas

`enquetes` guarda a pergunta, turma e situação. `opcoes_enquete` guarda uma linha por opção e sua ordem. Cada voto tem um identificador numérico, uma referência à enquete e o índice da opção. Mensagens sobre sugestões usam a mesma ligação entre registro pai e filho.

## Kanban

`espacos_kanban` identifica o proprietário e agrupa quadros pessoais ou compartilhados. Quadros, colunas, cartões e itens de checklist ficam em tabelas relacionadas. O vínculo entre cartão e coluna exige que os dois pertençam ao mesmo quadro. Participantes e pedidos de acesso ficam em tabelas próprias.

## Auditoria

Os eventos de auditoria guardam a ação, a autoria e o momento da alteração. `valores_historico` guarda os campos anteriores em linhas tipadas, com posição e vínculo com a auditoria. Isso preserva objetos e listas mesmo após a exclusão do registro original.

## Visitas e permissões

- [Visitas aos sites]({{ '/postgresql.html#obj-visitas_aos_sites' | relative_url }}) separa as visitas por site e deduplica acessos dentro de intervalos de 30 minutos.
- [Acessos recentes à Agenda]({{ '/postgresql.html#obj-acessos_recentes_agenda' | relative_url }}) e [Acessos recentes ao Cadê o professor]({{ '/postgresql.html#obj-acessos_recentes_professores' | relative_url }}) guardam o último acesso autenticado em cada site.
- [Perfis de acesso administrativo]({{ '/postgresql.html#obj-perfis_administrativos' | relative_url }}) guarda uma projeção do papel e da turma. A identidade da conta vem do Firebase Authentication.
- [Bloqueios de acesso à Agenda]({{ '/postgresql.html#obj-bloqueios_agenda' | relative_url }}) guarda os bloqueios por e-mail ou rede aplicados à Agenda.

Os vínculos de horários usam chaves estrangeiras no PostgreSQL. Os vínculos entre documentos, contas e atividades usam identificadores que a API valida.

## Histórico do Firestore

A exportação privada guarda a cópia original do Firestore. A tabela de arquivo e o esquema relacional foram retirados do Aiven. O processo está registrado no [Histórico do Firestore]({{ '/firestore-legado.html' | relative_url }}).
