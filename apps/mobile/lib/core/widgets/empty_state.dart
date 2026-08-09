import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Una lista vacía dice por qué está vacía. Una pantalla en blanco se lee como
/// que la app se rompió.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final atenuado = context.colors.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: spacing.xxl, color: atenuado),
            SizedBox(height: spacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.texts.bodyLarge?.copyWith(color: atenuado),
            ),
            if (action != null) ...[
              SizedBox(height: spacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
