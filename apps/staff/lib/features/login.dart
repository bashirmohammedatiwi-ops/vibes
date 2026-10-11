import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/permissions.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showPin = false;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await Api.map('/api/auth/pin', method: 'POST', body: {'phone': _phone.text.trim(), 'pin': _pin.text.trim()});
      await Session.saveTokens(access: data['accessToken'] as String, refresh: (data['refreshToken'] as String?) ?? '');
      Session.applyMe(await Api.map('/api/staff/me'));
      await StaffPermissions.requestForCallCenter();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OfficeShell()));
    } catch (e) {
      await Session.clear(notify: false);
      setState(() => _error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _canSubmit => _phone.text.trim().isNotEmpty && _pin.text.trim().isNotEmpty && !_busy;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<StaffBrand>()?.montserrat;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: placeNavy,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: placeNavyFill),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // ── العلامة ──
                      AnimatedPadding(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.fromLTRB(24, keyboard ? 20 : 48, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: placeGoldFill,
                                borderRadius: BorderRadius.circular(StaffRadius.lg),
                                boxShadow: [BoxShadow(color: placeGold.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 6))],
                              ),
                              child: Text(
                                'V',
                                style: (brand ?? const TextStyle()).copyWith(fontSize: 28, fontWeight: FontWeight.w800, color: placeInk),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'VIBES',
                              style: (brand ?? const TextStyle()).copyWith(
                                fontSize: 13,
                                letterSpacing: 6,
                                color: placeGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'مكتب الموظفين',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'مركز اتصال · محادثات · حجوزات · إدارة',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // ── بطاقة الدخول ──
                      Container(
                        margin: const EdgeInsets.fromLTRB(StaffSpace.page, 24, StaffSpace.page, StaffSpace.page),
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(StaffRadius.xl),
                          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 12))],
                        ),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'تسجيل الدخول',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w900, color: placeInk),
                              ),
                              const Text(
                                'استخدم رقم هاتفك ورمز الدخول الذي سلّمه لك المشرف.',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: placeInk2,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.telephoneNumber],
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, color: placeInk),
                                decoration: const InputDecoration(
                                  labelText: 'رقم الهاتف',
                                  hintText: '07xx xxx xxxx',
                                  prefixIcon: Icon(Icons.phone_rounded),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _pin,
                                obscureText: !_showPin,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) {
                                  if (_canSubmit) _login();
                                },
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: placeInk,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'رمز الدخول',
                                  prefixIcon: const Icon(Icons.lock_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _showPin ? 'إخفاء الرمز' : 'إظهار الرمز',
                                    icon: Icon(_showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                    onPressed: () => setState(() => _showPin = !_showPin),
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                child: _error == null
                                    ? const SizedBox(width: double.infinity)
                                    : Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: placeDanger.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(StaffRadius.md),
                                          border: Border.all(color: placeDanger.withValues(alpha: 0.2)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: placeDanger, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _error!,
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  color: placeDanger,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _canSubmit ? _login : null,
                                  child: _busy
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('دخول'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_rounded, size: 14, color: placeInk3),
                                  SizedBox(width: 5),
                                  Text(
                                    'اتصال آمن — للموظفين المصرّح لهم فقط',
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w600, color: placeInk3),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
