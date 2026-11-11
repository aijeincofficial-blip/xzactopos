import 'package:flutter/material.dart';

import 'theme.dart';

/// Soft sculptural surface card: subtle white-to-cool-slate gradient, fine hairline border,
/// and diffused ambient shadow. Custom [color] paints flat while keeping the same shape and shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Gap.l),
    this.color,
    this.radius,
    this.borderColor,
    this.borderWidth = 1.0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? radius;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final r = BorderRadius.circular(radius ?? Gap.radiusL);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        gradient: color != null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [scheme.surface.withValues(alpha: 0.96), Color.lerp(scheme.surface, Colors.black, 0.14)!.withValues(alpha: 0.96)]
                    : [scheme.surface, const Color(0xFFFAFCFF)],
              ),
        borderRadius: r,
        border: Border.all(
          color: borderColor ?? (dark ? Colors.white.withValues(alpha: 0.08) : scheme.outlineVariant),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withValues(alpha: 0.28) : const Color(0x0B0F172A),
            blurRadius: 14,
            offset: const Offset(0, 4),
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

/// Sculptural Hero KPI Card aligned cleanly to the 16px horizontal layout rail.
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Gap.l + 4),
        radius: 22,
        borderColor: accent ? scheme.primary.withValues(alpha: 0.35) : null,
        child: child,
      ),
    );
  }
}

/// Tactile app-icon squircle badge: smooth gradient of [color], crisp white icon,
/// and a subtle colored ambient shadow underneath.
class CoinBadge extends StatelessWidget {
  const CoinBadge({
    super.key,
    required this.icon,
    required this.color,
    this.iconColor,
    this.size = 42,
  });

  final IconData icon;
  final Color color;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    final light = hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 0.82)).toColor();
    final deep = hsl.withLightness((hsl.lightness - 0.05).clamp(0.14, 1.0)).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.30),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, deep]),
        boxShadow: [
          BoxShadow(
            color: deep.withValues(alpha: 0.22),
            blurRadius: size * 0.22,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: Icon(icon, size: size * 0.50, color: iconColor ?? Colors.white)),
    );
  }
}

/// Small rounded squircle badge with an icon.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.onColor,
    this.size = 42,
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

/// Soft Pill Badge for counts, statuses, or micro-tags.
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
          letterSpacing: 0.2,
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
            CoinBadge(icon: icon, color: scheme.primary, size: 64),
            const SizedBox(height: Gap.l),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.outline,
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
