import 'package:flutter/material.dart';

/// Reusable rounded Najikify logo used across the app (navigation rail,
/// About page, dialogs) so the brand mark is never a placeholder icon.
class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;

  const AppLogo({super.key, this.size = 44, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/logo/najikify-logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback only if the bundled logo is ever missing.
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: Text(
                'N',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
