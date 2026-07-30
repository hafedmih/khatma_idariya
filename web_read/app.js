// ═══════════════════════════════════════════════
//  الختمة الإدارية — نسخة القراءة للويب
//  منطق الواجهة (مبني على home_screen / hizb_detail_screen)
// ═══════════════════════════════════════════════

const DAYS    = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const DAYS_AB = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
const MONTHS  = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
                 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const ORDINALS = ['الأول', 'الثاني', 'الثالث', 'الرابع',
                  'الخامس', 'السادس', 'السابع', 'الثامن'];
const PLAY_URL = 'https://play.google.com/store/apps/details?id=com.hafedmih.khatma';

// تدرّجات ألوان الأحزاب الثلاثة (app_theme.dart)
const HIZB_GRADIENTS = [
  ['#1A5C38', '#2E8B57'], // أول — أخضر
  ['#1E3A8A', '#3B5FCC'], // ثانٍ — أزرق
  ['#7C3238', '#A0522D'], // ثالث — بني
];

// ── الحالة ──
let AHZAB_BY_NUM = {};
let selectedDate = stripTime(new Date());

// ── أدوات مساعدة ──
function stripTime(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }
function isSameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
function isToday(d) { return isSameDay(d, new Date()); }
function fmtDate(d) { return `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`; }
function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
// المصحف يُقرأ محلياً من pdf/<رقم الحزب>.pdf
function pdfUrl(num) { return `pdf/${num}.pdf`; }
function youtubeId(url) {
  for (const re of [/youtu\.be\/([A-Za-z0-9_\-]{11})/, /[?&]v=([A-Za-z0-9_\-]{11})/, /embed\/([A-Za-z0-9_\-]{11})/]) {
    const m = re.exec(url || ''); if (m) return m[1];
  }
  return null;
}
function youtubeEmbedUrl(url) { const id = youtubeId(url); return id ? `https://www.youtube.com/embed/${id}?rel=0` : null; }
// الهواتف: عارض PDF داخل iframe غير موثوق — نفتح في تبويب جديد بدلاً من ذلك
function isTouchMobile() { return window.matchMedia('(max-width: 700px), (pointer: coarse)').matches; }

// ═══════════════════════════════════════════════
//  الوضع الفاتح/الداكن (الافتراضي: فاتح)
// ═══════════════════════════════════════════════
function currentTheme() {
  return document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
}
function applyTheme(t) {
  document.documentElement.setAttribute('data-theme', t);
  try { localStorage.setItem('theme', t); } catch (_) {}
  const btn = document.getElementById('theme-btn');
  if (btn) { btn.textContent = t === 'dark' ? '☀️' : '🌙'; }
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', t === 'dark' ? '#0F3D26' : '#1A5C38');
}
function toggleTheme() { applyTheme(currentTheme() === 'dark' ? 'light' : 'dark'); }

// ═══════════════════════════════════════════════
function boot() {
  applyTheme(currentTheme()); // يضبط أيقونة الزر حسب الوضع المحفوظ
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

  document.getElementById('app').innerHTML = `
    <div class="wrap">
      ${dateCard(d, nums.length, cycle, dayInCyc)}
      <div class="section-title"><span class="bar"></span><h2>ورد اليوم</h2><span class="sub">${nums.length} أحزاب</span></div>
      <div id="hizb-list">${nums.map((n, i) => hizbCard(AHZAB_BY_NUM[n], i)).join('')}</div>
      <div class="share-bar">
        <button class="sh img" onclick="openShareCard()">📸 صورة الورد</button>
        <button class="sh wa" onclick="shareTo('whatsapp')">واتساب</button>
        <button class="sh fb" onclick="shareTo('facebook')">فيسبوك</button>
        <button class="sh tw" onclick="shareTo('twitter')">تويتر</button>
      </div>
      ${friday ? fridayBanner() : ''}
      <div class="mini-row">
        <button class="mini-card" onclick="openAllHizbs()"><span class="ic green">📖</span><span class="t">المصحف الكامل</span></button>
        <button class="mini-card" onclick="openKhatmaNights()"><span class="ic gold">🌙</span><span class="t">ليلة الختمة</span></button>
      </div>
      <button class="about-banner" onclick="openAbout()">
        <span class="ab-ic">📱</span>
        <span class="ab-txt"><b>عن البرنامج وتطبيق الجوال</b><small>التذكيرات، الاستماع، القراءة دون إنترنت…</small></span>
        <span class="ab-chev">‹</span>
      </button>
      <div class="section-title"><span class="bar"></span><h2>هذا الأسبوع</h2></div>
      ${weekPreview(d)}
      <div class="stats-footer" id="stats-footer" style="display:none">
        <span>🟢 <b class="online-n">—</b> متصل الآن</span>
        <span class="sep2">•</span>
        <span><b class="total-n">—</b> زيارة</span>
      </div>
    </div>`;
  window.scrollTo(0, 0);
  if (window.renderCounter) window.renderCounter();
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
  return `<div class="friday"><span class="ic">📖</span><div><div class="h">🌟 يوم الجمعة المبارك</div><div class="s">تذكّر قراءة سورة الكهف</div></div></div>`;
}

// بطاقة مضغوطة على الصفحة الرئيسية — نقرة تفتح شاشة التفاصيل
function hizbCard(h, dayIndex, from) {
  if (!h) return '';
  const g = HIZB_GRADIENTS[Math.min(dayIndex, 2)];
  const r = h.range?.from || {}, to = h.range?.to || {};
  return `
    <button class="hizb-card compact" onclick="openHizbDetail(${h.hizb}, '${from || 'home'}')">
      <div class="badge" style="background:linear-gradient(135deg,${g[0]},${g[1]})"><span class="lbl">الحزب</span><span class="num">${h.hizb}</span></div>
      <div class="body">
        <div class="opening">${esc(h.opening_verse)}</div>
        <div class="range-pill">📖&nbsp;<span>${esc(r.surah)} (${r.ayah}) — ${esc(to.surah)} (${to.ayah})</span></div>
        <div class="meta">☰&nbsp;٨ أثمان &nbsp;•&nbsp; اقرأ / استمع<span class="chev">‹</span></div>
      </div>
    </button>`;
}

// شاشة تفاصيل الحزب — فاتحة، نطاق، اقرأ/استمع، الأثمان الثمانية
function openHizbDetail(num, from) {
  const h = AHZAB_BY_NUM[num]; if (!h) return;
  const back = from === 'all' ? 'openAllHizbs()' : 'renderHome()';
  const r = h.range?.from || {}, to = h.range?.to || {};
  document.getElementById('app').innerHTML = `
    <div class="detail-hero">
      <button class="hero-back" onclick="${back}" title="رجوع">‹</button>
      <div class="hero-num"><span>الحزب</span><b>${num}</b></div>
    </div>
    <div class="wrap detail-wrap">
      <div class="verse-card">
        <div class="vc-label">❝ فاتحة الحزب</div>
        <div class="vc-text">${esc(h.opening_verse)}</div>
      </div>
      <div class="range-card">📖 من سورة ${esc(r.surah)} الآية ${r.ayah} إلى سورة ${esc(to.surah)} الآية ${to.ayah}</div>
      <div class="actions-row detail-actions">
        <button class="action-btn read" onclick="openPdf(${num})"><span class="ic">📄</span><span class="lbl">اقرأ</span><span class="sub">المصحف</span></button>
        ${h.youtube
          ? `<button class="action-btn listen" onclick="openYoutube(${num})"><span class="ic">▶</span><span class="lbl">استمع</span><span class="sub">يوتيوب</span></button>`
          : `<div class="action-btn listen disabled"><span class="ic">▶</span><span class="lbl">استمع</span><span class="sub">غير متاح</span></div>`}
      </div>
      <div class="athman-title"><span class="bar"></span><h3>الأثمان الثمانية</h3><span class="cnt">${(h.athman || []).length} أثمان</span></div>
      ${(h.athman || []).map(thumnTile).join('')}
    </div>`;
  window.scrollTo(0, 0);
}

function thumnTile(t) {
  const ord = ORDINALS[(t.thumn || 1) - 1] || t.thumn;
  return `
    <div class="thumn">
      <div class="n">${t.thumn}</div>
      <div class="txt">
        <div class="head"><span class="ord">الثمن ${ord}</span><span class="loc">${esc(t.surah)} • آية ${t.ayah}</span></div>
        <div class="verse">${esc(t.opening_verse)}</div>
      </div>
    </div>`;
}

function weekPreview(d) {
  const dartWeekday = d.getDay() === 0 ? 7 : d.getDay();
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
function toggleCard(num) { document.getElementById(`card-${num}`)?.classList.toggle('open'); }
function goToday() { selectedDate = stripTime(new Date()); renderHome(); }
function pickDay(key) { const [y, m, d] = key.split('-').map(Number); selectedDate = new Date(y, m, d); renderHome(); }

function openDatePicker() {
  const inp = document.getElementById('date-input');
  const p = n => String(n).padStart(2, '0');
  inp.value = `${selectedDate.getFullYear()}-${p(selectedDate.getMonth() + 1)}-${p(selectedDate.getDate())}`;
  if (inp.showPicker) inp.showPicker(); else inp.click();
}
function onDateInput(e) {
  const v = e.target.value; if (!v) return;
  const [y, m, d] = v.split('-').map(Number);
  selectedDate = new Date(y, m - 1, d); renderHome();
}

// ═══════════════════════════════════════════════
//  القارئ (PDF) / المشغّل (يوتيوب)
// ═══════════════════════════════════════════════
function showModal(title, iframeSrc, newTabUrl, kind) {
  const ov = document.getElementById('modal');
  const box = ov.querySelector('.modal');
  box.classList.remove('modal--pdf', 'modal--video');
  box.classList.add(kind === 'video' ? 'modal--video' : 'modal--pdf');
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

// اقرأ → PDF محلي بعارض المتصفح الأصلي
function openPdf(num) {
  const url = pdfUrl(num);
  if (isTouchMobile()) { window.open(url, '_blank', 'noopener'); return; } // الهاتف: تبويب جديد
  showModal(`الحزب ${num} — المصحف`, `${url}#view=FitH`, url, 'pdf');       // سطح المكتب: نافذة قراءة
}
// استمع → يوتيوب مدمج
function openYoutube(num) {
  const h = AHZAB_BY_NUM[num];
  const embed = youtubeEmbedUrl(h.youtube);
  if (!embed) { if (h.youtube) window.open(h.youtube, '_blank', 'noopener'); return; }
  showModal(`الحزب ${num} — تلاوة`, embed, h.youtube, 'video');
}

// ═══════════════════════════════════════════════
//  المصحف الكامل — قائمة الأحزاب الستين
// ═══════════════════════════════════════════════
function openAllHizbs() {
  document.getElementById('app').innerHTML = `
    <div class="wrap">
      <div class="back-bar"><button onclick="renderHome()">‹ رجوع</button></div>
      <div class="section-title"><span class="bar"></span><h2>المصحف الكامل</h2><span class="sub">٦٠ حزباً</span></div>
      ${window.AHZAB.map(h => `
        <button class="list-row" style="width:100%;text-align:inherit" onclick="openHizbDetail(${h.hizb}, 'all')">
          <span class="av">${h.hizb}</span>
          <span class="info"><span class="h">الحزب ${h.hizb}</span><span class="s">${esc(h.opening_verse)}</span></span>
          <span class="ics">${h.youtube ? '▶️' : ''} 📄</span>
        </button>`).join('')}
    </div>`;
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
  document.getElementById('app').innerHTML = `
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
//  حول: عن الموقع والبرنامج + تطبيق الجوال
// ═══════════════════════════════════════════════
function openAbout() {
  document.getElementById('app').innerHTML = `
    <div class="detail-hero about-hero">
      <button class="hero-back" onclick="renderHome()" title="رجوع">‹</button>
      <div class="about-head">
        <div class="about-logo"><img src="favicon.png" alt="أيقونة التطبيق"></div>
        <div class="about-title">القرآن الكريم - ختمة الإدارة</div>
      </div>
    </div>
    <div class="wrap detail-wrap about-wrap">
      <section class="about-card">
        <h3><span class="bar"></span> عن الموقع</h3>
        <p>هذا الموقع نسخة ويب خفيفة من تطبيق «القرآن الكريم - ختمة الإدارة». يعرض <b>وِرد اليوم</b> —
        الأحزاب والأثمان المقررة لكل يوم — مع <b>القراءة</b> (المصحف) و<b>الاستماع</b> (تلاوة ورش)،
        ومعاينة الأسبوع، ومواعيد ليالي الختمة.</p>
      </section>

      <section class="about-card">
        <h3><span class="bar"></span> عن برنامج الختمة الإدارية</h3>
        <p>الختمة الإدارية برنامجٌ من برامج <b>أهل شنقيط</b> (موريتانيا) لختم القرآن الكريم كل <b>٢١ يوماً</b>.
        تُقرأ <b>ثلاثة أحزاب</b> كل يوم (وحزبان يوم الجمعة مع تخصيص وقتٍ لسورة الكهف)، فتكتمل الختمة
        (٦٠ حزباً) في نهاية كل دورة مدّتها ٢١ يوماً، ثم تبدأ دورة جديدة.</p>
      </section>

      <section class="about-card">
        <h3><span class="bar"></span> تطبيق الجوال (أندرويد)</h3>
        <p>لتجربة أكمل مع <b>التذكيرات اليومية</b> والقراءة دون إنترنت، حمّل التطبيق على هاتفك:</p>
        <div class="store-row">
          <a class="play-btn" href="${PLAY_URL}" target="_blank" rel="noopener">
            <span class="pi">▶</span>
            <span class="pt"><small>متوفّر على</small><b>Google Play</b></span>
          </a>
          <div class="qr">
            <img src="play-qr.png" alt="رمز QR لتحميل التطبيق من Google Play">
            <span>امسح الرمز للتحميل</span>
          </div>
        </div>
        <div class="feat-title">أهم مميزات التطبيق</div>
        <ul class="features">
          <li><span>🔔</span> تذكيرات يومية بالورد (إشعارات على الجهاز)</li>
          <li><span>🎧</span> استماع للتلاوة (رواية ورش) داخل التطبيق</li>
          <li><span>📖</span> قراءة المصحف (PDF) بدون إنترنت</li>
          <li><span>🗓️</span> وِرد أي يوم مع معاينة الأسبوع كاملاً</li>
          <li><span>🌙</span> مواعيد ليالي الختمة</li>
          <li><span>📤</span> مشاركة وِرد اليوم</li>
          <li><span>🌘</span> وضع ليلي ونهاري</li>
        </ul>
      </section>

      <div class="about-foot">khatma-idara.online</div>
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
    text += `   📄 مصحف: ${new URL(pdfUrl(n), location.href).href}\n`;
    if (h.youtube) text += `   ▶️ استماع: ${h.youtube}\n`;
    text += '\n';
  }
  text = text.trim();
  try {
    if (navigator.share) await navigator.share({ title: 'القرآن الكريم - ختمة الإدارة', text });
    else { await navigator.clipboard.writeText(text); alert('تم نسخ ورد اليوم'); }
  } catch (_) {}
}

document.addEventListener('DOMContentLoaded', boot);
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });
