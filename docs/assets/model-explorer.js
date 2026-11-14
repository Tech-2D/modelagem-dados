function normalize(value) {
  return value.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase('pt-BR')
}

function element(tag, text, className) {
  const item = document.createElement(tag)
  if (text) item.textContent = text
  if (className) item.className = className
  return item
}

function icon(name) {
  const ns = 'http://www.w3.org/2000/svg'
  const svg = document.createElementNS(ns, 'svg')
  const use = document.createElementNS(ns, 'use')
  svg.setAttribute('aria-hidden', 'true')
  svg.setAttribute('focusable', 'false')
  svg.setAttribute('class', 'docs-icon')
  use.setAttribute('href', '#icon-' + name)
  svg.append(use)
  return svg
}

function tag(label, style) {
  return element('span', label, 'schema-tag schema-tag-' + style)
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
  const usage = data('model-usage')
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
    const title = element('h3', outgoing ? 'Depende de' : 'Usado por tabelas')
    title.prepend(icon('link'))
    block.append(title)
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

  function schemaCard(table) {
    const card = element('section', '', 'schema-card')
    const header = element('header', '', 'schema-card-header')
    const heading = element('div')
    heading.append(element('h2', table.name), element('p', 'tech2d · ' + table.columns.length + ' colunas'))
    header.append(icon('table'), heading)
    if (table.foreign_key_count) header.append(tag(table.foreign_key_count + ' FK', 'fk'))
    const columns = element('ul', '', 'schema-columns')
    columns.setAttribute('aria-label', 'Colunas de ' + table.name)
    for (const column of table.columns) {
      const row = element('li', '', 'schema-column')
      const name = element('span', '', 'schema-column-name')
      const props = element('span', '', 'schema-column-properties')
      const primary = table.primary_key.includes(column.name)
      const foreign = table.references.some(ref => ref.column === column.name)
      if (primary || foreign) {
        const mark = element('span', '', primary ? 'column-key' : 'column-link')
        mark.append(icon(primary ? 'key' : 'link'))
        name.append(mark)
      }
      name.append(element('code', column.name))
      props.append(element('code', column.type.replace('character varying', 'varchar').replace('timestamp with time zone', 'timestamptz'), 'schema-column-type'))
      if (primary) props.append(tag('PK', 'pk'))
      if (foreign) props.append(tag('FK', 'fk'))
      if (column.unique) props.append(tag('UNIQUE', 'unique'))
      if (column.check) props.append(tag('CHECK', 'check'))
      if (column.generated) props.append(tag('IDENTITY', 'identity'))
      if (!column.nullable) props.append(tag('NOT NULL', 'required'))
      row.append(name, props)
      const note = notes[table.name]?.[column.name] || column.comment
      if (note) row.append(element('small', note, 'schema-column-note'))
      columns.append(row)
    }
    card.append(header)
    const feature = element('p', usage[table.name]?.feature, 'schema-feature')
    feature.prepend(icon('layers'))
    card.append(feature, element('p', usage[table.name]?.description || table.comment, 'schema-card-description'))
    card.append(columns)
    return card
  }

  function renderDetails() {
    const table = tableByName.get(selected)
    const catalogLink = element('a', 'Abrir no catálogo de tabelas', 'model-catalog-link')
    catalogLink.href = new URL('postgresql.html#obj-' + selected, location.href)
    catalogLink.append(icon('arrow'))
    const relations = element('div', '', 'model-relations')
    showRelationships(table, relations, 'out')
    showRelationships(table, relations, 'in')
    const related = viewUsage.get(selected)
    if (related.length) {
      const block = element('section', '', 'model-view-usage')
      const title = element('h3', 'Usado por views')
      title.prepend(icon('eye'))
      block.append(title)
      for (const name of related) {
        const link = element('a', name, 'model-object-link')
        link.href = new URL('views.html#view-' + name, location.href)
        block.append(link)
      }
      relations.append(block)
    }
    details.replaceChildren(schemaCard(table), catalogLink, relations)
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
