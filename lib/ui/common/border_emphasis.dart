import 'package:flutter/widgets.dart';

class BorderEmphasis extends StatefulWidget {
  const BorderEmphasis({
    super.key,
    required this.child,
    required this.color1,
    required this.color2,
    this.borderRadius = 0.0,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final double borderRadius;
  final Duration duration;
  final Color color1;
  final Color color2;

  @override
  State<BorderEmphasis> createState() => _BorderEmphasisState();
}

class _BorderEmphasisState extends State<BorderEmphasis>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  Color.lerp(widget.color1, widget.color2, _controller.value) ??
                  widget.color1,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: child,
        );
      },
    );
  }
}
