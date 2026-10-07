// Gig Mileage Log — all data stays in this browser's localStorage.
const KEY = 'giglog-data-v1';
const DEFAULT_PLATFORMS = ['DoorDash', 'Amazon Flex', 'Uber Eats', 'Grubhub', 'Instacart', 'Walmart Spark'];
// IRS standard mileage rates ($/mile). Verify on irs.gov and edit in Settings.
const DEFAULT_RATES = { 2023: 0.655, 2024: 0.67, 2025: 0.70, 2026: 0.725 };

const $ = id => document.getElementById(id);
const money = n => '$' + (n || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const num = v => (v === '' || v == null || isNaN(+v)) ? null : +v;
const pad = n => String(n).padStart(2, '0');
const todayStr = () => { const d = new Date(); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; };
const timeStr = d => `${pad(d.getHours())}:${pad(d.getMinutes())}`;
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// ---------- storage ----------
function load() {
  try {
    const d = JSON.parse(localStorage.getItem(KEY));
    if (d && Array.isArray(d.shifts)) return { platforms: DEFAULT_PLATFORMS, rates: { ...DEFAULT_RATES }, active: null, ...d };
  } catch (e) { /* fall through */ }
  return { shifts: [], platforms: [...DEFAULT_PLATFORMS], rates: { ...DEFAULT_RATES }, active: null };
}
let data = load();
function save() { localStorage.setItem(KEY, JSON.stringify(data)); render(); }

// ---------- helpers ----------
function hours(s) {
  const [sh, sm] = s.start.split(':').map(Number);
  const [eh, em] = s.end.split(':').map(Number);
  let mins = (eh * 60 + em) - (sh * 60 + sm);
  if (mins < 0) mins += 24 * 60; // shift crossed midnight
  return mins / 60;
}
function rateFor(year) {
  if (data.rates[year] != null) return data.rates[year];
  const years = Object.keys(data.rates).map(Number).filter(y => y <= year).sort((a, b) => b - a);
  return years.length ? data.rates[years[0]] : 0;
}
const yearOf = s => +s.date.slice(0, 4);
function years() {
  const ys = new Set(data.shifts.map(yearOf)); ys.add(new Date().getFullYear());
  return [...ys].sort((a, b) => b - a);
}
function fillSelect(sel, items, keep = true) {
  const prev = sel.value;
  sel.innerHTML = items.map(i => typeof i === 'object'
    ? `<option value="${esc(i.value)}">${esc(i.label)}</option>`
    : `<option>${esc(i)}</option>`).join('');
  if (keep && [...sel.options].some(o => o.value === prev)) sel.value = prev;
}

// ---------- tabs ----------
document.querySelectorAll('nav button').forEach(b => b.onclick = () => {
  document.querySelectorAll('nav button').forEach(x => x.classList.toggle('active', x === b));
  document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.id === 'tab-' + b.dataset.tab));
});

// ---------- quick start / end ----------
$('start-shift').onclick = () => {
  const now = new Date();
  data.active = { platform: $('quick-platform').value, date: todayStr(), start: timeStr(now), odoStart: num($('start-odo-quick').value) };
  $('start-odo-quick').value = '';
  save();
};
$('end-shift').onclick = () => {
  const a = data.active, odoEnd = num($('end-odo-quick').value);
  let miles = (a.odoStart != null && odoEnd != null) ? +(odoEnd - a.odoStart).toFixed(1) : null;
  if (miles == null || miles < 0) {
    const m = prompt('Business miles driven this shift?');
    if (m === null) return;
    miles = num(m) ?? 0;
  }
  data.shifts.push({
    id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()),
    platform: a.platform, date: a.date, start: a.start, end: timeStr(new Date()),
    odoStart: a.odoStart, odoEnd, miles, earnings: num($('earn-quick').value), tips: null, notes: ''
  });
  data.active = null;
  $('end-odo-quick').value = $('earn-quick').value = '';
  save();
};
$('cancel-shift').onclick = () => { if (confirm('Discard the shift in progress?')) { data.active = null; save(); } };

// ---------- manual form ----------
function autoMiles() {
  const s = num($('f-odo-start').value), e = num($('f-odo-end').value);
  if (s != null && e != null && e >= s) $('f-miles').value = (e - s).toFixed(1);
}
$('f-odo-start').oninput = $('f-odo-end').oninput = autoMiles;

function resetForm() {
  $('shift-form').reset();
  $('f-id').value = '';
  $('f-date').value = todayStr();
  $('form-title').textContent = 'Add shift manually';
  $('f-cancel').classList.add('hidden');
}
$('f-cancel').onclick = resetForm;

$('shift-form').onsubmit = e => {
  e.preventDefault();
  const id = $('f-id').value;
  const shift = {
    id: id || (crypto.randomUUID ? crypto.randomUUID() : String(Date.now())),
    platform: $('f-platform').value, date: $('f-date').value,
    start: $('f-start').value, end: $('f-end').value,
    odoStart: num($('f-odo-start').value), odoEnd: num($('f-odo-end').value),
    miles: num($('f-miles').value) ?? 0,
    earnings: num($('f-earnings').value), tips: num($('f-tips').value),
    notes: $('f-notes').value.trim()
  };
  if (id) data.shifts = data.shifts.map(s => s.id === id ? shift : s);
  else data.shifts.push(shift);
  resetForm();
  save();
};

function editShift(id) {
  const s = data.shifts.find(x => x.id === id); if (!s) return;
  $('f-id').value = s.id; $('f-platform').value = s.platform; $('f-date').value = s.date;
  $('f-start').value = s.start; $('f-end').value = s.end;
  $('f-odo-start').value = s.odoStart ?? ''; $('f-odo-end').value = s.odoEnd ?? '';
  $('f-miles').value = s.miles ?? ''; $('f-earnings').value = s.earnings ?? '';
  $('f-tips').value = s.tips ?? ''; $('f-notes').value = s.notes ?? '';
  $('form-title').textContent = 'Edit shift';
  $('f-cancel').classList.remove('hidden');
  document.querySelector('nav button[data-tab="log"]').click();
  $('shift-form').scrollIntoView({ behavior: 'smooth' });
}
function deleteShift(id) {
  if (confirm('Delete this shift?')) { data.shifts = data.shifts.filter(s => s.id !== id); save(); }
}

// ---------- history ----------
$('h-year').onchange = $('h-platform').onchange = renderHistory;
function renderHistory() {
  const y = +$('h-year').value, p = $('h-platform').value;
  const list = data.shifts.filter(s => yearOf(s) === y && (!p || s.platform === p))
    .sort((a, b) => (b.date + b.start).localeCompare(a.date + a.start));
  $('history-list').innerHTML = list.length ? list.map(s => `
    <div class="card shift">
      <div>
        <b>${esc(s.platform)}</b> · ${esc(s.date)}
        <div class="meta">${esc(s.start)}–${esc(s.end)} (${hours(s).toFixed(2)} h) · ${s.miles ?? 0} mi
          ${s.earnings != null ? ' · ' + money(s.earnings + (s.tips || 0)) : ''}</div>
        ${s.notes ? `<div class="meta">${esc(s.notes)}</div>` : ''}
      </div>
      <div class="actions">
        <button data-edit="${esc(s.id)}">Edit</button>
        <button class="danger" data-del="${esc(s.id)}">Delete</button>
      </div>
    </div>`).join('') : '<p class="muted">No shifts recorded.</p>';
}
$('history-list').onclick = e => {
  if (e.target.dataset.edit) editShift(e.target.dataset.edit);
  if (e.target.dataset.del) deleteShift(e.target.dataset.del);
};

// ---------- summary ----------
$('s-year').onchange = renderSummary;
function totals(list) {
  return list.reduce((t, s) => ({
    shifts: t.shifts + 1, hours: t.hours + hours(s), miles: t.miles + (s.miles || 0),
    income: t.income + (s.earnings || 0) + (s.tips || 0)
  }), { shifts: 0, hours: 0, miles: 0, income: 0 });
}
function renderSummary() {
  const y = +$('s-year').value, rate = rateFor(y);
  const list = data.shifts.filter(s => yearOf(s) === y);
  const t = totals(list);
  const byPlatform = {}, byMonth = {};
  list.forEach(s => {
    (byPlatform[s.platform] ||= []).push(s);
    (byMonth[s.date.slice(0, 7)] ||= []).push(s);
  });
  const row = (label, l) => { const x = totals(l); return `<tr><td>${esc(label)}</td><td>${x.shifts}</td><td>${x.hours.toFixed(1)}</td><td>${x.miles.toFixed(1)}</td><td>${money(x.income)}</td></tr>`; };
  const table = (title, groups) => `<div class="card"><h2>${title}</h2><table>
    <tr><th></th><th>Shifts</th><th>Hours</th><th>Miles</th><th>Income</th></tr>
    ${Object.keys(groups).sort().map(k => row(k, groups[k])).join('')}</table></div>`;
  $('summary').innerHTML = `
    <div class="card"><h2>${y} totals</h2><div class="stats">
      <div class="stat">Business miles<b>${t.miles.toFixed(1)}</b></div>
      <div class="stat">Mileage deduction<b>${money(t.miles * rate)}</b><small>@ $${rate}/mi</small></div>
      <div class="stat">Gross income<b>${money(t.income)}</b></div>
      <div class="stat">Hours worked<b>${t.hours.toFixed(1)}</b><small>${t.shifts} shifts</small></div>
    </div></div>
    ${list.length ? table('By platform', byPlatform) + table('By month', byMonth) : ''}`;
}

$('export-csv').onclick = () => {
  const y = +$('s-year').value;
  const list = data.shifts.filter(s => yearOf(s) === y).sort((a, b) => (a.date + a.start).localeCompare(b.date + b.start));
  const cols = ['Date', 'Platform', 'Start', 'End', 'Hours', 'Odometer Start', 'Odometer End', 'Business Miles', 'Earnings', 'Tips', 'Purpose', 'Notes'];
  const q = v => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const rows = list.map(s => [s.date, s.platform, s.start, s.end, hours(s).toFixed(2), s.odoStart, s.odoEnd,
    s.miles, s.earnings, s.tips, `${s.platform} deliveries`, s.notes].map(q).join(','));
  const t = totals(list);
  rows.push('', [q('TOTAL'), '', '', '', q(t.hours.toFixed(2)), '', '', q(t.miles.toFixed(1)), q(t.income.toFixed(2))].join(','));
  rows.push([q(`Deduction @ $${rateFor(y)}/mi`), '', '', '', '', '', '', q((t.miles * rateFor(y)).toFixed(2))].join(','));
  download(`mileage-log-${y}.csv`, [cols.map(q).join(','), ...rows].join('\n'), 'text/csv');
};

// ---------- settings ----------
function renderSettings() {
  $('platform-list').innerHTML = data.platforms.map((p, i) =>
    `<li>${esc(p)} <button class="danger" data-rm-platform="${i}">Remove</button></li>`).join('');
  $('rate-list').innerHTML = Object.keys(data.rates).sort((a, b) => b - a).map(y =>
    `<div><span>${y}: $${data.rates[y]}/mi</span><button class="danger" data-rm-rate="${y}">Remove</button></div>`).join('');
}
$('platform-list').onclick = e => {
  const i = e.target.dataset.rmPlatform;
  if (i != null && confirm(`Remove ${data.platforms[i]}? Existing shifts are kept.`)) { data.platforms.splice(+i, 1); save(); }
};
$('add-platform').onclick = () => {
  const v = $('new-platform').value.trim();
  if (v && !data.platforms.includes(v)) { data.platforms.push(v); $('new-platform').value = ''; save(); }
};
$('rate-list').onclick = e => { const y = e.target.dataset.rmRate; if (y) { delete data.rates[y]; save(); } };
$('add-rate').onclick = () => {
  const y = num($('rate-year').value), r = num($('rate-value').value);
  if (y && r != null) { data.rates[y] = r; $('rate-year').value = $('rate-value').value = ''; save(); }
};

$('backup').onclick = () => download(`giglog-backup-${todayStr()}.json`, JSON.stringify(data, null, 2), 'application/json');
$('restore').onchange = e => {
  const file = e.target.files[0]; if (!file) return;
  file.text().then(txt => {
    const d = JSON.parse(txt);
    if (!Array.isArray(d.shifts)) throw new Error('bad file');
    if (confirm(`Replace current data with backup (${d.shifts.length} shifts)?`)) { data = { ...load(), ...d }; save(); }
  }).catch(() => alert('Could not read that backup file.'));
  e.target.value = '';
};

function download(name, content, type) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([content], { type }));
  a.download = name; a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

// ---------- render ----------
function render() {
  const platforms = [...new Set([...data.platforms, ...data.shifts.map(s => s.platform)])];
  document.querySelectorAll('.platform-select').forEach(s => fillSelect(s, data.platforms.length ? data.platforms : platforms));
  fillSelect($('h-platform'), [{ value: '', label: 'All' }, ...platforms]);
  document.querySelectorAll('.year-select').forEach(s => fillSelect(s, years()));

  const a = data.active;
  $('active-shift').classList.toggle('hidden', !a);
  $('start-card').classList.toggle('hidden', !!a);
  if (a) $('active-info').textContent = `${a.platform} · started ${a.start} on ${a.date}` +
    (a.odoStart != null ? ` · odometer ${a.odoStart}` : '');

  renderHistory(); renderSummary(); renderSettings();
}

resetForm();
render();
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
