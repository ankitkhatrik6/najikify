import 'package:flutter/material.dart';

class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isScanning;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isScanning = false,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  AnimationController? _radarController;

  @override
  void initState() {
    super.initState();
    if (widget.isScanning) {
      _startRadar();
    }
  }

  @override
  void didUpdateWidget(covariant EmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
        _startRadar();
      } else {
        _stopRadar();
      }
    }
  }

  void _startRadar() {
    _radarController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  void _stopRadar() {
    _radarController?.stop();
    _radarController?.dispose();
    _radarController = null;
  }

  @override
  void dispose() {
    _radarController?.dispose();
    super.dispose();
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    if (!widget.isScanning || _radarController == null) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          size: 32,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _radarController!,
      builder: (context, child) {
        final t = _radarController!.value;
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ripple
              _buildRipple(colorScheme, (t).remainder(1.0), 140),
              // Inner ripple
              _buildRipple(colorScheme, (t + 0.5).remainder(1.0), 108),
              // Center icon core
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRipple(ColorScheme colorScheme, double progress, double maxDiameter) {
    final scale = 0.5 + (0.5 * progress);
    final opacity = ((1.0 - progress) * 0.45).clamp(0.0, 1.0);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: maxDiameter,
        height: maxDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: opacity),
            width: 2.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIcon(colorScheme),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                widget.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.actionLabel != null && widget.onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: widget.onAction,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(widget.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
