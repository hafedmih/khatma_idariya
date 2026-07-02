import 'package:flutter/material.dart';
import '../models/hizb.dart';
import '../theme/app_theme.dart';

class ThumnTile extends StatefulWidget {
  final Thumn thumn;
  final bool  initiallyExpanded;

  const ThumnTile({
    super.key,
    required this.thumn,
    this.initiallyExpanded = false,
  });

  @override
  State<ThumnTile> createState() => _ThumnTileState();
}

class _ThumnTileState extends State<ThumnTile>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _ctrl;
  late Animation<double>   _rotate;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _expanded ? 1.0 : 0.0,
    );
    _rotate = Tween(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _expanded ? _ctrl.forward() : _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _expanded
              ? AppTheme.primary.withOpacity(0.04)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? AppTheme.primary.withOpacity(0.25)
                : const Color(0xFFECE8E3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── الرأس ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // رقم الثمن
                  _ThumnNumber(number: widget.thumn.number, active: _expanded),
                  const SizedBox(width: 12),
                  // السورة والآية
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الثمن ${widget.thumn.ordinalLabel}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textLow,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'سورة ${widget.thumn.surah} — الآية ${widget.thumn.ayah}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textHigh,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // سهم التوسع
                  RotationTransition(
                    turns: _rotate,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _expanded ? AppTheme.primary : AppTheme.textLow,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            // ── نص الآية (قابل للتوسع) ──
            SizeTransition(
              sizeFactor: _fade,
              child: FadeTransition(
                opacity: _fade,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      right: BorderSide(
                        color: AppTheme.primary.withOpacity(0.4),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    widget.thumn.openingVerse,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 2.0,
                      color: AppTheme.textHigh,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _ThumnNumber extends StatelessWidget {
  final int  number;
  final bool active;
  const _ThumnNumber({required this.number, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : AppTheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: active ? Colors.white : AppTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
