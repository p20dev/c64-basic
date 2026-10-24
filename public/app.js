const library = document.querySelector('#library');
const player = document.querySelector('#player');
const status = document.querySelector('#status');
const programsElement = document.querySelector('#programs');
const refreshButton = document.querySelector('#refresh');
const searchInput = document.querySelector('#search');
const categoryFilter = document.querySelector('#category-filter');
const languageFilter = document.querySelector('#language-filter');
const sortOrder = document.querySelector('#sort-order');
const resetFiltersButton = document.querySelector('#reset-filters');
const gridViewButton = document.querySelector('#grid-view');
const listViewButton = document.querySelector('#list-view');
const sourceModal = document.querySelector('#source-modal');
const sourceTitle = document.querySelector('#source-title');
const sourceKind = document.querySelector('#source-kind');
const sourceStatus = document.querySelector('#source-status');
const sourceCode = document.querySelector('#source-code');
const programBadges = document.querySelector('#program-badges');
const programDescription = document.querySelector('#program-description');
const programReleaseDate = document.querySelector('#program-release-date');
const programControls = document.querySelector('#program-controls');
const programSentinel = document.querySelector('#program-sentinel');
let allPrograms = [];
let filteredPrograms = [];
let visibleProgramCount = 0;
const PROGRAM_BATCH_SIZE = 12;
let programObserver;

const categoryMeta = {
  Arcade: '🎮', Creative: '✎', Demo: '✦', Dice: '⚄', Educational: '⌁',
  Logic: '◆', Memory: '◫', Music: '♪', Puzzle: '⌘', Reflex: '⚡',
  Simulation: '⚙', Strategy: '♟', Trivia: '?', Utility: '⚒', Word: 'Aa'
};

const languageLabels = {
  basic: 'BASIC',
  'machine-code': 'Machine Code'
};

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function categoryFromRoute() {
  const match = location.pathname.match(/^\/category\/([a-z0-9]+(?:-[a-z0-9]+)*)\/?$/);
  return match?.[1] || '';
}

function createCategoryPill(category) {
  const iconName = categoryMeta[category] || '●';
  const pill = document.createElement('a');
  pill.className = 'category-pill';
  pill.href = `/category/${slugify(category)}`;
  const icon = document.createElement('span');
  icon.setAttribute('aria-hidden', 'true');
  icon.textContent = iconName;
  const label = document.createElement('span');
  label.textContent = category;
  pill.append(icon, label);
  pill.setAttribute('aria-label', `Show all ${category} programs`);
  return pill;
}

function createLanguageBadge(language) {
  const badge = document.createElement('span');
  badge.className = `language-badge language-${language}`;
  badge.textContent = languageLabels[language] || language;
  return badge;
}

function createKeyGroup(keys) {
  const group = document.createElement('span');
  group.className = 'key-group';
  for (const keyName of keys) {
    const key = document.createElement('kbd');
    key.textContent = keyName;
    group.append(key);
  }
  return group;
}

function searchText(program) {
  const controls = program.controls.flatMap(control => [...control.keys, control.description]);
  return `${program.title} ${program.description} ${program.category} ${languageLabels[program.language]} ${controls.join(' ')}`.toLowerCase();
}

function formatReleaseDate(value) {
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${value}T00:00:00Z`));
}

function createProgramCard(program) {
    const card = document.createElement('article');
    card.className = 'program-card';
    const programUrl = `/program/${encodeURIComponent(program.slug)}`;
    card.addEventListener('click', event => {
      if (!event.target.closest('a, button')) location.href = programUrl;
    });

    const badges = document.createElement('div');
    badges.className = 'card-badges';
    badges.append(createCategoryPill(program.category), createLanguageBadge(program.language));

    const screenshot = document.createElement('div');
    screenshot.className = 'card-screenshot';
    if (program.screenshot) {
      const image = document.createElement('img');
      image.src = program.screenshot;
      image.alt = `${program.title} running on a Commodore 64`;
      image.loading = 'lazy';
      image.decoding = 'async';
      screenshot.append(image);
    } else {
      screenshot.classList.add('placeholder');
      screenshot.innerHTML = '<span aria-hidden="true">C64</span><span class="sr-only">Screenshot not yet available</span>';
    }

    const title = document.createElement('h2');
    title.className = 'program-title';
    title.textContent = program.title;

    const description = document.createElement('p');
    description.className = 'program-description';
    description.textContent = program.description;

    const releaseDate = document.createElement('p');
    releaseDate.className = 'release-date';
    releaseDate.textContent = `Released ${formatReleaseDate(program.releaseDate)}`;

    const actions = document.createElement('div');
    actions.className = 'program-actions';
    const run = document.createElement('a');
    run.className = 'card-action';
    run.href = programUrl;
    run.innerHTML = '<span class="play-icon" aria-hidden="true">▶</span><span>Run</span>';
    const source = document.createElement('button');
    source.className = 'card-action';
    source.type = 'button';
    source.innerHTML = '<span class="code-icon" aria-hidden="true">&lt;/&gt;</span><span>Source</span>';
    source.disabled = !program.source;
    source.addEventListener('click', () => showSource(program));
    actions.append(run, source);
    card.append(screenshot, badges, title, description, releaseDate, actions);
    return card;
}

function appendProgramBatch() {
  const nextCount = Math.min(visibleProgramCount + PROGRAM_BATCH_SIZE, filteredPrograms.length);
  const fragment = document.createDocumentFragment();
  for (const program of filteredPrograms.slice(visibleProgramCount, nextCount)) fragment.append(createProgramCard(program));
  programsElement.append(fragment);
  visibleProgramCount = nextCount;
  programSentinel.hidden = visibleProgramCount >= filteredPrograms.length;
  status.className = 'status';
  status.textContent = `${filteredPrograms.length} matching ${filteredPrograms.length === 1 ? 'program' : 'programs'}`;
}

function observeProgramSentinel() {
  programObserver.disconnect();
  if (!programSentinel.hidden) requestAnimationFrame(() => programObserver.observe(programSentinel));
}

function loadBatchNearViewport() {
  if (programSentinel.hidden || visibleProgramCount >= filteredPrograms.length) return;
  if (programSentinel.getBoundingClientRect().top <= window.innerHeight + 500) appendProgramBatch();
}

function updateFilterIndicators() {
  searchInput.classList.toggle('active-filter', searchInput.value.trim() !== '');
  categoryFilter.classList.toggle('active-filter', categoryFilter.value !== '');
  languageFilter.classList.toggle('active-filter', languageFilter.value !== '');
  resetFiltersButton.classList.toggle('filters-active', Boolean(
    searchInput.value.trim() || categoryFilter.value || languageFilter.value
  ));
}

function renderPrograms() {
  const query = searchInput.value.trim().toLowerCase();
  const selectedCategory = categoryFilter.value;
  const selectedLanguage = languageFilter.value;
  updateFilterIndicators();
  filteredPrograms = allPrograms
    .filter(program => !selectedCategory || program.category === selectedCategory)
    .filter(program => !selectedLanguage || program.language === selectedLanguage)
    .filter(program => !query || searchText(program).includes(query))
    .sort((left, right) => {
      if (sortOrder.value === 'category') return left.category.localeCompare(right.category) || left.title.localeCompare(right.title);
      if (sortOrder.value === 'newest') return right.releaseDate.localeCompare(left.releaseDate) || left.title.localeCompare(right.title);
      if (sortOrder.value === 'oldest') return left.releaseDate.localeCompare(right.releaseDate) || left.title.localeCompare(right.title);
      return left.title.localeCompare(right.title);
    });

  programsElement.replaceChildren();
  visibleProgramCount = 0;
  appendProgramBatch();
  observeProgramSentinel();
}

async function showSource(program) {
  sourceTitle.textContent = program.title;
  sourceKind.textContent = program.language === 'machine-code' ? 'Assembly source' : 'BASIC V2 source';
  sourceStatus.hidden = false;
  sourceStatus.className = 'status';
  sourceStatus.textContent = 'Loading source…';
  sourceCode.hidden = true;
  sourceCode.querySelector('code').textContent = '';
  sourceModal.showModal();
  try {
    const response = await fetch(`/api/source?path=${encodeURIComponent(program.path)}`, { cache: 'no-store' });
    if (!response.ok) throw new Error('The program source could not be loaded.');
    sourceCode.querySelector('code').textContent = await response.text();
    sourceStatus.hidden = true;
    sourceCode.hidden = false;
  } catch (error) {
    sourceStatus.className = 'status error';
    sourceStatus.textContent = error.message;
  }
}

function populateFilters(programs) {
  const categories = [...new Set(programs.map(program => program.category))].sort();
  categoryFilter.replaceChildren(new Option('All categories', ''), ...categories.map(category => new Option(category, category)));
  const routeSlug = categoryFromRoute();
  const routeCategory = categories.find(category => slugify(category) === routeSlug);
  if (routeCategory) categoryFilter.value = routeCategory;
  else categoryFilter.value = '';
}

async function loadPrograms() {
  status.hidden = false;
  status.className = 'status';
  status.textContent = 'Loading programs…';
  refreshButton.disabled = true;
  try {
    const response = await fetch('/api/programs', { cache: 'no-store' });
    if (!response.ok) throw new Error('The program list could not be loaded.');
    const { programs } = await response.json();
    allPrograms = programs;
    populateFilters(programs);
    renderPrograms();
  } catch (error) {
    status.className = 'status error';
    status.textContent = error.message;
  } finally {
    refreshButton.disabled = false;
  }
}

function renderProgramDetails(program) {
  programBadges.replaceChildren(createCategoryPill(program.category), createLanguageBadge(program.language));
  programDescription.textContent = program.description;
  programReleaseDate.textContent = `Released ${formatReleaseDate(program.releaseDate)}`;
  programControls.replaceChildren();
  for (const control of program.controls) {
    const row = document.createElement('div');
    row.className = 'control-row';
    const description = document.createElement('span');
    description.textContent = control.description;
    row.append(createKeyGroup(control.keys), description);
    programControls.append(row);
  }
}

function startEmulator(program) {
  library.hidden = true;
  player.hidden = false;
  document.title = `${program.title} — C64 Program Collection`;
  document.querySelector('#program-title').textContent = program.title;
  renderProgramDetails(program);

  window.EJS_player = '#game';
  window.EJS_core = 'vice_x64sc';
  window.EJS_gameUrl = `/api/program?path=${encodeURIComponent(program.path)}`;
  window.EJS_gameName = program.path.split('/').at(-1);
  window.EJS_pathtodata = 'https://cdn.emulatorjs.org/stable/data/';
  window.EJS_startOnLoaded = true;
  window.EJS_language = 'en-US';
  window.EJS_defaultOptions = {
    menubarBehavior: 'anywhere',
    keyboardInput: 'enabled',
    lockMouse: 'disabled'
  };

  const loader = document.createElement('script');
  loader.src = `${window.EJS_pathtodata}loader.js`;
  loader.onerror = () => {
    const message = document.querySelector('#emulator-error');
    message.hidden = false;
    message.textContent = 'The WASM VICE emulator could not be downloaded. Check your connection and try again.';
  };
  document.body.append(loader);
}

async function loadProgramPage(slug) {
  library.hidden = true;
  player.hidden = false;
  try {
    const response = await fetch('/api/programs', { cache: 'no-store' });
    if (!response.ok) throw new Error('The program list could not be loaded.');
    const { programs } = await response.json();
    const program = programs.find(entry => entry.slug === slug);
    if (!program) throw new Error('This program does not exist.');
    startEmulator(program);
  } catch (error) {
    const message = document.querySelector('#emulator-error');
    message.hidden = false;
    message.textContent = error.message;
  }
}

function setCategory(category) {
  categoryFilter.value = category;
  const url = category ? `/category/${slugify(category)}` : '/';
  history.pushState({}, '', url);
  renderPrograms();
}

function resetFilters() {
  searchInput.value = '';
  categoryFilter.value = '';
  languageFilter.value = '';
  sortOrder.value = 'newest';
  if (location.pathname !== '/') history.pushState({}, '', '/');
  renderPrograms();
}

refreshButton.addEventListener('click', loadPrograms);
resetFiltersButton.addEventListener('click', resetFilters);
searchInput.addEventListener('input', renderPrograms);
categoryFilter.addEventListener('change', () => setCategory(categoryFilter.value));
languageFilter.addEventListener('change', renderPrograms);
sortOrder.addEventListener('change', renderPrograms);
gridViewButton.addEventListener('click', () => setView('grid'));
listViewButton.addEventListener('click', () => setView('list'));
document.querySelector('#close-source').addEventListener('click', () => sourceModal.close());
sourceModal.addEventListener('click', event => {
  if (event.target === sourceModal) sourceModal.close();
});
window.addEventListener('popstate', () => {
  if (!library.hidden) {
    populateFilters(allPrograms);
    renderPrograms();
  }
});

programObserver = new IntersectionObserver(entries => {
  if (entries.some(entry => entry.isIntersecting) && visibleProgramCount < filteredPrograms.length) appendProgramBatch();
}, { rootMargin: '500px 0px' });
window.addEventListener('scroll', loadBatchNearViewport, { passive: true });
window.addEventListener('resize', loadBatchNearViewport);

function setView(view) {
  const list = view === 'list';
  programsElement.classList.toggle('list-view', list);
  gridViewButton.classList.toggle('active', !list);
  listViewButton.classList.toggle('active', list);
  gridViewButton.setAttribute('aria-pressed', String(!list));
  listViewButton.setAttribute('aria-pressed', String(list));
  localStorage.setItem('program-view', view);
}

setView(localStorage.getItem('program-view') === 'list' ? 'list' : 'grid');
const legacyProgramPath = new URLSearchParams(location.search).get('program');
const programPage = location.pathname.match(/^\/program\/([a-z0-9]+(?:-[a-z0-9]+)*)\/?$/);
if (legacyProgramPath) {
  const slug = legacyProgramPath.split('/')[0];
  location.replace(`/program/${encodeURIComponent(slug)}`);
} else if (programPage) loadProgramPage(decodeURIComponent(programPage[1]));
else loadPrograms();
