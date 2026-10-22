part of '../superadmin_view.dart';

class _TopGlassIcon extends StatelessWidget {
  const _TopGlassIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 43,
          height: 43,
          child: _FrostedPanel(
            radius: 14,
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Icon(icon, color: _AdminColors.ink, size: 20),
              ),
            ),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _AdminColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: _AdminColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      );
}

class _MetricGlass extends StatelessWidget {
  const _MetricGlass({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _FrostedPanel(
        padding: const EdgeInsets.all(15),
        radius: 20,
        child: SizedBox(
          height: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (_AdminColors.dark ? Colors.white : _AdminColors.violet).withOpacity(_AdminColors.dark ? .08 : .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _AdminColors.dark ? const Color(0xFFFFD0DB) : _AdminColors.violet, size: 19),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: _AdminColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: _AdminColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.lab});
  final bool lab;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: lab
                ? const [Color(0xFFFB7185), Color(0xFFC026D3)]
                : const [Color(0xFF7C3AED), Color(0xFFB45CF0)],
          ),
        ),
        child: Icon(
          lab ? Icons.science_outlined : Icons.person_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
}

class _StatusCapsule extends StatelessWidget {
  const _StatusCapsule(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.095),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withOpacity(.17)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _AdminColors.dark
                ? Color.lerp(color, Colors.white, .48)!
                : color,
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      );
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                constraints: const BoxConstraints(minHeight: 42),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(.19),
                      color.withOpacity(.09),
                    ],
                  ),
                  border: Border.all(color: color.withOpacity(.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: _AdminColors.dark
                        ? Color.lerp(color, Colors.white, .44)!
                        : color),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: _AdminColors.dark
                            ? Color.lerp(color, Colors.white, .44)!
                            : color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
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
