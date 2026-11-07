import 'package:flutter/material.dart';

import 'theme.dart';

/// Sculptural white card with soft diffuse dual shadow and subtle hairline border.
/// Exactly captures the floating, tactile ceramic aesthetic from the reference.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Gap.xl),
    this.color,
    this.radius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final r = BorderRadius.circular(radius ?? Gap.radiusXL);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: r,
        border: Border.all(
          color: dark ? scheme.outlineVariant.withValues(alpha: 0.5) : scheme.outlineVariant,
          width: 1.0,
        ),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x08101E33),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A sculptural Hero Card directly styled after the reference swap card:
/// Pure white surface, clean label with pill badge on top right, huge bold numbers,
/// and subtle secondary indicators.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.child,
    this.accent = false,
    this.onTap,
  });

  final Widget child;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.s),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Gap.xl + 4),
        radius: Gap.radiusXL,
        child: child,
      ),
    );
  }
}

/// A flat icon in a lightly tinted circle (the old glowing "coin" is gone: no glow, no white-on-solid).
class CoinBadge extends StatelessWidget {
  const CoinBadge({
    super.key,
    required this.icon,
    required this.color,
    this.iconColor,
    this.size = 46,
  });

  final IconData icon;
  final Color color;

  /// Defaults to [color].
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Center(child: Icon(icon, size: size * 0.5, color: iconColor ?? color)),
    );
  }
}

/// Small rounded square or circular badge with an icon.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.onColor,
    this.size = 46,
  });

  final IconData icon;
  final Color color;
  final Color? onColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CoinBadge(icon: icon, color: color, iconColor: onColor, size: size);
  }
}

/// Floating Pill Badge for counts, statuses, or micro-tags (like [Max] in the reference).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.textKey,
    this.color,
    this.textColor,
  });

  final String label;
  final Key? textKey;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.primaryContainer;
    final fg = textColor ?? scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        key: textKey,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Calm, refined empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(icon, size: 36, color: scheme.outline),
            ),
            const SizedBox(height: Gap.l),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
            ),
            if (action != null) ...[const SizedBox(height: Gap.xl), action!],
          ],
        ),
      ),
    );
  }
}
