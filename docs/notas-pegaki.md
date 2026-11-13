---
layout: default
title: Notas do Pegaki
---

# Notas do Pegaki

A migration `023_notas_pegaki.sql` adiciona o caderno de notas privado ao PostgreSQL centralizado. O Firebase Authentication identifica a conta; a API obtém o UID do token validado, sem aceitar um proprietário pelo corpo da requisição.

| Objeto | Finalidade |
| --- | --- |
| `pegaki_disciplinas` | Catálogo de disciplinas com ID estável e série. |
| `pegaki_cadernos` | Conta, ano letivo, série, modos de entrada, versão da fórmula e controle de concorrência. |
| `pegaki_notas` | N1, N2, média informada e peso da N1 por disciplina e semestre. |
| `pegaki_recuperacoes` | Nota de recuperação final por disciplina. |
| `visao_pegaki_resultados` | Médias semestrais, média recuperada, anual, final, nota necessária e situação. |

Notas vazias são `NULL`, mantendo a distinção entre “sem nota” e zero. As notas variam de 0 a 10 com duas casas decimais; pesos variam de 10% a 90%, em passos de 5%. Chaves estrangeiras impedem misturar disciplinas e cadernos de séries diferentes.

A visão usa a regra `tech-2026-v1`, equivalente ao cálculo do Pegaki: média ponderada por semestre, segundo semestre com peso 2 na média anual, recuperação de média limitada a 7 e recuperação final com aprovação a partir de 6. O catálogo começa com as 18 disciplinas já disponíveis no segundo ano; as demais séries serão cadastradas quando suas listas forem definidas.

## Acesso e sincronização

`GET /api/pegaki?academicYear=2026&gradeYear=2` carrega o próprio caderno. `POST /api/pegaki` salva notas e modos em uma transação, exigindo `expectedVersion`. Uma versão desatualizada recebe HTTP 409, preservando o caderno já gravado por outra aba ou dispositivo.

As tabelas privadas têm Row Level Security. O usuário de runtime recebe apenas os privilégios necessários e configura `tech2d.uid` dentro da transação; esse contexto é descartado ao terminar a requisição. A visão usa `security_invoker`, preservando as mesmas políticas. Ela não integra o catálogo público nem o endpoint genérico de documentos.

Sem login, o Pegaki continua usando o armazenamento local. Depois do login, as notas da conta são carregadas separadamente; a pessoa pode importar as notas antigas do navegador e salvar na conta. Os PDFs permanecem no dispositivo: somente as notas extraídas são enviadas ao salvar.

## Uso futuro pela IA

A visão fornece dados estruturados e resultados reproduzíveis, com conta, ano letivo, disciplina e versão da regra. Esta mudança não envia notas a uma IA e não cria um acesso administrativo global. Uma integração futura deverá consultar a própria conta autenticada e definir o uso das notas de forma explícita.
