import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

Future<void> providerLogout(BuildContext context, WidgetRef ref) async {
  await ref.read(authControllerProvider.notifier).logout();
  if (context.mounted) context.go('/home');
}
