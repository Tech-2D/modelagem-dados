---
title: Modelagem de dados
permalink: /
---

A Agenda e o Cadê o professor usam **PostgreSQL no Aiven** como banco de aplicação. O navegador consulta a API no **Cloudflare Workers**, que se conecta ao banco pelo **Hyperdrive**.

| Componente | Papel |
| --- | --- |
| PostgreSQL | Atividades, horários, turmas, avisos, perfis de acesso, automações e estatísticas |
| Firebase Authentication | Login e identidade da conta. A API verifica a identidade antes de aplicar as permissões |
| Cloudflare R2 | Arquivos anexados às atividades. O banco mantém os metadados e as referências |
| Redis | Cache de catálogos na implementação legada de consultas |
| Firestore | Origem histórica dos documentos preservados durante a migração |

<div class="doc-links">
  <a href="./postgresql.html"><strong>PostgreSQL</strong><span>Modelo, tabelas, índices e scripts executáveis</span></a>
  <a href="./redis.html"><strong>Redis</strong><span>Chaves, expiração e renovação do cache legado</span></a>
</div>

O catálogo atual atende consultas públicas de atividades, horários e atualizações. A API usa projeções do banco para retornar os campos permitidos. Gravações passam pela validação de permissões e pelas transações do PostgreSQL. O Worker de compatibilidade também encaminha os catálogos ao SQL na configuração atual.

[Código da API SQL](https://github.com/Tech-2D/professores/tree/main/agenda-sql-api) · [Repositório de modelagem](https://github.com/Tech-2D/modelagem-dados)
