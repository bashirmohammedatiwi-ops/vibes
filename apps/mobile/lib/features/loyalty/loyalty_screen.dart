import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../home/home_sections.dart';
import 'loyalty_data.dart';

/// بطاقات الولاء: مسار أختام لكل نوع ينتهي بهدية الخصم.
class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> {
  HomeSection? _section;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(loyaltyProvider);
    return Scaffold(
      backgroundColor: Vibes.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _Message(
                  icon: Icons.wifi_off_rounded,
                  text: 'تعذّر تحميل بطاقاتك'.tr,
                  action: 'إعادة المحاولة'.tr,
                  onAction: () => ref.invalidate(loyaltyProvider),
                ),
                data: (status) {
                  final programs =
                      status?.programs.where((p) => p.enabled).toList() ??
                      const <LoyaltyProgram>[];
                  if (programs.isEmpty) {
                    return _Message(
                      icon: Icons.card_giftcard_rounded,
                      text: 'برنامج الولاء غير متاح حالياً'.tr,
                    );
                  }
                  final current = programs.firstWhere(
                    (p) => p.section == _section,
                    orElse: () => programs.firstWhere(
                      (p) => p.rewardReady,
                      orElse: () => programs.first,
                    ),
                  );
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(loyaltyProvider.future),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                      children: [
                        _WorldTabs(
                          programs: programs,
                          selected: current,
                          onSelect: (p) => setState(() => _section = p.section),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: VibesMotion.base,
                          child: _ProgramView(
                            key: ValueKey(current.type),
                            program: current,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 20, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, color: Vibes.ink),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'بطاقات الولاء'.tr,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Vibes.ink,
                ),
              ),
              Text(
                'لكل نوع بطاقته: المزارع والقاعات والتزيين'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Vibes.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WorldTabs extends StatelessWidget {
  const _WorldTabs({
    required this.programs,
    required this.selected,
    required this.onSelect,
  });

  final List<LoyaltyProgram> programs;
  final LoyaltyProgram selected;
  final ValueChanged<LoyaltyProgram> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Vibes.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final p in programs)
          Expanded(
            child: _WorldTab(
              program: p,
              active: p.type == selected.type,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(p);
              },
            ),
          ),
      ],
    ),
  );
}

class _WorldTab extends StatelessWidget {
  const _WorldTab({
    required this.program,
    required this.active,
    required this.onTap,
  });

  final LoyaltyProgram program;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WorldPalette.of(program.section);
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: VibesMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? palette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  program.section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active ? palette.onAccent : Vibes.inkSecondary,
                  ),
                ),
              ),
              if (program.rewardReady) ...[
                const SizedBox(width: 5),
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 14,
                  color: active ? palette.onAccent : palette.accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgramView extends StatelessWidget {
  const _ProgramView({super.key, required this.program});

  final LoyaltyProgram program;

  @override
  Widget build(BuildContext context) {
    final palette = WorldPalette.of(program.section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StampCard(program: program, palette: palette),
        const SizedBox(height: 14),
        _StatsRow(program: program, palette: palette),
        if (program.stampHistory.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionTitle('أختام هذه الدورة'.tr),
          for (final (i, stamp) in program.stampHistory.indexed)
            _HistoryRow(
              leading: '${i + 1}',
              title: stamp.placeName,
              date: stamp.date,
              palette: palette,
            ),
        ],
        if (program.rewardHistory.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionTitle('خصوماتك السابقة'.tr),
          for (final reward in program.rewardHistory)
            _HistoryRow(
              icon: Icons.card_giftcard_rounded,
              title: reward.placeName,
              date: reward.date,
              trailing: '−${PriceText.format(reward.discount)} ${'د.ع'.tr}',
              palette: palette,
            ),
        ],
        const SizedBox(height: 22),
        _SectionTitle('كيف يعمل؟'.tr),
        _RuleRow(
          n: 1,
          text: 'كل حجز مكتمل في {world} يمنحك ختماً.'.trArgs({
            'world': program.section.label,
          }),
        ),
        _RuleRow(
          n: 2,
          text: 'بعد {required} أختام يصبح حجزك التالي بخصم {percent}%.'.trArgs(
            {'required': program.required, 'percent': program.percent},
          ),
        ),
        _RuleRow(
          n: 3,
          text:
              'تختار استخدام الخصم عند الحجز، ولا يُجمع مع كوبون. وإذا أُلغي الحجز يعود خصمك.'
                  .tr,
        ),
      ],
    );
  }
}

/// البطاقة الرئيسية: مسار متعرّج يرسم نفسه من ختم إلى ختم حتى الهدية.
class _StampCard extends StatefulWidget {
  const _StampCard({required this.program, required this.palette});

  final LoyaltyProgram program;
  final WorldPalette palette;

  @override
  State<_StampCard> createState() => _StampCardState();
}

class _StampCardState extends State<_StampCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted && widget.program.rewardReady) {
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    final world = widget.palette;
    final ready = p.rewardReady;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [world.nightHigh, world.night],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: world.glow.withValues(alpha: ready ? .45 : .22),
            blurRadius: ready ? 34 : 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ready ? 'خصمك جاهز'.tr : 'باقي {n} على خصمك'.trN(p.remaining),
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
              _PercentSeal(percent: p.percent, color: world.accentLight),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            ready
                ? 'استخدم خصم {percent}% في حجزك القادم في {world}.'.trArgs({
                    'percent': p.percent,
                    'world': p.section.label,
                  })
                : '{stamps} من {required} حجوزات مكتملة في {world}'.trArgs({
                    'stamps': p.stamps,
                    'required': p.required,
                    'world': p.section.label,
                  }),
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: .78),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) =>
                _StampTrail(program: p, palette: world, t: _c.value),
          ),
          if (ready) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: world.accentLight,
                  foregroundColor: world.night,
                ),
                onPressed: () => context.go('/search?type=${p.type}'),
                child: Text(
                  p.rewardsAvailable > 1
                      ? 'لديك {n} خصومات — احجز الآن'.trArgs({
                          'n': p.rewardsAvailable,
                        })
                      : 'احجز بخصمك الآن'.tr,
                ),
              ),
            ),
          ] else if (p.inProgress > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: Colors.white.withValues(alpha: .75),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '{n} حجز جارٍ يضاف ختمه عند اكتماله'.trN(p.inProgress),
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .75),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PercentSeal extends StatelessWidget {
  const _PercentSeal({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .55)),
    ),
    child: Text(
      '$percent%',
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );
}

/// الأختام مرتبة في صفوف متعرجة، آخرها عقدة الهدية.
class _StampTrail extends StatelessWidget {
  const _StampTrail({
    required this.program,
    required this.palette,
    required this.t,
  });

  final LoyaltyProgram program;
  final WorldPalette palette;
  final double t;

  @override
  Widget build(BuildContext context) {
    final total = program.required + 1;
    final perRow = total <= 6 ? 3 : (total <= 12 ? 4 : 5);
    final rows = (total / perRow).ceil();
    const node = 54.0;
    const rowGap = 26.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final height = rows * node + (rows - 1) * rowGap;
        final centers = <Offset>[];
        for (var i = 0; i < total; i++) {
          final row = i ~/ perRow;
          var col = i % perRow;
          if (row.isOdd) col = perRow - 1 - col; // المسار يلتف مع نهاية الصف
          var x = node / 2 + col * (width - node) / (perRow - 1);
          if (rtl) x = width - x;
          centers.add(Offset(x, node / 2 + row * (node + rowGap)));
        }
        // التقدم الفعلي: عدد القطع المكتملة على المسار
        final reached = program.rewardReady
            ? total - 1.0
            : math.max(0, program.stamps - 1).toDouble();
        final progress = reached * Curves.easeOutCubic.transform(t);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrailPainter(
                    centers: centers,
                    progress: progress,
                    done: palette.accentLight,
                    rest: Colors.white.withValues(alpha: .18),
                  ),
                ),
              ),
              for (var i = 0; i < total; i++)
                Positioned(
                  left: centers[i].dx - node / 2,
                  top: centers[i].dy - node / 2,
                  width: node,
                  height: node,
                  child: i == total - 1
                      ? _GiftNode(
                          ready: program.rewardReady,
                          palette: palette,
                          reveal: _reveal(i),
                        )
                      : _StampNode(
                          number: i + 1,
                          stamped: i < program.stamps,
                          palette: palette,
                          reveal: _reveal(i),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _reveal(int i) {
    final total = program.required + 1;
    final start = (i / total) * .75;
    return Curves.easeOutBack.transform(((t - start) / .25).clamp(0.0, 1.0));
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.centers,
    required this.progress,
    required this.done,
    required this.rest,
  });

  final List<Offset> centers;
  final double progress;
  final Color done;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      canvas.drawLine(a, b, base..color = rest);
      final f = (progress - i).clamp(0.0, 1.0);
      if (f > 0) {
        canvas.drawLine(a, Offset.lerp(a, b, f)!, base..color = done);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.progress != progress || old.done != done || old.rest != rest;
}

class _StampNode extends StatelessWidget {
  const _StampNode({
    required this.number,
    required this.stamped,
    required this.palette,
    required this.reveal,
  });

  final int number;
  final bool stamped;
  final WorldPalette palette;
  final double reveal;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: stamped ? reveal.clamp(0.0, 1.2) : 1,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: stamped ? palette.accentLight : palette.night,
        border: Border.all(
          color: stamped
              ? palette.accentLight
              : Colors.white.withValues(alpha: .28),
          width: 1.6,
        ),
      ),
      alignment: Alignment.center,
      child: stamped
          ? Icon(Icons.check_rounded, size: 26, color: palette.night)
          : Text(
              '$number',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: .6),
              ),
            ),
    ),
  );
}

class _GiftNode extends StatefulWidget {
  const _GiftNode({
    required this.ready,
    required this.palette,
    required this.reveal,
  });

  final bool ready;
  final WorldPalette palette;
  final double reveal;

  @override
  State<_GiftNode> createState() => _GiftNodeState();
}

class _GiftNodeState extends State<_GiftNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.ready) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.palette;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: widget.ready
            ? widget.reveal.clamp(0.0, 1.2) * (1 + _pulse.value * .07)
            : 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.ready
                ? LinearGradient(
                    colors: [world.accentLight, world.accent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: widget.ready ? null : world.night,
            border: Border.all(
              color: widget.ready
                  ? world.accentLight
                  : Colors.white.withValues(alpha: .45),
              width: 1.8,
            ),
            boxShadow: widget.ready
                ? [
                    BoxShadow(
                      color: world.accentLight.withValues(
                        alpha: .3 + _pulse.value * .35,
                      ),
                      blurRadius: 12 + _pulse.value * 14,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
      child: Icon(
        Icons.card_giftcard_rounded,
        size: 25,
        color: widget.ready ? world.night : Colors.white.withValues(alpha: .75),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.program, required this.palette});

  final LoyaltyProgram program;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Stat(
          value: PriceText.format(program.lifetimeSaved),
          label: 'وفّرت (د.ع)'.tr,
          palette: palette,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Stat(
          value: '${program.lifetimeRewards}',
          label: 'خصومات مستخدمة'.tr,
          palette: palette,
        ),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.palette,
  });

  final String value;
  final String label;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Vibes.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Vibes.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: palette.accentDeep,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Vibes.inkSecondary,
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: VibesFont.ui,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: Vibes.ink,
      ),
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    this.leading,
    this.icon,
    required this.title,
    required this.date,
    this.trailing,
    required this.palette,
  });

  final String? leading;
  final IconData? icon;
  final String title;
  final DateTime date;
  final String? trailing;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.accentSoft,
            shape: BoxShape.circle,
          ),
          child: icon != null
              ? Icon(icon, size: 17, color: palette.accentDeep)
              : Text(
                  leading ?? '',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: palette.accentDeep,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Vibes.ink,
                ),
              ),
              Text(
                '${date.year}/${date.month}/${date.day}',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Vibes.inkTertiary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Vibes.success,
            ),
          ),
      ],
    ),
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$n.',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Vibes.teal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Vibes.inkSecondary,
              height: 1.55,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Vibes.inkTertiary),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Vibes.inkSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}
