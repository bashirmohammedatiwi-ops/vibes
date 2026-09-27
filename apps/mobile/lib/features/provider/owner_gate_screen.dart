import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';

final ownerProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/api/providers/me');
  if (data is Map<String, dynamic>) return data;
  return null;
});

/// بوابة أصحاب المزارع والقاعات — تقديم الطلب أو انتظار الموافقة أو الدخول للإدارة
class OwnerGateScreen extends ConsumerStatefulWidget {
  const OwnerGateScreen({super.key});

  @override
  ConsumerState<OwnerGateScreen> createState() => _OwnerGateScreenState();
}

class _OwnerGateScreenState extends ConsumerState<OwnerGateScreen> {
  final _business = TextEditingController();
  final _note = TextEditingController();
  final _types = <String>{};
  bool _saving = false;

  @override
  void dispose() {
    _business.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/providers/me',
            body: {
              'businessName': _business.text.trim().isEmpty
                  ? null
                  : _business.text.trim(),
              'placeTypes': _types.toList(),
              'note': _note.text.trim(),
            },
          );
      await ref.read(authControllerProvider.notifier).refreshMe();
      ref.invalidate(ownerProfileProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('وصل طلبك — نراجع الحساب ثم نفتح لك بوابة الإدارة'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _enterPortal() async {
    await ref.read(authControllerProvider.notifier).refreshMe();
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.isProvider) {
      context.go('/provider');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ما زال الحساب قيد المراجعة')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.isProvider) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/provider');
      });
    }
    final profile = ref.watch(ownerProfileProvider);
    final kyc =
        profile.valueOrNull?['kycStatus'] as String? ?? auth.user?.kycStatus;

    return Scaffold(
      body: MaisonWash(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            MaisonPageHeader(
              title: 'بوابة المالك',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              trailing: const CrestSeal(size: 28, color: Vibes.coral),
            ),
            Text(
              'إدارة المزرعة أو القاعة: الحجوزات من VIBEES وخارجها في مكان واحد. الصور يلتقطها فريقنا بعد الموافقة.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VibesTheme.textSecondaryOf(context),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            profile.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    ShimmerBox(height: 180, radius: VibesRadius.xl),
                    SizedBox(height: 14),
                    ShimmerBox(height: 56, radius: VibesRadius.lg),
                  ],
                ),
              ),
              error: (error, _) => ErrorCanvas(
                message: maisonError(error),
                onRetry: () => ref.invalidate(ownerProfileProvider),
              ),
              data: (_) {
                if (kyc == 'VERIFIED') {
                  return _VerifiedCard(onEnter: _enterPortal);
                }
                if (kyc == 'PENDING') {
                  return _PendingCard(
                    name: _businessName(profile.valueOrNull),
                    onRefresh: () async {
                      await ref
                          .read(authControllerProvider.notifier)
                          .refreshMe();
                      ref.invalidate(ownerProfileProvider);
                      await _enterPortal();
                    },
                  );
                }
                return _ApplyCard(
                  business: _business,
                  note: _note,
                  types: _types,
                  rejected: kyc == 'REJECTED',
                  reason: profile.valueOrNull?['rejectionReason'] as String?,
                  saving: _saving,
                  onToggleType: (type) => setState(() {
                    if (_types.contains(type)) {
                      _types.remove(type);
                    } else {
                      _types.add(type);
                    }
                  }),
                  onSubmit: _apply,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _businessName(Map<String, dynamic>? profile) {
    final name = profile?['businessName'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    return null;
  }
}

class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: VibesTheme.surfaceOf(context),
      borderColor: VibesTheme.hairlineOf(context),
      shadows: Vibes.card,
      railColor: Vibes.teal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حسابك موثّق',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'ادخل لإدارة الحجوزات والتقويم وتسجيل الحجوزات الخارجية حتى يظهر التوفر الحقيقي للضيوف.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VibesTheme.textSecondaryOf(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            VibesButton(
              label: 'دخول بوابة المالك',
              icon: Icons.home_work_outlined,
              onPressed: onEnter,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.onRefresh, this.name});

  final VoidCallback onRefresh;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: VibesTheme.surfaceOf(context),
      borderColor: VibesTheme.hairlineOf(context),
      shadows: Vibes.card,
      railColor: Vibes.teal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name == null ? 'طلبك قيد المراجعة' : 'طلب $name قيد المراجعة',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'فريق VIBEES يراجع الحساب. بعد الموافقة نفتح لك بوابة الإدارة، ونصوّر المكان بأنفسنا — لا حاجة لرفع صور.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VibesTheme.textSecondaryOf(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            VibesButton(
              label: 'تحديث الحالة',
              ghost: true,
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyCard extends StatelessWidget {
  const _ApplyCard({
    required this.business,
    required this.note,
    required this.types,
    required this.onToggleType,
    required this.onSubmit,
    required this.saving,
    required this.rejected,
    this.reason,
  });

  final TextEditingController business;
  final TextEditingController note;
  final Set<String> types;
  final ValueChanged<String> onToggleType;
  final VoidCallback onSubmit;
  final bool saving;
  final bool rejected;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rejected) ...[
          FolioPanel(
            color: VibesTheme.surfaceOf(context),
            borderColor: SemanticColors.danger.withValues(alpha: .35),
            railColor: SemanticColors.danger,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'رُفض الطلب${reason == null || reason!.isEmpty ? '' : ': $reason'}\nيمكنك إرسال طلب جديد بعد تصحيح البيانات.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        FolioPanel(
          color: VibesTheme.surfaceOf(context),
          borderColor: VibesTheme.hairlineOf(context),
          shadows: Vibes.card,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'افتح حساب مالك',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'بعد الموافقة تدير كل الحجوزات من التطبيق — بما فيها الخارجية — ليظهر للضيوف اليوم المتاح فعلياً. فريق VIBEES يصور المكان.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VibesTheme.textSecondaryOf(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                MaisonField(
                  label: 'اسم المزرعة أو القاعة',
                  controller: business,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                Text(
                  'نوع المكان',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        ('FARM', 'مزرعة'),
                        ('HALL', 'قاعة'),
                        ('DECORATION', 'تزيين'),
                      ].map((item) {
                        return MaisonChip(
                          label: item.$2,
                          active: types.contains(item.$1),
                          onTap: () => onToggleType(item.$1),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 14),
                MaisonField(
                  label: 'ملاحظة للفريق (اختياري)',
                  controller: note,
                  hint: 'الموقع، عدد القاعات، أو أي تفصيل يسهّل المراجعة',
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                VibesButton(
                  label: rejected ? 'إعادة إرسال الطلب' : 'إرسال طلب المالك',
                  icon: Icons.send_rounded,
                  loading: saving,
                  onPressed: onSubmit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
