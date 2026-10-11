import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'login.dart';
import 'shell.dart';

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Session.load();
    if (Session.token != null || (Session.refreshToken != null && Session.refreshToken!.isNotEmpty)) {
      try {
        if (Session.token == null) await Session.refreshAccess();
        if (Session.token != null) {
          Session.applyMe(await Api.map('/api/staff/me'));
        }
      } catch (_) {
        await Session.clear(notify: false);
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const _Splash();
    }
    if (Session.token == null) return const LoginScreen();
    return const OfficeShell();
  }
}

/// شاشة الإقلاع — بنفس هوية شاشة الدخول.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<StaffBrand>()?.montserrat ?? const TextStyle();
    return Scaffold(
      backgroundColor: placeNavy,
      body: Container(
        decoration: const BoxDecoration(gradient: placeNavyFill),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: placeGoldFill,
                borderRadius: BorderRadius.circular(StaffRadius.xl),
                boxShadow: [BoxShadow(color: placeGold.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Text(
                'V',
                style: brand.copyWith(fontSize: 34, fontWeight: FontWeight.w800, color: placeInk),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'VIBES',
              style: brand.copyWith(fontSize: 14, letterSpacing: 7, color: placeGold, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'مكتب الموظفين',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white70),
            ),
            const SizedBox(height: 28),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: placeGold)),
          ],
        ),
      ),
    );
  }
}
