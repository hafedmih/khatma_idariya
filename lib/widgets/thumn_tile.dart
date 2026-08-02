import 'package:flutter/material.dart';
import '../models/hizb.dart';
import '../services/links_service.dart';
import '../screens/pdf_viewer_screen.dart';
import '../theme/app_theme.dart';

// اختصار الثمن: بطاقة تُظهر رقم الثمن وبدايته، والضغط عليها يفتح صفحته للقراءة
class ThumnTile extends StatelessWidget {
  final Thumn      thumn;
  final int        hizbNumber;
  final String?    youtubeUrl;
  final HizbLinks? links;

  const ThumnTile({
    super.key,
    required this.thumn,
    required this.hizbNumber,
    this.youtubeUrl,
    this.links,
  });

  void _openRead(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PdfViewerScreen(
        hizbNumber: hizbNumber,
        title: 'الحزب $hizbNumber — الثمن ${thumn.number}',
        youtubeUrl: youtubeUrl,
        hizbLinks: links,
        initialPage: thumn.number, // كل ثمن = صفحة (8 أثمان = 8 صفحات)
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openRead(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECE8E3)),
        ),
        child: Row(
          children: [
            _ThumnNumber(number: thumn.number),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الثمن ${thumn.ordinalLabel} — سورة ${thumn.surah} ${thumn.ayah}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textLow,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // بداية الثمن كعنوان فرعي
                  Text(
                    thumn.openingVerse,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.8,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textHigh,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _ThumnNumber extends StatelessWidget {
  final int number;
  const _ThumnNumber({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
