import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/device_id.dart';
import '../../core/utils/error_guard.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import '../chat/conversations_screen.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String _deviceId = '';
  bool _diagnostics = false;

  static const _faq = [
    (
      'كيف أحجز مكاناً؟',
      'اختر المكان ثم التاريخ والوقت المناسب واضغط تأكيد الحجز — سيتواصل معك المالك لتأكيد التفاصيل والدفع.'
    ),
    (
      'ما طرق الدفع المتاحة؟',
      'التحويل البنكي أو محافظ Zain Cash وQi Card — ارفع صورة الإيصال من صفحة الحجز بعد الدفع.'
    ),
    (
      'هل يمكنني إلغاء حجزي؟',
      'قبل تأكيد المالك يمكنك الإلغاء مباشرة من صفحة الحجز. بعد التأكيد أرسل طلب إلغاء واسترداد من التفاصيل، وسيُحسب المبلغ وفق سياسة الإلغاء.'
    ),
    (
      'كيف أصبح مالكاً (مزوّداً)؟',
      'سجّل برقم هاتفك ثم راسلنا على واتساب لتفعيل حساب المالك ورفع أماكنك.'
    ),
  ];

  @override
  void initState() {
    super.initState();
    diagnosticDeviceId().then((id) {
      if (mounted) setState(() => _deviceId = id);
    });
  }

  String _digits(String? phone) {
    final raw = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    return raw.isEmpty ? '9647700000000' : raw;
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final errors = ErrorGuard.recent();
    final settings = ref.watch(appSettingsProvider).value;
    final phone = _digits(settings?.supportPhone);
    final instructions = settings?.paymentInstructions ?? '';

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'الدعم والمساعدة',
              kicker: 'نحن معك',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const SectionHeader('الأسئلة الشائعة'),
                  ..._faq.asMap().entries.map(
                        (entry) => _FaqRow(
                          question: entry.value.$1,
                          answer: entry.value.$2,
                        ),
                      ),
                  if (instructions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FaqRow(
                      question: 'كيف أدفع حجزي؟',
                      answer: instructions,
                    ),
                  ],
                  const SizedBox(height: 22),
                  const SectionHeader('تواصل معنا'),
                  VibesCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ContactRow(
                          icon: Icons.forum_outlined,
                          label: 'محادثة داخل التطبيق',
                          color: Vibes.coral,
                          onTap: () => openSupportChat(context, ref),
                        ),
                        Divider(height: 1, color: VibesTheme.hairlineOf(context)),
                        _ContactRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'واتساب — الأسرع رداً',
                          color: Vibes.teal,
                          onTap: () => _launch('https://wa.me/$phone'),
                        ),
                        Divider(height: 1, color: VibesTheme.hairlineOf(context)),
                        _ContactRow(
                          icon: Icons.call_outlined,
                          label: 'اتصال هاتفي',
                          color: Vibes.coral,
                          onTap: () => _launch('tel:+$phone'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: () => setState(() => _diagnostics = !_diagnostics),
                    child: Text(
                      _diagnostics ? 'إخفاء التفاصيل التقنية' : 'تفاصيل تقنية',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Vibes.inkTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (_diagnostics) ...[
                  const SizedBox(height: 10),
                  FolioPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _deviceId.isEmpty ? 'جاري التجهيز…' : _deviceId,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: VibesTheme.textTertiaryOf(context),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: _deviceId.isEmpty
                                  ? null
                                  : () {
                                      Clipboard.setData(
                                          ClipboardData(text: _deviceId));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('تم النسخ')),
                                      );
                                    },
                              child: const Text('نسخ'),
                            ),
                          ],
                        ),
                        if (errors.isEmpty)
                          Text(
                            'لا أخطاء مسجلة — التطبيق يعمل بسلام',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Vibes.success,
                                    ),
                          )
                        else ...[
                          Text(
                            'آخر الأخطاء (لإرسالها للفريق):',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          ...errors.take(3).map(
                                (e) => Text(
                                  e,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color:
                                            VibesTheme.textTertiaryOf(context),
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                        ],
                      ],
                    ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 14, top: 0),
        iconColor: Vibes.teal,
        collapsedIconColor: VibesTheme.textTertiaryOf(context),
        title: Row(
          children: [
            const SizedBox(width: 3, height: 16, child: ColoredBox(color: Vibes.teal)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                question,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 17),
            child: Text(
              answer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.8,
                    color: VibesTheme.textSecondaryOf(context),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            MaisonIconWell(icon: icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: VibesTheme.textTertiaryOf(context),
            ),
          ],
        ),
      ),
    );
  }
}
