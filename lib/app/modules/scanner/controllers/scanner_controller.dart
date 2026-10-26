import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../data/cbc_parser.dart';
import '../../../data/patient_metadata_parser.dart';
import '../../../data/hemoguard_pdf_generator.dart';
import '../widgets/patient_review_dialog.dart';
import '../widgets/patient_match_dialog.dart';
import '../../../data/thalassemia_predictor.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_client.dart';

class ScannerController extends GetxController {
  /// The seven parameters, in display order.
  final List<CbcParameter> params = CbcParser.parameters;

  /// key -> value (null means not-yet-known; never fabricated).
  late final RxMap<String, double?> values = <String, double?>{
    for (final p in params) p.key: null,
  }.obs;

  /// One text controller per field, so scans/clears can update the inputs and
  /// user edits flow back into [values].
  late final Map<String, TextEditingController> textControllers = {
    for (final p in params) p.key: TextEditingController(),
  };

  final RxString rawText = ''.obs;
  final RxBool isText = (Get.arguments?['type'] == 'text').obs;
  final RxBool isProcessing = false.obs;
  final RxBool isAnalyzing = false.obs;
  final RxBool isDetected = false.obs;
  final RxBool hasScanned = false.obs;

  // New patient workflow state; independent from the CBC prediction model.
  final RxBool consentConfirmed = false.obs;
  final RxBool consentLoading = true.obs;
  final RxString consentText = ''.obs;
  final RxString consentVersion = ''.obs;
  String? _consentIntentId;
  Map<String,String> patientDraft = {};
  final Rxn<Map<String,dynamic>> savedReport = Rxn<Map<String,dynamic>>();
  final RxString patientPublicId = ''.obs;
  final RxString pdfLocation = ''.obs;
  String _requestId = _newRequestId();
  static String _newRequestId() => '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1<<32)}';

  Future<void> _loadConsent() async {
    try {
      final response = await Get.find<AuthService>().api('GET','/api/consent/current');
      consentText.value = response['text']?.toString() ?? '';
      consentVersion.value = response['version']?.toString() ?? '';
    } catch(e) {
      Get.snackbar('Consent information unavailable',e.toString(),snackPosition:SnackPosition.TOP);
    } finally { consentLoading.value=false; }
  }

  Future<void> retryConsent() async {
    if(consentLoading.value)return;
    consentLoading.value=true;
    await _loadConsent();
  }

  Future<void> confirmConsent() async {
    if(consentVersion.value.isEmpty || consentLoading.value)return;
    consentLoading.value=true;
    try {
      final response=await Get.find<AuthService>().api('POST','/api/consent/intents',
        body:{'accepted':true,'version':consentVersion.value});
      _consentIntentId=response['consent_intent_id']?.toString();
      consentConfirmed.value=true;
      if(!isText.value)await initCamera();
    } catch(e) {
      Get.snackbar('Consent not recorded',e.toString(),snackPosition:SnackPosition.TOP);
    } finally {consentLoading.value=false;}
  }

  final Rxn<ThalassemiaResult> result = Rxn<ThalassemiaResult>();
  bool get isThalassemia => result.value?.isThalassemia ?? false;
  double get probability => result.value?.probability ?? 0.0;

  ThalassemiaPredictor? _predictor;
  bool get isModelLoaded => _predictor?.isLoaded ?? false;

  final Rx<CameraController?> cameraController = Rx<CameraController?>(null);
  final RxBool isCameraInitialized = false.obs;

  /// Maps a display key to the feature key the predictor expects.
  static const Map<String, String> _featureKey = {
    'Hemoglobin Level (g/dL)': 'Hemoglobin Level',
    'RBC Count (mil/cmm)': 'RBC Count',
    'Hematocrit (%)': 'Hematocrit',
    'MCV (fL)': 'MCV',
    'MCH (pg)': 'MCH',
    'MCHC (g/dL)': 'MCHC',
    'RDW-CV (%)': 'RDW-CV',
  };

  @override
  void onInit() {
    super.onInit();
    _loadModel();
    _loadConsent();
  }

  @override
  void onClose() {
    cameraController.value?.dispose();
    for (final c in textControllers.values) {
      c.dispose();
    }
    super.onClose();
  }

  Future<void> _loadModel() async {
    try {
      final raw = await rootBundle.loadString('assets/xgboast.json');
      _predictor = ThalassemiaPredictor.fromJson(json.decode(raw) as List);
      debugPrint('Model loaded: ${_predictor!.trees.length} trees');
    } catch (e) {
      debugPrint('Error loading model: $e');
    }
  }

  // ----- camera / image input -----------------------------------------------

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final ctrl = CameraController(
        cameras.first,
        ResolutionPreset.veryHigh, // sharper text for OCR
        enableAudio: false,
      );
      await ctrl.initialize();
      cameraController.value = ctrl;
      isCameraInitialized.value = true;
    } catch (e) {
      debugPrint('Camera init failed: $e');
    }
  }

  Future<void> takePicture() async {
    if (!isCameraInitialized.value || cameraController.value == null) return;
    try {
      final file = await cameraController.value!.takePicture();
      await _processImage(file);
    } catch (e) {
      debugPrint('Capture failed: $e');
    }
  }

  Future<void> pickImage(BuildContext context,
      {ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) await _processImage(image);
  }

  Future<void> _processImage(XFile image) async {
    // Immediately leave the camera and show the form with loaders in the
    // fields while OCR runs.
    for (final p in params) {
      values[p.key] = null;
      textControllers[p.key]!.clear();
    }
    values.refresh();
    isDetected.value = false;
    result.value = null;
    savedReport.value=null;
    patientPublicId.value='';
    pdfLocation.value='';
    patientDraft={};
    _requestId=_newRequestId();
    hasScanned.value = true;
    isProcessing.value = true;
    try {
      final parsed = await _readValues(image.path);
      // Apply everything we could read. Anything unread stays null.
      for (final p in params) {
        final v = parsed[p.key];
        values[p.key] = v;
        textControllers[p.key]!.text = v == null ? '' : _fmt(v);
      }
      values.refresh();
      patientDraft=PatientMetadataParser.parse(rawText.value);

      if (parsed.isEmpty) {
        Get.snackbar(
          'Couldn\'t read the report',
          'Try a sharper, well-lit, straight photo — or enter values manually.',
          snackPosition: SnackPosition.TOP,
        );
      } else if (missingKeys.isNotEmpty) {
        Get.snackbar(
          'Review needed',
          'Fill in ${missingKeys.map(_shortFor).join(", ")} to run the analysis.',
          snackPosition: SnackPosition.TOP,
        );
      } else {
        Get.snackbar('Report values detected',
          'Review the patient information and CBC values, then tap Analyze.',
          snackPosition:SnackPosition.TOP);
      }
    } catch (e) {
      debugPrint('OCR error: $e');
      Get.snackbar('Error', 'Failed to process image: $e',
          snackPosition: SnackPosition.TOP);
    } finally {
      isProcessing.value = false;
    }
  }

  /// Read CBC values using Google ML Kit on-device text recognition — fast,
  /// reliable on real photos, and fully offline.
  ///
  /// ML Kit groups a table by COLUMNS (all labels in one block, values in
  /// another), so it's parsed two ways and the results merged:
  ///   1. rows rebuilt from bounding boxes (groups text by vertical position →
  ///      "HCT … 29" lands on one line, which the parser needs), and
  ///   2. the raw block/line text (a fallback for single-column layouts).
  Future<Map<String, double>> _readValues(String imagePath) async {
    final merged = <String, double>{};
    final sw = Stopwatch()..start();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));

      final lines = <TextLine>[];
      final blockBuffer = StringBuffer();
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          lines.add(line);
          blockBuffer.writeln(line.text);
        }
      }

      final rowText = _rebuildRows(lines);
      final blockText = blockBuffer.toString();
      rawText.value = rowText.isNotEmpty ? rowText : blockText;

      // Column alignment is primary: it matches the Nth label to the Nth
      // result-column value by reading order, which is immune to the row skew
      // that photos-at-an-angle introduce. Row/block text then fill any gaps
      // (they handle single-line / inline layouts).
      final columnResult = _columnAlign(lines);
      columnResult.forEach((k, v) => merged[k] = v);
      CbcParser.parse(rowText).forEach((k, v) => merged.putIfAbsent(k, () => v));
      CbcParser.parse(blockText).forEach((k, v) => merged.putIfAbsent(k, () => v));

      debugPrint('OCR: ${sw.elapsedMilliseconds}ms, ${merged.length} values');
      // Preserve diagnostic OCR dumps for debug builds only. Never persist
      // identifiable raw patient text in a production release.
      if (kDebugMode) await _dumpDebug(blockText, rowText, columnResult, merged, lines);
    } finally {
      await recognizer.close();
    }
    return merged;
  }

  static int _scanCount = 0;

  /// Append each scan's OCR text + parsed values to a history file on external
  /// storage so it can be pulled with `adb pull` for diagnosis across multiple
  /// scans (logcat is unreliable on this device).
  Future<void> _dumpDebug(String blockText, String rowText,
      Map<String, double> columnResult, Map<String, double> merged,
      List<TextLine> lines) async {
    try {
      _scanCount++;
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final e = StringBuffer()
        ..writeln('\n########## SCAN #$_scanCount ##########')
        ..writeln('FINAL (${merged.length}/7): $merged')
        ..writeln('COLUMN-ALIGN (${columnResult.length}/7): $columnResult')
        ..writeln('--- ROWS ---')
        ..writeln(rowText)
        ..writeln('--- SHORT LINES w/ COORDS ---');
      for (final l in lines) {
        if (l.text.length > 22) continue; // skip prose; keep labels/numbers
        final b = l.boundingBox;
        e.writeln('[x${b.left.toStringAsFixed(0)} '
            'y${b.center.dy.toStringAsFixed(0)}] ${l.text}');
      }
      await File('${dir.path}/scan_history.txt')
          .writeAsString(e.toString(), mode: FileMode.append);
      // Also keep the raw block text of the latest scan separately.
      await File('${dir.path}/last_block.txt').writeAsString(blockText);
    } catch (err) {
      debugPrint('dump err: $err');
    }
  }

  /// Reconstruct visual rows from ML Kit lines: group lines whose vertical
  /// centres are close (same table row), then order each group left-to-right.
  static String _rebuildRows(List<TextLine> lines) {
    final placed = lines.where((l) => l.boundingBox.height > 0).toList()
      ..sort((a, b) =>
          a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));
    if (placed.isEmpty) return '';

    final rows = <List<TextLine>>[];
    for (final line in placed) {
      final cy = line.boundingBox.center.dy;
      final tol = line.boundingBox.height * 0.6;
      final row = rows.isEmpty
          ? null
          : rows.last; // input is y-sorted, so only the last row can match
      if (row != null && (cy - row.first.boundingBox.center.dy).abs() <= tol) {
        row.add(line);
      } else {
        rows.add([line]);
      }
    }

    final buffer = StringBuffer();
    for (final row in rows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      buffer.writeln(row.map((l) => l.text).join('  '));
    }
    return buffer.toString();
  }

  /// Spatial column matching: for each CBC label, pair it with the result-column
  /// value that sits on the same table row (nearest vertical centre), using the
  /// text bounding boxes. This is robust to (a) skewed photos, (b) missing
  /// labels — an unlabelled value simply goes unclaimed instead of shifting the
  /// rest — and (c) OCR-misspelled labels via fuzzy matching. Only fires for
  /// clearly columnar layouts, so it stays silent on inline single-line reports
  /// which the text parser already handles.
  static Map<String, double> _columnAlign(List<TextLine> lines) {
    final out = <String, double>{};

    // Label-only lines (no inline number) → the columnar case.
    final labels = <(CbcParameter, Rect)>[];
    for (final l in lines) {
      if (RegExp(r'\d').hasMatch(l.text)) continue; // has an inline number
      final p = CbcParser.matchLabelFuzzy(l.text);
      if (p != null) labels.add((p, l.boundingBox));
    }
    if (labels.length < 3) return out;

    double labelRight = labels.first.$2.right;
    for (final e in labels) {
      if (e.$2.right > labelRight) labelRight = e.$2.right;
    }

    // Result-column cells: single numbers to the right of the label column.
    final nums = <(double, Rect)>[];
    for (final l in lines) {
      final v = CbcParser.resultNumber(l.text);
      if (v == null) continue;
      if (l.boundingBox.left < labelRight - 5) continue;
      nums.add((v, l.boundingBox));
    }
    if (nums.isEmpty) return out;

    // Estimate row spacing from consecutive label vertical gaps.
    labels.sort((a, b) => a.$2.center.dy.compareTo(b.$2.center.dy));
    final lys = labels.map((l) => l.$2.center.dy).toList();
    double rowSpacing = 40;
    if (lys.length >= 2) {
      final gaps = <double>[];
      for (var i = 1; i < lys.length; i++) {
        gaps.add(lys[i] - lys[i - 1]);
      }
      gaps.sort();
      rowSpacing = gaps[gaps.length ~/ 2].clamp(18.0, 90.0);
    }
    final maxGap = rowSpacing * 1.1; // a value sits within ~1 row of its label
    const aboveMargin = 6.0; // value may be a hair above its label baseline

    // Each value belongs to the nearest label ABOVE it (labels head their row;
    // the value column is printed a bit lower). Keep the closest value per label.
    final claims = <String, (double, double)>{}; // key -> (value, gap)
    for (final (val, nbox) in nums) {
      final vy = nbox.center.dy;
      CbcParameter? lab;
      double labY = -1e9;
      for (final (param, lbox) in labels) {
        final ly = lbox.center.dy;
        if (ly <= vy + aboveMargin && ly > labY) {
          labY = ly;
          lab = param;
        }
      }
      if (lab == null) continue;
      final gap = vy - labY;
      if (gap > maxGap) continue;
      final ok = CbcParser.validate(lab, val);
      if (ok == null) continue;
      final existing = claims[lab.key];
      if (existing == null || gap < existing.$2) {
        claims[lab.key] = (ok, gap);
      }
    }
    claims.forEach((k, v) => out[k] = v.$1);
    return out;
  }

  // ----- values / prediction -------------------------------------------------

  List<String> get missingKeys =>
      [for (final p in params) if (values[p.key] == null) p.key];

  bool get canPredict => missingKeys.isEmpty;

  void setValue(String key, String text) {
    final cleaned = text.trim();
    values[key] = cleaned.isEmpty ? null : double.tryParse(cleaned);
    if(savedReport.value != null) {result.value=null;isDetected.value=false;savedReport.value=null;pdfLocation.value='';}
  }

  void clearAll() {
    // Every new finalized screening needs a fresh consent attestation.
    if(savedReport.value != null) {
      consentConfirmed.value=false;
      _consentIntentId=null;
    }
    for (final p in params) {
      values[p.key] = null;
      textControllers[p.key]!.clear();
    }
    values.refresh();
    isDetected.value = false;
    result.value = null;
    savedReport.value=null;
    patientPublicId.value='';
    pdfLocation.value='';
    patientDraft={};
    _requestId=_newRequestId();
  }

  /// Trim a trailing ".0" so 91.0 shows as "91" but 30.8 stays "30.8".
  static String _fmt(double v) {
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  /// Patient-linked report flow. Existing XGBoost calculation is unchanged.
  /// The new record and the original usage count finalize in one transaction.
  Future<void> runPrediction() async {
    if(isAnalyzing.value)return;
    if(savedReport.value!=null) {
      Get.snackbar('Already saved','This analysis is in patient history. Rescan for a new test.',snackPosition:SnackPosition.TOP);
      return;
    }
    if(!consentConfirmed.value || _consentIntentId==null) {
      Get.snackbar('Consent required','Confirm patient permission before analyzing.',snackPosition:SnackPosition.TOP);
      return;
    }
    if(!isModelLoaded){Get.snackbar('Model not ready','Please try again in a moment.',snackPosition:SnackPosition.TOP);return;}
    if(!canPredict){Get.snackbar('Missing values','Enter ${missingKeys.map(_shortFor).join(", ")} to run analysis.',snackPosition:SnackPosition.TOP);return;}
    isAnalyzing.value=true;
    isDetected.value=false;
    result.value=null;
    try {
      // Patient fields remain editable even when OCR filled them all.
      final reviewed=await Get.dialog<Map<String,String>>(
        PatientReviewDialog(initial:patientDraft),barrierDismissible:false);
      if(reviewed==null)return;
      patientDraft=reviewed;
      final auth=Get.find<AuthService>();
      final match=await auth.api('POST','/api/patients/match',body:{
        'name':reviewed['name'],'age_at_test':reviewed['age_at_test'],
        'sex':reviewed['sex'],'public_id':reviewed['public_id'],
        'lab_patient_number':reviewed['lab_patient_number'],
      });
      final choices=(match['matches'] as List?)?.map((p)=>Map<String,dynamic>.from(p as Map)).toList()??[];
      String? existingPatientId;
      if(choices.isNotEmpty) {
        final selection=await Get.dialog<String>(
          PatientMatchDialog(matches:choices,verified:match['verified']==true),
          barrierDismissible:false);
        if(selection==null)return;
        if(selection=='rescan') {
          clearAll();
          if(!isText.value)hasScanned.value=false;
          return;
        }
        if(selection!='new') {
          existingPatientId=selection;
        } else {
          // An explicit new-patient selection must not retain someone else's
          // detected ID or already-assigned laboratory patient number.
          reviewed['public_id']='';
          reviewed['lab_patient_number']='';
        }
      }
      final sample=<String,double>{for(final p in params)_featureKey[p.key]!:values[p.key]!};
      // The existing predictor and numerical calculations are not altered.
      final calculated=_predictor!.predict(sample);
      final authorized=await auth.api('POST','/api/reports/authorize',
        body:{'mode':isText.value?'text':'image'});
      final finalized=await auth.api('POST','/api/clinical-reports/finalize',body:{
        'authorization_id':authorized['authorization_id'],
        'request_id':_requestId,
        'consent_intent_id':_consentIntentId,
        'existing_patient_id':existingPatientId,
        'patient':{
          'name':reviewed['name'],
          'age_at_test':reviewed['age_at_test'],
          'sex':reviewed['sex'],
          'lab_patient_number':reviewed['lab_patient_number'],
          'public_id':reviewed['public_id'],
        },
        'source_report_number':reviewed['source_report_number'],
        'sample_date':reviewed['sample_date'],
        'cbc':{
          'hemoglobin':values['Hemoglobin Level (g/dL)'],
          'rbc':values['RBC Count (mil/cmm)'],
          'hematocrit':values['Hematocrit (%)'],
          'mcv':values['MCV (fL)'],
          'mch':values['MCH (pg)'],
          'mchc':values['MCHC (g/dL)'],
          'rdw_cv':values['RDW-CV (%)'],
        },
        'prediction':{
          'is_thalassemia':calculated.isThalassemia,
          'probability':calculated.probability,
          'raw_score':calculated.rawScore,
          'model_version':'xgboast.json-v1',
        }
      });
      final report=Map<String,dynamic>.from(finalized['report'] as Map);
      final patient=Map<String,dynamic>.from(finalized['patient'] as Map);
      savedReport.value=report;
      patientPublicId.value=patient['public_id']?.toString()??'';
      result.value=calculated;
      isDetected.value=true;
      try {
        final pdf=await HemoGuardPdfGenerator.generate(report,patientPublicId:patientPublicId.value);
        pdfLocation.value=pdf.path;
        Get.snackbar('Report saved','Patient ${patientPublicId.value} • PDF saved in HemoGuardReports',
          snackPosition:SnackPosition.TOP);
      } catch(e) {
        Get.snackbar('Report saved','Medical record saved, but PDF creation failed: $e',snackPosition:SnackPosition.TOP);
      }
    } on ApiException catch(e) {
      if(e.statusCode==403 && e.message.contains('Consent confirmation')) {
        consentConfirmed.value=false;
        _consentIntentId=null;
        Get.snackbar('Consent expired','Confirm patient permission again before scanning.',snackPosition:SnackPosition.TOP);
      } else {
        Get.snackbar('Could not save report',e.message,snackPosition:SnackPosition.TOP);
      }
    } catch(e) {
      debugPrint('Patient analysis failed: $e');
      Get.snackbar('Error','Could not finish analysis. Please try again.',snackPosition:SnackPosition.TOP);
    } finally {isAnalyzing.value=false;}
  }

  String _shortFor(String key) => CbcParser.parameterForKey(key)?.short ?? key;
}
