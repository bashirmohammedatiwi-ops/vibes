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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: placeInk)));
    }
    if (Session.token == null) return const LoginScreen();
    return const OfficeShell();
  }
}
