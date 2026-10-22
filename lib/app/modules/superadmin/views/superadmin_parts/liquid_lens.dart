part of '../superadmin_view.dart';

/// Morphing glass droplet, inspired by optical highlights and the stretched
/// lens behavior in iOS dock references. This remains a Flutter approximation.
class _LiquidGlassLens extends StatelessWidget {
  const _LiquidGlassLens({required this.morph});
  final double morph;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: (_AdminColors.dark ? const Color(0xFFFFA7B9) : const Color(0xFFAC55C4)).withOpacity(_AdminColors.dark ? (.05 + morph * .05) : (.10 + morph * .11)),
              blurRadius: 12 + morph * 8,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: (_AdminColors.dark ? Colors.black : const Color(0xFF5A315C)).withOpacity(.10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipPath(
          clipper: _FluidLensClipper(morph),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 19, sigmaY: 19),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _AdminColors.dark
                          ? const [
                              Color(0x5AFFFFFF),
                              Color(0x423A3A3A),
                              Color(0x3E2A2A2A),
                              Color(0x52323232),
                            ]
                          : const [
                              Color(0xADFFFFFF),
                              Color(0x64FFE8FF),
                              Color(0x4FD2AFE5),
                              Color(0x9BFFFFFF),
                            ],
                      stops: const [0, .30, .71, 1],
                    ),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-.73, -.95),
                        radius: 1.28,
                        colors: _AdminColors.dark
                            ? [
                                Color(0x44FFFFFF),
                                Color(0x08FFFFFF),
                                Color(0x00FFFFFF),
                              ]
                            : [
                                Color(0xABFFFFFF),
                                Color(0x28FFFFFF),
                                Color(0x00FFFFFF),
                              ],
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _LiquidLensRim(morph: morph),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// A slightly asymmetric, elastic capsule instead of a sliding rectangle.
class _FluidLensClipper extends CustomClipper<Path> {
  const _FluidLensClipper(this.morph);
  final double morph;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = h * .47;
    final pull = morph * 4.0;
    return Path()
      ..moveTo(r, 1)
      ..cubicTo(w * .34, 1 - pull * .22, w * .69, 1 + pull * .26,
          w - r, 1)
      ..cubicTo(w - r * .20, 1 - pull * .45,
          w + pull * .55, h * .24, w - 1, h / 2)
      ..cubicTo(w + pull * .55, h * .76,
          w - r * .15, h + pull * .20, w - r, h - 1)
      ..cubicTo(w * .68, h - 1 - pull * .25,
          w * .35, h - 1 + pull * .25, r, h - 1)
      ..cubicTo(r * .18, h + pull * .25,
          -pull * .40, h * .76, 1, h / 2)
      ..cubicTo(-pull * .40, h * .24, r * .18, 1 - pull * .24, r, 1)
      ..close();
  }

  @override
  bool shouldReclip(covariant _FluidLensClipper oldClipper) =>
      oldClipper.morph != morph;
}

/// A thin fading fluid bridge, visible only mid-movement between tab centers.
class _DockFluidTrailPainter extends CustomPainter {
  const _DockFluidTrailPainter({
    required this.position,
    required this.cell,
    required this.strength,
  });
  final double position;
  final double cell;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength < .001) return;
    // Use the nearest anchored tab as the tail. This keeps the fluid
    // connection natural when swiping either left or right.
    final from = position.roundToDouble();
    final x1 = 5 + cell * (from + .5);
    final x2 = 5 + cell * (position + .5);
    final y = size.height / 2;
    final bend = 5 + 5 * strength;
    final path = Path()
      ..moveTo(x1, y - 2.5)
      ..cubicTo(x1 + (x2 - x1) * .35, y - bend,
          x1 + (x2 - x1) * .65, y - bend, x2, y - 6)
      ..quadraticBezierTo(x2 + 5, y, x2, y + 6)
      ..cubicTo(x1 + (x2 - x1) * .65, y + bend,
          x1 + (x2 - x1) * .35, y + bend, x1, y + 2.5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            (_AdminColors.dark ? const Color(0xFFFFFFFF) : const Color(0xFFB979D4)).withOpacity((_AdminColors.dark ? .05 : .10) * strength),
            (_AdminColors.dark ? const Color(0xFFFFE1E8) : const Color(0xFFFFE4FD)).withOpacity((_AdminColors.dark ? .34 : .58) * strength),
            (_AdminColors.dark ? const Color(0xFFFFB7C6) : const Color(0xFFBF72D2)).withOpacity((_AdminColors.dark ? .10 : .21) * strength),
          ],
        ).createShader(Rect.fromLTWH(
            math.min(x1, x2), y - 14, math.max(1.0, (x2 - x1).abs()), 28)),
    );
  }

  @override
  bool shouldRepaint(covariant _DockFluidTrailPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.cell != cell ||
      oldDelegate.strength != strength;
}

class _LiquidLensRim extends CustomPainter {
  const _LiquidLensRim({required this.morph});
  final double morph;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 22 || size.height < 22) return;
    final w = size.width;
    final h = size.height;
    final top = Path()
      ..moveTo(8, h * .44)
      ..cubicTo(7, h * .13, w * .21, 3, w * .43, 3)
      ..cubicTo(w * .72, 3 - morph, w * .85, 7, w - 8, h * .30);
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7 + morph * .7
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0x12FFFFFF), Color(0xEEFFFFFF), Color(0x33FFFFFF)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    final bottom = Path()
      ..moveTo(10, h * .73)
      ..cubicTo(w * .25, h - 3, w * .76, h - 3, w - 10, h * .73);
    canvas.drawPath(
      bottom,
      Paint()
        ..color = const Color(0x9AFFFFFF)
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidLensRim oldDelegate) =>
      oldDelegate.morph != morph;
}

