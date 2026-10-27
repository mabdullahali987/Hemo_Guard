import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';

import 'package:hemo_guard/app/theme/app_theme.dart';
import 'package:hemo_guard/app/modules/home/widgets/user_glass.dart';
import 'package:hemo_guard/app/data/cbc_parser.dart';
import '../controllers/scanner_controller.dart';
import '../widgets/consent_gate.dart';

/// Display-only typical adult reference ranges (hints for the user; not used
/// by the parser or the model).
const Map<String, String> _typicalRange = {
  'Hb': '12 – 17',
  'RBC': '4.2 – 5.9',
  'HCT': '37 – 52',
  'MCV': '80 – 100',
  'MCH': '27 – 33',
  'MCHC': '32 – 36',
  'RDW': '11.5 – 14.5',
};

class ScannerView extends GetView<ScannerController> {
  const ScannerView({super.key});

  @override
  Widget build(BuildContext context) {
    return UserGlassScope(child: Scaffold(
      backgroundColor: Colors.transparent,
      // The keyboard must NOT resize the body: the no-scroll form divides the
      // available height with Expanded rows, so shrinking it when the keyboard
      // opens would squeeze/overflow the grid. Keeping it fixed also stops the
      // orientation heuristic from flipping mid-edit (the old cause of the
      // keyboard opening and instantly closing on some phones).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: Obx(() =>
            Text(controller.isText.value ? 'Enter Values' : 'Scan Report')),
      ),
      body: SafeArea(
        child: Obx(() {
          if (!controller.consentConfirmed.value) {
            return ConsentGate(controller: controller);
          }
          final showCamera =
              !controller.isText.value && !controller.hasScanned.value;
          return showCamera ? const _CameraView() : const _FormView();
        }),
      ),
    ));
  }
}

// ---------------------------------------------------------------------------
// Camera
// ---------------------------------------------------------------------------

class _CameraView extends GetView<ScannerController> {
  const _CameraView();

  @override
  Widget build(BuildContext context) {
    // Use the device orientation, not the layout constraints: the latter would
    // flip when the keyboard shrinks the body.
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Builder(builder: (context) {
      if (landscape) {
        // Balanced: preview centred on the left, controls stacked on the right.
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: AspectRatio(aspectRatio: 3 / 4, child: _preview()),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Point at a CBC report',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 15, color: UserGlassColors.muted)),
                    const SizedBox(height: 20),
                    _captureButton(),
                    const SizedBox(height: 14),
                    _galleryButton(context),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Point at a CBC report',
                style: TextStyle(fontSize: 15, color: UserGlassColors.muted)),
            const SizedBox(height: 16),
            Expanded(child: _preview()),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _galleryButton(context)),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _captureButton()),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _preview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() => controller.isCameraInitialized.value
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller
                        .cameraController.value!.value.previewSize!.height,
                    height: controller
                        .cameraController.value!.value.previewSize!.width,
                    child: CameraPreview(controller.cameraController.value!),
                  ),
                )
              : Container(
                  color: Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                )),
          const _ScanLine(),
        ],
      ),
    );
  }

  Widget _captureButton() => ElevatedButton.icon(
        onPressed: controller.takePicture,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Capture'),
      );

  Widget _galleryButton(BuildContext context) => OutlinedButton.icon(
        onPressed: () => controller.pickImage(context),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Gallery'),
      );
}

// ---------------------------------------------------------------------------
// Values form (used for manual entry and post-scan editing)
// ---------------------------------------------------------------------------

class _FormView extends GetView<ScannerController> {
  const _FormView();

  @override
  Widget build(BuildContext context) {
    // Use the device orientation, not the layout constraints: the latter would
    // flip when the keyboard shrinks the body, rebuilding the whole form and
    // dropping the focused field (which made the keyboard flicker open/closed).
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Builder(builder: (context) {
      if (landscape) {
        // Fields grid on the left, actions + prediction on the right.
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _header(),
                    const SizedBox(height: 10),
                    Expanded(child: _grid(3)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actions(),
                    const SizedBox(height: 16),
                    Flexible(child: const _ResultBanner()),
                    const SizedBox(height: 12),
                    _disclaimer(),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      // Portrait: everything stacked, grid fills the free space (no scroll).
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 10),
            Expanded(child: _grid(2)),
            const SizedBox(height: 12),
            const _ResultBanner(),
            const SizedBox(height: 12),
            _actions(),
            const SizedBox(height: 10),
            _disclaimer(),
          ],
        ),
      );
    });
  }

  Widget _header() {
    return Obx(() {
      if (controller.isProcessing.value) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Reading report…',
                style: TextStyle(fontSize: 15, color: UserGlassColors.muted)),
          ],
        );
      }
      return Text(
        controller.isText.value
            ? 'Enter your CBC values'
            : 'Review the scanned values',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: UserGlassColors.muted),
      );
    });
  }

  Widget _actions() {
    return Obx(() {
      final busy = controller.isProcessing.value || controller.isAnalyzing.value;
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () {
                      controller.clearAll();
                      if (!controller.isText.value) {
                        controller.hasScanned.value = false;
                      }
                    },
              child: Text(controller.isText.value ? 'Clear' : 'Rescan'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: busy || controller.savedReport.value != null ? null : controller.runPrediction,
              child: const Text('Analyze'),
            ),
          ),
        ],
      );
    });
  }

  Widget _disclaimer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 14, color: UserGlassColors.muted),
        SizedBox(width: 6),
        Flexible(
          child: Text('Screening aid only — not a diagnosis.',
              style: TextStyle(fontSize: 12, color: UserGlassColors.muted)),
        ),
      ],
    );
  }

  /// Fields in [cols] columns, dividing the available height so nothing needs
  /// scrolling.
  Widget _grid(int cols) {
    final params = controller.params;
    final rows = <Widget>[];
    for (var i = 0; i < params.length; i += cols) {
      final cells = <Widget>[];
      for (var j = 0; j < cols; j++) {
        final idx = i + j;
        cells.add(Expanded(
          child: idx < params.length
              ? _FieldCell(param: params[idx])
              : const SizedBox(),
        ));
        if (j < cols - 1) cells.add(const SizedBox(width: 10));
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(Expanded(
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
      ));
    }
    return Column(children: rows);
  }
}

/// A single CBC value cell used in the grid.
class _FieldCell extends GetView<ScannerController> {
  const _FieldCell({required this.param});
  final CbcParameter param;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: UserGlassColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UserGlassColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(param.short,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(param.unit,
                  style: TextStyle(fontSize: 10, color: UserGlassColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          _ValueField(param: param),
          const SizedBox(height: 3),
          Text('normal ${_typicalRange[param.short] ?? ''}',
              style: TextStyle(fontSize: 10, color: UserGlassColors.muted)),
        ],
      ),
    );
  }
}

/// The editable value field with a loading state; shared by the grid cells.
class _ValueField extends GetView<ScannerController> {
  const _ValueField({required this.param});
  final CbcParameter param;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isProcessing.value) {
        return const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      final missing = controller.values[param.key] == null;
      return TextField(
        controller: controller.textControllers[param.key],
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          hintText: '—',
          enabledBorder: missing
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.warn, width: 1.2),
                )
              : null,
        ),
        onChanged: (t) => controller.setValue(param.key, t),
      );
    });
  }
}

class _ResultBanner extends GetView<ScannerController> {
  const _ResultBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isDetected.value || controller.result.value == null) {
        return const SizedBox.shrink();
      }
      final positive = controller.isThalassemia; // thalassemia detected
      final color = positive ? AppColors.danger : AppColors.positive;
      final bg = positive ? AppColors.dangerBg : AppColors.positiveBg;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(
              positive ? Icons.warning_amber_rounded : Icons.verified_outlined,
              color: color,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              positive
                  ? 'Thalassemia indicators detected'
                  : 'No thalassemia indicators',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            if (controller.patientPublicId.value.isNotEmpty) ...[
              const SizedBox(height:10),
              Text('Patient ID: ${controller.patientPublicId.value}',
                style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:color)),
              const SizedBox(height:4),
               Text('Saved as a new report. Previous records are unchanged.',
                textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:color)),
            ],
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Decorative scan line for the camera preview
// ---------------------------------------------------------------------------

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Align(
        alignment: Alignment(0, _c.value * 2 - 1),
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: UserGlassColors.violet.withValues(alpha: 0.7),
            boxShadow: [
              BoxShadow(
                  color: UserGlassColors.violet.withValues(alpha: 0.4), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}
