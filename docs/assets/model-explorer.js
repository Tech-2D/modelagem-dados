function normalize(value) {
  return value.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase('pt-BR')
}

function element(tag, text, className) {
  const item = document.createElement(tag)
  if (text) item.textContent = text
  if (className) item.className = className
  return item
}

function data(id) {
  return JSON.parse(document.getElementById(id).textContent)
}

function tableHash(name) {
  return '#tabela=' + encodeURIComponent(name)
}

function tableLink(name) {
  const link = element('a', name, 'model-object-link')
  link.href = tableHash(name)
  return link
}

function shortestPath(graph, start, end) {
  const parents = new Map([[start, null]])
  const queue = [start]
  for (const name of queue) {
    if (name === end) {
      const result = []
      for (let node = end; node !== null; node = parents.get(node)) result.unshift(node)
      return result
    }
    for (const next of graph.get(name)) {
      if (parents.has(next)) continue
      parents.set(next, name)
      queue.push(next)
    }
  }
  return []
}

function initialize(explorer) {
  const tables = data('model-schema').filter(object => object.kind === 'table')
  const groups = data('model-groups')
  const views = data('model-views')
  const notes = data('model-notes')
  const areaByTable = new Map(groups.flatMap(group => group.objects.map(item => [item.name, group])))
  const tableByName = new Map(tables.map(table => [table.name, table]))
  const graph = new Map(tables.map(table => [table.name, new Set()]))
  const incoming = new Map(tables.map(table => [table.name, []]))
  const viewUsage = new Map(tables.map(table => [table.name, []]))
  for (const table of tables) {
    for (const reference of table.references) {
      if (!tableByName.has(reference.table)) continue
      incoming.get(reference.table).push({ source: table.name, ...reference })
      graph.get(table.name).add(reference.table)
      graph.get(reference.table).add(table.name)
    }
  }
  for (const view of views) {
    for (const dependency of view.dependencies) viewUsage.get(dependency)?.push(view.name)
  }

  const find = name => explorer.querySelector('[data-model-' + name + ']')
  const search = find('search')
  const area = find('area')
  const list = find('list')
  const result = find('result')
  const details = find('details')
  const destination = find('destination')
  const route = find('route')
  const clear = find('clear')
  const path = find('path')
  const defaultTable = tableByName.has('horarios_aula') ? 'horarios_aula' : tables[0].name
  const titles = new Map(groups.flatMap(group => group.objects.map(item => [item.name, item.title])))
  const searchIndex = new Map(tables.map(table => [
    table.name, normalize([table.name, titles.get(table.name), table.comment, ...table.columns.map(column => column.name)].join(' ')),
  ]))
  let selected

  function renderList() {
    const terms = normalize(search.value.trim()).split(/\s+/).filter(Boolean)
    const matches = tables.filter(table => (!area.value || areaByTable.get(table.name)?.id === area.value)
      && terms.every(term => searchIndex.get(table.name).includes(term)))
    result.textContent = matches.length === 1 ? '1 tabela' : matches.length + ' tabelas'
    list.replaceChildren()
    if (!matches.length) {
      list.append(element('p', 'Nenhuma tabela encontrada.', 'model-empty'))
      return
    }
    for (const table of matches) {
      const link = tableLink(table.name)
      if (table.name === selected) link.setAttribute('aria-current', 'location')
      list.append(link)
    }
  }

  function showRelationships(table, panel, direction) {
    const block = element('section', '', 'model-relation-block')
    const outgoing = direction === 'out'
    const references = outgoing ? table.references : incoming.get(table.name)
    block.append(element('h3', outgoing ? 'Depende de' : 'Usado por tabelas'))
    if (!references.length) block.append(element('p', 'Nenhuma chave estrangeira nesta direção.', 'model-empty'))
    for (const ref of references) {
      const item = element('div', '', 'model-relation')
      item.append(tableLink(outgoing ? ref.table : ref.source))
      const source = outgoing ? ref.column : ref.source + '.' + ref.column
      const target = outgoing ? ref.table + '.' + ref.target : ref.target
      item.append(element('code', source + ' → ' + target))
      block.append(item)
    }
    panel.append(block)
  }

  function showColumns(table) {
    const wrap = element('div', '', 'model-columns')
    const grid = element('table', '', 'dictionary-table')
    const caption = element('caption', 'Colunas de ' + table.name, 'visually-hidden')
    const headings = grid.createTHead().insertRow()
    grid.prepend(caption)
    for (const title of ['Coluna', 'Tipo', 'Finalidade']) {
      const th = element('th', title)
      th.scope = 'col'
      headings.append(th)
    }
    const body = grid.createTBody()
    for (const column of table.columns) {
      const row = body.insertRow()
      const name = element('th')
      name.scope = 'row'
      const qualities = []
      if (table.primary_key.includes(column.name)) qualities.push('PK')
      if (table.references.some(ref => ref.column === column.name)) qualities.push('FK')
      if (column.generated) qualities.push('Gerada pelo banco')
      qualities.push(column.nullable ? 'Aceita nulo' : 'Obrigatória')
      name.append(element('code', column.name), element('small', qualities.join(' · '), 'column-null'))
      row.append(name)
      row.insertCell().append(element('code', column.type.replace('character varying', 'varchar').replace('timestamp with time zone', 'timestamptz')))
      row.insertCell().textContent = notes[table.name]?.[column.name] || column.comment || 'Sem descrição registrada.'
    }
    wrap.append(grid)
    return wrap
  }

  function renderDetails() {
    const table = tableByName.get(selected)
    const header = element('header', '', 'model-table-header')
    header.append(element('span', areaByTable.get(selected)?.name || 'PostgreSQL', 'model-area-label'),
      element('h2', titles.get(selected) || selected), element('code', 'tech2d.' + selected))
    if (table.comment) header.append(element('p', table.comment))
    const catalogLink = element('a', 'Abrir no catálogo de tabelas')
    catalogLink.href = new URL('postgresql.html#obj-' + selected, location.href)
    header.append(catalogLink)
    const relations = element('div', '', 'model-relations')
    showRelationships(table, relations, 'out')
    showRelationships(table, relations, 'in')
    const related = viewUsage.get(selected)
    if (related.length) {
      const block = element('section', '', 'model-view-usage')
      block.append(element('h3', 'Usado por views'))
      for (const name of related) {
        const link = element('a', name, 'model-object-link')
        link.href = new URL('views.html#view-' + name, location.href)
        block.append(link)
      }
      relations.append(block)
    }
    details.replaceChildren(header, relations, showColumns(table))
  }

  function clearPath() {
    path.replaceChildren()
    clear.hidden = true
  }

  function selectFromHash() {
    const name = new URLSearchParams(location.hash.slice(1)).get('tabela')
    selected = tableByName.has(name) ? name : defaultTable
    if (destination.value === selected) destination.value = ''
    Array.from(destination.options).forEach(option => { option.disabled = option.value === selected })
    route.disabled = !destination.value
    clearPath()
    renderList()
    renderDetails()
  }

  destination.add(new Option('Escolher tabela de destino', ''))
  for (const table of tables) destination.add(new Option(table.name, table.name))
  search.addEventListener('input', renderList)
  area.addEventListener('change', renderList)
  destination.addEventListener('change', () => {
    route.disabled = !destination.value
    clearPath()
  })
  route.addEventListener('click', () => {
    const chain = shortestPath(graph, selected, destination.value)
    path.replaceChildren()
    clear.hidden = false
    if (!chain.length) {
      path.append(element('p', 'Não há caminho por chaves estrangeiras entre essas tabelas.', 'model-empty'))
      return
    }
    const count = chain.length - 1
    const steps = element('ol', '', 'model-path')
    for (const name of chain) {
      const step = element('li')
      step.append(tableLink(name))
      steps.append(step)
    }
    path.append(element('p', count + (count === 1 ? ' vínculo por chave estrangeira' : ' vínculos por chaves estrangeiras')), steps)
  })
  clear.addEventListener('click', () => {
    destination.value = ''
    route.disabled = true
    clearPath()
    destination.focus()
  })
  window.addEventListener('hashchange', selectFromHash)
  selectFromHash()
  explorer.hidden = false
}

const explorer = document.querySelector('[data-model-explorer]')
if (explorer) initialize(explorer)
