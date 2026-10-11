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
      final data = await Api.map('/api/auth/pin', method: 'POST', body: {
        'phone': _phone.text.trim(),
        'pin': _pin.text.trim(),
      });
      await Session.saveTokens(
        access: data['accessToken'] as String,
        refresh: (data['refreshToken'] as String?) ?? '',
      );
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
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<StaffBrand>()?.montserrat;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [placeInk, Color(0xFF1E2A3D)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VIBES', style: brand?.copyWith(fontSize: 13, letterSpacing: 5, color: placeBrass, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text('مكتب الموظفين', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('مركز اتصال · محادثات · حجوزات', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: placeInk.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('دخول آمن', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pin,
                        obscureText: !_showPin,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'رمز الدخول',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_showPin ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showPin = !_showPin),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: placeDanger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                          child: Text(_error!, style: const TextStyle(color: placeDanger, fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _login,
                        child: _busy
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('تسجيل الدخول'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
