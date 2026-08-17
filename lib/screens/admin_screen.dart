import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hizb.dart';
import '../services/admin_service.dart';
import '../services/hizb_service.dart';
import '../services/links_service.dart';
import '../theme/app_theme.dart';
import 'page_time_calibration_screen.dart';

// ══════════════════════════════════════════════════════════════
//  AdminScreen — دخول المشرف + ضبط أوقات صفحات الأحزاب
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
  bool _isAdmin       = false;
  bool _checkingAdmin = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    // إذا كان المستخدم مسجلاً مسبقاً
    _loggedIn = Supabase.instance.client.auth.currentUser != null;
    if (_loggedIn) _afterLogin();
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
      _afterLogin();
    } on AuthException catch (e) {
      setState(() { _loginError = e.message; });
    } finally {
      setState(() { _loggingIn = false; });
    }
  }

  // تسجيل الدخول وحده لا يكفي — يجب أن يكون الحساب في app_admins.
  Future<void> _afterLogin() async {
    setState(() => _checkingAdmin = true);
    final ok = await AdminService.isAdmin(refresh: true);
    if (!mounted) return;
    setState(() { _isAdmin = ok; _checkingAdmin = false; });
    if (ok) _loadData();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    AdminService.invalidate();
    setState(() { _loggedIn = false; _isAdmin = false; _links = []; });
  }

  // ══ تحميل الأحزاب وأوقاتها ════════════════════════════════
  List<HizbLinks> _links = [];
  List<Hizb>      _ahzab = [];
  bool _loadingLinks     = false;

  Future<void> _loadData() async {
    setState(() => _loadingLinks = true);
    LinksService.invalidateCache();
    final map = await LinksService.load();
    List<Hizb> ahzab = const [];
    try {
      ahzab = await HizbService.loadAhzab();
    } catch (_) {
      // نصوص الافتتاح غير متاحة — القائمة تعمل بأرقام الأحزاب فقط.
    }
    if (!mounted) return;
    setState(() {
      _links = List.generate(60, (i) =>
          map[i + 1] ?? HizbLinks(hizb: i + 1, youtube: '', pdf: ''));
      _ahzab = ahzab;
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
      body: !_loggedIn
          ? _buildLoginForm()
          : _checkingAdmin
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : _isAdmin
                  ? _buildHizbList()
                  : _buildNotAdmin(),
    );
  }

  // ── حساب مسجَّل لكنّه ليس مشرفاً ──────────────────────────
  Widget _buildNotAdmin() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_accounts_rounded,
                  size: 64, color: Colors.red.shade300),
              const SizedBox(height: 20),
              const Text('هذا الحساب ليس مشرفاً',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textHigh)),
              const SizedBox(height: 10),
              const Text(
                'لوحة الإدارة مخصّصة لحسابات المشرفين فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMed),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      );

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

  // ── قائمة الأحزاب ─────────────────────────────────────────
  Widget _buildHizbList() {
    if (_loadingLinks) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    return ListView.builder(
      // حشوة سفليّة بقدر شريط تنقّل أندرويد حتى لا يُقتطع آخر حزب.
      padding: EdgeInsets.fromLTRB(
          12, 12, 12, 12 + MediaQuery.viewPaddingOf(context).bottom),
      itemCount: _links.length,
      itemBuilder: (ctx, i) => _HizbEditTile(
        links: _links[i],
        hizb: HizbService.find(_ahzab, i + 1),
        onTimesChanged: _loadData,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  _HizbEditTile — بطاقة حزب واحد: افتتاحه، وضبط أوقاته بالاستماع
// ══════════════════════════════════════════════════════════════
class _HizbEditTile extends StatefulWidget {
  final HizbLinks    links;
  final Hizb?        hizb;
  final VoidCallback onTimesChanged;

  const _HizbEditTile({
    required this.links,
    required this.hizb,
    required this.onTimesChanged,
  });

  @override
  State<_HizbEditTile> createState() => _HizbEditTileState();
}

class _HizbEditTileState extends State<_HizbEditTile> {
  bool _expanded = false;

  /// هل أوقات الصفحات السبع مضبوطة كلّها؟
  bool get _calibrated {
    final t = widget.links.pageTimes;
    return t.length >= 7 && t.take(7).every((v) => v > 0);
  }

  /// الحفظ يقع داخل شاشة الضبط؛ هنا نُحدّث القائمة بعد الرجوع فقط.
  Future<void> _openCalibration() async {
    final result = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => PageTimeCalibrationScreen(
          hizb: widget.links.hizb,
          initialTimes: widget.links.pageTimes,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _expanded = false);
    widget.onTimesChanged();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hizb;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
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
          // افتتاح الحزب بدل حالة يوتيوب — كما في قائمة المصحف.
          subtitle: (h == null)
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (h.openingVerse.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          h.openingVerse,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: AppTheme.textMed),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${h.from.surah} (${h.from.ayah})'
                        ' — ${h.to.surah} (${h.to.ayah})',
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textLow),
                      ),
                    ),
                  ],
                ),
          trailing: Icon(
            _calibrated ? Icons.timer_rounded : Icons.timer_off_outlined,
            size: 19,
            color: _calibrated ? AppTheme.primary : Colors.red.shade300,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _openCalibration,
                  icon: const Icon(Icons.headphones_rounded, size: 18),
                  label: const Text('ضبط الأوقات بالاستماع',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
