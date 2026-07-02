import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/links_service.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
//  AdminScreen — تسجيل الدخول + تعديل روابط الأحزاب
// ══════════════════════════════════════════════════════════════

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loggingIn     = false;
  bool _loggedIn      = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    // إذا كان المستخدم مسجلاً مسبقاً
    _loggedIn = Supabase.instance.client.auth.currentUser != null;
    if (_loggedIn) _loadLinks();
  }

  // ══ تسجيل الدخول ══════════════════════════════════════════
  Future<void> _login() async {
    setState(() { _loggingIn = true; _loginError = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      setState(() { _loggedIn = true; });
      _loadLinks();
    } on AuthException catch (e) {
      setState(() { _loginError = e.message; });
    } finally {
      setState(() { _loggingIn = false; });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    setState(() { _loggedIn = false; _links = []; });
  }

  // ══ تحميل الروابط ═════════════════════════════════════════
  List<HizbLinks> _links  = [];
  bool _loadingLinks       = false;

  Future<void> _loadLinks() async {
    setState(() => _loadingLinks = true);
    LinksService.invalidateCache();
    final map = await LinksService.load();
    setState(() {
      _links       = List.generate(60, (i) =>
          map[i + 1] ?? HizbLinks(hizb: i + 1, youtube: '', pdf: ''));
      _loadingLinks = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: const Text('لوحة الإدارة',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_loggedIn)
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
        ],
      ),
      body: _loggedIn ? _buildLinksEditor() : _buildLoginForm(),
    );
  }

  // ── نموذج تسجيل الدخول ────────────────────────────────────
  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 64, color: AppTheme.primary),
            const SizedBox(height: 24),
            const Text('تسجيل دخول المشرف',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHigh)),
            const SizedBox(height: 28),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDec('البريد الإلكتروني', Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: _inputDec('كلمة المرور', Icons.lock_outline),
              onSubmitted: (_) => _login(),
            ),
            if (_loginError != null) ...[
              const SizedBox(height: 12),
              Text(_loginError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loggingIn ? null : _login,
                child: _loggingIn
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('دخول',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppTheme.primary),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
    ),
  );

  // ── محرر الروابط ──────────────────────────────────────────
  Widget _buildLinksEditor() {
    if (_loadingLinks) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _links.length,
      itemBuilder: (ctx, i) => _HizbEditTile(
        links: _links[i],
        onSaved: () => _showSaved(),
      ),
    );
  }

  void _showSaved() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم الحفظ ✓'),
        backgroundColor: AppTheme.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  _HizbEditTile — بطاقة تعديل روابط حزب واحد
// ══════════════════════════════════════════════════════════════
class _HizbEditTile extends StatefulWidget {
  final HizbLinks    links;
  final VoidCallback onSaved;

  const _HizbEditTile({required this.links, required this.onSaved});

  @override
  State<_HizbEditTile> createState() => _HizbEditTileState();
}

class _HizbEditTileState extends State<_HizbEditTile> {
  bool _expanded = false;
  bool _saving   = false;
  late final TextEditingController _ytCtrl;
  late final TextEditingController _pdfCtrl;

  @override
  void initState() {
    super.initState();
    _ytCtrl  = TextEditingController(text: widget.links.youtube);
    _pdfCtrl = TextEditingController(text: widget.links.pdf);
  }

  @override
  void dispose() {
    _ytCtrl.dispose();
    _pdfCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await LinksService.updateLinks(
        widget.links.hizb,
        youtube: _ytCtrl.text.trim(),
        pdf:     _pdfCtrl.text.trim(),
      );
      widget.onSaved();
      setState(() => _expanded = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withOpacity(0.12),
            child: Text(
              '${widget.links.hizb}',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(
            'الحزب ${widget.links.hizb}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            widget.links.youtube.isNotEmpty ? '✓ يوتيوب  ' : '✗ يوتيوب  ',
            style: TextStyle(
              fontSize: 11,
              color: widget.links.youtube.isNotEmpty
                  ? AppTheme.primary
                  : Colors.red.shade300,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _ytCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رابط يوتيوب',
                      prefixIcon: Icon(Icons.play_circle_outline,
                          color: Colors.red),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pdfCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رابط PDF',
                      prefixIcon: Icon(Icons.picture_as_pdf_outlined,
                          color: Colors.deepOrange),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
