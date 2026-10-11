import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/marketplace_providers.dart';
import '../../shared/data/property_providers.dart';

/// معالج ذاتي للبيانات — مزوّدات الصفحة الرئيسية تحفظ نتيجتها طوال الجلسة،
/// وإن فشل جلبها مرة (أول فتح على iOS، شبكة متقطعة) يبقى الخطأ محفوظاً
/// والقسم فارغاً حتى إغلاق التطبيق. هذا المعالج يعيد تحميل أي قسم فشل:
///   • بعد ثوانٍ من الإقلاع (يلتقط فشل أول فتح)
///   • عند عودة التطبيق للواجهة
///   • عند عودة الشبكة
/// ولا يلمس الأقسام الناجحة، فلا طلبات زائدة.
class DataHealer extends ConsumerStatefulWidget {
  const DataHealer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DataHealer> createState() => _DataHealerState();
}

class _DataHealerState extends ConsumerState<DataHealer>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _net;
  final _timers = <Timer>[];
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // فحوص مبكرة بعد الإقلاع — أول فتح هو الأكثر عرضة للفشل
    for (final s in const [4, 10, 25]) {
      _timers.add(Timer(Duration(seconds: s), _heal));
    }
    _net = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (_wasOffline && !offline) {
        // انتظر لحظة حتى تستقر الشبكة ثم أعد ما فشل
        _timers.add(Timer(const Duration(milliseconds: 800), _heal));
      }
      _wasOffline = offline;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _heal();
  }

  void _heal() {
    if (!mounted) return;
    final ref = this.ref;
    void retry(ProviderOrFamily provider, AsyncValue<Object?> value) {
      if (value.hasError && !value.isLoading) ref.invalidate(provider);
    }

    retry(bannersProvider, ref.read(bannersProvider));
    retry(spotlightsProvider, ref.read(spotlightsProvider));
    retry(featuredPropertiesProvider, ref.read(featuredPropertiesProvider));
    retry(topRatedPropertiesProvider, ref.read(topRatedPropertiesProvider));
    retry(locationsProvider, ref.read(locationsProvider));
    retry(publicCouponsProvider, ref.read(publicCouponsProvider));
    final all = propertiesProvider(null);
    retry(all, ref.read(all));
    for (final type in const ['FARM', 'HALL', 'DECORATION']) {
      final p = newPropertiesProvider(type);
      retry(p, ref.read(p));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _net?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
