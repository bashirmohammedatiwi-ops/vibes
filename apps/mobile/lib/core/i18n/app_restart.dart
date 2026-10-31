import 'package:flutter/widgets.dart';

/// يعيد بناء التطبيق كاملاً (مع مخازن Riverpod) عند تغيير اللغة،
/// فتُجلب كل البيانات والنصوص باللغة الجديدة.
class AppRestart extends StatefulWidget {
  const AppRestart({super.key, required this.child});

  final Widget child;

  static VoidCallback? _trigger;

  static void trigger() => _trigger?.call();

  @override
  State<AppRestart> createState() => _AppRestartState();
}

class _AppRestartState extends State<AppRestart> {
  var _key = UniqueKey();

  @override
  void initState() {
    super.initState();
    AppRestart._trigger = () => setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
