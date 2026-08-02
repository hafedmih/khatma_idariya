import 'package:flutter/material.dart';
import '../models/hizb.dart';
import '../theme/app_theme.dart';

class HizbCard extends StatelessWidget {
  final Hizb   hizb;
  final int    dayIndex;   // ١، ٢، أو ٣ (ترتيب الحزب في اليوم)
  final VoidCallback onTap;
  final VoidCallback? onYoutube;
  final bool   hasAudio;     // تتوفّر تلاوة mp3
  final bool   hasPageTimes; // يتوفّر تقسيم الصفحات (مزامنة)
  final bool   isDownloaded; // التلاوة منزّلة (تعمل دون إنترنت)

  const HizbCard({
    super.key,
    required this.hizb,
    required this.dayIndex,
    required this.onTap,
    this.onYoutube,
    this.hasAudio = false,
    this.hasPageTimes = false,
    this.isDownloaded = false,
  });

  List<Color> get _gradient =>
    AppTheme.hizbGradients[(dayIndex - 1).clamp(0, 2)];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _gradient.first.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ───── رقم الحزب ─────
                _HizbBadge(number: hizb.number, gradient: _gradient),
                // ───── المحتوى ─────
                Expanded(child: _Content(
                  hizb: hizb,
                  onYoutube: onYoutube,
                  hasAudio: hasAudio,
                  hasPageTimes: hasPageTimes,
                  isDownloaded: isDownloaded,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _HizbBadge extends StatelessWidget {
  final int number;
  final List<Color> gradient;
  const _HizbBadge({required this.number, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'الحزب',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _Content extends StatelessWidget {
  final Hizb hizb;
  final VoidCallback? onYoutube;
  final bool hasAudio;
  final bool hasPageTimes;
  final bool isDownloaded;
  const _Content({
    required this.hizb,
    this.onYoutube,
    this.hasAudio = false,
    this.hasPageTimes = false,
    this.isDownloaded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── فاتحة الحزب ──
          Text(
            hizb.openingVerse,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textHigh,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 8),
          // ── النطاق + علامات الحالة ──
          Row(
            children: [
              Flexible(child: _RangePill(hizb: hizb)),
              const Spacer(),
              // التلاوة منزّلة (تعمل دون إنترنت)
              if (isDownloaded)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.offline_pin_rounded,
                      color: Color(0xFF2E7D32), size: 18),
                ),
              // تتوفّر تلاوة mp3 (لا تُعرض إن كانت منزّلة — معلومة مكرّرة)
              if (hasAudio && !isDownloaded)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.play_circle_outline_rounded,
                      color: Colors.red, size: 18),
                ),
              // يتوفّر تقسيم الصفحات (مزامنة الصوت)
              if (hasPageTimes)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.auto_stories_rounded,
                      color: Color(0xFF1A73E8), size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final Hizb hizb;
  const _RangePill({required this.hizb});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 12, color: AppTheme.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${hizb.from.surah} (${hizb.from.ayah}) — ${hizb.to.surah} (${hizb.to.ayah})',
              style: const TextStyle(fontSize: 11, color: AppTheme.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
