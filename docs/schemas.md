---
title: Organização por áreas
description: Localize as tabelas da Agenda, dos professores, do Kanban e do Pegaki em um único banco.
---

Todas as tabelas da aplicação permanecem no schema `tech2d`, dentro do banco `defaultdb`. Não há uma divisão física por aplicativo. Em uma consulta como `tech2d.atividades`, o prefixo identifica onde a tabela está no PostgreSQL.

As áreas abaixo servem para navegar na documentação. Elas não criam schemas nem cópias das tabelas.

## Encontre as tabelas

<div class="doc-links">
{% for group in site.data.catalog %}
  <a href="{{ '/postgresql.html' | relative_url }}#{{ group.id }}"><strong>{{ group.name | escape }}</strong><span>{{ group.objects.size }} tabelas · {% for item in group.objects limit: 3 %}<code>{{ item.name }}</code>{% unless forloop.last %}, {% endunless %}{% endfor %}</span></a>
{% endfor %}
</div>

## Como as partes se conectam

- **Agenda:** atividades, anexos, avisos, sugestões, representantes e resumos por e-mail.
- **Cadê o professor:** horários de aula e os catálogos de professores, disciplinas, turmas e faixas de horário.
- **Kanban:** espaços, quadros, colunas, cartões, checklists, participantes e pedidos de acesso.
- **Pegaki:** disciplinas, cadernos, notas e recuperações. As notas são protegidas por conta com RLS.
- **Dados compartilhados:** perfis, identidade e versão dos registros, acessos, auditoria e controles dos serviços.

As tabelas podem se relacionar entre áreas por chaves estrangeiras. O [explorador de relações]({{ '/modelagem.html' | relative_url }}) mostra esses vínculos usando as definições do PostgreSQL.

## Tabelas, views e funções

As [tabelas]({{ '/postgresql.html' | relative_url }}) armazenam os dados em colunas tipadas. As [views]({{ '/views.html' | relative_url }}) reúnem os campos usados nas respostas da API. As [funções]({{ '/funcoes.html' | relative_url }}) executam operações como gravação, consulta de catálogos e expurgo. As [procedures]({{ '/procedures.html' | relative_url }}) têm uma página separada; o inventário informa se alguma estiver instalada.

O Worker autentica o usuário e verifica as permissões antes de executar essas operações com o papel limitado `tech2d_api`. O prefixo `tech2d` não concede acesso aos dados por si só.

## Simplificações aplicadas

A versão `036_expurgo_direto` está instalada no banco.

| Mudança | Estrutura atual |
| --- | --- |
| Acessos recentes da Agenda e dos professores | Uma tabela, `acessos_recentes`, com chave composta por `site` e `id_usuario`. O campo site também identifica os acessos do Pegaki. |
| Catálogo de matérias | O Pegaki reutiliza disciplinas; disciplinas_series associa matérias e séries sem repetir nomes. visao_disciplinas_pegaki preserva os rótulos usados pela interface. |
| Expurgo de atividades | O Worker exclui os anexos do R2 antes de remover a atividade e seus metadados do PostgreSQL. A rotina não cria cópias. |
| Auditoria da antiga rota de atividades | A tabela antiga foi retirada; as operações atuais usam `auditoria_aplicacao` e `valores_historico`. |
| Listas e agrupamentos | Foram removidos os marcadores `grupo` e `listas_presentes`. A ordem continua explícita nas tabelas filhas, e a API devolve listas vazias como `[]`. |

O histórico dos scripts fica no Git. A versão instalada fica no comentário de `tech2d`, sem uma tabela de controle de migrações. Os schemas internos do PostgreSQL e do Aiven pertencem ao serviço e não fazem parte das áreas da aplicação.

## Recurso retirado: enquetes

A versão 033 removeu as enquetes da Agenda, suas opções e votos e a aprovação de eleitores. As quatro tabelas e as funções exclusivas foram retiradas; os caminhos antigos da API recusam consultas e gravações. O quadro de avisos, as sugestões e suas conversas continuam disponíveis.

## Recurso retirado: anotações de estudo

A versão 034 removeu a tabela `anotacoes` do antigo Caderno Infinito, que estava vazia, e suas duas funções SQL exclusivas. O caminho `notebookNotes` foi retirado das permissões de leitura e gravação da API. Os cadernos, notas e recuperações do Pegaki continuam descritos no catálogo de notas escolares.
