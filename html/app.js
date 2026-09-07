const menu = document.querySelector('#shopmenu');
const status = document.querySelector('.selection');
const buttons = [...document.querySelectorAll('.bike__rent')];
const inGame = typeof GetParentResourceName === 'function';
let busy = false;
let closeTimer;
let closing = false;

function setBusy(value) {
  busy = value;
  buttons.forEach(button => { button.disabled = value || button.dataset.available === 'false'; });
}

function show(bikes) {
  clearTimeout(closeTimer);
  closing = false;
  menu.classList.remove('is-closing');
  if (Array.isArray(bikes)) {
    for (const button of buttons) {
      const bike = bikes.find(item => item.id === button.dataset.bike);
      button.dataset.available = String(Boolean(bike));
      button.closest('.bike').hidden = !bike;
      if (!bike) continue;
      const card = button.closest('.bike');
      card.querySelector('.bike__name').textContent = bike.name;
      card.querySelector('.bike__price').textContent = `$${bike.price}`;
      button.setAttribute('aria-label', `${bike.name} für ${bike.price} Dollar mieten`);
    }
  }
  menu.hidden = false;
  status.textContent = '';
  setBusy(false);
}

function hide() {
  if (menu.hidden || closing) return;
  closing = true;
  menu.classList.add('is-closing');
  const finish = () => {
    menu.hidden = true;
    menu.classList.remove('is-closing');
    status.textContent = '';
    closing = false;
  };
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) finish();
  else closeTimer = setTimeout(finish, 320);
}

async function post(action, data = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(`https://${GetParentResourceName()}/${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
      signal: controller.signal,
    });
    if (!response.ok) throw new Error('NUI request failed');
    return await response.json();
  } finally { clearTimeout(timeout); }
}

async function close() {
  if (!inGame) { hide(); return; }
  try { await post('close'); hide(); }
  catch { status.textContent = 'Schließen fehlgeschlagen. Bitte erneut ESC drücken.'; }
}

window.addEventListener('message', ({ data }) => {
  if (!data || typeof data !== 'object') return;
  if (data.action === 'open') show(data.bikes);
  if (data.action === 'close') hide();
  if (data.action === 'result') {
    setBusy(false);
    status.textContent = data.message || '';
  }
});

document.querySelector('.rental').addEventListener('click', async event => {
  const button = event.target.closest('.bike__rent');
  if (!button || busy || closing || button.disabled) return;
  if (!inGame) {
    status.textContent = 'Browser-Vorschau: Die Ausleihe funktioniert auf deinem FiveM-Server.';
    return;
  }
  setBusy(true);
  status.textContent = 'Ausleihe wird geprüft …';
  try {
    // Nur die ID übertragen. Preis und Fahrzeugmodell bestimmt der Server.
    const result = await post('rent', { id: button.dataset.bike });
    if (!result.ok) {
      setBusy(false);
      status.textContent = result.message || 'Ausleihe fehlgeschlagen.';
    }
  } catch {
    setBusy(false);
    status.textContent = 'Verbindung fehlgeschlagen. Bitte erneut versuchen.';
  }
});

document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && !menu.hidden && !closing) close();
});

if (inGame) post('ready').catch(() => {});
else if (new URLSearchParams(location.search).has('preview')) show();
