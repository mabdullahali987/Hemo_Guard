part of '../superadmin_view.dart';

class _LiquidHistorySheet extends StatelessWidget {
  const _LiquidHistorySheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 35, 12, 9),
      child: SizedBox(
        height: height * .79,
        child: _DialogGlassSurface(
          radius: 29,
          child: Column(children: [
            const SizedBox(height: 11),
            Container(width: 42, height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: const Color(0x557C3AED),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: _AdminColors.accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _AdminColors.ink,
                        fontWeight: FontWeight.w800, fontSize: 19)),
                    Text('Completed report history',
                      style: TextStyle(color: _AdminColors.muted, fontSize: 12)),
                  ],
                )),
                IconButton(
                  tooltip: 'Close history',
                  icon: Icon(Icons.close_rounded, color: _AdminColors.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Expanded(child: child),
          ]),
        ),
      ),
    );
  }
}

class _HistoryFeedback extends StatelessWidget {
  const _HistoryFeedback({
    required this.icon, required this.heading,
    required this.description, this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String heading;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 42, color: _AdminColors.violet),
        const SizedBox(height: 13),
        Text(heading, textAlign: TextAlign.center,
            style: TextStyle(color: _AdminColors.ink,
                fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 7),
        Text(description, textAlign: TextAlign.center,
            style: TextStyle(color: _AdminColors.muted, fontSize: 12)),
        if (onAction != null) ...[
          const SizedBox(height: 20),
          _LiquidPrimaryAction(title: actionLabel ?? 'Retry',
              onPressed: onAction),
        ],
      ]),
    ),
  );
}

class _GlassHistoryCount extends StatelessWidget {
  const _GlassHistoryCount({required this.total});
  final int total;
  @override
  Widget build(BuildContext context) => _FrostedPanel(
    radius: 17,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      const Icon(Icons.auto_graph_rounded, color: _AdminColors.violet),
      const SizedBox(width: 11),
      Text('$total reports generated',
          style: TextStyle(color: _AdminColors.ink,
              fontWeight: FontWeight.w800, fontSize: 14)),
    ]),
  );
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.scanned, required this.date});
  final bool scanned;
  final String date;
  @override
  Widget build(BuildContext context) => _FrostedPanel(
    radius: 17,
    padding: const EdgeInsets.all(13),
    child: Row(children: [
      Container(
        width: 43, height: 43,
        decoration: BoxDecoration(
          color: (scanned ? _AdminColors.violet : _AdminColors.magenta).withOpacity(.11),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(scanned ? Icons.document_scanner_outlined : Icons.edit_note_outlined,
            color: scanned ? _AdminColors.violet : _AdminColors.magenta),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(scanned ? 'Scanned report' : 'Manual report',
            style: TextStyle(color: _AdminColors.ink,
                fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          Text(date, style: TextStyle(color: _AdminColors.muted, fontSize: 11)),
        ],
      )),
    ]),
  );
}

/// Translucent violet-to-rose create button. Only the appearance differs;
/// tapping it still opens the original accountDialog() route.
