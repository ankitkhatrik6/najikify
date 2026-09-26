import 'package:flutter/material.dart';

/// Concentric rings that expand and fade outwards around [child] — the
/// AirDrop-style "sharing into the room" signal used by the splash screen.
///
/// The animation is a single repeating controller, so it is cheap: only the
/// ring transforms rebuild. When the platform asks for reduced motion
/// (`MediaQuery.disableAnimations`), the rings are drawn once, frozen, and no
/// ticker keeps running.
class SharePulse extends StatefulWidget {
  /// Outer size of the widget; rings are drawn inside this square.
  final double size;

  /// Number of staggered rings.
  final int ringCount;

  /// Ring colour; defaults to the theme primary colour.
  final Color? color;

  /// Dwell time of one ring's full travel.
  final Duration period;

  /// Content placed in the middle of the rings (usually the logo).
  final Widget? child;

  const SharePulse({
    super.key,
    this.size = 240,
    this.ringCount = 3,
    this.color,
    this.period = const Duration(milliseconds: 2400),
    this.child,
  });

  @override
  State<SharePulse> createState() => _SharePulseState();
}

class _SharePulseState extends State<SharePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Accessibility: never loop animations for users who disabled motion.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft glow behind the rings so the logo appears to emit light.
              Container(
                width: widget.size * 0.62,
                height: widget.size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ringColor.withValues(alpha: 0.30),
                      ringColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              for (int i = 0; i < widget.ringCount; i++) _ring(i, ringColor),
              if (widget.child != null) widget.child!,
            ],
          );
        },
      ),
    );
  }

  Widget _ring(int index, Color ringColor) {
    // Stagger the rings evenly around the cycle.
    final progress =
        (_controller.value + index / widget.ringCount) % 1.0;
    final scale = 0.40 + progress * 0.60;
    final opacity = (1.0 - progress) * 0.55;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor.withValues(alpha: 0.85),
              width: 1.4 + (1.0 - progress) * 1.6,
            ),
          ),
        ),
      ),
    );
  }
}