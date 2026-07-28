// ═══════════════════════════════════════════════
//  الختمة الإدارية — نسخة القراءة للويب
//  منطق الواجهة (مبني على home_screen / hizb_detail_screen)
// ═══════════════════════════════════════════════

// ── أسماء الأيام والشهور (مفهرسة حسب Date.getDay(): 0=الأحد) ──
const DAYS   = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const DAYS_AB = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
const MONTHS = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
                'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const ORDINALS = ['الأول', 'الثاني', 'الثالث', 'الرابع',
                  'الخامس', 'السادس', 'السابع', 'الثامن'];

// تدرّجات ألوان الأحزاب الثلاثة (app_theme.dart)
const HIZB_GRADIENTS = [
  ['#1A5C38', '#2E8B57'], // أول — أخضر
  ['#1E3A8A', '#3B5FCC'], // ثانٍ — أزرق
  ['#7C3238', '#A0522D'], // ثالث — بني
];

// ── الحالة ──
let AHZAB_BY_NUM = {};      // { رقم الحزب: بيانات }
let selectedDate = stripTime(new Date());

// ── أدوات مساعدة ──
function stripTime(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }
function isSameDay(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}
function isToday(d) { return isSameDay(d, new Date()); }
function fmtDate(d) { return `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`; }
function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function driveFileId(url) {
  // يدعم الصيغتين: /file/d/<ID>/view  و  open?id=<ID>
  const m = /\/d\/([^/?]+)/.exec(url || '') || /[?&]id=([^&]+)/.exec(url || '');
  return m ? m[1] : null;
}
function drivePreviewUrl(url) {
  const id = driveFileId(url);
  return id ? `https://drive.google.com/file/d/${id}/preview` : null;
}
function youtubeId(url) {
  for (const re of [/youtu\.be\/([A-Za-z0-9_\-]{11})/, /[?&]v=([A-Za-z0-9_\-]{11})/, /embed\/([A-Za-z0-9_\-]{11})/]) {
    const m = re.exec(url || '');
    if (m) return m[1];
  }
  return null;
}
function youtubeEmbedUrl(url) {
  const id = youtubeId(url);
  return id ? `https://www.youtube.com/embed/${id}?rel=0` : null;
}

// ═══════════════════════════════════════════════
//  الإقلاع
// ═══════════════════════════════════════════════
function boot() {
  if (!window.AHZAB) {
    document.getElementById('app').innerHTML =
      `<div class="center-screen"><p>تعذّر تحميل بيانات الأحزاب.</p></div>`;
    return;
  }
  window.AHZAB.forEach(h => { AHZAB_BY_NUM[h.hizb] = h; });
  renderHome();
}

// ═══════════════════════════════════════════════
//  الشاشة الرئيسية — ورد اليوم
// ═══════════════════════════════════════════════
function renderHome() {
  const d = selectedDate;
  const nums = KhatmaCalculator.getHizbsForDate(d);
  const cycle = KhatmaCalculator.getCycleNumber(d);
  const dayInCyc = KhatmaCalculator.getDayInCycle(d);
  const friday = d.getDay() === 5;

  const app = document.getElementById('app');
  app.innerHTML = `
    <div class="wrap">
      ${dateCard(d, nums.length, cycle, dayInCyc)}
      <div class="mini-row">
        <button class="mini-card" onclick="openAllHizbs()">
          <span class="ic green">📖</span><span class="t">المصحف الكامل</span>
        </button>
        <button class="mini-card" onclick="openKhatmaNights()">
          <span class="ic gold">🌙</span><span class="t">ليلة الختمة</span>
        </button>
      </div>
      ${friday ? fridayBanner() : ''}
      <div class="section-title">
        <span class="bar"></span><h2>ورد اليوم</h2>
        <span class="sub">${nums.length} أحزاب</span>
      </div>
      <div id="hizb-list">
        ${nums.map((n, i) => hizbCard(AHZAB_BY_NUM[n], i)).join('')}
      </div>
      <div class="section-title"><span class="bar"></span><h2>هذا الأسبوع</h2></div>
      ${weekPreview(d)}
    </div>
  `;
  window.scrollTo(0, 0);
}

function dateCard(d, hizbCount, cycle, dayInCyc) {
  return `
    <div class="date-card">
      <div class="top">
        <span class="label">${isToday(d) ? 'اليوم' : 'التاريخ المختار'}</span>
        ${isToday(d) ? '' : `<button class="chip" onclick="goToday()">العودة لليوم</button>`}
      </div>
      <div class="date-line">${esc(fmtDate(d))}</div>
      <div class="stats">
        <div class="stat"><span class="k">الأحزاب</span><span class="v">${hizbCount}</span></div>
        <div class="sep"></div>
        <div class="stat"><span class="k">الدورة</span><span class="v">${cycle}</span></div>
        <div class="sep"></div>
        <div class="stat"><span class="k">يوم الدورة</span><span class="v">${dayInCyc} / ٢١</span></div>
      </div>
    </div>`;
}

function fridayBanner() {
  return `
    <div class="friday">
      <span class="ic">📖</span>
      <div>
        <div class="h">🌟 يوم الجمعة المبارك</div>
        <div class="s">تذكّر قراءة سورة الكهف</div>
      </div>
    </div>`;
}

// ── بطاقة الحزب (قابلة للتوسّع لعرض الأثمان + اقرأ/استمع) ──
function hizbCard(h, dayIndex) {
  if (!h) return '';
  const g = HIZB_GRADIENTS[Math.min(dayIndex, 2)];
  const from = h.range?.from || {}, to = h.range?.to || {};
  return `
    <div class="hizb-card" id="card-${h.hizb}">
      <div class="badge" style="background:linear-gradient(135deg,${g[0]},${g[1]})">
        <span class="lbl">الحزب</span><span class="num">${h.hizb}</span>
      </div>
      <div class="body">
        <button style="all:unset;display:block;width:100%;cursor:pointer" onclick="toggleCard(${h.hizb})">
          <div class="opening">${esc(h.opening_verse)}</div>
          <div class="range-pill">📖&nbsp;<span>${esc(from.surah)} (${from.ayah}) — ${esc(to.surah)} (${to.ayah})</span></div>
          <div class="meta">☰&nbsp;٨ أثمان<span class="expand">⌄</span></div>
        </button>
        <div class="actions-row">
          <button class="action-btn read" onclick="openPdf(${h.hizb})">
            <span class="ic">📄</span><span class="lbl">اقرأ</span><span class="sub">المصحف</span>
          </button>
          ${h.youtube
            ? `<button class="action-btn listen" onclick="openYoutube(${h.hizb})">
                 <span class="ic">▶</span><span class="lbl">استمع</span><span class="sub">يوتيوب</span>
               </button>`
            : `<div class="action-btn listen disabled">
                 <span class="ic">▶</span><span class="lbl">استمع</span><span class="sub">غير متاح</span>
               </div>`}
        </div>
      </div>
      <div class="hizb-detail">
        <div class="detail-inner">
          <div class="athman-title">
            <span class="bar"></span><h3>الأثمان الثمانية</h3>
            <span class="cnt">${(h.athman || []).length} أثمان</span>
          </div>
          ${(h.athman || []).map(thumnTile).join('')}
        </div>
      </div>
    </div>`;
}

function thumnTile(t) {
  const ord = ORDINALS[(t.thumn || 1) - 1] || t.thumn;
  return `
    <div class="thumn">
      <div class="n">${t.thumn}</div>
      <div class="txt">
        <div class="head">
          <span class="ord">الثمن ${ord}</span>
          <span class="loc">${esc(t.surah)} • آية ${t.ayah}</span>
        </div>
        <div class="verse">${esc(t.opening_verse)}</div>
      </div>
    </div>`;
}

function weekPreview(d) {
  const dartWeekday = d.getDay() === 0 ? 7 : d.getDay();          // الاثنين = 1
  const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate() - (dartWeekday - 1));
  const week = KhatmaCalculator.getWeekHizbs(monday);
  return `<div class="week">${week.map(({ date, hizbs }) => {
    const sel = isSameDay(date, d);
    return `
      <button class="day ${sel ? 'sel' : ''}" onclick="pickDay('${date.getFullYear()}-${date.getMonth()}-${date.getDate()}')">
        <div class="wd">${DAYS_AB[date.getDay()]}</div>
        <div class="dn">${date.getDate()}</div>
        <div class="hz">${hizbs.length ? hizbs[0] : '—'}</div>
      </button>`;
  }).join('')}</div>`;
}

// ═══════════════════════════════════════════════
//  التفاعلات
// ═══════════════════════════════════════════════
function toggleCard(num) {
  document.getElementById(`card-${num}`)?.classList.toggle('open');
}
function goToday() { selectedDate = stripTime(new Date()); renderHome(); }
function pickDay(key) {
  const [y, m, d] = key.split('-').map(Number);
  selectedDate = new Date(y, m, d);
  renderHome();
}
function goDate(d) { selectedDate = stripTime(d); renderHome(); }

// منتقي التاريخ عبر <input type=date> المخفي
function openDatePicker() {
  const inp = document.getElementById('date-input');
  const p = n => String(n).padStart(2, '0');
  inp.value = `${selectedDate.getFullYear()}-${p(selectedDate.getMonth() + 1)}-${p(selectedDate.getDate())}`;
  if (inp.showPicker) inp.showPicker(); else inp.click();
}
function onDateInput(e) {
  const v = e.target.value;
  if (!v) return;
  const [y, m, d] = v.split('-').map(Number);
  selectedDate = new Date(y, m - 1, d);
  renderHome();
}

// ═══════════════════════════════════════════════
//  النوافذ المنبثقة — اقرأ / استمع
// ═══════════════════════════════════════════════
function showModal(title, iframeSrc, newTabUrl) {
  const ov = document.getElementById('modal');
  ov.querySelector('.mt').textContent = title;
  ov.querySelector('.frame').innerHTML = iframeSrc
    ? `<iframe src="${esc(iframeSrc)}" allow="autoplay; encrypted-media" allowfullscreen></iframe>`
    : `<div class="center-screen" style="color:#fff">المحتوى غير متاح</div>`;
  const nt = ov.querySelector('a.newtab');
  if (newTabUrl) { nt.href = newTabUrl; nt.style.display = ''; } else { nt.style.display = 'none'; }
  ov.classList.add('show');
  document.body.style.overflow = 'hidden';
}
function closeModal(e) {
  if (e && e.target !== e.currentTarget && !e.target.closest('[data-close]')) return;
  const ov = document.getElementById('modal');
  ov.classList.remove('show');
  ov.querySelector('.frame').innerHTML = '';
  document.body.style.overflow = '';
}

function openPdf(num) {
  const h = AHZAB_BY_NUM[num];
  showModal(`الحزب ${num} — المصحف`, drivePreviewUrl(h.pdf), h.pdf || null);
}
function openYoutube(num) {
  const h = AHZAB_BY_NUM[num];
  showModal(`الحزب ${num} — تلاوة`, youtubeEmbedUrl(h.youtube), h.youtube || null);
}

// ═══════════════════════════════════════════════
//  المصحف الكامل — قائمة الأحزاب الستين
// ═══════════════════════════════════════════════
function openAllHizbs() {
  const app = document.getElementById('app');
  app.innerHTML = `
    <div class="wrap">
      <div class="back-bar"><button onclick="renderHome()">‹ رجوع</button></div>
      <div class="section-title"><span class="bar"></span><h2>المصحف الكامل</h2><span class="sub">٦٠ حزباً</span></div>
      ${window.AHZAB.map(h => `
        <button class="list-row" style="width:100%;text-align:inherit" onclick="openHizbStandalone(${h.hizb})">
          <span class="av">${h.hizb}</span>
          <span class="info">
            <span class="h">الحزب ${h.hizb}</span>
            <span class="s">${esc(h.opening_verse)}</span>
          </span>
          <span class="ics">${h.youtube ? '▶️' : ''} 📄</span>
        </button>`).join('')}
    </div>`;
  window.scrollTo(0, 0);
}

// عرض حزب مفرد (من المصحف الكامل) — الأثمان + اقرأ/استمع
function openHizbStandalone(num) {
  const h = AHZAB_BY_NUM[num];
  if (!h) return;
  const app = document.getElementById('app');
  app.innerHTML = `
    <div class="wrap">
      <div class="back-bar"><button onclick="openAllHizbs()">‹ رجوع</button></div>
      <div id="hizb-list">${hizbCard(h, 0)}</div>
    </div>`;
  document.getElementById(`card-${num}`)?.classList.add('open');
  window.scrollTo(0, 0);
}

// ═══════════════════════════════════════════════
//  ليالي الختمة
// ═══════════════════════════════════════════════
function openKhatmaNights() {
  const today = stripTime(new Date());
  const end = new Date(today.getFullYear() + 2, today.getMonth(), today.getDate());
  const dates = KhatmaCalculator.getKhatmaDates(today, end);
  const nearest = dates[0] || null;

  const banner = nearest ? `
    <div class="khatma-banner">
      <div class="lbl">🌙 أقرب ليلة ختمة</div>
      <div class="dt">${esc(fmtDate(nearest))}</div>
      <div class="away">بعد ${Math.round((nearest - today) / 86400000)} يوماً</div>
      <div class="chips">${KhatmaCalculator.getHizbsForDate(nearest).map(h => `<span>ح ${h}</span>`).join('')}</div>
    </div>` : '';

  const app = document.getElementById('app');
  app.innerHTML = `
    <div class="wrap">
      <div class="back-bar"><button onclick="renderHome()">‹ رجوع</button></div>
      <div class="section-title"><span class="bar"></span><h2>ليالي الختمة</h2></div>
      ${banner}
      ${dates.map((d, i) => {
        const daysAway = Math.round((d - today) / 86400000);
        const first = i === 0;
        return `
          <div class="list-row ${first ? 'gold' : ''}">
            <span class="av" style="${first ? 'background:rgba(212,160,23,.2);color:var(--gold)' : ''}">${i + 1}</span>
            <span class="info">
              <span class="h" style="${first ? 'color:var(--gold)' : ''}">${esc(fmtDate(d))}</span>
              <span class="s">الأحزاب: ${KhatmaCalculator.getHizbsForDate(d).join('، ')}</span>
            </span>
            <span style="font-size:12px;font-weight:600;color:${first ? 'var(--gold)' : 'var(--text-low)'}">${daysAway} ي</span>
          </div>`;
      }).join('')}
    </div>`;
  window.scrollTo(0, 0);
}

// ═══════════════════════════════════════════════
//  مشاركة ورد اليوم
// ═══════════════════════════════════════════════
async function shareWird() {
  const d = selectedDate;
  const nums = KhatmaCalculator.getHizbsForDate(d);
  let text = `القرآن الكريم - ختمة الإدارة\n\n📖 ورد ${fmtDate(d)}:\n\n`;
  for (const n of nums) {
    const h = AHZAB_BY_NUM[n];
    const from = h.range?.from || {}, to = h.range?.to || {};
    text += `• الحزب ${n}: من سورة ${from.surah} الآية ${from.ayah} إلى سورة ${to.surah} الآية ${to.ayah}\n`;
    if (h.youtube) text += `   ▶️ استماع: ${h.youtube}\n`;
    if (h.pdf) text += `   📄 مصحف: ${h.pdf}\n`;
    text += '\n';
  }
  text = text.trim();
  try {
    if (navigator.share) {
      await navigator.share({ title: 'القرآن الكريم - ختمة الإدارة', text });
    } else {
      await navigator.clipboard.writeText(text);
      alert('تم نسخ ورد اليوم');
    }
  } catch (_) { /* أُلغيت المشاركة */ }
}

document.addEventListener('DOMContentLoaded', boot);
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });
