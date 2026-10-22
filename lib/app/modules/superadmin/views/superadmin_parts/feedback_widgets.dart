part of '../superadmin_view.dart';

class _GlassCreateUserButton extends StatelessWidget {
  const _GlassCreateUserButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: (_AdminColors.dark ? Colors.black : _AdminColors.magenta).withOpacity(_AdminColors.dark ? .24 : .19),
              blurRadius: 21,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(17),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _AdminColors.dark
                          ? const [Color(0xD9161616), Color(0xCC1E1E1E), Color(0xCC332026)]
                          : const [Color(0xB4C69AF8), Color(0xAAB977F0), Color(0xB6F49ABB)],
                    ),
                    border: Border.all(
                      color: _AdminColors.dark ? const Color(0x28FFFFFF) : const Color(0xDDFFFFFF),
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            color: _AdminColors.dark ? Color(0xFFF4F4F4) : Color(0xFF4C176E), size: 19),
                        SizedBox(width: 9),
                        Text('Add user',
                            style: TextStyle(
                              color: _AdminColors.dark ? Color(0xFFF4F4F4) : Color(0xFF4C176E),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Compact screen-local feedback placed immediately above the floating dock.
/// Draws a check stroke after a successful request instead of showing a
/// hard blue/purple Snackbar in an unpredictable ScaffoldMessenger position.
class _GlassFeedbackNotice extends StatelessWidget {
  const _GlassFeedbackNotice({
    required this.message,
    required this.isError,
  });
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: (_AdminColors.dark ? Colors.black : const Color(0xFF7D4385)).withOpacity(_AdminColors.dark ? .26 : .19),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _AdminColors.dark
                        ? (isError
                            ? const [Color(0xE026161A), Color(0xD5341E24)]
                            : const [Color(0xD9171717), Color(0xCF101010), Color(0xD3241D20)])
                        : (isError
                            ? const [Color(0xD5FFF5F7), Color(0xC5FFD3E3)]
                            : const [Color(0xC9FFFFFF), Color(0xBEEFD9FD), Color(0xC5FBE0EE)]),
                  ),
                  border: Border.all(
                    color: _AdminColors.dark ? const Color(0x24FFFFFF) : const Color(0xEFFFFFFF),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isError)
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFB62756), size: 26)
                      else
                        _AnimatedGlassTick(reduceMotion: reduceMotion),
                      const SizedBox(width: 11),
                      Flexible(
                        child: Text(message,
                          style: TextStyle(
                            color: isError
                                ? (_AdminColors.dark ? const Color(0xFFFFB6D1) : const Color(0xFF90264A))
                                : _AdminColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            height: 1.25,
                          ),
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
    );
  }
}

class _AnimatedGlassTick extends StatelessWidget {
  const _AnimatedGlassTick({required this.reduceMotion});
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Transform.scale(
          scale: .86 + .14 * value,
          child: CustomPaint(
            size: const Size(26, 26),
            painter: _GlassTickPainter(progress: value),
          ),
        ),
      );
}

class _GlassTickPainter extends CustomPainter {
  const _GlassTickPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawCircle(
      outer.center,
      size.width / 2,
      Paint()
        ..shader = (_AdminColors.dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF303030), Color(0xFF1D1D1D), Color(0xFF9F435A)],
              )
            : _AdminColors.accent).createShader(outer),
    );
    final tick = Path()
      ..moveTo(size.width * .25, size.height * .52)
      ..lineTo(size.width * .43, size.height * .69)
      ..lineTo(size.width * .77, size.height * .33);
    final pathMetric = tick.computeMetrics().first;
    canvas.drawPath(
      pathMetric.extractPath(0, pathMetric.length * progress),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassTickPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

