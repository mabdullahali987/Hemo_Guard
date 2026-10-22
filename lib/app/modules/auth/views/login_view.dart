import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_client.dart';

// Page-local palette. Global AppTheme and every other Flutter screen stay intact.
class _Pearl {
  static const violet = Color(0xFF7C3AED);
  static const magenta = Color(0xFFC026D3);
  static const rose = Color(0xFFFB7185);
  static const ink = Color(0xFF281733);
  static const muted = Color(0xFF786780);
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta, rose],
  );
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final email = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  bool showPassword = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Get.find<AuthService>().login(email.text, password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final base = Theme.of(context);
    final themed = base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: _Pearl.violet),
      scaffoldBackgroundColor: Colors.transparent,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(.62),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: _Pearl.violet.withOpacity(.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: _Pearl.violet, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFBF3055)),
        ),
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _LoginBackdrop(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 24),
                      child: child,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: _LoginGlass(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(27, 32, 27, 30),
                          child: Form(
                            key: form,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 74,
                                    height: 74,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(23),
                                      gradient: _Pearl.gradient,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _Pearl.violet.withOpacity(.25),
                                          blurRadius: 26,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.monitor_heart_outlined,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 19),
                                const Text(
                                  'HemoGuard',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                    color: _Pearl.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'WELCOME BACK',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _Pearl.muted,
                                    fontSize: 10,
                                    letterSpacing: 2.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 31),
                                const Text(
                                  'Sign in',
                                  style: TextStyle(
                                    color: _Pearl.ink,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -.6,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Enter your account credentials.',
                                  style: TextStyle(
                                    color: _Pearl.muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: email,
                                  enabled: !busy,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  style: const TextStyle(color: _Pearl.ink),
                                  decoration: const InputDecoration(
                                    labelText: 'Email address',
                                    prefixIcon: Icon(Icons.mail_outline_rounded),
                                  ),
                                  validator: (v) => v == null || !v.contains('@')
                                      ? 'Enter your email'
                                      : null,
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: password,
                                  enabled: !busy,
                                  obscureText: !showPassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  style: const TextStyle(color: _Pearl.ink),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: showPassword
                                          ? 'Hide password'
                                          : 'Show password',
                                      onPressed: () => setState(
                                          () => showPassword = !showPassword),
                                      icon: Icon(showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Enter your password'
                                      : null,
                                  onFieldSubmitted: (_) => submit(),
                                ),
                                AnimatedSize(
                                  duration: reducedMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  child: error == null
                                      ? const SizedBox(width: double.infinity)
                                      : Padding(
                                          padding: const EdgeInsets.only(top: 15),
                                          child: Container(
                                            padding: const EdgeInsets.all(13),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFE9EF)
                                                  .withOpacity(.76),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFFE11D48)
                                                    .withOpacity(.25),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  color: Color(0xFFB92851),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    error!,
                                                    style: const TextStyle(
                                                      color: Color(0xFF8D2645),
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 24),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: _Pearl.gradient,
                                    borderRadius: BorderRadius.circular(17),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _Pearl.magenta.withOpacity(.23),
                                        blurRadius: 22,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(17),
                                      onTap: busy ? null : submit,
                                      child: SizedBox(
                                        height: 56,
                                        child: Center(
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                                milliseconds: 190),
                                            child: busy
                                                ? const SizedBox(
                                                    key: ValueKey('loading'),
                                                    width: 23,
                                                    height: 23,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(Colors.white),
                                                    ),
                                                  )
                                                : const Row(
                                                    key: ValueKey('signin'),
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Sign in securely',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      SizedBox(width: 11),
                                                      Icon(
                                                        Icons.arrow_forward_rounded,
                                                        color: Colors.white,
                                                        size: 19,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFBF9FC),
                  Color(0xFFF7EDFC),
                  Color(0xFFFFF2F6),
                ],
              ),
            ),
          ),
          Positioned(
            left: -160,
            top: -155,
            child: _GlowOrb(
              size: 390,
              color: _Pearl.violet.withOpacity(.22),
            ),
          ),
          Positioned(
            right: -150,
            top: 150,
            child: _GlowOrb(
              size: 370,
              color: _Pearl.rose.withOpacity(.21),
            ),
          ),
          Positioned(
            left: 10,
            bottom: -185,
            child: _GlowOrb(
              size: 350,
              color: _Pearl.magenta.withOpacity(.16),
            ),
          ),
          child,
        ],
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
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

class _LoginGlass extends StatelessWidget {
  const _LoginGlass({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(33),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF764A84).withOpacity(.16),
              blurRadius: 55,
              offset: const Offset(0, 23),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(33),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(.76),
                    Colors.white.withOpacity(.36),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(.91),
                  width: 1.4,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(33),
                          gradient: RadialGradient(
                            center: const Alignment(-.85, -.95),
                            radius: 1.18,
                            colors: [
                              Colors.white.withOpacity(.48),
                              Colors.white.withOpacity(.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: const _LoginGlassRim(),
                      ),
                    ),
                  ),
                  child,
                ],
              ),
            ),
          ),
        ),
      );
}

/// Optical edge shimmer around the login card. Standard Flutter rendering,
/// keeping all authentication inputs and behavior exactly as before.
class _LoginGlassRim extends CustomPainter {
  const _LoginGlassRim();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 80 || size.height < 80) return;
    final w = size.width;
    final h = size.height;
    final upper = Path()
      ..moveTo(10, h * .20)
      ..cubicTo(10, 15, 17, 6, w * .27, 5)
      ..lineTo(w * .64, 5)
      ..cubicTo(w * .83, 5, w - 7, 18, w - 7, h * .16);
    canvas.drawPath(
      upper,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [
            Color(0x44FFFFFF),
            Color(0xFFFFFFFF),
            Color(0x49FBE4FF),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    final lower = Path()
      ..moveTo(14, h * .87)
      ..cubicTo(14, h - 11, w * .20, h - 5, w * .4, h - 5)
      ..lineTo(w * .71, h - 5);
    canvas.drawPath(
      lower,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0x88FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _LoginGlassRim oldDelegate) => false;
}
