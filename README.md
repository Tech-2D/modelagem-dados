# Modelagem de dados da Tech-2D

Documentação do PostgreSQL usado pela Agenda e pelo Cadê o professor, com as migrações do esquema `tech2d` e a integração do cache de catálogos públicos em Redis. [Abrir site da documentação](https://tech-2d.github.io/database/)

| Conteúdo | Onde encontrar |
| --- | --- |
| Arquitetura e serviços de dados | [Visão geral](docs/index.md) |
| Tabelas, colunas, tipos e chaves | [PostgreSQL](docs/postgresql.md) |
| Áreas do sistema e simplificações aplicadas | [Organização por áreas](docs/schemas.md) |
| Views, colunas e origem dos dados | [Views da API](docs/views.md) |
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

As migrações criam o esquema vazio. A versão atual fica no comentário do schema. As consultas de negócio podem retornar zero linhas até você inserir dados de teste. Use o banco local criado acima para experimentar.

## Atualizar o espelho

O repositório [Tech-2D/api](https://github.com/Tech-2D/api) é a fonte das migrações. Atualize primeiro o repositório da API, depois copie os scripts para `sql/migrations/`, inclua as novas versões em `sql/migrate.psql` na ordem numérica e atualize a documentação. Para regenerar os detalhes do catálogo, aplique as migrações em um banco local e rode:

```sh
psql -d tech2d_local -v ON_ERROR_STOP=1 -At -f sql/catalog.psql > docs/_data/schema.json
```

Inclua o título em português em `docs/_data/catalog.yml` e descreva a função do objeto com `COMMENT ON` na migração. O catálogo extrai a descrição das tabelas dos comentários do PostgreSQL. Mantenha a finalidade dos campos em `docs/_data/column_notes.json` e o inventário de views em `docs/_data/views.json`. O catálogo corresponde ao esquema PostgreSQL após a migration 032; as migrations anteriores ficam preservadas como histórico.

O site é gerado pelo GitHub Pages a partir de `docs/`. A organização das páginas foi inspirada no [Astro Database Workspace](https://github.com/Astro-Inter/astro-database).


## Atualizar o estilo do site

A documentação usa Tailwind CSS 4.3.5 para o layout responsivo. A folha pronta fica em `docs/assets/docs.css`, servida estaticamente pelo GitHub Pages. Depois de alterar `src/styles.css` ou as classes dos templates, gere o arquivo compilado e inclua-o no commit:

```sh
npm ci
npm run build:css
```


## Objetos no menu lateral

O explorador usa os inventários de `docs/_data/schema.json`, `views.json` e `routines.json` para gerar grupos, contagens e links. Ao adicionar uma tabela ou view, atualize o inventário correspondente. Para regenerar as funções e procedures após uma migration:

```sh
psql -d tech2d_local -v ON_ERROR_STOP=1 -At -f sql/routines.psql > docs/_data/routines.json
```

As âncoras das rotinas usam nome e assinatura, mantendo os links estáveis quando novos objetos são incluídos.

## Notas do Pegaki

A [modelagem de notas](docs/notas-pegaki.md) descreve os cadernos, notas e recuperações privados, o catálogo compartilhado e a visão de resultados, com RLS e fórmulas versionadas para futuras análises. A migration 024 foi aplicada ao PostgreSQL centralizado em 13/11/2026. O cálculo e o isolamento por conta foram conferidos no banco real assumindo o papel limitado da API em uma transação revertida.

## Finalidade das tabelas e dos campos

Cada card do catálogo e do explorador apresenta onde a tabela é usada no sistema. O arquivo `docs/_data/table_usage.json` mantém a área e a descrição desse uso. `docs/_data/column_notes.json` explica a finalidade de cada campo. Ao alterar o inventário, atualize as duas fontes para que uma tabela ou coluna nova não apareça sem explicação.

Todas as tabelas permanecem em `tech2d`. As áreas do site organizam a navegação; não são schemas separados. A versão 032 consolida os acessos dos três sites e reutiliza o catálogo geral de disciplinas no Pegaki. As migrations 029 e 030 preparam a compatibilidade; publique a API atualizada antes de aplicar 031 e 032.

Antes de publicar a documentação, confira a cobertura e gere o CSS:

```sh
npm run check
npm run build:css
```
