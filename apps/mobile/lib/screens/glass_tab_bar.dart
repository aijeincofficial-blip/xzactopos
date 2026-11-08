import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One entry of [GlassTabBar].
class GlassTab {
  const GlassTab({required this.key, required this.label, required this.icon});
  final String key;
  final String label;

  /// Builds the (outline) icon; [color] is the bar's icon colour.
  final Widget Function(Color color) icon;
}

/// The owner's mockup bar: a frosted glass bar whose top edge dips into a silky smooth wave
/// that cradles a raised, glowing circular POS button. Thin outline icons, slate labels on the
/// exact same baseline; the selected tab sits in a white/frosted pill with a mint glow.
/// In dark mode the bar stays a light translucent frosted glass, as in the mockup.
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

  static const double barHeight = 70.0;
  static const double button = 62.0;
  static const double sideMargin = 16.0;
  static const double bottomMargin = 12.0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const iconColor = Color(0xFF0F1C3C);
    const activeIconColor = Color(0xFF0F172A);

    return SizedBox(
      height: barHeight + button / 2 + bottomMargin + bottomInset,
      child: LayoutBuilder(builder: (context, c) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The smoothly waved frosted glass bar
            Positioned(
              left: sideMargin,
              right: sideMargin,
              bottom: bottomMargin + bottomInset,
              height: barHeight,
              child: CustomPaint(
                painter: _BarShadowPainter(dark: dark),
                child: ClipPath(
                  clipper: _WaveClipper(),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: CustomPaint(
                      foregroundPainter: _BarEdgePainter(dark: dark),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: dark
                                ? [
                                    const Color(0xFFB8C8DD).withValues(alpha: 0.88),
                                    const Color(0xFF98ACC4).withValues(alpha: 0.84),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.94),
                                    const Color(0xFFF1F4FA).withValues(alpha: 0.88),
                                  ],
                          ),
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < tabs.length; i++)
                              Expanded(
                                child: i == centerIndex
                                    ? _CenterItem(
                                        key: Key(tabs[i].key),
                                        label: tabs[i].label,
                                        selected: i == index,
                                        dark: dark,
                                        onTap: () => onSelect(i),
                                      )
                                    : _SideItem(
                                        key: Key(tabs[i].key),
                                        tab: tabs[i],
                                        selected: i == index,
                                        dark: dark,
                                        iconColor: iconColor,
                                        activeIconColor: activeIconColor,
                                        onTap: () => onSelect(i),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The raised glowing POS button, nestled in the wave cradle
            Positioned(
              left: c.maxWidth / 2 - button / 2,
              bottom: bottomMargin + bottomInset + barHeight - button / 2 - 3,
              child: _PosButton(
                size: button,
                selected: index == centerIndex,
                dark: dark,
                onTap: () => onSelect(centerIndex),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Continuous flowing wave path matching the owner's mockup.
Path _barPath(Size s) {
  const r = 28.0; // corner radius
  const span = 68.0; // half-width of the wave dip
  const depth = 26.0; // depth of the wave dip
  final cx = s.width / 2;

  return Path()
    ..moveTo(0, r)
    ..quadraticBezierTo(0, 0, r, 0)
    ..lineTo(cx - span, 0)
    // S-curve dip down to center (cx, depth)
    ..cubicTo(cx - span * 0.52, 0, cx - span * 0.40, depth, cx, depth)
    // S-curve rise back up to (cx + span, 0)
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

class _BarShadowPainter extends CustomPainter {
  _BarShadowPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _barPath(size).shift(const Offset(0, 8));
    canvas.drawPath(
      path,
      Paint()
        ..color = dark ? Colors.black.withValues(alpha: 0.40) : const Color(0x180F172A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  @override
  bool shouldRepaint(covariant _BarShadowPainter old) => old.dark != dark;
}

class _BarEdgePainter extends CustomPainter {
  _BarEdgePainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _barPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: dark ? 0.45 : 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _BarEdgePainter old) => old.dark != dark;
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.dark,
    required this.iconColor,
    required this.activeIconColor,
    required this.onTap,
  });

  final GlassTab tab;
  final bool selected;
  final bool dark;
  final Color iconColor;
  final Color activeIconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected
        ? const Color(0xFF0F172A)
        : (dark ? const Color(0xFF475569) : const Color(0xFF64748B));

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: SizedBox(
          height: GlassTabBar.barHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 7,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 56,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: selected
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: dark
                                ? [
                                    Colors.white.withValues(alpha: 0.72),
                                    const Color(0xFFEFF3F8).withValues(alpha: 0.55),
                                  ]
                                : [
                                    Colors.white,
                                    const Color(0xFFEFF3F8),
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2DD4BF).withValues(alpha: dark ? 0.70 : 0.45),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        )
                      : null,
                  child: tab.icon(selected ? activeIconColor : iconColor),
                ),
              ),
              Positioned(
                bottom: 8,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

class _CenterItem extends StatelessWidget {
  const _CenterItem({
    super.key,
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected
        ? const Color(0xFF0F172A)
        : (dark ? const Color(0xFF475569) : const Color(0xFF64748B));

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

/// Floating circular POS button featuring the official XZACTO logo mark,
/// with a crisp neutral rim and subtle drop shadow (no blue outer glow/ring).
class _PosButton extends StatelessWidget {
  const _PosButton({
    required this.size,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final double size;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'POS',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dark
                    ? Colors.black.withValues(alpha: 0.50)
                    : const Color(0xFF0F172A).withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: dark
                    ? Colors.black.withValues(alpha: 0.25)
                    : const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.white,
              width: 2.2,
            ),
            gradient: const RadialGradient(
              center: Alignment(0, -0.35),
              radius: 0.85,
              colors: [
                Color(0xFF0B1E48),
                Color(0xFF060B18),
              ],
            ),
          ),
          child: Center(
            child: Image.asset(
              'assets/brand/logo_mark.png',
              width: size * 0.64,
              height: size * 0.64,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}


// ---------- Outline icons drawn to match the owner's mockup ----------

Paint _line(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Calendar with clock hands, plus green peso badge (Today).
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
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'P',
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
    // Outer calendar card
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, 3.5, w - 4, h - 5), const Radius.circular(3.5)),
      p,
    );
    // Header divider line
    canvas.drawLine(Offset(2, 9), Offset(w - 2, 9), p);
    // Top rings
    canvas.drawLine(Offset(w * 0.30, 1.5), Offset(w * 0.30, 5.5), p);
    canvas.drawLine(Offset(w * 0.70, 1.5), Offset(w * 0.70, 5.5), p);
    // Clock hands
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

    // Top opening
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(bottomCenter.dx, bottomCenter.dy)
        ..lineTo(left.dx, left.dy)
        ..close(),
      p,
    );

    // Box body outline
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(left.dx, left.dy + bodyDepth)
        ..lineTo(bottomCenter.dx, bottomCenter.dy + bodyDepth)
        ..lineTo(right.dx, right.dy + bodyDepth)
        ..lineTo(right.dx, right.dy),
      p,
    );

    // Center vertical fold
    canvas.drawLine(bottomCenter, Offset(bottomCenter.dx, bottomCenter.dy + bodyDepth), p);

    // Outward open flaps
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

    // Cover
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(5.5, 1.5, w - 7.5, h - 3), const Radius.circular(3)),
      p,
    );
    // Vertical margin line
    canvas.drawLine(Offset(9.5, 1.5), Offset(9.5, h - 1.5), p);
    // Spiral rings
    for (final y in [5.5, 10.5, 15.5, 20.5]) {
      canvas.drawLine(Offset(2.0, y), Offset(6.0, y), p);
    }
    // Lines on the cover
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
