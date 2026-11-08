import 'package:flutter/material.dart';

import 'theme.dart';

/// Soft glass card (the More-grid look): faint white-to-lavender gradient, white hairline,
/// one lavender drop shadow. Dark: translucent navy with a faint white edge.
/// A custom [color] keeps the same shape and shadow but paints flat.
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
                    ? [scheme.surface.withValues(alpha: 0.95), Color.lerp(scheme.surface, Colors.black, 0.15)!.withValues(alpha: 0.95)]
                    : [scheme.surface, Color.lerp(scheme.surface, const Color(0xFFF1F5F9), 0.50)!],
              ),
        borderRadius: r,
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withValues(alpha: 0.25) : const Color(0x0C0F172A),
            blurRadius: 16,
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

/// Glossy app-icon badge (the More-grid look): a rounded square filled with a light-to-deep
/// gradient of [color], a white icon, and a soft coloured shadow underneath.
/// [iconColor] overrides the white icon.
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
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    final light = hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 0.85)).withHue((hsl.hue + 12) % 360).toColor();
    final deep = hsl.withLightness((hsl.lightness - 0.06).clamp(0.12, 1.0)).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.30),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, deep]),
        boxShadow: [BoxShadow(color: deep.withValues(alpha: 0.30), blurRadius: size * 0.26, offset: Offset(0, size * 0.10))],
      ),
      child: Center(child: Icon(icon, size: size * 0.52, color: iconColor ?? Colors.white)),
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
            CoinBadge(icon: icon, color: scheme.primary, size: 72),
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
