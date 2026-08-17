import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../config/audio_config.dart';
import '../models/hizb.dart';
import '../services/audio_download_service.dart';
import '../services/hizb_service.dart';
import '../services/links_service.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
//  ضبط أوقات الصفحات بالسماع — للمشرف فقط
//
//  الطريقة: اضغط رقم أيّ صفحة فيبدأ الصوت من وقتها المحفوظ في
//  Supabase. إن لم تكن البداية مضبوطة، قدّم أو أرجع بالأزرار حتى
//  تسمع أول كلمة من الصفحة، ثم اضغط «التقاط». ثم «حفظ».
//
//  الصفحة 1 = 0 دائماً ولا تُخزَّن؛ المخزَّن 7 أرقام للصفحات 2→8.
//  نصّ بداية كل صفحة مأخوذ من الثمن المقابل لها (الحزب = 8 أثمان
//  والملف = 8 صفحات، فالصفحة N تبدأ عند الثمن N).
// ══════════════════════════════════════════════════════════════

const int _kPageCount = 7; // الصفحات 2..8
const int _kTotalPages = 8;

class PageTimeCalibrationScreen extends StatefulWidget {
  final int hizb;
  final List<int> initialTimes;

  const PageTimeCalibrationScreen({
    super.key,
    required this.hizb,
    this.initialTimes = const [],
  });

  @override
  State<PageTimeCalibrationScreen> createState() =>
      _PageTimeCalibrationScreenState();
}

class _PageTimeCalibrationScreenState extends State<PageTimeCalibrationScreen> {
  final AudioPlayer _player = AudioPlayer();

  late List<int> _times;
  Hizb? _hizb;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int? _justCaptured;

  @override
  void initState() {
    super.initState();
    _times = List<int>.generate(
      _kPageCount,
      (i) => i < widget.initialTimes.length ? widget.initialTimes[i] : 0,
    );
    _loadHizb();
    _initAudio();
  }

  Future<void> _loadHizb() async {
    try {
      final all = await HizbService.loadAhzab();
      if (!mounted) return;
      setState(() => _hizb = HizbService.find(all, widget.hizb));
    } catch (_) {
      // بيانات الأحزاب غير متاحة — الشاشة تعمل بدون نصوص البدايات.
    }
  }

  Future<void> _initAudio() async {
    try {
      if (await AudioDownloadService.isDownloaded(widget.hizb)) {
        final f = await AudioDownloadService.localFile(widget.hizb);
        await _player.setFilePath(f.path);
      } else {
        await _player.setUrl(AudioConfig.urlFor(widget.hizb));
      }
      if (!mounted) return;

      _player.positionStream.listen((p) {
        if (mounted) setState(() => _pos = p);
      });
      _player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _dur = d);
      });
      _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _playing = s.playing);
      });

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل التلاوة: $e';
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ── بيانات الصفحات ─────────────────────────────────────────
  /// وقت بداية الصفحة (1..8) — الصفحة 1 دائماً صفر.
  int _timeOfPage(int page) => page <= 1 ? 0 : _times[page - 2];

  /// نصّ بداية الصفحة من الثمن المقابل لها.
  Thumn? _thumnOfPage(int page) {
    final list = _hizb?.athman;
    if (list == null || list.length < page) return null;
    return list[page - 1];
  }

  /// الصفحة التي يقع فيها موضع التشغيل الحالي.
  int get _currentPage {
    final s = _pos.inSeconds;
    var page = 1;
    for (var i = 0; i < _kPageCount; i++) {
      if (_times[i] > 0 && s >= _times[i]) page = i + 2;
    }
    return page;
  }

  // ── التحكّم بالمشغّل ────────────────────────────────────────
  void _seekBy(int seconds) {
    var target = _pos + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (_dur > Duration.zero && target > _dur) target = _dur;
    _player.seek(target);
  }

  void _togglePlay() => _playing ? _player.pause() : _player.play();

  /// يشغّل الصفحة من وقتها المحفوظ في Supabase تماماً.
  Future<void> _playPage(int page) async {
    await _player.seek(Duration(seconds: _timeOfPage(page)));
    await _player.play();
  }

  // ── تعديل الأوقات ──────────────────────────────────────────
  void _capture(int page) {
    setState(() {
      _times[page - 2] = _pos.inSeconds;
      _justCaptured = page;
    });
  }

  void _nudge(int page, int delta) {
    setState(() {
      final v = _times[page - 2] + delta;
      _times[page - 2] = v < 0 ? 0 : v;
    });
  }

  void _clear(int page) => setState(() => _times[page - 2] = 0);

  // ── التحقّق ثم الحفظ ───────────────────────────────────────
  String? _validate() {
    for (var i = 0; i < _kPageCount; i++) {
      if (_times[i] <= 0) return 'وقت صفحة ${i + 2} غير محدَّد.';
    }
    for (var i = 1; i < _kPageCount; i++) {
      if (_times[i] <= _times[i - 1]) {
        return 'وقت صفحة ${i + 2} يجب أن يكون بعد صفحة ${i + 1}.';
      }
    }
    if (_dur > Duration.zero && _times.last >= _dur.inSeconds) {
      return 'وقت صفحة 8 يتجاوز مدّة التلاوة.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      _toast(problem, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      // يُحفظ في Supabase (جدول hizb_page_times) ثم نسخة محلية للعمل دون إنترنت.
      await LinksService.updatePageTimes(widget.hizb, _times);
      await AudioDownloadService.savePageTimes(widget.hizb, _times);
      if (!mounted) return;
      _toast('تم حفظ أوقات الحزب ${widget.hizb} في Supabase ✓');
      Navigator.pop(context, _times);
    } catch (e) {
      if (mounted) _toast('تعذّر الحفظ: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : AppTheme.primary,
    ));
  }

  /// للأوقات غير المضبوطة: شرطة بدل 00:00 حتى يتميّز «غير محدَّد» عن الصفر.
  static String _fmt(int seconds) =>
      seconds <= 0 ? '—' : _clock(seconds);

  /// لعدّاد المشغّل: الصفر وقتٌ صحيح، فيُعرض 00:00 لا شرطة.
  static String _clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = s ~/ 60;
    return '${m.toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ── الواجهة ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('ضبط أوقات الصفحات — الحزب ${widget.hizb}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : Column(
                  children: [
                    _playerCard(),
                    const Divider(height: 1),
                    Expanded(child: _pageList()),
                    _saveBar(),
                  ],
                ),
    );
  }

  // ── بطاقة المشغّل ──────────────────────────────────────────
  Widget _playerCard() {
    final maxSec = _dur.inSeconds > 0 ? _dur.inSeconds.toDouble() : 1.0;
    final cur = _pos.inSeconds.clamp(0, _dur.inSeconds).toDouble();
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LTR إلزاماً: في RTL ينقلب ترتيب «الحالي / المدّة» بصرياً.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${_clock(_pos.inSeconds)}  /  ${_fmt(_dur.inSeconds)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('صفحة $_currentPage',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDk)),
              ),
            ],
          ),
          Slider(
            value: cur,
            max: maxSec,
            activeColor: AppTheme.primary,
            onChanged: (v) => _player.seek(Duration(seconds: v.round())),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ctrlBtn('−10', () => _seekBy(-10)),
              _ctrlBtn('−1', () => _seekBy(-1)),
              const SizedBox(width: 6),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                iconSize: 30,
                onPressed: _togglePlay,
                icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 6),
              _ctrlBtn('+1', () => _seekBy(1)),
              _ctrlBtn('+10', () => _seekBy(10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(42, 38),
          padding: EdgeInsets.zero,
          foregroundColor: AppTheme.primary,
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  // ── بداية الحزب ────────────────────────────────────────────
  Widget _hizbHeader() {
    final h = _hizb;
    if (h == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.goldLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 16, color: AppTheme.primaryDk),
              const SizedBox(width: 6),
              Text('بداية الحزب ${h.number}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDk)),
            ],
          ),
          const SizedBox(height: 6),
          if (h.openingVerse.isNotEmpty)
            Text(h.openingVerse,
                style: const TextStyle(
                    fontSize: 15, height: 1.7, color: AppTheme.textHigh)),
          const SizedBox(height: 6),
          Text(h.rangeFull,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMed)),
        ],
      ),
    );
  }

  // ── قائمة الصفحات ──────────────────────────────────────────
  Widget _pageList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _kTotalPages + 1, // +1 لبطاقة بداية الحزب
      itemBuilder: (ctx, row) {
        if (row == 0) return _hizbHeader();
        return _pageRow(row); // row == رقم الصفحة 1..8
      },
    );
  }

  Widget _pageRow(int page) {
    final t = _timeOfPage(page);
    final thumn = _thumnOfPage(page);
    final isFirst = page == 1;
    final isCurrent = _currentPage == page;
    final captured = _justCaptured == page;

    return Container(
      decoration: BoxDecoration(
        color: captured
            ? AppTheme.gold.withValues(alpha: 0.16)
            : isCurrent
                ? AppTheme.primary.withValues(alpha: 0.07)
                : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          right: BorderSide(
            width: 3,
            color: isCurrent ? AppTheme.primary : Colors.transparent,
          ),
        ),
      ),
      child: InkWell(
        // اضغط الصفحة ← يبدأ الصوت من وقتها المحفوظ في Supabase.
        onTap: (isFirst || t > 0) ? () => _playPage(page) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: t > 0 || isFirst
                        ? AppTheme.primary.withValues(alpha: 0.14)
                        : Colors.red.withValues(alpha: 0.10),
                    child: Text('$page',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t > 0 || isFirst
                                ? AppTheme.primary
                                : Colors.red.shade400)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        isFirst ? '00:00' : _fmt(t),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: (t > 0 || isFirst)
                              ? AppTheme.textHigh
                              : AppTheme.textLow,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  if (isFirst)
                    const Expanded(
                      child: Text('تبدأ من الصفر دائماً',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textLow)),
                    )
                  else ...[
                    _miniBtn(Icons.remove_rounded, () => _nudge(page, -1)),
                    _miniBtn(Icons.add_rounded, () => _nudge(page, 1)),
                    const Spacer(),
                    if (t > 0)
                      IconButton(
                        tooltip: 'مسح',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _clear(page),
                        icon: Icon(Icons.close_rounded,
                            size: 17, color: Colors.red.shade300),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _capture(page),
                      icon: const Icon(Icons.my_location_rounded, size: 14),
                      label: const Text('التقاط',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
              // نصّ بداية الصفحة (من الثمن المقابل)
              if (thumn != null && thumn.openingVerse.isNotEmpty) ...[
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(right: 36),
                  child: Text(
                    thumn.openingVerse,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, height: 1.6, color: AppTheme.textMed),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 36, top: 2),
                  child: Text(
                    '${thumn.surah} — الآية ${thumn.ayah}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textLow),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: AppTheme.textMed),
        ),
      );

  // ── شريط الحفظ ─────────────────────────────────────────────
  Widget _saveBar() {
    final problem = _validate();
    return Container(
      color: AppTheme.surface,
      // إضافة حشوة شريط تنقّل أندرويد حتى لا يختفي الزر تحته.
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 14 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        children: [
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(problem,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_saving || problem != null) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('حفظ في Supabase',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
