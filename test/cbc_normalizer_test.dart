//cbc_normalizer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hemo_guard/app/data/cbc_normalizer.dart';

void main() {
  test('converts comma decimals to dots', () {
    expect(CbcNormalizer.normalize('HGB 12,4'), 'HGB 12.4');
  });

  test('collapses repeated whitespace', () {
    expect(CbcNormalizer.normalize('MCV    70.1'), 'MCV 70.1');
  });

  test('strips non-printable stray characters', () {
    expect(CbcNormalizer.normalize('RBC 5.1'), 'RBC 5.1');
  });
}
