const library = document.querySelector('#library');
const player = document.querySelector('#player');
const status = document.querySelector('#status');
const programsElement = document.querySelector('#programs');
const refreshButton = document.querySelector('#refresh');
const searchInput = document.querySelector('#search');
const typeFilter = document.querySelector('#type-filter');
const sortOrder = document.querySelector('#sort-order');
const gridViewButton = document.querySelector('#grid-view');
const listViewButton = document.querySelector('#list-view');
const sourceModal = document.querySelector('#source-modal');
const sourceTitle = document.querySelector('#source-title');
const sourceStatus = document.querySelector('#source-status');
const sourceCode = document.querySelector('#source-code');
let allPrograms = [];

function titleFromPath(path) {
  const filename = path.split('/').at(-1).replace(/\.prg$/i, '');
  return filename.split('-').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
}

const typeIcons = {
  Arcade: '🎮',
  Logic: '◆',
  Strategy: '♟',
  Simulation: '⚙',
  Memory: '◫',
  Puzzle: '⌘',
  Music: '♪',
  Creative: '✎',
  Demo: '✦',
  Dice: '⚄',
  Word: 'Aa',
  Reflex: '⚡',
  Educational: '⌁',
  Trivia: '?',
  Utility: '⚒'
};

function renderPrograms() {
  const query = searchInput.value.trim().toLowerCase();
  const selectedType = typeFilter.value;
  const programs = allPrograms
    .filter(program => !selectedType || program.type === selectedType)
    .filter(program => !query || `${program.title} ${program.description} ${program.type} ${program.controls.join(' ')}`.toLowerCase().includes(query))
    .sort((left, right) => {
      if (sortOrder.value === 'type') return left.type.localeCompare(right.type) || left.title.localeCompare(right.title);
      return left.title.localeCompare(right.title);
    });

  programsElement.replaceChildren();
  for (const program of programs) {
    const card = document.createElement('article');
    card.className = 'program-card';
    const programUrl = `/program/${encodeURIComponent(program.slug)}`;
    card.addEventListener('click', event => {
      if (!event.target.closest('a, button')) location.href = programUrl;
    });

    const pill = document.createElement('span');
    pill.className = 'type-pill';
    pill.textContent = `${typeIcons[program.type] || '●'} ${program.type}`;

    const title = document.createElement('h2');
    title.className = 'program-title';
    title.textContent = program.title;

    const description = document.createElement('p');
    description.className = 'program-description';
    description.textContent = program.description;

    const controls = document.createElement('div');
    controls.className = 'controls';
    controls.setAttribute('aria-label', `Controls: ${program.controls.join(', ')}`);
    for (const control of program.controls) {
      const key = document.createElement('kbd');
      key.textContent = control;
      controls.append(key);
    }

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
    card.append(pill, title, description, controls, actions);
    programsElement.append(card);
  }
  status.textContent = `${programs.length} of ${allPrograms.length} programs shown`;
}

async function showSource(program) {
  sourceTitle.textContent = program.title;
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
    const currentType = typeFilter.value;
    const types = [...new Set(programs.map(program => program.type))].sort();
    typeFilter.replaceChildren(new Option('All types', ''), ...types.map(type => new Option(type, type)));
    if (types.includes(currentType)) typeFilter.value = currentType;
    renderPrograms();
  } catch (error) {
    status.className = 'status error';
    status.textContent = error.message;
  } finally {
    refreshButton.disabled = false;
  }
}

function startEmulator(program) {
  const programPath = program.path;
  library.hidden = true;
  player.hidden = false;
  const title = program.title || titleFromPath(programPath);
  document.title = `${title} — C64 BASIC Collection`;
  document.querySelector('#program-title').textContent = title;

  window.EJS_player = '#game';
  window.EJS_core = 'vice_x64sc';
  window.EJS_gameUrl = `/api/program?path=${encodeURIComponent(programPath)}`;
  window.EJS_gameName = programPath.split('/').at(-1);
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

refreshButton.addEventListener('click', loadPrograms);
searchInput.addEventListener('input', renderPrograms);
typeFilter.addEventListener('change', renderPrograms);
sortOrder.addEventListener('change', renderPrograms);
gridViewButton.addEventListener('click', () => setView('grid'));
listViewButton.addEventListener('click', () => setView('list'));
document.querySelector('#close-source').addEventListener('click', () => sourceModal.close());
sourceModal.addEventListener('click', event => {
  if (event.target === sourceModal) sourceModal.close();
});

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

