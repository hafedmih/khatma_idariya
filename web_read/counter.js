// ═══════════════════════════════════════════════
//  عدّاد الزوّار: المتصلون الآن + إجمالي الزيارات
//  يتصل بـ counter.php على نفس الخادم — يختفي بهدوء إن تعذّر
// ═══════════════════════════════════════════════
(function () {
  // معرّف زائر عشوائي (غير شخصي) لحساب المتصلين
  const VID = (function () {
    try {
      let v = localStorage.getItem('vid');
      if (!v) { v = Math.random().toString(36).slice(2) + Date.now().toString(36); localStorage.setItem('vid', v); }
      return v;
    } catch (_) { return 'anon' + Math.floor(Math.random() * 1e6); }
  })();

  let state = null;

  // يُعاد استدعاؤها بعد كل رسم للصفحة الرئيسية
  window.renderCounter = function () {
    const el = document.getElementById('stats-footer');
    if (!el) return;
    if (!state) { el.style.display = 'none'; return; }
    el.style.display = '';
    const on = el.querySelector('.online-n'), tt = el.querySelector('.total-n');
    if (on) on.textContent = state.online;
    if (tt) tt.textContent = Number(state.total).toLocaleString('en-US');
  };

  async function ping(firstVisit) {
    const p = new URLSearchParams({ vid: VID });
    if (firstVisit) p.set('visit', '1');
    try {
      const r = await fetch('counter.php?' + p.toString(), { cache: 'no-store' });
      if (!r.ok) throw 0;
      const j = await r.json();
      state = { online: j.online | 0, total: j.total | 0 };
      window.renderCounter();
    } catch (_) { /* لا يظهر العداد إن لم يتوفّر الخادم */ }
  }

  // زيارة جديدة مرة واحدة لكل جلسة تصفّح
  const firstVisit = (function () {
    try { if (!sessionStorage.getItem('visited')) { sessionStorage.setItem('visited', '1'); return true; } } catch (_) {}
    return false;
  })();

  function start() { ping(firstVisit); setInterval(() => ping(false), 45000); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
