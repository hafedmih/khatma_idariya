import 'package:flutter/material.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════
//  شاشة المستخدمين المحظورين — عرض ورفع الحظر
// ═══════════════════════════════════════════════
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<BlockedUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = GroupService.blockedUsers();
  }

  void _reload() {
    setState(() { _future = GroupService.blockedUsers(); });
  }

  Future<void> _unblock(BlockedUser u) async {
    final name = (u.displayName != null && u.displayName!.trim().isNotEmpty)
        ? u.displayName!.trim() : 'هذا المستخدم';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفع الحظر'),
        content: Text('رفع الحظر عن $name؟ سيظهر محتواه لك من جديد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفع الحظر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupService.unblockUser(u.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('رُفع الحظر عن $name')));
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('المستخدمون المحظورون',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<BlockedUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final users = snap.data ?? const <BlockedUser>[];
          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_rounded, size: 64, color: AppTheme.textLow),
                    SizedBox(height: 12),
                    Text('لا يوجد مستخدمون محظورون',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('عند حظر عضو من مجموعة سيظهر هنا لرفع الحظر.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMed, fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final u = users[i];
              final name = (u.displayName != null && u.displayName!.trim().isNotEmpty)
                  ? u.displayName!.trim() : 'مستخدم';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8E4DF)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primary.withOpacity(.12),
                      backgroundImage:
                          u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null,
                      child: u.avatarUrl == null
                          ? const Icon(Icons.person, color: AppTheme.primary) : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    OutlinedButton(
                      onPressed: () => _unblock(u),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('رفع الحظر',
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
