import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'auth_controller.dart';

/// الدخول — هاتف ثم رمز OTP بست خانات أنيقة
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeStep = false;
  bool _loading = false;
  String? _error;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      final code = _codeController.text;
      if (code.length == 6) _verify();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _normalizedPhone {
    var phone = _phoneController.text.trim().replaceAll(' ', '');
    if (phone.startsWith('07') && phone.length == 11) {
      phone = '964${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _sendCode() async {
    final phone = _normalizedPhone;
    if (phone.length < 12) {
      setState(() => _error = 'أدخل رقم هاتف عراقي صحيح (مثال 07XXXXXXXXX)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _codeStep = true;
        _loading = false;
        _resendSeconds = 45;
      });
      _tickResend();
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _tickResend() async {
    while (_resendSeconds > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _resendSeconds--);
    }
  }

  Future<void> _verify() async {
    if (_loading) return;
    final phone = _normalizedPhone;
    final code = _codeController.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(phone, code);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final auth = ref.read(authControllerProvider);
      context.go(auth.isProvider ? '/provider' : '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _codeController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العلامة
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: GoldColors.gradient,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: GoldColors.onGold, size: 26),
                      ),
                      const SizedBox(width: 14),
                      ShaderMask(
                        shaderCallback: (b) =>
                            GoldColors.textGradient.createShader(b),
                        child: Text(
                          'VIBES',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: .05, end: 0),
                  const SizedBox(height: 40),

                  Text(
                    _codeStep ? 'أدخل رمز التحقق' : 'أهلاً بك مجدداً',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: InkColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeStep
                        ? 'أرسلنا رمزاً من ستة أرقام إلى $_normalizedPhone'
                        : 'سجّل الدخول برقم هاتفك لتابع حجوزاتك وأماكنك المفضلة',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: InkColors.textSecondary,
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 32),

                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],

                  if (!_codeStep) ...[
                    _PhoneField(
                      controller: _phoneController,
                      onSubmit: _sendCode,
                    ),
                    const SizedBox(height: 20),
                    VibesButton(
                      label: 'إرسال رمز التحقق',
                      loading: _loading,
                      onPressed: _sendCode,
                    ),
                  ] else ...[
                    _CodeField(
                      controller: _codeController,
                      phone: _normalizedPhone,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _resendSeconds > 0
                              ? 'إعادة الإرسال بعد $_resendSeconds ثانية'
                              : 'لم يصلك الرمز؟',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: InkColors.textTertiary,
                                  ),
                        ),
                        if (_resendSeconds == 0) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _sendCode,
                            child: Text(
                              'إعادة إرسال',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: GoldColors.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _codeStep = false;
                          _codeController.clear();
                          _error = null;
                        }),
                        child: const Text('تغيير الرقم'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'بالدخول أنت توافق على شروط الاستخدام وسياسة الخصوصية',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: InkColors.textTertiary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SemanticColors.danger.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(VibesRadius.md),
        border: Border.all(
          color: SemanticColors.danger.withValues(alpha: .3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: SemanticColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SemanticColors.danger,
                  ),
            ),
          ),
        ],
      ),
    ).animate().shakeX(duration: 400.ms).fadeIn();
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmit(),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: InkColors.textPrimary,
          ),
      decoration: const InputDecoration(
        hintText: '07XX XXX XXXX',
        prefixIcon: Icon(Icons.phone_outlined),
        counterText: '',
      ),
      maxLength: 13,
    );
  }
}

class _CodeField extends StatefulWidget {
  const _CodeField({required this.controller, required this.phone});

  final TextEditingController controller;
  final String phone;

  @override
  State<_CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<_CodeField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;

    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final filled = i < code.length;
              final isLast = i == 5 && filled;
              return AnimatedContainer(
                duration: VibesMotion.fast,
                curve: VibesMotion.curve,
                width: 48,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: InkColors.canvasHigh,
                  borderRadius: BorderRadius.circular(VibesRadius.md),
                  border: Border.all(
                    color: isLast
                        ? GoldColors.gold
                        : filled
                            ? GoldColors.gold.withValues(alpha: .5)
                            : InkColors.hairline,
                    width: isLast ? 1.4 : 1,
                  ),
                ),
                child: Text(
                  filled ? code[i] : '',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: InkColors.textPrimary,
                      ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
