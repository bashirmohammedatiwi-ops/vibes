import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'auth_controller.dart';

/// الدخول — دعوة ضيافة على حقل Midnight، لا نموذج SaaS
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _PinPhase { phone, create, confirm, unlock }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  _PinPhase _phase = _PinPhase.phone;
  String _draftPin = '';
  bool _loading = false;
  bool _pinBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      if (_phase != _PinPhase.phone && _codeController.text.length == 6) {
        _submitPin();
      }
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

  String get _displayPhone {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return '';
    return raw.startsWith('07') ? raw : _normalizedPhone;
  }

  Future<void> _continuePhone() async {
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
      final hasPin = await ref.read(authControllerProvider.notifier).hasPin(phone);
      if (!mounted) return;
      setState(() {
        _phase = hasPin ? _PinPhase.unlock : _PinPhase.create;
        _draftPin = '';
        _loading = false;
        _codeController.clear();
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = maisonError(e);
      });
    }
  }

  Future<void> _submitPin() async {
    if (_loading || _pinBusy || _phase == _PinPhase.phone) return;
    final pin = _codeController.text.trim();
    if (pin.length != 6) return;
    _pinBusy = true;

    if (_phase == _PinPhase.create) {
      setState(() {
        _draftPin = pin;
        _phase = _PinPhase.confirm;
        _error = null;
        _codeController.clear();
      });
      _pinBusy = false;
      HapticFeedback.selectionClick();
      return;
    }

    if (_phase == _PinPhase.confirm && pin != _draftPin) {
      setState(() {
        _error = 'الرقمان غير متطابقين — اختر الرقم من جديد';
        _phase = _PinPhase.create;
        _draftPin = '';
        _codeController.clear();
      });
      _pinBusy = false;
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .loginWithPin(_normalizedPhone, pin);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = maisonError(e);
        _codeController.clear();
      });
    } finally {
      _pinBusy = false;
    }
  }

  void _finish() {
    final auth = ref.read(authControllerProvider);
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    if (context.canPop()) {
      context.pop(true);
      return;
    }
    if (next != null && next.startsWith('/') && !next.startsWith('//')) {
      context.go(next);
      return;
    }
    context.go(auth.isProvider ? '/provider' : '/home');
  }

  void _backToPhone() {
    setState(() {
      _phase = _PinPhase.phone;
      _draftPin = '';
      _codeController.clear();
      _error = null;
      _loading = false;
    });
  }

  String get _headline => switch (_phase) {
    _PinPhase.phone => 'ادخل\nحين تشاء',
    _PinPhase.create => 'ستة\nأرقام',
    _PinPhase.confirm => 'أكّد\nالرقم',
    _PinPhase.unlock => 'أهلاً\nبك',
  };

  String get _subtitle => switch (_phase) {
    _PinPhase.phone => 'تصفح الأماكن بحرية. الدخول عند إتمام الحجز',
    _PinPhase.create => 'اختر ستة أرقام خاصة بك، بلا رسائل تحقق',
    _PinPhase.confirm => 'أدخل الأرقام الستة مرة أخرى',
    _PinPhase.unlock => 'أدخل الرقم السري لحساب $_displayPhone',
  };

  String get _kicker => switch (_phase) {
    _PinPhase.phone => 'ضيافة بلا عجلة',
    _PinPhase.create || _PinPhase.confirm => 'رقم سري جديد',
    _PinPhase.unlock => 'الرقم السري',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MaisonNightWash(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 80 || constraints.maxHeight < 80) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BrandLockup(kicker: _kicker)
                            .animate()
                            .fadeIn(duration: 420.ms)
                            .slideY(begin: .04, end: 0),
                        const SizedBox(height: 20),
                        Text(
                          _headline,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: Vibes.canvas,
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                              ),
                        ).animate().fadeIn(delay: 80.ms),
                        const SizedBox(height: 10),
                        const ArcFlourish(width: 42, color: Vibes.tealBright),
                        const SizedBox(height: 12),
                        Text(
                          _subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xCCFAF7F0),
                                height: 1.65,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child:
                          MaisonInviteDock(
                                child: SafeArea(
                                  top: false,
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 520,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          18,
                                          24,
                                          12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _InvitationForm(
                                              phase: _phase,
                                              loading: _loading,
                                              error: _error,
                                              phoneController: _phoneController,
                                              codeController: _codeController,
                                              onContinue: _continuePhone,
                                              onChangeNumber: _backToPhone,
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 140.ms)
                              .slideY(begin: .06, end: 0),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.kicker});

  final String kicker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VibesLogo.lockup(height: 72),
        const SizedBox(height: 18),
        MaisonKicker(
          kicker,
          light: true,
          color: Vibes.tealBright,
        ),
      ],
    );
  }
}

class _InvitationForm extends StatelessWidget {
  const _InvitationForm({
    required this.phase,
    required this.loading,
    required this.error,
    required this.phoneController,
    required this.codeController,
    required this.onContinue,
    required this.onChangeNumber,
  });

  final _PinPhase phase;
  final bool loading;
  final String? error;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final VoidCallback onContinue;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          _ErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        if (phase == _PinPhase.phone) ...[
          MaisonField(
            label: 'رقم الهاتف',
            controller: phoneController,
            hint: '07XX XXX XXXX',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onContinue(),
            maxLength: 13,
            textDirection: TextDirection.ltr,
            fieldDirection: TextDirection.ltr,
            prefix: Text(
              '+964',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Vibes.coral,
              ),
            ),
          ),
          const SizedBox(height: 20),
          VibesButton(
            label: 'متابعة',
            loading: loading,
            onPressed: onContinue,
          ),
        ] else ...[
          Text(
            switch (phase) {
              _PinPhase.create => 'اختر الرقم السري',
              _PinPhase.confirm => 'أكّد الرقم السري',
              _ => 'الرقم السري',
            },
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Vibes.inkSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _CodeField(controller: codeController),
          if (loading) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onChangeNumber,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('تغيير الرقم'),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const ScallopDivider(),
        const SizedBox(height: 12),
        Text(
          'بالدخول أنت توافق على شروط الاستخدام وسياسة الخصوصية',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Vibes.inkTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: SemanticColors.danger.withValues(alpha: .08),
      borderColor: SemanticColors.danger.withValues(alpha: .28),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: SemanticColors.danger,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: SemanticColors.danger),
              ),
            ),
          ],
        ),
      ),
    ).animate().shakeX(duration: 400.ms).fadeIn();
  }
}

class _CodeField extends StatefulWidget {
  const _CodeField({required this.controller});

  final TextEditingController controller;

  @override
  State<_CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<_CodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
          Row(
            children: List.generate(6, (i) {
              final filled = i < code.length;
              final isNext = i == code.length;
              final active = isNext || (i == 5 && filled);
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: i == 5 ? 0 : 6),
                  child: AnimatedContainer(
                    duration: VibesMotion.fast,
                    curve: VibesMotion.curve,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: Vibes.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: Folio.compact,
                        side: BorderSide(
                          color: active
                              ? Vibes.teal
                              : filled
                              ? Vibes.coral.withValues(alpha: .45)
                              : Vibes.hairlineStrong,
                          width: active ? 1.6 : 1,
                        ),
                      ),
                    ),
                    child: Text(
                      filled ? code[i] : '',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Vibes.ink,
                      ),
                    ),
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
