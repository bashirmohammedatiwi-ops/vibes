import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile/profile_screen.dart' show openLegal;
import '../../core/app_mode/app_mode_controller.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../home/home_sections.dart';
import 'auth_controller.dart';

/// ═══════════════════════════════════════════════════════════
/// الدخول — رأس ليلي بجوّ العالم الحالي يحتضن الشعار، وبطاقة بيضاء
/// تصعد فوقه تحمل خطوة واحدة فقط في كل مرة. الألوان كلها من العالم.
/// ═══════════════════════════════════════════════════════════
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _PinPhase { phone, create, confirm, unlock }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _pinFocus = FocusNode();
  _PinPhase _phase = _PinPhase.phone;
  String _draftPin = '';
  bool _loading = false;
  bool _pinBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_onPinChanged);
    _phoneController.addListener(_rebuild);
    _phoneFocus.addListener(_rebuild);
    _pinFocus.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onPinChanged() {
    if (mounted) setState(() {});
    if (_phase == _PinPhase.phone) return;
    if (_pinController.text.length == 6) {
      _submitPin();
    } else if (_error != null) {
      setState(() => _error = null);
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_rebuild);
    _pinController.removeListener(_onPinChanged);
    _phoneFocus.removeListener(_rebuild);
    _pinFocus.removeListener(_rebuild);
    _phoneController.dispose();
    _pinController.dispose();
    _phoneFocus.dispose();
    _pinFocus.dispose();
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
    _phoneFocus.unfocus();
    final phone = _normalizedPhone;
    if (phone.length < 12) {
      setState(() => _error = 'أدخل رقم هاتف عراقي صحيح، مثل 07XXXXXXXXX');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final hasPin = await ref
          .read(authControllerProvider.notifier)
          .hasPin(phone);
      if (!mounted) return;
      setState(() {
        _phase = hasPin ? _PinPhase.unlock : _PinPhase.create;
        _draftPin = '';
        _loading = false;
        _pinController.clear();
      });
      HapticFeedback.lightImpact();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocus.requestFocus();
      });
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
    final pin = _pinController.text.trim();
    if (pin.length != 6) return;
    _pinBusy = true;

    if (_phase == _PinPhase.create) {
      setState(() {
        _draftPin = pin;
        _phase = _PinPhase.confirm;
        _error = null;
        _pinController.clear();
      });
      _pinBusy = false;
      HapticFeedback.selectionClick();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocus.requestFocus();
      });
      return;
    }

    if (_phase == _PinPhase.confirm && pin != _draftPin) {
      setState(() {
        _error = 'الرقمان غير متطابقين — أعد الاختيار';
        _phase = _PinPhase.create;
        _draftPin = '';
        _pinController.clear();
      });
      _pinBusy = false;
      HapticFeedback.lightImpact();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocus.requestFocus();
      });
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
        _pinController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocus.requestFocus();
      });
    } finally {
      _pinBusy = false;
    }
  }

  Future<void> _finish() async {
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
    if (auth.isProvider) {
      await ref.read(appModeProvider.notifier).onProviderLogin();
      if (!mounted) return;
      context.go('/provider');
      return;
    }
    context.go('/home');
  }

  void _backToPhone() {
    _pinFocus.unfocus();
    setState(() {
      _phase = _PinPhase.phone;
      _draftPin = '';
      _pinController.clear();
      _error = null;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  String get _kicker => switch (_phase) {
    _PinPhase.phone => 'VIBES',
    _PinPhase.create => 'خطوة ١ من ٢',
    _PinPhase.confirm => 'خطوة ٢ من ٢',
    _PinPhase.unlock => 'مرحباً بعودتك',
  };

  String get _headline => switch (_phase) {
    _PinPhase.phone => 'سجّل دخولك',
    _PinPhase.create => 'اختر رقماً سرياً',
    _PinPhase.confirm => 'أكّد الرقم السري',
    _PinPhase.unlock => 'أدخل الرقم السري',
  };

  String get _subtitle => switch (_phase) {
    _PinPhase.phone =>
      'رقم هاتفك العراقي يكفي. الحساب يُنشأ تلقائياً عند أول دخول.',
    _PinPhase.create =>
      'ستة أرقام تتذكرها بسهولة. تُحفظ مشفّرة ولا يطّلع عليها أحد.',
    _PinPhase.confirm => 'أعد كتابة الأرقام نفسها لتثبيتها.',
    _PinPhase.unlock => 'نفس الأرقام التي اخترتها لهذا الرقم.',
  };

  @override
  Widget build(BuildContext context) {
    final isPin = _phase != _PinPhase.phone;
    final world = ref.watch(homeSectionProvider);
    final p = world.palette;
    final step = switch (_phase) {
      _PinPhase.phone => 0,
      _PinPhase.create || _PinPhase.unlock => 1,
      _PinPhase.confirm => 2,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(darkBackground: true),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ── الرأس الليلي بجوّ العالم ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 290,
              child: WorldAtmosphere(palette: p, night: true, intensity: 1.2),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        _GlassCircle(
                          icon: isPin
                              ? Icons.arrow_back_rounded
                              : Icons.close_rounded,
                          onTap: isPin
                              ? _backToPhone
                              : () => context.canPop()
                                    ? context.pop()
                                    : context.go('/home'),
                        ),
                        const Spacer(),
                        _WorldTag(world: world),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const VibesLogo.mark(
                    size: 62,
                    color: Colors.white,
                  ).animate().scale(
                    begin: const Offset(.85, .85),
                    duration: 520.ms,
                    curve: Curves.easeOutBack,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    p.mood,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: .75),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // ── البطاقة الصاعدة ──
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 30,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: 340.ms,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, .04),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: ListView(
                          key: ValueKey(_phase),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                          children: [
                            _StepDots(step: step, total: 3, palette: p),
                            const SizedBox(height: 18),
                            Text(
                              _kicker,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: p.accentDeep,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _headline,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF141C2B),
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _subtitle,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5A6678),
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_error != null) ...[
                              _ErrorNote(message: _error!).animate().shakeX(
                                hz: 5,
                                amount: 4,
                                duration: 360.ms,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (isPin) ...[
                              if (_displayPhone.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: _PhoneChip(
                                    phone: _displayPhone,
                                    accent: p.accentDeep,
                                    onTap: _backToPhone,
                                  ),
                                ),
                              _PinBoxes(
                                value: _pinController.text,
                                focusNode: _pinFocus,
                                controller: _pinController,
                                error: _error != null,
                                palette: p,
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: _loading
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: p.accent,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.lock_outline_rounded,
                                            size: 14,
                                            color: Color(0xFF5A6678),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'محفوظ ومشفّر · ${_pinController.text.length} / 6',
                                            style: TextStyle(
                                              fontFamily: VibesFont.ui,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF5A6678),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              if (_phase == _PinPhase.unlock) ...[
                                const SizedBox(height: 10),
                                Center(
                                  child: TextButton(
                                    onPressed: () => context.push('/support'),
                                    child: Text(
                                      'نسيت الرقم السري؟ تواصل مع الدعم',
                                      style: TextStyle(
                                        fontFamily: VibesFont.ui,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: p.accentDeep,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              _PhoneField(
                                controller: _phoneController,
                                focusNode: _phoneFocus,
                                onSubmitted: _continuePhone,
                                palette: p,
                              ),
                              const SizedBox(height: 20),
                              _PrimaryButton(
                                label: 'متابعة',
                                loading: _loading,
                                onTap: _continuePhone,
                                palette: p,
                              ),
                              const SizedBox(height: 22),
                              const _TrustRow(),
                              const SizedBox(height: 18),
                              const _LegalLine(),
                            ],
                          ],
                        ),
                      ),
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

const _ink = Color(0xFF141C2B);
const _ink2 = Color(0xFF5A6678);
const _line = Color(0xFFE4E9F0);
const _paper = Color(0xFFF6F7F9);

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .12),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

class _WorldTag extends StatelessWidget {
  const _WorldTag({required this.world});

  final HomeSection world;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: .12),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VibesCategoryIcon(
            category: world.icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            world.label,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.step,
    required this.total,
    required this.palette,
  });

  final int step;
  final int total;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsetsDirectional.only(end: 6),
            width: i == step ? 28 : 8,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i <= step ? palette.accent : _line,
            ),
          ),
      ],
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: context.world.accentDeep),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _ink2,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: context.world.canvas,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          item(Icons.bolt_rounded, 'دخول بثوانٍ\nبلا رسائل'),
          item(Icons.shield_outlined, 'رقم سري\nمشفّر'),
          item(Icons.support_agent_rounded, 'دعم مباشر\nعند الحاجة'),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.palette,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? palette.accent : _line,
          width: focused ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (focused ? palette.glow : _ink).withValues(
              alpha: focused ? .16 : .04,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsetsDirectional.only(start: 9),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accentFaint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('🇮🇶', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '+964',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: palette.accentDeep,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textDirection: TextDirection.ltr,
              cursorColor: palette.accent,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: 1.2,
              ),
              decoration: const InputDecoration(
                hintText: '07XX XXX XXXX',
                hintStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB7C0CC),
                  letterSpacing: .6,
                ),
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinBoxes extends StatelessWidget {
  const _PinBoxes({
    required this.value,
    required this.focusNode,
    required this.controller,
    required this.error,
    required this.palette,
  });

  final String value;
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool error;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) SizedBox(width: i == 3 ? 16 : 8),
                  Expanded(
                    child: _PinCell(
                      digit: i < value.length ? value[i] : null,
                      active: focusNode.hasFocus && i == value.length,
                      error: error,
                      palette: palette,
                    ),
                  ),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinCell extends StatelessWidget {
  const _PinCell({
    required this.digit,
    required this.active,
    required this.error,
    required this.palette,
  });

  final String? digit;
  final bool active;
  final bool error;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) {
    final filled = digit != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? palette.accentFaint : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error
              ? const Color(0xFFDC2626)
              : active
              ? palette.accent
              : filled
              ? palette.accent.withValues(alpha: .55)
              : _line,
          width: active ? 2 : (filled ? 1.4 : 1),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: palette.glow.withValues(alpha: .22),
                  blurRadius: 14,
                ),
              ]
            : const [],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: filled
            ? Container(
                key: const ValueKey('dot'),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accentDeep,
                ),
              )
            : active
            ? Container(
                key: const ValueKey('caret'),
                width: 2,
                height: 22,
                color: palette.accent,
              )
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }
}

class _PhoneChip extends StatelessWidget {
  const _PhoneChip({
    required this.phone,
    required this.accent,
    required this.onTap,
  });

  final String phone;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_iphone_rounded, size: 14, color: _ink2),
              const SizedBox(width: 6),
              Text(
                phone,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'تغيير',
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.palette,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final WorldPalette palette;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: palette.fill,
          borderRadius: BorderRadius.circular(18),
          boxShadow: loading ? const [] : palette.glowShadow,
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: palette.onAccent,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: palette.onAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: palette.onAccent,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «بالمتابعة أنت توافق على شروط الاستخدام وسياسة الخصوصية» — بروابط فعلية.
class _LegalLine extends StatelessWidget {
  const _LegalLine();

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: VibesFont.ui,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: Color(0xFF8A9099),
      height: 1.6,
    );
    final link = base.copyWith(
      fontWeight: FontWeight.w800,
      color: const Color(0xFF1B3857),
      decoration: TextDecoration.underline,
    );
    Widget a(String label, String path) => GestureDetector(
      onTap: () => openLegal(path),
      child: Text(label, style: link),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text('بالمتابعة أنت توافق على ', style: base),
        a('شروط الاستخدام', '/terms'),
        Text(' و', style: base),
        a('سياسة الخصوصية', '/privacy'),
        Text('.', style: base),
      ],
    );
  }
}
