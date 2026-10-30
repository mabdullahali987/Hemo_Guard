import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'user_glass.dart';

/// A user-scoped, high-contrast glass notice that sits ABOVE bottom sheets.
/// Unlike a ScaffoldMessenger snackbar it never shifts the report sheet or
/// inherits the legacy light-theme snackbar text color.
class UserFeedback {
  UserFeedback._();
  static OverlayEntry? _active;
  static Timer? _timeout;

  static void info(String title, String message, {BuildContext? context}) =>
      _show(title, message, context: context, type: _NoticeType.info);

  static void error(String title, String message, {BuildContext? context}) =>
      _show(title, message, context: context, type: _NoticeType.error);

  static void success(String title, String message,
          {BuildContext? context, String? filePath}) =>
      _show(title, message, context: context,
          type: _NoticeType.success, filePath: filePath);

  static void _show(String title, String message,
      {BuildContext? context, required _NoticeType type, String? filePath}) {
    final navigator = context == null
        ? Get.key.currentState
        : Navigator.maybeOf(context, rootNavigator: true);
    final overlay = navigator?.overlay ?? Get.key.currentState?.overlay;
    if (overlay == null) {
      // Very early startup only: still explicitly specify readable colors.
      final dark = UserGlassColors.dark;
      Get.snackbar(title, message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: dark ? const Color(0xFF222028) : const Color(0xFFFFF7FF),
          colorText: dark ? Colors.white : const Color(0xFF281733),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4));
      return;
    }
    _timeout?.cancel();
    _active?.remove();
    _active?.dispose();
    _active = null;

    final safeTop = MediaQuery.of(overlay.context).padding.top;
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => Positioned(
      left: 14, right: 14, top: safeTop + 12,
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: _GlassNotice(title: title, message: message,
          type: type, filePath: filePath),
      )),
    ));
    _active = entry;
    overlay.insert(entry); // Root overlay: visible above the report bottom sheet.
    _timeout = Timer(Duration(seconds: filePath == null ? 4 : 7), () {
      if (identical(_active, entry)) {
        entry.remove();
        entry.dispose();
        _active = null;
      }
    });
  }
}

enum _NoticeType { info, error, success }

class _GlassNotice extends StatelessWidget {
  const _GlassNotice({required this.title, required this.message,
    required this.type, this.filePath});
  final String title;
  final String message;
  final String? filePath;
  final _NoticeType type;

  @override
  Widget build(BuildContext context) {
    final dark = UserGlassColors.dark;
    final foreground = dark ? const Color(0xFFF8F3FC) : const Color(0xFF281733);
    final secondary = dark ? const Color(0xFFE2D2E8) : const Color(0xFF624C70);
    final accent = type == _NoticeType.error
        ? (dark ? const Color(0xFFFFADB9) : const Color(0xFFAB244F))
        : type == _NoticeType.success
            ? (dark ? const Color(0xFF9BFFC9) : const Color(0xFF176F49))
            : (dark ? const Color(0xFFE1BFFF) : UserGlassColors.violet);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero : const Duration(milliseconds: 370),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, -14 * (1 - value)), child: child),
      ),
      child: Semantics(
        liveRegion: true,
        label: '$title. $message${filePath == null ? '' : '. Saved to $filePath'}',
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: dark
                  ? const [Color(0xFF29212E), Color(0xFF1A161D)]
                  : const [Color(0xFFFFFAFF), Color(0xFFF9EFFC)],
              ),
              border: Border.all(color: dark
                ? const Color(0xFF69566C) : const Color(0xFFDAB8E6)),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(dark ? .46 : .16),
                blurRadius: 25, offset: const Offset(0, 9))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(dark ? .16 : .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: type == _NoticeType.success
                  ? _SuccessCheck(color: accent)
                  : Icon(type == _NoticeType.error
                      ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                      color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: TextStyle(color: foreground,
                  fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(message, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: secondary, fontSize: 12.5, height: 1.35)),
                if (filePath != null && filePath!.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: filePath!)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF382C3D) : const Color(0xFFEEE0F4),
                        borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Icon(Icons.folder_outlined, size: 15, color: accent),
                        const SizedBox(width: 7),
                        Expanded(child: Text(filePath!, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: foreground, fontSize: 11, height: 1.3))),
                        const SizedBox(width: 5),
                        Icon(Icons.copy_rounded, color: secondary, size: 15),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Saved in app storage • tap the path to copy',
                    style: TextStyle(color: secondary, fontSize: 10.5)),
                ],
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The success stroke completes after the notice appears. No dependencies.
class _SuccessCheck extends StatefulWidget {
  const _SuccessCheck({required this.color});
  final Color color;
  @override
  State<_SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<_SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 620))..forward();

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, __) => CustomPaint(
      painter: _CheckPainter(_controller.value, widget.color),
      size: const Size(26, 26),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2.6
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawArc(Rect.fromCircle(center: center, radius: 11), -math.pi / 2,
      2 * math.pi * (progress / .65).clamp(0.0, 1.0), false, paint);
    final checkProgress = ((progress - .50) / .50).clamp(0.0, 1.0);
    if (checkProgress > 0) {
      final p = Path()..moveTo(7, 13)..lineTo(11, 17)..lineTo(19, 9);
      final metrics = p.computeMetrics();
      for (final metric in metrics) {
        canvas.drawPath(metric.extractPath(0, metric.length * checkProgress), paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
