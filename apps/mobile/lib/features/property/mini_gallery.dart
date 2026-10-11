import 'package:flutter/material.dart';

import '../../core/utils/vibes_net_image.dart';

import '../../core/theme/app_theme.dart';

/// معرض مصغر قابل للسحب داخل بطاقة المكان — نقاط + عدة صور
class MiniGallery extends StatefulWidget {
  const MiniGallery({
    super.key,
    required this.images,
    required this.height,
    this.placeholder,
  });

  final List<String> images;
  final double height;
  final WidgetBuilder? placeholder;

  @override
  State<MiniGallery> createState() => _MiniGalleryState();
}

class _MiniGalleryState extends State<MiniGallery> {
  final _controller = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => VibesNetImage(
            url: widget.images[i],
            fade: const Duration(milliseconds: 160),
            fallback:
                widget.placeholder?.call(context) ??
                Container(color: Vibes.surfaceMuted),
          ),
        ),
        // نقاط الموضع
        if (widget.images.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: i == _index ? 14 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? Colors.white
                        : Colors.white.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
