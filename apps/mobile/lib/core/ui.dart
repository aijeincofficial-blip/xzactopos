import 'package:flutter/material.dart';

import 'theme.dart';

/// One look for every card in the app: white surface, big radius, soft shadow (no heavy borders).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Gap.l), this.color});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(Gap.radiusXL);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: radius,
        boxShadow: dark ? null : [BoxShadow(color: scheme.primary.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6))],
        border: dark ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// The big number at the top of a screen (Home, Today, Utang): a large rounded card with the page margins.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.child, this.accent = false, this.onTap});
  final Widget child;

  /// primary gradient with light text (money in) instead of a soft container colour.
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = accent ? scheme.onPrimary : scheme.onPrimaryContainer;
    final radius = BorderRadius.circular(Gap.radiusXL);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.s),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: accent ? null : scheme.primaryContainer,
          gradient: accent
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, Color.lerp(scheme.primary, Colors.black, 0.28)!],
                )
              : null,
          boxShadow: accent ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10))] : null,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Gap.xl),
            child: DefaultTextStyle.merge(style: TextStyle(color: fg), child: child),
          ),
        ),
      ),
    );
  }
}
/// Small rounded square with an icon, used on Home tiles and list rows.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.onColor, this.size = 44});
  final IconData icon;
  final Color color;
  final Color? onColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Gap.radiusM - 2)),
      child: Icon(icon, size: size * 0.55, color: onColor ?? Colors.white),
    );
  }
}

/// A calm empty state: icon, one sentence, optional action. Centered, with page margins.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: scheme.outline),
          const SizedBox(height: Gap.m),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: Gap.l), action!],
        ]),
      ),
    );
  }
}

