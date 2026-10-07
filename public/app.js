const library = document.querySelector('#library');
const player = document.querySelector('#player');
const status = document.querySelector('#status');
const programsElement = document.querySelector('#programs');
const refreshButton = document.querySelector('#refresh');

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
  Demo: '✦'
};

async function loadPrograms() {
  status.hidden = false;
  status.className = 'status';
  status.textContent = 'Loading programs…';
  programsElement.replaceChildren();
  refreshButton.disabled = true;
  try {
    const response = await fetch('/api/programs', { cache: 'no-store' });
    if (!response.ok) throw new Error('The program list could not be loaded.');
    const { programs } = await response.json();
    for (const program of programs) {
      const link = document.createElement('a');
      link.className = 'program-card';
      link.href = `/?program=${encodeURIComponent(program.path)}`;

      const pill = document.createElement('span');
      pill.className = 'type-pill';
      pill.textContent = `${typeIcons[program.type] || '●'} ${program.type}`;

      const title = document.createElement('strong');
      title.className = 'program-title';
      title.textContent = program.title;

      const description = document.createElement('span');
      description.className = 'program-description';
      description.textContent = program.description;

      const controls = document.createElement('span');
      controls.className = 'controls';
      controls.setAttribute('aria-label', `Controls: ${program.controls.join(', ')}`);
      for (const control of program.controls) {
        const key = document.createElement('kbd');
        key.textContent = control;
        controls.append(key);
      }

      const action = document.createElement('span');
      action.className = 'program-action';
      action.textContent = 'Run program →';
      link.append(pill, title, description, controls, action);
      programsElement.append(link);
    }
    status.textContent = programs.length ? `${programs.length} programs available` : 'No PRG files found.';
  } catch (error) {
    status.className = 'status error';
    status.textContent = error.message;
  } finally {
    refreshButton.disabled = false;
  }
}

function startEmulator(programPath) {
  library.hidden = true;
  player.hidden = false;
  const title = titleFromPath(programPath);
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

refreshButton.addEventListener('click', loadPrograms);
const programPath = new URLSearchParams(location.search).get('program');
if (programPath) startEmulator(programPath);
else loadPrograms();

