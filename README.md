# Modelagem de dados da Tech-2D

Documentação do PostgreSQL usado pela Agenda e pelo Cadê o professor, com as migrações do esquema `tech2d` e uma referência do cache legado em Redis. [Abrir site da documentação](https://tech-2d.github.io/modelagem-dados/)

| Conteúdo | Onde encontrar |
| --- | --- |
| Arquitetura e serviços de dados | [Visão geral](docs/index.md) |
| Tabelas, projeções, permissões e índices | [PostgreSQL](docs/postgresql.md) |
| Relações e fluxos dos dados | [Modelagem](docs/modelagem.md) |
| Exemplos de leitura SQL | [Consultas](docs/consultas.md) |
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

O repositório [Tech-2D/api](https://github.com/Tech-2D/api) é a fonte das migrações. Atualize primeiro o repositório da API, depois copie os scripts para `sql/migrations/`, inclua as novas versões em `sql/migrate.psql` na ordem numérica e atualize a documentação. Para regenerar os detalhes do catálogo, aplique as migrações em um banco local e rode:

```sh
psql -d tech2d_local -v ON_ERROR_STOP=1 -At -f sql/catalog.psql > docs/_data/schema.json
```

Inclua os novos objetos na área correspondente de `docs/_data/catalog.yml`. A cópia atual corresponde ao commit [`0988406`](https://github.com/Tech-2D/api/tree/09884068b73ef9641138a712d4da7c1f7fc0023c/migrations).

O site é gerado pelo GitHub Pages a partir de `docs/`. A organização das páginas foi inspirada no [Astro Database Workspace](https://github.com/Astro-Inter/astro-database).
