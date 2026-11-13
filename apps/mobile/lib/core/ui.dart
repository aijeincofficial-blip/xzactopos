import 'package:flutter/material.dart';

import 'design_tokens.g.dart';
import 'theme.dart';

/// Night Market paper card: flat `--paper` (or `--ink2` in dark mode), zero gradients/blurs,
/// `1.5px` sand/ink hairline border, optional tap handler.
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
    this.borderWidth = Gap.border,
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
    final r = BorderRadius.circular(radius ?? Gap.radiusL);
    final bg = color ?? scheme.surface;
    final stroke = borderColor ?? scheme.outlineVariant;
    final interactive = onTap != null || onLongPress != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(color: stroke, width: borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: interactive
            ? InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: r,
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Top summary card on Today, Utang, Expenses, Services, Day Close, Shift.
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
    final bg = accent
        ? (scheme.isDark ? scheme.nmInkLine : scheme.nmOkBg.withValues(alpha: 0.48))
        : scheme.surface;
    final border = accent
        ? (scheme.isDark ? scheme.nmLime.withValues(alpha: 0.55) : scheme.nmOkDot.withValues(alpha: 0.55))
        : scheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
      child: AppCard(
        onTap: onTap,
        color: bg,
        borderColor: border,
        borderWidth: Gap.border,
        padding: const EdgeInsets.all(Gap.l + 4),
        radius: Gap.radiusL,
        child: child,
      ),
    );
  }
}

/// Tactile flat Night Market squircle icon tile with `1.5px` border. Zero gloss gradients.
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.isDark;
    final bg = color.withValues(alpha: dark ? 0.18 : 0.12);
    final border = color.withValues(alpha: dark ? 0.35 : 0.24);
    final fg = iconColor ?? color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Icon(icon, color: fg, size: size * 0.52),
    );
  }
}

/// Square rounded icon badge for compact cards and headers.
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
  Widget build(BuildContext context) => CoinBadge(icon: icon, color: color, iconColor: onColor, size: size);
}

/// Rounded status pill (Paid, Completed, Pending Sync, Active Shift, Low/Out stock).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.textKey,
    this.color,
    this.textColor,
    this.dotColor,
    this.borderColor,
  });

  final String label;
  final Key? textKey;
  final Color? color;
  final Color? textColor;
  final Color? dotColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? (scheme.isDark ? scheme.nmInkLine : scheme.nmOkBg);
    final fg = textColor ?? (scheme.isDark ? scheme.nmTextOnDarkOrLime : scheme.nmOkFg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.0) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            key: textKey,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

extension _StatusColorHelper on ColorScheme {
  Color get nmTextOnDarkOrLime => nmLime;
}

/// Item descriptor for [SegmentedPillBar].
class SegmentedPillItem<T> {
  const SegmentedPillItem({
    required this.value,
    required this.label,
    this.icon,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Key? key;
}

/// Night Market recessed sand/ink track switcher with dark ink / lime active pill
/// and auto-scaling labels so multi-word segments never clip or wrap onto 2 lines.
class SegmentedPillBar<T> extends StatelessWidget {
  const SegmentedPillBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.height = 44,
  });

  final List<SegmentedPillItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.chipFill,
        borderRadius: BorderRadius.circular(Gap.radiusM),
        border: Border.all(color: scheme.outlineVariant, width: Gap.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _SegmentedPillTab<T>(
                item: items[i],
                selected: items[i].value == selected,
                height: height - 8,
                onTap: () => onChanged(items[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedPillTab<T> extends StatelessWidget {
  const _SegmentedPillTab({
    required this.item,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final SegmentedPillItem<T> item;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeBg = scheme.isDark ? scheme.nmLime : scheme.nmInk;
    final fg = selected
        ? (scheme.isDark ? scheme.nmInk : scheme.nmLime)
        : scheme.outline;
    final r = BorderRadius.circular(Gap.radiusS);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: item.key,
        onTap: onTap,
        borderRadius: r,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: height,
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: r,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 17, color: fg),
                  const SizedBox(width: 5),
                ],
                Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stadium choice pill (e.g. Cash / E-wallet / Card, GCash / Maya).
class AppPillChip extends StatelessWidget {
  const AppPillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accentColor,
    this.height = 44,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? accentColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.isDark;
    final r = BorderRadius.circular(height / 2);

    final bg = selected
        ? (dark ? scheme.nmLime : scheme.nmInk)
        : scheme.surface;
    final border = selected
        ? (dark ? scheme.nmLime : scheme.nmInk)
        : scheme.outlineVariant;
    final fg = selected
        ? (dark ? scheme.nmInk : scheme.nmLime)
        : scheme.onSurface;
    final iconColor = selected
        ? fg
        : (accentColor ?? scheme.outline);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(color: border, width: selected ? 1.8 : Gap.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: iconColor),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Night Market dashed receipt divider (`1.5px` `--dash` ticks).
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, this.color, this.dashWidth = 5, this.dashGap = 4, this.height = 1.5});

  final Color? color;
  final double dashWidth;
  final double dashGap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.nmDash;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _DashedLinePainter(c, dashWidth, dashGap, height)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color, this.dashWidth, this.dashGap, this.thickness);
  final Color color;
  final double dashWidth;
  final double dashGap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      final end = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) =>
      old.color != color || old.dashWidth != dashWidth || old.dashGap != dashGap || old.thickness != thickness;
}

/// Torn-paper thermal receipt zig-zag edge (matches Night Market web `.receipt::after`).
class ZigzagEdge extends StatelessWidget {
  const ZigzagEdge({
    super.key,
    this.fillColor,
    this.strokeColor,
    this.height = 10,
    this.toothWidth = 14,
    this.flip = false,
  });

  final Color? fillColor;
  final Color? strokeColor;
  final double height;
  final double toothWidth;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = fillColor ?? scheme.surface;
    final stroke = strokeColor ?? scheme.outlineVariant;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ZigzagPainter(fill: fill, stroke: stroke, toothWidth: toothWidth, flip: flip),
      ),
    );
  }
}

class _ZigzagPainter extends CustomPainter {
  const _ZigzagPainter({required this.fill, required this.stroke, required this.toothWidth, required this.flip});
  final Color fill;
  final Color stroke;
  final double toothWidth;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / toothWidth).ceil().clamp(4, 120);
    final step = size.width / count;
    final path = Path();
    final strokePath = Path();

    if (!flip) {
      // Flat top edge, pointed teeth pointing down
      path.moveTo(0, 0);
      strokePath.moveTo(0, 0);
      for (var i = 0; i < count; i++) {
        final mid = i * step + step / 2;
        final end = (i + 1) * step;
        path.lineTo(mid, size.height - 1);
        path.lineTo(end, 0);
        strokePath.lineTo(mid, size.height - 1);
        strokePath.lineTo(end, 0);
      }
      path.lineTo(size.width, 0);
      path.close();
    } else {
      // Flat bottom edge, pointed teeth pointing up
      path.moveTo(0, size.height);
      strokePath.moveTo(0, size.height);
      for (var i = 0; i < count; i++) {
        final mid = i * step + step / 2;
        final end = (i + 1) * step;
        path.lineTo(mid, 1);
        path.lineTo(end, size.height);
        strokePath.lineTo(mid, 1);
        strokePath.lineTo(end, size.height);
      }
      path.lineTo(size.width, size.height);
      path.close();
    }

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      strokePath,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ZigzagPainter old) =>
      old.fill != fill || old.stroke != stroke || old.toothWidth != toothWidth || old.flip != flip;
}

/// Night Market thermal-paper slip card with torn zig-zag top and/or bottom edges.
class NightMarketReceiptCard extends StatelessWidget {
  const NightMarketReceiptCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 20),
    this.topZigzag = false,
    this.bottomZigzag = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool topZigzag;
  final bool bottomZigzag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final border = scheme.outlineVariant;
    final r = Radius.circular(topZigzag ? 0 : Gap.radiusL);
    final br = Radius.circular(bottomZigzag ? 0 : Gap.radiusL);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topZigzag) ZigzagEdge(fillColor: bg, strokeColor: border, flip: true),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(topLeft: r, topRight: r, bottomLeft: br, bottomRight: br),
            border: Border(
              left: BorderSide(color: border, width: Gap.border),
              right: BorderSide(color: border, width: Gap.border),
              top: topZigzag ? BorderSide.none : BorderSide(color: border, width: Gap.border),
              bottom: bottomZigzag ? BorderSide.none : BorderSide(color: border, width: Gap.border),
            ),
          ),
          padding: padding,
          child: child,
        ),
        if (bottomZigzag) ZigzagEdge(fillColor: bg, strokeColor: border),
      ],
    );
  }
}

/// Primary Night Market `#D4F25A` lime pill button with `#0F1A16` ink typography.
class LimeButton extends StatelessWidget {
  const LimeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: expand ? Size.fromHeight(height) : Size(0, height),
        backgroundColor: scheme.nmLime,
        foregroundColor: scheme.nmInk,
        disabledBackgroundColor: scheme.nmDisabledBg,
        disabledForegroundColor: scheme.nmDisabledFg,
        shape: const StadiumBorder(),
        side: BorderSide(
          color: onPressed == null
              ? scheme.outlineVariant
              : (scheme.isDark ? scheme.nmLimeHover.withValues(alpha: 0.4) : scheme.nmInk.withValues(alpha: 0.22)),
          width: Gap.border,
        ),
        textStyle: const TextStyle(
          fontFamily: NightMarketFont.sans,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
    return btn;
  }
}

/// Night Market square color swatch tile with 2-letter monogram (`IB`, `AM`, `MC`, `CS`)
/// derived from the item's category/name, matching docs/design.md §6.
class CategorySwatchTile extends StatelessWidget {
  const CategorySwatchTile({
    super.key,
    required this.name,
    this.category,
    this.size = 44,
    this.radius = 12,
  });

  final String name;
  final String? category;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final sw = categorySwatchFor(name, category: category);
    final code = productMonogram(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: sw.background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: sw.foreground.withValues(alpha: 0.18), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        maxLines: 1,
        style: TextStyle(
          fontFamily: NightMarketFont.display,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: sw.foreground,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Empty-state screen placeholder with optional action button.
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
            CoinBadge(
              icon: icon,
              color: scheme.isDark ? scheme.nmLime : scheme.nmInk,
              size: 64,
            ),
            const SizedBox(height: Gap.l),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (action != null) ...[const SizedBox(height: Gap.xl), action!],
          ],
        ),
      ),
    );
  }
}

/// Tiny Night Market dot + text pill used in lists/headers.
class NightMarketDotTag extends StatelessWidget {
  const NightMarketDotTag({super.key, required this.label, this.dotColor, this.backgroundColor, this.textColor});
  final String label;
  final Color? dotColor;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StatusPill(
      label: label,
      color: backgroundColor ?? (scheme.isDark ? DesignTokens.inkLine : DesignTokens.okBg),
      textColor: textColor ?? (scheme.isDark ? DesignTokens.textOnDark : DesignTokens.okFg),
      dotColor: dotColor ?? (scheme.isDark ? DesignTokens.lime : DesignTokens.okDot),
    );
  }
}
