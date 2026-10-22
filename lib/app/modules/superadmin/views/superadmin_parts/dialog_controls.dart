part of '../superadmin_view.dart';

class _LiquidAdminDialog extends StatelessWidget {
  const _LiquidAdminDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
    required this.onCancel,
    required this.onAction,
    required this.actionLabel,
    required this.secondaryLabel,
    this.busy = false,
    this.danger = false,
    this.errorMessage,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget content;
  final VoidCallback onCancel;
  final VoidCallback onAction;
  final String actionLabel;
  final String secondaryLabel;
  final bool busy;
  final bool danger;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 450, maxHeight: height * .85),
        child: _DialogGlassSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(23, 23, 23, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 47,
                      width: 47,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: danger
                            ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFFB7185)])
                            : _AdminColors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: (danger ? _AdminColors.rose : _AdminColors.violet)
                                .withOpacity(.19),
                            blurRadius: 16, offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 23),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(
                            color: _AdminColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -.5,
                          )),
                          const SizedBox(height: 5),
                          Text(subtitle, style: TextStyle(
                            color: _AdminColors.muted, fontSize: 12,
                            height: 1.35,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(23, 0, 23, 8),
                  child: _DialogFeedback(message: errorMessage!),
                ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(23, 7, 23, 13),
                  child: content,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 10, 21, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: busy ? null : onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: _AdminColors.violet,
                        minimumSize: const Size(65, 45),
                      ),
                      child: Text(secondaryLabel),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _LiquidPrimaryAction(
                        title: actionLabel,
                        danger: danger,
                        busy: busy,
                        onPressed: busy ? null : onAction,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidPrimaryAction extends StatelessWidget {
  const _LiquidPrimaryAction({
    required this.title,
    required this.onPressed,
    this.danger = false,
    this.busy = false,
  });
  final String title;
  final VoidCallback? onPressed;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .65 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 45),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: danger
                ? const LinearGradient(colors: [Color(0xFFD9275B), Color(0xFFEF6488)])
                : _AdminColors.accent,
            boxShadow: [BoxShadow(
              color: (danger ? _AdminColors.rose : _AdminColors.violet)
                  .withOpacity(.23), blurRadius: 13, offset: const Offset(0, 5),
            )],
            border: Border.all(color: const Color(0xAAFFFFFF)),
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white,
                    ),
                  )
                : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DialogAccountSummary extends StatelessWidget {
  const _DialogAccountSummary({required this.user});
  final Map<String, dynamic> user;
  @override
  Widget build(BuildContext context) => _FrostedPanel(
    padding: const EdgeInsets.all(13),
    radius: 17,
    child: Row(children: [
      _AccountAvatar(lab: user['account_type'] == 'lab'),
      const SizedBox(width: 11),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user['display_name']?.toString() ?? 'Account',
              style: TextStyle(color: _AdminColors.ink,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(user['email']?.toString() ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _AdminColors.muted, fontSize: 11)),
        ],
      )),
    ]),
  );
}

class _DialogInfo extends StatelessWidget {
  const _DialogInfo({required this.text, required this.icon, this.danger = false});
  final String text;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      color: (_AdminColors.dark
                      ? (danger ? const Color(0xFF2A181D) : const Color(0xFF1C1C1C))
                      : (danger ? const Color(0xFFFFDFE8) : const Color(0xFFF0E6FF)))
          .withOpacity(.75),
      border: Border.all(
        color: (danger ? _AdminColors.rose : _AdminColors.violet).withOpacity(.20),
      ),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20,
          color: danger
              ? (_AdminColors.dark ? const Color(0xFFFFA4BE) : const Color(0xFFAF2153))
              : (_AdminColors.dark ? const Color(0xFFF2F2F2) : _AdminColors.violet)),
      const SizedBox(width: 9),
      Expanded(child: Text(text, style: TextStyle(
          color: _AdminColors.ink, fontSize: 12, height: 1.4))),
    ]),
  );
}

class _DialogFeedback extends StatelessWidget {
  const _DialogFeedback({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: (_AdminColors.dark ? const Color(0xFF24181C) : const Color(0xFFFFE8F0))
                          .withOpacity(.88),
        border: Border.all(color: const Color(0x77DF4778)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.error_outline_rounded,
            color: _AdminColors.dark ? const Color(0xFFFFA4BE) : const Color(0xFFB52258), size: 20),
        const SizedBox(width: 9),
        Expanded(child: Text(message, style: TextStyle(
          color: _AdminColors.dark ? const Color(0xFFFFD2DE) : const Color(0xFF9D1B50),
          fontSize: 12, fontWeight: FontWeight.w600, height: 1.35,
        ))),
      ]),
    ),
  );
}

class _DialogSwitch extends StatelessWidget {
  const _DialogSwitch({
    required this.label, required this.description,
    required this.value, required this.onChanged,
  });
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      color: _AdminColors.dark ? const Color(0x55171717) : const Color(0xAAFFFFFF),
      border: Border.all(color: _AdminColors.dark
                ? const Color(0x22FFFFFF) : const Color(0x66FFFFFF)),
    ),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _AdminColors.ink,
              fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 3),
          Text(description, style: TextStyle(
              color: _AdminColors.muted, fontSize: 11)),
        ],
      )),
      Switch.adaptive(value: value, onChanged: onChanged,
          activeColor: _AdminColors.violet),
    ]),
  );
}

