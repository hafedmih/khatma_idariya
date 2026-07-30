// ═══════════════════════════════════════════════
//  المشاركة: صورة الورد (Canvas) + روابط اجتماعية
//  يعتمد على المتغيرات العامة في app.js:
//  selectedDate, AHZAB_BY_NUM, KhatmaCalculator, fmtDate, HIZB_GRADIENTS
// ═══════════════════════════════════════════════

let _wirdBlob = null;

// رابط الموقع للمشاركة (يتجاهل file:// أثناء التطوير)
function siteUrl() {
  if (location.protocol === 'file:' || location.origin === 'null') return 'https://khatma-idara.online';
  return location.origin + location.pathname.replace(/index\.html$/, '');
}

// نص ورد اليوم للمشاركة — يطابق محتوى الصورة (فاتحة كل حزب + النطاق)
function wirdShareText() {
  const d = selectedDate;
  const nums = KhatmaCalculator.getHizbsForDate(d);
  let t = `القرآن الكريم - ختمة الإدارة\n📖 ورد ${fmtDate(d)}\n`;
  for (const n of nums) {
    const h = AHZAB_BY_NUM[n];
    const f = h.range?.from || {}, to = h.range?.to || {};
    t += `\n• الحزب ${n}: ${h.opening_verse}\n  (من ${f.surah} ${f.ayah} إلى ${to.surah} ${to.ayah})\n`;
  }
  return t.trim();
}

// مشاركة نصية سريعة (واتساب / فيسبوك / تويتر)
function shareTo(platform) {
  const text = wirdShareText(), url = siteUrl();
  let u;
  if (platform === 'whatsapp')      u = `https://wa.me/?text=${encodeURIComponent(text + '\n\n' + url)}`;
  else if (platform === 'facebook') u = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`;
  else if (platform === 'twitter')  u = `https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`;
  if (u) window.open(u, '_blank', 'noopener');
}

// ─────────── رسم بطاقة الورد كصورة PNG ───────────
function _roundRectPath(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
function _wrap(ctx, text, maxW) {
  const words = String(text || '').split(/\s+/);
  const lines = []; let cur = '';
  for (const w of words) {
    const t = cur ? cur + ' ' + w : w;
    if (ctx.measureText(t).width > maxW && cur) { lines.push(cur); cur = w; }
    else cur = t;
  }
  if (cur) lines.push(cur);
  return lines;
}

async function buildWirdImage() {
  const d = selectedDate;
  const nums = KhatmaCalculator.getHizbsForDate(d);
  const hizbs = nums.map(n => AHZAB_BY_NUM[n]);
  const cycle = KhatmaCalculator.getCycleNumber(d);
  const dayInCyc = KhatmaCalculator.getDayInCycle(d);

  const W = 1080, PAD = 40, HEADER = 330, CARD_H = 232, GAP = 22;
  const bodyTop = HEADER + 34;
  const H = bodyTop + hizbs.length * (CARD_H + GAP) + 86;

  const cv = document.createElement('canvas');
  cv.width = W; cv.height = H;
  const ctx = cv.getContext('2d');

  // ضمان تحميل خط Cairo قبل الرسم
  try {
    await Promise.all([
      document.fonts.load('800 62px Cairo'), document.fonts.load('700 40px Cairo'),
      document.fonts.load('600 34px Cairo'), document.fonts.load('800 96px Cairo'),
    ]);
    await document.fonts.ready;
  } catch (_) {}

  ctx.textBaseline = 'alphabetic';
  ctx.direction = 'rtl';

  // خلفية
  ctx.fillStyle = '#F8F5F0'; ctx.fillRect(0, 0, W, H);

  // ترويسة متدرجة
  const hg = ctx.createLinearGradient(0, 0, W, HEADER);
  hg.addColorStop(0, '#0F3D26'); hg.addColorStop(.5, '#1A5C38'); hg.addColorStop(1, '#2E8B57');
  ctx.fillStyle = hg; ctx.fillRect(0, 0, W, HEADER);
  ctx.textAlign = 'center';
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 44px Cairo';  ctx.fillText('القرآن الكريم - ختمة الإدارة', W / 2, 90);
  ctx.font = '800 64px Cairo';  ctx.fillText(fmtDate(d), W / 2, 186);
  ctx.fillStyle = 'rgba(255,255,255,.85)';
  ctx.font = '600 34px Cairo';
  ctx.fillText(`الدورة ${cycle}  •  اليوم ${dayInCyc}/٢١  •  ${hizbs.length} أحزاب`, W / 2, 258);

  // بطاقات الأحزاب
  const cardW = W - 2 * PAD;
  hizbs.forEach((h, i) => {
    const y = bodyTop + i * (CARD_H + GAP);
    _drawHizbBlock(ctx, h, i, PAD, y, cardW, CARD_H);
  });

  // تذييل
  ctx.textAlign = 'center';
  ctx.fillStyle = '#1A5C38';
  ctx.font = '700 34px Cairo';
  ctx.fillText('khatma-idara.online', W / 2, H - 36);

  return await new Promise(res => cv.toBlob(res, 'image/png'));
}

function _drawHizbBlock(ctx, h, idx, x, y, w, hgt) {
  const grad = HIZB_GRADIENTS[Math.min(idx, 2)];
  // بطاقة بيضاء
  _roundRectPath(ctx, x, y, w, hgt, 26); ctx.fillStyle = '#ffffff'; ctx.fill();
  // شارة الرقم على اليمين (RTL)
  const badgeW = 172, bx = x + w - badgeW;
  ctx.save(); _roundRectPath(ctx, x, y, w, hgt, 26); ctx.clip();
  const bg = ctx.createLinearGradient(bx, y, bx + badgeW, y + hgt);
  bg.addColorStop(0, grad[0]); bg.addColorStop(1, grad[1]);
  ctx.fillStyle = bg; ctx.fillRect(bx, y, badgeW, hgt);
  ctx.restore();
  ctx.textAlign = 'center'; ctx.fillStyle = '#ffffff';
  ctx.font = '600 28px Cairo';  ctx.fillText('الحزب', bx + badgeW / 2, y + hgt / 2 - 26);
  ctx.font = '800 96px Cairo';  ctx.fillText(String(h.hizb), bx + badgeW / 2, y + hgt / 2 + 52);

  // المحتوى (يمين، ضمن المساحة المتبقية)
  const cRight = bx - 34, cLeft = x + 34, cw = cRight - cLeft;
  ctx.textAlign = 'right';
  // فاتحة الحزب (سطران كحد أقصى)
  ctx.fillStyle = '#1A1A1A'; ctx.font = '700 38px Cairo';
  const lines = _wrap(ctx, h.opening_verse, cw).slice(0, 2);
  let ty = y + 66;
  for (const l of lines) { ctx.fillText(l, cRight, ty); ty += 54; }
  // النطاق: السور والآيات
  const f = h.range?.from || {}, to = h.range?.to || {};
  ctx.fillStyle = '#1A5C38'; ctx.font = '600 33px Cairo';
  ctx.fillText(`من ${f.surah} (${f.ayah}) إلى ${to.surah} (${to.ayah})`, cRight, y + hgt - 36);
}

// ─────────── نافذة صورة الورد ───────────
async function openShareCard() {
  const ov = document.getElementById('share-modal');
  const body = document.getElementById('share-body');
  body.innerHTML = `<div class="share-loading"><div class="spinner"></div><p>جارٍ إنشاء صورة الورد…</p></div>`;
  ov.classList.add('show'); document.body.style.overflow = 'hidden';
  try {
    _wirdBlob = await buildWirdImage();
    const src = URL.createObjectURL(_wirdBlob);
    const text = wirdShareText(), url = siteUrl();
    body.innerHTML = `
      <img src="${src}" alt="ورد اليوم">
      <div class="btns">
        <button class="b-sh" onclick="shareWirdImage()">📤 مشاركة الصورة</button>
        <button class="b-dl" onclick="downloadWird()">⬇️ تحميل</button>
        <a class="b-wa" href="https://wa.me/?text=${encodeURIComponent(text + '\n\n' + url)}" target="_blank" rel="noopener">واتساب</a>
        <a class="b-fb" href="https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}" target="_blank" rel="noopener">فيسبوك</a>
        <a class="b-tw" href="https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}" target="_blank" rel="noopener">تويتر</a>
        <button class="b-close" data-close onclick="closeShareModal(event)">إغلاق</button>
      </div>
      <p class="hint">«مشاركة الصورة» ترفق الصورة مباشرة على واتساب/إنستغرام من الهاتف. على الحاسوب استخدم «تحميل» ثم أرفقها. أزرار واتساب/فيسبوك/تويتر تشارك رابط الموقع والنص.</p>`;
  } catch (e) {
    body.innerHTML = `<div class="share-loading"><p>تعذّر إنشاء الصورة.</p><button class="b-close" data-close onclick="closeShareModal(event)" style="background:#888;color:#fff;padding:10px 18px;border-radius:10px">إغلاق</button></div>`;
  }
}
function closeShareModal(e) {
  if (e && e.target !== e.currentTarget && !e.target.closest('[data-close]')) return;
  const ov = document.getElementById('share-modal');
  ov.classList.remove('show'); document.body.style.overflow = '';
}
function downloadWird() {
  if (!_wirdBlob) return;
  const a = document.createElement('a');
  a.href = URL.createObjectURL(_wirdBlob);
  a.download = `ورد-${fmtDate(selectedDate)}.png`;
  document.body.appendChild(a); a.click(); a.remove();
}
async function shareWirdImage() {
  if (!_wirdBlob) { downloadWird(); return; }
  const file = new File([_wirdBlob], 'wird.png', { type: 'image/png' });
  try {
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file] }); // الصورة فقط (تحوي كل المحتوى)
    } else {
      downloadWird();
    }
  } catch (_) {}
}

document.addEventListener('keydown', e => { if (e.key === 'Escape') closeShareModal(); });
