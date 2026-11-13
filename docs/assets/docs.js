const article = document.querySelector('.article')
const toc = document.querySelector('[data-toc]')
const headings = [...article.querySelectorAll('h2[id]')]
if (toc && headings.length > 1) {
  const list = toc.querySelector('ul')
  for (const heading of headings) {
    const item = document.createElement('li')
    const link = document.createElement('a')
    link.href = '#' + encodeURIComponent(heading.id)
    link.textContent = heading.textContent
    item.append(link)
    list.append(item)
  }
  toc.hidden = false
}

const controls = document.querySelector('[data-catalog-controls]')
if (controls) {
  const search = controls.querySelector('input')
  const area = controls.querySelector('select')
  const status = controls.querySelector('[data-catalog-status]')
  const toggle = controls.querySelector('[data-catalog-toggle]')
  const groups = [...article.querySelectorAll('[data-catalog-group]')]
  const normalize = text => text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase('pt-BR')
  const entries = new Map(groups.flatMap(group => [...group.querySelectorAll('[data-catalog-object]')]
    .map(item => [item, normalize(item.textContent)])))

  function filterCatalog() {
    const terms = normalize(search.value.trim()).split(/\s+/).filter(Boolean)
    let total = 0
    for (const group of groups) {
      const areaMatches = !area?.value || area.value === group.dataset.catalogGroup
      let groupTotal = 0
      for (const item of group.querySelectorAll('[data-catalog-object]')) {
        item.hidden = !areaMatches || !terms.every(term => entries.get(item).includes(term))
        if (!item.hidden) groupTotal += 1
      }
      group.hidden = groupTotal === 0
      if (!group.hidden) total += groupTotal
    }
    status.textContent = total === 0 ? 'Nenhum resultado. Tente outro termo.'
      : total === 1 ? '1 resultado' : total + ' resultados'
    updateToggle()
  }

  const expandable = item => item.querySelector('[data-catalog-expand]') || item
  const visibleEntries = () => [...entries.keys()].filter(item => !item.hidden).map(expandable)
  const cardLayout = [...entries.keys()].some(item => expandable(item) !== item)
  function updateToggle() {
    const visible = visibleEntries()
    toggle.disabled = visible.length === 0
    toggle.textContent = visible.length && visible.every(item => item.open)
      ? (cardLayout ? 'Fechar detalhes' : 'Fechar resultados')
      : (cardLayout ? 'Abrir detalhes' : 'Abrir resultados')
  }

  function openLinkedObject() {
    const target = document.getElementById(location.hash.slice(1))
    if (!entries.has(target)) return
    if (target.hidden || target.closest('[data-catalog-group]').hidden) {
      search.value = ''
      if (area) area.value = ''
      filterCatalog()
    }
    expandable(target).open = true
    target.scrollIntoView({ block: 'start' })
  }

  controls.hidden = false
  search.addEventListener('input', filterCatalog)
  area?.addEventListener('change', filterCatalog)
  toggle.addEventListener('click', () => {
    const visible = visibleEntries()
    const open = visible.some(item => !item.open)
    for (const item of visible) item.open = open
    updateToggle()
  })
  for (const item of entries.keys()) expandable(item).addEventListener('toggle', updateToggle)
  window.addEventListener('hashchange', openLinkedObject)
  filterCatalog()
  openLinkedObject()
}

if (navigator.clipboard) {
  for (const code of article.querySelectorAll('pre > code')) {
    const block = code.closest('pre')
    const button = document.createElement('button')
    const status = document.createElement('span')
    const toolbar = document.createElement('div')
    toolbar.className = 'code-toolbar'
    button.type = 'button'
    button.textContent = 'Copiar código'
    status.setAttribute('role', 'status')
    button.addEventListener('click', async () => {
      status.textContent = ''
      try {
        await navigator.clipboard.writeText(code.textContent)
        status.textContent = 'Copiado'
      } catch {
        status.textContent = 'Selecione o código para copiar.'
      }
    })
    toolbar.append(button, status)
    block.before(toolbar)
  }
}

// Mantém destacado o objeto aberto por um link do explorador.
function markExplorerObject() {
  for (const link of document.querySelectorAll('[data-object-link]')) {
    const url = new URL(link.href);
    const selected = url.pathname === location.pathname && url.hash === location.hash;
    if (selected) { link.setAttribute('aria-current', 'location'); link.closest('details').open = true; }
    else link.removeAttribute('aria-current');
  }
}
window.addEventListener('hashchange', markExplorerObject);
markExplorerObject();
