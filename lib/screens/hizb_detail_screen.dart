import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hizb.dart';
import '../services/links_service.dart';
import '../theme/app_theme.dart';
import '../widgets/thumn_tile.dart';
import 'pdf_viewer_screen.dart';

class HizbDetailScreen extends StatelessWidget {
  final Hizb       hizb;
  final HizbLinks? links; // روابط من السيرفر (تُقدَّم على روابط ahzab.json)

  const HizbDetailScreen({super.key, required this.hizb, this.links});

  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _OpeningVerseCard(hizb: hizb),
                const SizedBox(height: 12),
                _RangeCard(hizb: hizb),
                const SizedBox(height: 16),
                _ActionRow(hizb: hizb, links: links),
                const SizedBox(height: 28),
                _AthmanSection(hizb: hizb),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver AppBar متمدد ──
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppTheme.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsets.fromLTRB(60, 0, 60, 14),
        title: Text(
          'الحزب ${hizb.number}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        background: _AppBarBackground(hizbNumber: hizb.number),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
          tooltip: 'نسخ فاتحة الحزب',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: hizb.openingVerse));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم نسخ فاتحة الحزب'),
                duration: Duration(seconds: 2),
                backgroundColor: AppTheme.primary,
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
class _AppBarBackground extends StatelessWidget {
  final int hizbNumber;
  const _AppBarBackground({required this.hizbNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDk, AppTheme.primary, AppTheme.primaryLt],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // دائرة زخرفية
          Positioned(
            right: -40, top: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            left: -20, bottom: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          // الرقم الكبير
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                Text(
                  'الحزب',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$hizbNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _OpeningVerseCard extends StatelessWidget {
  final Hizb hizb;
  const _OpeningVerseCard({required this.hizb});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          right: BorderSide(color: AppTheme.gold, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded, color: AppTheme.gold, size: 18),
              const SizedBox(width: 6),
              Text(
                'فاتحة الحزب',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hizb.openingVerse,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 16,
              height: 2.0,
              color: AppTheme.textHigh,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _RangeCard extends StatelessWidget {
  final Hizb hizb;
  const _RangeCard({required this.hizb});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hizb.rangeFull,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  final Hizb       hizb;
  final HizbLinks? links;
  const _ActionRow({required this.hizb, this.links});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            icon:    Icons.play_circle_fill_rounded,
            label:   'استمع',
            sub:     'يوتيوب',
            color:   const Color(0xFFCC0000),
            enabled: _ytUrl.isNotEmpty,
            onTap:   _ytUrl.isNotEmpty ? () => _launchExternal(_ytUrl) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionBtn(
            icon:    Icons.picture_as_pdf_rounded,
            label:   'اقرأ',
            sub:     'Google Drive',
            color:   const Color(0xFF1A73E8),
            enabled: _pdfUrl.isNotEmpty,
            onTap:   _pdfUrl.isNotEmpty ? () => _openPdf(context) : null,
          ),
        ),
      ],
    );
  }

  // روابط مدمجة: السيرفر أولاً، ثم ahzab.json احتياطياً
  String get _ytUrl  => (links?.youtube.isNotEmpty == true) ? links!.youtube : hizb.youtube;
  String get _pdfUrl => (links?.pdf.isNotEmpty     == true) ? links!.pdf     : hizb.pdf;

  // يوتيوب → يفتح خارجياً في تطبيق يوتيوب أو المتصفح
  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // PDF → يفتح داخل التطبيق بمتصفح مدمج
  void _openPdf(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url:        _pdfUrl,
          title:      'الحزب ${hizb.number}',
          youtubeUrl: _ytUrl,
          hizbLinks:  links,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sub;
  final Color    color;
  final bool     enabled;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 5))]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: enabled ? Colors.white : Colors.grey, size: 30),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                color: enabled ? Colors.white70 : Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _AthmanSection extends StatelessWidget {
  final Hizb hizb;
  const _AthmanSection({required this.hizb});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── العنوان ──
        Row(
          children: [
            Container(
              width: 4, height: 22,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'الأثمان الثمانية',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${hizb.athman.length} أثمان',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── القائمة ──
        ...hizb.athman.map((t) => ThumnTile(thumn: t)),
      ],
    );
  }
}
