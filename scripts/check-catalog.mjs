import { readFile } from 'node:fs/promises'
import assert from 'node:assert/strict'
const read = path => readFile(new URL('../' + path, import.meta.url), 'utf8')
const schema = JSON.parse(await read('docs/_data/schema.json'))
const notes = JSON.parse(await read('docs/_data/column_notes.json'))
const usage = JSON.parse(await read('docs/_data/table_usage.json'))
const catalog = [...(await read('docs/_data/catalog.yml')).matchAll(/^    - name: (\w+)$/gm)].map(m => m[1])
const names = schema.map(t => t.name)
assert.deepEqual([...catalog].sort(), [...names].sort(), 'O menu deve conter cada tabela uma única vez')
assert.deepEqual(Object.keys(usage).sort(), [...names].sort(), 'Toda tabela deve ter um uso documentado')
assert.deepEqual(Object.keys(notes).sort(), [...names].sort(), 'As notas devem corresponder às tabelas atuais')
let columns = 0
for (const table of schema) {
  assert.ok(usage[table.name].feature && usage[table.name].description.length > 80, table.name + ': explicar tela e serviço')
  for (const column of table.columns) {
    assert.ok(notes[table.name][column.name]?.length > 20, table.name + '.' + column.name + ': explicar a finalidade')
    assert.doesNotMatch(notes[table.name][column.name], /^Campo \w+ no contrato/, 'Substituir rótulo técnico por uma explicação')
    columns++
  }
  for (const ref of table.references) assert.ok(names.includes(ref.table), 'Referência a uma tabela retirada: ' + ref.table)
}
console.log(`Catálogo validado: ${schema.length} tabelas, ${columns} campos, todos com explicação.`)
