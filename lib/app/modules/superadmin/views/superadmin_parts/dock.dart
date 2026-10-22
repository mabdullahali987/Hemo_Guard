part of '../superadmin_view.dart';

// Extracted verbatim from the original SuperadminView.
extension _SuperadminDock on _SuperadminViewState {
  // Translucent compact dock with an elastic glass lens. The custom shape
  // stretches at tab boundaries and leaves a fading fluid ribbon in its wake.
  // One TabController drives both page movement and the dock; no duplicate
  // navigation, requests, timers, or additional dependencies are introduced.
  Widget _navigation() => LayoutBuilder(
        builder: (context, constraints) {
          const labels = ['Overview', 'Accounts', 'Reports', 'Audit'];
          const icons = [
            Icons.dashboard_rounded,
            Icons.people_alt_rounded,
            Icons.description_rounded,
            Icons.history_rounded,
          ];
          const dockHeight = 59.0;
          final cell = (constraints.maxWidth - 10) / 4;
          final reduceMotion = MediaQuery.of(context).disableAnimations;
          return Container(
            height: dockHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(31),
              boxShadow: [
                BoxShadow(
                  color: (_AdminColors.dark ? Colors.black : const Color(0xFF4D224F)).withOpacity(_AdminColors.dark ? .34 : .18),
                  blurRadius: 26,
                  spreadRadius: -6,
                  offset: const Offset(0, 11),
                ),
                BoxShadow(
                  color: (_AdminColors.dark ? const Color(0x22FFFFFF) : _AdminColors.rose).withOpacity(_AdminColors.dark ? .04 : .08),
                  blurRadius: 20,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(31),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedBuilder(
                  animation: _tabs.animation!,
                  builder: (context, _) {
                    final position = _tabs.animation!.value
                        .clamp(0.0, 3.0)
                        .toDouble();
                    final phase = position - position.floorToDouble();
                    final liquid = reduceMotion ? 0.0 :
                        math.sin(math.pi * phase).clamp(0.0, 1.0).toDouble();
                    final lensWidth = cell - 5 + liquid * 26;
                    final lensCenter = 5 + cell * (position + .5);
                    final lensLeft = (lensCenter - lensWidth / 2)
                        .clamp(2.0, constraints.maxWidth - lensWidth - 2.0)
                        .toDouble();
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Translucent, not opaque charcoal: moving page colors
                        // remain visible through the blurred material.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(31),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _AdminColors.dark
                                    ? const [
                                        Color(0x2AFFFFFF),
                                        Color(0x14000000),
                                        Color(0x20101010),
                                      ]
                                    : const [
                                        Color(0x4DFFFFFF),
                                        Color(0x269D71AA),
                                        Color(0x337D547D),
                                      ],
                                stops: const [0, .51, 1],
                              ),
                              border: Border.all(
                                color: _AdminColors.dark
                                    ? const Color(0x30FFFFFF)
                                    : const Color(0xB7FFFFFF),
                                width: 1.05,
                              ),
                            ),
                          ),
                        ),
                        // Upper glint and lower rosy reflection trace the
                        // capsule's curvature while preserving transparency.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(31),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: _AdminColors.dark
                                      ? const [
                                          Color(0x22FFFFFF),
                                          Color(0x05000000),
                                          Color(0x08000000),
                                        ]
                                      : const [
                                          Color(0x60FFFFFF),
                                          Color(0x06FFFFFF),
                                          Color(0x15EB68A8),
                                        ],
                                  stops: const [0, .39, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!reduceMotion && liquid > .001)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _DockFluidTrailPainter(
                                  position: position,
                                  cell: cell,
                                  strength: liquid,
                                ),
                              ),
                            ),
                          ),
                        // One morphing lens. Travel widens its belly, pinches
                        // its rim and paints a connecting glossy fluid trail.
                        Positioned(
                          top: 3,
                          bottom: 3,
                          left: lensLeft,
                          width: lensWidth,
                          child: _LiquidGlassLens(morph: liquid),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            children: [
                              for (var i = 0; i < labels.length; i++)
                                Expanded(
                                  child: Semantics(
                                    button: true,
                                    selected: _tabs.index == i,
                                    label: '${labels[i]} tab',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(29),
                                        splashColor: (_AdminColors.dark ? Colors.white : _AdminColors.violet)
                                            .withOpacity(_AdminColors.dark ? .05 : .09),
                                        highlightColor: Colors.transparent,
                                        onTap: () {
                                          if (_tabs.index == i &&
                                              !_tabs.indexIsChanging) return;
                                          _tabs.animateTo(
                                            i,
                                            duration: reduceMotion
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 550),
                                            curve: Curves.easeInOutCubic,
                                          );
                                        },
                                        child: SizedBox(
                                          height: dockHeight,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Transform.scale(
                                                scale: 1.0 + .14 *
                                                    (1 - (position - i).abs())
                                                        .clamp(0.0, 1.0)
                                                        .toDouble(),
                                                child: Icon(
                                                  icons[i],
                                                  size: 20,
                                                  color: Color.lerp(
                                                    _AdminColors.dark
                                                        ? const Color(0xFFA7A7A7)
                                                        : const Color(0xFF5D4166),
                                                    _AdminColors.dark
                                                        ? const Color(0xFFFFD3DE)
                                                        : _AdminColors.violet,
                                                    (1 - (position - i).abs())
                                                        .clamp(0.0, 1.0)
                                                        .toDouble(),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  labels[i],
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 9.3,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color.lerp(
                                                      _AdminColors.dark
                                                          ? const Color(0xFF979797)
                                                          : const Color(0xFF695473),
                                                      _AdminColors.dark
                                                          ? const Color(0xFFFFD3DE)
                                                          : _AdminColors.violet,
                                                      (1 - (position - i).abs())
                                                          .clamp(0.0, 1.0)
                                                          .toDouble(),
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
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      );

  // TabBarView handles the single horizontal page movement; opacity supplies
  // a gentle liquid fade without a second outgoing-page animation.
  Widget _fadeTab(int index, Widget child) => AnimatedBuilder(
        animation: _tabs.animation!,
        child: child,
        builder: (context, child) {
          final reduced = MediaQuery.of(context).disableAnimations;
          final distance = (_tabs.animation!.value - index).abs()
              .clamp(0.0, 1.0).toDouble();
          return Opacity(
            opacity: reduced ? 1 : 1 - distance * .17,
            child: child,
          );
        },
      );

}
