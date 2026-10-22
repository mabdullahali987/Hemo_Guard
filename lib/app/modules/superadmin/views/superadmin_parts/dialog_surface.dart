part of '../superadmin_view.dart';

// Dialog and report history presentation is scoped to this screen only.
// Flutter blur + translucent highlights approximate (but don't replicate)
// Apple's native Liquid Glass compositing.
class _DialogGlassSurface extends StatelessWidget {
  const _DialogGlassSurface({required this.child, this.radius = 30});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _AdminColors.dark
                ? const [Color(0xCC181818), Color(0xB3101010), Color(0xBF20191B)]
                : const [Color(0xC8FFFCFF), Color(0xA6F9F0FC), Color(0xC2FCECF5)],
          ),
          border: Border.all(color: _AdminColors.dark
              ? const Color(0x26FFFFFF) : const Color(0xF5FFFFFF), width: 1.25),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 28, offset: Offset(0, 12)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100, right: -65,
              child: _AdminOrb(size: 210, color: _AdminColors.dark ? const Color(0x10FFFFFF) : const Color(0x28C026D3)),
            ),
            Positioned(
              bottom: -125, left: -90,
              child: _AdminOrb(size: 210, color: _AdminColors.dark ? const Color(0x12FF9AAE) : const Color(0x20FB7185)),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: RadialGradient(
                      center: const Alignment(-.85, -1.0), radius: 1.5,
                      colors: _AdminColors.dark
                          ? const [Color(0x16FFFFFF), Color(0x00FFFFFF)]
                          : const [Color(0x88FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

