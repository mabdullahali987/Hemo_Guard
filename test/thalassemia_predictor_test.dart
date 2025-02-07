import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hemo_guard/app/data/thalassemia_predictor.dart';

/// Read-only smoke test of the on-device XGBoost inference. It does NOT modify
/// the model — it just loads assets/xgboast.json and checks the pipeline runs
/// and separates a classic microcytic (thalassemic) profile from a normal one.
void main() {
  test('model loads and ranks a thalassemic profile above a normal one', () {
    final file = File('assets/xgboast.json');
    expect(file.existsSync(), isTrue, reason: 'model asset must exist');

    final predictor =
        ThalassemiaPredictor.fromJson(json.decode(file.readAsStringSync()) as List);
    expect(predictor.isLoaded, isTrue);

    // Classic beta-thalassemia trait: low MCV/MCH, high RBC & RDW.
    final thal = predictor.predict({
      'RBC Count': 6.5,
      'Hemoglobin Level': 11.1,
      'Hematocrit': 45.5,
      'MCV': 59.0,
      'MCH': 18.0,
      'MCHC': 31.0,
      'RDW-CV': 22.0,
    });

    // Healthy adult male (img1).
    final normal = predictor.predict({
      'RBC Count': 5.20,
      'Hemoglobin Level': 16.0,
      'Hematocrit': 47.2,
      'MCV': 91.0,
      'MCH': 30.8,
      'MCHC': 33.9,
      'RDW-CV': 12.7,
    });

    expect(thal.probability, inInclusiveRange(0.0, 1.0));
    expect(normal.probability, inInclusiveRange(0.0, 1.0));
    expect(thal.probability, greaterThan(normal.probability),
        reason: 'microcytic profile should score higher risk');
  });
}
