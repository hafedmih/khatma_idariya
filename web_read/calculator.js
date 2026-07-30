// ═══════════════════════════════════════════════
//  خوارزمية الختمة الإدارية — نظام الارتكاز
//  (منقولة حرفياً من lib/services/khatma_calculator.dart)
//  دورة واحدة = ٢١ يوماً = ٦٠ حزباً
//  ٦ أيام × ٣ أحزاب + الجمعة × ٢ = ٢٠ حزباً/أسبوع
// ═══════════════════════════════════════════════

const KhatmaCalculator = (() => {
  // نقطة الارتكاز: ١ يوليو ٢٠٢٦ = الأحزاب ١٩، ٢٠، ٢١
  const ANCHOR_UTC   = Date.UTC(2026, 6, 1); // الشهور في JS تبدأ من صفر → 6 = يوليو
  const ANCHOR_FIRST = 19;
  const PER_CYCLE    = 60;
  const PER_WEEK     = 20; // 6×3 + 1×2
  const DAY_MS       = 86400000;

  const _mod = (a, b) => ((a % b) + b) % b;

  const _utcMidnight = (date) =>
    Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());

  const _daysFromAnchor = (date) =>
    Math.round((_utcMidnight(date) - ANCHOR_UTC) / DAY_MS);

  const _weekdayAtOffset = (offsetDays) =>
    new Date(ANCHOR_UTC + offsetDays * DAY_MS).getUTCDay();

  const _isFridayOffset = (offsetDays) => _weekdayAtOffset(offsetDays) === 5;

  function _countHizbsBeforeDay(days) {
    if (days === 0) return 0;
    if (days > 0) {
      const fullWeeks = Math.floor(days / 7);
      const remaining = days % 7;
      let count = fullWeeks * PER_WEEK;
      for (let i = 0; i < remaining; i++) {
        count += _isFridayOffset(fullWeeks * 7 + i) ? 2 : 3;
      }
      return count;
    } else {
      const absDays   = -days;
      const fullWeeks = Math.floor(absDays / 7);
      const remaining = absDays % 7;
      let count = -(fullWeeks * PER_WEEK);
      for (let i = 0; i < remaining; i++) {
        count -= _isFridayOffset(-(fullWeeks * 7 + i + 1)) ? 2 : 3;
      }
      return count;
    }
  }

  function getHizbsForDate(date) {
    const days        = _daysFromAnchor(date);
    const hizbsBefore = _countHizbsBeforeDay(days);
    const firstHizb   = _mod(ANCHOR_FIRST - 1 + hizbsBefore, PER_CYCLE) + 1;
    const isFriday    = date.getDay() === 5;
    if (isFriday) {
      return [firstHizb, _mod(firstHizb, PER_CYCLE) + 1];
    }
    return [
      firstHizb,
      _mod(firstHizb,     PER_CYCLE) + 1,
      _mod(firstHizb + 1, PER_CYCLE) + 1,
    ];
  }

  function getCycleNumber(date) {
    return Math.trunc(_daysFromAnchor(date) / 21) + 1;
  }

  function getDayInCycle(date) {
    return _mod(_daysFromAnchor(date), 21) + 1;
  }

  function getWeekHizbs(weekStart) {
    const out = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + i);
      out.push({ date: d, hizbs: getHizbsForDate(d) });
    }
    return out;
  }

  function getKhatmaDates(from, to) {
    const result = [];
    let d = new Date(from.getFullYear(), from.getMonth(), from.getDate());
    const end = new Date(to.getFullYear(), to.getMonth(), to.getDate());
    while (d.getTime() <= end.getTime()) {
      if (getHizbsForDate(d).includes(60)) result.push(new Date(d));
      d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
    }
    return result;
  }

  return { getHizbsForDate, getCycleNumber, getDayInCycle, getWeekHizbs, getKhatmaDates };
})();
