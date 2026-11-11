# Modelagem de dados da Tech-2D

Documentação do PostgreSQL usado pela Agenda e pelo Cadê o professor, com as migrações do esquema `tech2d` e uma referência do cache legado em Redis. [Abrir site da documentação](https://tech-2d.github.io/modelagem-dados/)

| Conteúdo | Onde encontrar |
| --- | --- |
| Arquitetura e serviços de dados | [Visão geral](docs/index.md) |
| Tabelas, projeções, permissões e índices | [PostgreSQL](docs/postgresql.md) |
| Catálogos, chaves, TTL e invalidação | [Redis](docs/redis.md) |
| DDL utilizado pela API | [Migrações SQL](sql/migrations/) |
| Consultas para explorar o esquema | [Exemplos SQL](sql/examples/consultas.sql) |

## Rodar o SQL localmente

Com o PostgreSQL rodando na sua máquina e `psql` e `createdb` disponíveis, execute na raiz do clone:

```sh
createdb tech2d_local
psql -d tech2d_local -v ON_ERROR_STOP=1 --single-transaction -f sql/migrate.psql
psql -d tech2d_local -v ON_ERROR_STOP=1 -f sql/examples/consultas.sql
```

As migrações criam o esquema vazio. As consultas de negócio podem retornar zero linhas até você inserir dados de teste. Use o banco local criado acima para experimentar.

## Atualizar o espelho

A API em `professores/agenda-sql-api` é a fonte das migrações. Atualize primeiro o repositório da API, depois copie os scripts para `sql/migrations/`, inclua as novas versões em `sql/migrate.psql` na ordem numérica e atualize a documentação. A cópia atual corresponde ao commit [`56c9965`](https://github.com/Tech-2D/professores/tree/56c9965968fcff752fa66bd7487065e41a483590/agenda-sql-api/migrations).

O site é gerado pelo GitHub Pages a partir de `docs/`. A organização das páginas foi inspirada no [Astro Database Workspace](https://github.com/Astro-Inter/astro-database).
