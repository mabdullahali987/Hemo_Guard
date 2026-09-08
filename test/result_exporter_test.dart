//result_exporter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hemo_guard/app/data/result_exporter.dart';

void main() {
  test('toCsv emits header and a row per value', () {
    final exporter = ResultExporter(
      values: {'HGB': 12.4, 'MCV': 70.1},
      probability: 0.82,
    );
    final csv = exporter.toCsv();
    expect(csv, contains('field,value,unit'));
    expect(csv, contains('HGB,12.4,'));
    expect(csv, contains('thalassemia_probability,0.82,'));
  });
}
