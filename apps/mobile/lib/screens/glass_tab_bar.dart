import 'package:flutter/material.dart';

import '../core/design_tokens.g.dart';
import '../core/theme.dart';

/// One entry of [GlassTabBar].
class GlassTab {
  const GlassTab({required this.key, required this.label, required this.icon});
  final String key;
  final String label;

  /// Builds the outline icon; [color] is the bar's icon colour.
  final Widget Function(Color color) icon;
}

/// Night Market docked floating bottom bar (`--ink` `#0F1A16` pill track with `1.5px` `--inkLine` border)
/// cradling the raised XZACTO POS crest button in `--lime` (`#D4F25A`). Zero glass blur or gradients.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.centerIndex,
    required this.onSelect,
  });

  final List<GlassTab> tabs;
  final int index;
  final int centerIndex;
  final ValueChanged<int> onSelect;

  static const double barHeight = 68.0;
  static const double button = 60.0;
  static const double sideMargin = 16.0;
  static const double bottomMargin = 10.0;
  static const double topClearance = 8.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const barBg = DesignTokens.ink;
    const barBorder = DesignTokens.inkLine2;
    const inactiveIcon = DesignTokens.mutedOnDark;
    const activeIcon = DesignTokens.ink;

    return SizedBox(
      height: barHeight + button / 2 + bottomMargin + topClearance + bottomInset,
      child: LayoutBuilder(builder: (context, c) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: sideMargin,
              right: sideMargin,
              bottom: bottomMargin + bottomInset,
              height: barHeight,
              child: CustomPaint(
                foregroundPainter: _BarEdgePainter(borderColor: barBorder),
                child: ClipPath(
                  clipper: _WaveClipper(),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: barBg),
                    child: Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: i == centerIndex
                                ? _CenterItem(
                                    key: Key(tabs[i].key),
                                    label: tabs[i].label,
                                    selected: i == index,
                                    onTap: () => onSelect(i),
                                  )
                                : _SideItem(
                                    key: Key(tabs[i].key),
                                    tab: tabs[i],
                                    selected: i == index,
                                    iconColor: inactiveIcon,
                                    activeIconColor: activeIcon,
                                    onTap: () => onSelect(i),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: c.maxWidth / 2 - button / 2,
              bottom: bottomMargin + bottomInset + barHeight - button / 2 - 3,
              child: _PosButton(
                size: button,
                selected: index == centerIndex,
                onTap: () => onSelect(centerIndex),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Crisp notched contour cradling the center POS button.
Path _barPath(Size s) {
  const r = 24.0;
  const span = 64.0;
  const depth = 24.0;
  final cx = s.width / 2;

  return Path()
    ..moveTo(0, r)
    ..quadraticBezierTo(0, 0, r, 0)
    ..lineTo(cx - span, 0)
    ..cubicTo(cx - span * 0.52, 0, cx - span * 0.40, depth, cx, depth)
    ..cubicTo(cx + span * 0.40, depth, cx + span * 0.52, 0, cx + span, 0)
    ..lineTo(s.width - r, 0)
    ..quadraticBezierTo(s.width, 0, s.width, r)
    ..lineTo(s.width, s.height - r)
    ..quadraticBezierTo(s.width, s.height, s.width - r, s.height)
    ..lineTo(r, s.height)
    ..quadraticBezierTo(0, s.height, 0, s.height - r)
    ..close();
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _barPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BarEdgePainter extends CustomPainter {
  _BarEdgePainter({required this.borderColor});
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _barPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _BarEdgePainter old) => old.borderColor != borderColor;
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.iconColor,
    required this.activeIconColor,
    required this.onTap,
  });

  final GlassTab tab;
  final bool selected;
  final Color iconColor;
  final Color activeIconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? DesignTokens.lime : DesignTokens.mutedOnDark;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: GlassTabBar.barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 8, vertical: selected ? 6 : 4),
                decoration: BoxDecoration(
                  color: selected ? DesignTokens.lime : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: tab.icon(selected ? activeIconColor : iconColor),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NightMarketFont.sans,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                  letterSpacing: selected ? 0.0 : 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterItem extends StatelessWidget {
  const _CenterItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? DesignTokens.lime : DesignTokens.mutedOnDark;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: GlassTabBar.barHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 8,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: NightMarketFont.sans,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tactile circular Night Market POS trigger button in electric `--lime` (`#D4F25A`)
/// or `--ink2` (`#16241F`) when inactive, cradling the XZACTO logo mark.
class _PosButton extends StatelessWidget {
  const _PosButton({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'POS',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? DesignTokens.lime : DesignTokens.ink2,
            border: Border.all(
              color: selected ? DesignTokens.ink : DesignTokens.lime.withValues(alpha: 0.65),
              width: selected ? 2.5 : 1.8,
            ),
          ),
          child: Center(
            child: selected
                ? const Icon(
                    Icons.point_of_sale_rounded,
                    color: DesignTokens.ink,
                    size: 28,
                  )
                : Image.asset(
                    'assets/brand/logo_mark.png',
                    width: size * 0.62,
                    height: size * 0.62,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.point_of_sale_rounded,
                      color: DesignTokens.lime,
                      size: 26,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------- Night Market crisp stroke glyphs ----------

Paint _line(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Calendar with clock hands + Night Market lime peso badge (Today).
class TodayGlyph extends StatelessWidget {
  const TodayGlyph({super.key, required this.color, this.badge = true});
  final Color color;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(size: const Size(25, 24), painter: _CalendarPainter(color)),
          if (badge)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: DesignTokens.lime,
                  shape: BoxShape.circle,
                  border: Border.all(color: DesignTokens.ink, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w900,
                    color: DesignTokens.ink,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarPainter extends CustomPainter {
  _CalendarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = _line(color, 1.8);
    final w = s.width;
    final h = s.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, 3.5, w - 4, h - 5), const Radius.circular(3.5)),
      p,
    );
    canvas.drawLine(Offset(2, 9), Offset(w - 2, 9), p);
    canvas.drawLine(Offset(w * 0.30, 1.5), Offset(w * 0.30, 5.5), p);
    canvas.drawLine(Offset(w * 0.70, 1.5), Offset(w * 0.70, 5.5), p);
    final c = Offset(w * 0.5, h * 0.63);
    canvas.drawLine(c, c.translate(0, -3.8), p);
    canvas.drawLine(c, c.translate(3.4, 0), p);
  }

  @override
  bool shouldRepaint(covariant _CalendarPainter old) => old.color != color;
}

/// Isometric open cardboard box (Stock).
class BoxGlyph extends StatelessWidget {
  const BoxGlyph({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(26, 26), painter: _BoxPainter(color));
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = _line(color, 1.8);
    final cx = s.width / 2;
    final cy = s.height / 2;

    final top = Offset(cx, cy - 8.5);
    final right = Offset(cx + 9.5, cy - 3.5);
    final bottomCenter = Offset(cx, cy + 1.5);
    final left = Offset(cx - 9.5, cy - 3.5);
    const bodyDepth = 9.5;

    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(bottomCenter.dx, bottomCenter.dy)
        ..lineTo(left.dx, left.dy)
        ..close(),
      p,
    );

    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(left.dx, left.dy + bodyDepth)
        ..lineTo(bottomCenter.dx, bottomCenter.dy + bodyDepth)
        ..lineTo(right.dx, right.dy + bodyDepth)
        ..lineTo(right.dx, right.dy),
      p,
    );

    canvas.drawLine(bottomCenter, Offset(bottomCenter.dx, bottomCenter.dy + bodyDepth), p);
    canvas.drawLine(left, Offset(left.dx - 3.5, left.dy + 3.5), p);
    canvas.drawLine(right, Offset(right.dx + 3.5, right.dy + 3.5), p);
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) => old.color != color;
}

/// Ring-bound notebook (Utang).
class NotebookGlyph extends StatelessWidget {
  const NotebookGlyph({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(24, 26), painter: _NotebookPainter(color));
}

class _NotebookPainter extends CustomPainter {
  _NotebookPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = _line(color, 1.8);
    final w = s.width;
    final h = s.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(5.5, 1.5, w - 7.5, h - 3), const Radius.circular(3)),
      p,
    );
    canvas.drawLine(Offset(9.5, 1.5), Offset(9.5, h - 1.5), p);
    for (final y in [5.5, 10.5, 15.5, 20.5]) {
      canvas.drawLine(Offset(2.0, y), Offset(6.0, y), p);
    }
    canvas.drawLine(Offset(12.5, 7.5), Offset(18.5, 7.5), p);
    canvas.drawLine(Offset(12.5, 11.5), Offset(16.5, 11.5), p);
  }

  @override
  bool shouldRepaint(covariant _NotebookPainter old) => old.color != color;
}

/// Three dots glyph (More).
class MoreGlyph extends StatelessWidget {
  const MoreGlyph({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(24, 24), painter: _MorePainter(color));
}

class _MorePainter extends CustomPainter {
  _MorePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    final cy = s.height / 2;
    final cx = s.width / 2;
    const r = 2.0;
    const d = 6.2;
    canvas.drawCircle(Offset(cx - d, cy), r, p);
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawCircle(Offset(cx + d, cy), r, p);
  }

  @override
  bool shouldRepaint(covariant _MorePainter old) => old.color != color;
}
