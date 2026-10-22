part of '../superadmin_view.dart';

// Private widgets below are local to SuperadminView; no global app theming,
// shared services, routing, or data handling is modified by this design.
class _AdminColors {
  static const violet = Color(0xFF7C3AED);
  static const magenta = Color(0xFFC026D3);
  static const rose = Color(0xFFFB7185);
  // Scoped to the superadmin library; global AppTheme is untouched.
  static bool get dark => HemoGuardSystemAppearance.isDark;
  static Color get ink => dark ? const Color(0xFFF4F4F4) : const Color(0xFF281733);
  static Color get muted => dark ? const Color(0xFFB0B0B0) : const Color(0xFF77687F);
  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta, rose],
  );
}

class _AdminCanvas extends StatelessWidget {
  const _AdminCanvas({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _AdminColors.dark
                    ? const [Color(0xFF030303), Color(0xFF090909), Color(0xFF111111)]
                    : const [Color(0xFFFBF9FC), Color(0xFFF7EFFC), Color(0xFFFFF1F5)],
              ),
            ),
          ),
          Positioned(
            top: -210,
            left: -175,
            child: _AdminOrb(
              size: 430,
              color: _AdminColors.dark ? const Color(0x14FFFFFF) : const Color(0x557C3AED),
            ),
          ),
          Positioned(
            top: 185,
            right: -190,
            child: _AdminOrb(
              size: 440,
              color: _AdminColors.dark ? const Color(0x16FF8EA7) : const Color(0x44E11D48),
            ),
          ),
          Positioned(
            bottom: -260,
            left: -50,
            child: _AdminOrb(
              size: 460,
              color: _AdminColors.dark ? const Color(0x10FFFFFF) : const Color(0x35C026D3),
            ),
          ),
          child,
        ],
      );
}

class _AdminOrb extends StatelessWidget {
  const _AdminOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0)],
            ),
          ),
        ),
      );
}

class _FrostedPanel extends StatelessWidget {
  const _FrostedPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: (_AdminColors.dark ? Colors.black : const Color(0xFF744982))
                  .withOpacity(_AdminColors.dark ? .33 : .105),
              offset: const Offset(0, 13),
              blurRadius: 34,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _AdminColors.dark
                        ? const Color(0xFF171717).withOpacity(.82)
                        : Colors.white.withOpacity(.73),
                    _AdminColors.dark
                        ? const Color(0xFF0E0E0E).withOpacity(.62)
                        : Colors.white.withOpacity(.39),
                  ],
                ),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.white.withOpacity(
                    _AdminColors.dark ? .18 : .87)),
              ),
              child: Stack(
                children: [
                  // A specular highlight along the upper surface gives the
                  // card a curved, refractive-looking illuminated edge.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: RadialGradient(
                            center: const Alignment(-.88, -1),
                            radius: 1.32,
                            colors: [
                              Colors.white.withOpacity(_AdminColors.dark ? .10 : .48),
                              Colors.white.withOpacity(_AdminColors.dark ? .015 : .08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      );
}

