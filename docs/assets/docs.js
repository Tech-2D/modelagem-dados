const article = document.querySelector('.article')
const toc = document.querySelector('[data-toc]')
const headings = [...article.querySelectorAll('h2[id]')]
if (headings.length > 1) {
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
  const groups = [...article.querySelectorAll('[data-catalog-group]')]
  const normalize = text => text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase('pt-BR')
  const entries = new Map(groups.flatMap(group => [...group.querySelectorAll('[data-catalog-object]')]
    .map(item => [item, normalize(item.textContent)])))

  function filterCatalog() {
    const terms = normalize(search.value.trim()).split(/\s+/)
    let total = 0
    for (const group of groups) {
      let groupTotal = 0
      for (const item of group.querySelectorAll('[data-catalog-object]')) {
        item.hidden = !terms.every(term => entries.get(item).includes(term))
        if (!item.hidden) groupTotal += 1
      }
      group.hidden = groupTotal === 0 || Boolean(area.value && area.value !== group.dataset.catalogGroup)
      if (!group.hidden) total += groupTotal
    }
    status.textContent = total === 0 ? 'Nenhum objeto encontrado. Tente outro termo ou área.'
      : total === 1 ? '1 objeto encontrado' : total + ' objetos encontrados'
  }

  function openLinkedObject() {
    const target = document.getElementById(location.hash.slice(1))
    if (!entries.has(target)) return
    if (target.hidden || target.closest('[data-catalog-group]').hidden) {
      search.value = ''
      area.value = ''
      filterCatalog()
    }
    target.open = true
    target.scrollIntoView({ block: 'start' })
  }

  controls.hidden = false
  search.addEventListener('input', filterCatalog)
  area.addEventListener('change', filterCatalog)
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
