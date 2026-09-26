import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/share_pulse.dart';

/// The first screen the user sees: the Najikify mark pulsing outwards in an
/// AirDrop-style ripple while the app finishes preparing its local-network
/// session. Tapping anywhere skips straight to the app.
///
/// The splash is purely decorative — `main()` already completed the database,
/// settings, HTTP server and discovery bootstrap before [runApp], so nothing
/// here blocks startup.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2400),
    this.next,
  });

  /// How long the animation plays before handing over to the app shell.
  final Duration duration;

  /// Screen shown next (defaults to [MainNavigationScaffold]).
  final Widget? next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _backdropBottom = Color(0xFF0B1220);
  static const Color _backdropTop = Color(0xFF152238);
  static const Color _glowText = Color(0xFF9EC5FF);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
  );
  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
  );
  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.30, 0.85, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tagline = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.50, 1.0, curve: Curves.easeOut),
  );

  Timer? _handover;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _handover = Timer(widget.duration, _goNext);
  }

  @override
  void dispose() {
    _handover?.cancel();
    _intro.dispose();
    super.dispose();
  }

  /// Cross-fades into the app shell exactly once.
  void _goNext() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _handover?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) =>
            widget.next ?? const MainNavigationScaffold(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _goNext,
      child: Scaffold(
        backgroundColor: _backdropBottom,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_backdropTop, _backdropBottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                SharePulse(
                  size: 250,
                  color: AppTheme.primarySeed,
                  child: AnimatedBuilder(
                    animation: _intro,
                    builder: (context, child) => Opacity(
                      opacity: _logoOpacity.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.72 + _logoScale.value * 0.28,
                        child: child,
                      ),
                    ),
                    child: const AppLogo(size: 104, borderRadius: 28),
                  ),
                ),
                const SizedBox(height: 30),
                _FadeUp(animation: _wordmark, child: _wordmarkText()),
                const SizedBox(height: 10),
                _FadeUp(
                  animation: _tagline,
                  child: const Text(
                    'Share files nearby — no cloud, no accounts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _FadeUp(
                  animation: _tagline,
                  child: const _DiscoveringFooter(glow: _glowText),
                ),
                const SizedBox(height: 34),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wordmarkText() {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, _glowText],
      ).createShader(rect),
      child: const Text(
        'Najikify',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Fades a child in while sliding it up a few pixels.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// "Looking for devices on your network" with three breathing dots — the same
/// discovery story the home screen tells once it appears.
class _DiscoveringFooter extends StatefulWidget {
  const _DiscoveringFooter({required this.glow});

  final Color glow;

  @override
  State<_DiscoveringFooter> createState() => _DiscoveringFooterState();
}

class _DiscoveringFooterState extends State<_DiscoveringFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Looking for devices on your network',
          style: TextStyle(color: Colors.white60, fontSize: 12.5),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _dots,
          builder: (context, _) => Row(
            children: List.generate(3, (index) {
              final t = (_dots.value + index / 3) % 1.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: (0.25 + (1 - t) * 0.75).clamp(0.0, 1.0),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.glow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
