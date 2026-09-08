//cbc_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hemo_guard/app/data/cbc_parser.dart';

/// Benchmark suite built from the real CBC reports in ~/Downloads/imgs_bnch.
/// Each `report` string is a realistic OCR transcription of one image; the
/// expectations are the values a human reads from that image. This runs on the
/// host with `flutter test` — no device or OCR engine required — so the parser
/// can be regression-tested offline.

const hb = 'Hemoglobin Level (g/dL)';
const rbc = 'RBC Count (mil/cmm)';
const hct = 'Hematocrit (%)';
const mcv = 'MCV (fL)';
const mch = 'MCH (pg)';
const mchc = 'MCHC (g/dL)';
const rdw = 'RDW-CV (%)';

void expectValues(String report, Map<String, double> expected,
    {Set<String> absent = const {}}) {
  final got = CbcParser.parse(report);
  expected.forEach((key, value) {
    expect(got[key], isNotNull, reason: '$key should be found');
    expect(got[key]!, closeTo(value, 0.001), reason: '$key value');
  });
  for (final key in absent) {
    expect(got[key], isNull, reason: '$key should NOT be found');
  }
}

void main() {
  group('benchmark reports', () {
    test('img1 — clean table, value before range', () {
      expectValues('''
White Blood Cell Count 5.4 4.0 - 11.0 K/uL
Red Blood Cell Count 5.20 4.40 - 6.00 M/uL
Hemoglobin 16.0 13.5 - 18.0 g/dL
Hematocrit 47.2 40.0 - 52.0 %
MCV 91 80 - 100 fL
MCH 30.8 27.0 - 33.0 pg
MCHC 33.9 31.0 - 36.0 g/dL
RDW 12.7 < 16.4 %
''', {
        hb: 16.0,
        rbc: 5.20,
        hct: 47.2,
        mcv: 91,
        mch: 30.8,
        mchc: 33.9,
        rdw: 12.7,
      });
    });

    test('img2 — DOW lab, no RDW', () {
      expectValues('''
HB 17.5 gm/dL 13.0-17.0
RBC 5.8 x 10^12/L 4.5-5.5
HCT 51 % 40-50
MCV 88 fL 80-100
MCH 30 pg 27-32
MCHC 35 gm/dL 31.5-34.5
WBC 5.4 x 10e9/L 4.0-10.0
''', {
        hb: 17.5,
        rbc: 5.8,
        hct: 51,
        mcv: 88,
        mch: 30,
        mchc: 35,
      }, absent: {
        rdw
      });
    });

    test('img3 — BLANK template must yield nothing (no fabrication)', () {
      final got = CbcParser.parse('''
Hemoglobin g/dl 12 - 15
Total Leukocyte Count cumm 4,800 - 10,800
Total RBC Count million/cumm 3.9 - 4.8
Hematocrit Value, Hct % 36 - 46
Mean Corpuscular Volume, MCV fL 83 - 101
Mean Cell Haemoglobin, MCH Pg 27 - 32
Mean Cell Haemoglobin CON, MCHC % 31.5 - 34.5
''');
      expect(got, isEmpty);
    });

    test('img4 — TATA labs', () {
      expectValues('''
Hemoglobin 10.3 gm/dL 12.0 - 15.0
RBC 3.70 mill/cmm 3.8 - 4.8
HCT 30.4 % 36 - 46
MCV 82.2 fL 83 - 101
MCH 27.9 pg 27 - 32
MCHC 34.0 g/dL 31.5 - 34.5
RDW 16.1 % 11.5 - 14.5
''', {
        hb: 10.3,
        rbc: 3.70,
        hct: 30.4,
        mcv: 82.2,
        mch: 27.9,
        mchc: 34.0,
        rdw: 16.1,
      });
    });

    test('img5 — ACCESA dense report', () {
      expectValues('''
HEMOGLOBIN 16.6 13.5 - 18.0 g/dL
HEMATOCRIT 49.7 38.5 - 50.0 %
MCV 94.9 80.0 - 100.0 fL
MCH 31.8 27.0 - 33.0 pg
MCHC 33.5 31.5 - 35.0 g/dL
RDW 12.3 11.5 - 14.5 %
RED BLOOD CELL COUNT 5.24 4.20 - 5.80 Million/uL
WHITE BLOOD CELL COUNT 3.9 3.8 - 10.8 Thousand/uL
''', {
        hb: 16.6,
        rbc: 5.24,
        hct: 49.7,
        mcv: 94.9,
        mch: 31.8,
        mchc: 33.5,
        rdw: 12.3,
      });
    });

    test('img6 — IDC', () {
      expectValues('''
WBC Count 9010 4000 - 11000 /mm3
RBC Count 4.47 4.50 - 6.50 mill/mm3
Hemoglobin 12.4 13.5 - 18.0 g/dl
Hematocrit 39.8 40 - 54 %
MCV 89 76 - 96 fl
MCH 27.7 27 - 32 pg
MCHC 31.2 31.5 - 34.5 g/dl
RDW-CV 15.8 11.5 - 14.5 %
''', {
        hb: 12.4,
        rbc: 4.47,
        hct: 39.8,
        mcv: 89,
        mch: 27.7,
        mchc: 31.2,
        rdw: 15.8,
      });
    });

    test('Sysmex analyzer — numbered rows, H flags, RDW-SD trap', () {
      expectValues('''
14 RBC 4.64 10^12/L 3.50 - 5.50
15 HGB 15.0 g/dL 11.0 - 16.0
16 HCT 44.2 % 37.0 - 54.0
17 MCV 95.3 fL 80.0 - 100.0
18 MCH 32.3 pg 27.0 - 34.0
19 MCHC 33.9 g/dL 32.0 - 36.0
20 RDW-CV H 16.4 % 11.0 - 16.0
21 RDW-SD H 56.5 fL 35.0 - 56.0
''', {
        rbc: 4.64,
        hb: 15.0,
        hct: 44.2,
        mcv: 95.3,
        mch: 32.3,
        mchc: 33.9,
        rdw: 16.4, // RDW-CV, not the RDW-SD 56.5 on the next line
      });
    });

    test('3-column Parameter/Value/Unit (thalassemic profile)', () {
      expectValues('''
Parameter Value Unit
MCV 59.0 fL
RBC 6.5 10*12/L
HGB 11.1 g/dL
MCHC 31.0 g/dL
RDW-CV 22.0 %
MCH 18.0 pg
HCT 45.5 %
''', {
        mcv: 59.0,
        rbc: 6.5,
        hb: 11.1,
        mchc: 31.0,
        rdw: 22.0,
        mch: 18.0,
        hct: 45.5,
      });
    });

    test('Chughtai — result AFTER reference range + electrophoresis rows', () {
      expectValues('''
Hb 11.5 - 14.5 g/dl 7.7
Total RBC 4 - 5.3 x10^12/l 5.1
HCT 33 - 43 % 29
MCV 76 - 90 fl 57
MCH 25 - 31 pg 15
MCHC 30 - 35 g/dl 27
HB A 95.0 - 98.0 % 98.1
HB A2 1.5 - 3.5 % 1.9
''', {
        hb: 7.7, // not 98.1 (HB A) or 1.9 (HB A2)
        rbc: 5.1,
        hct: 29,
        mcv: 57,
        mch: 15,
        mchc: 27,
      }, absent: {
        rdw
      });
    });

    test('MPL — severe real values (the old hardcoded set)', () {
      expectValues('''
RBC Count 0.71 3.3 - 4.8 mill/cmm
Hemoglobin Level 2.9 12 - 16 g/dL
Hematocrit 09 36 - 46 %
MCV 129 82 - 98 fL
MCH 41 27 - 31 pg
MCHC 32 32 - 36 g/dL
RDW-CV 23 11 - 16 %
''', {
        rbc: 0.71,
        hb: 2.9,
        hct: 9,
        mcv: 129,
        mch: 41,
        mchc: 32,
        rdw: 23,
      });
    });

    test('PIMS — RDW-SD before RDW-CV must not win', () {
      expectValues('''
WBC 2640 4000 - 10000 /uL
RBC 4.21 4.5 - 5.5 million/uL
HB 14.9 13 - 17 g/dL
HCT 44.7 40 - 50 %
MCV 106.1 80 - 98 fL
MCH 35.4 27 - 32 pg
MCHC 33.3 31.5 - 34.5 g/dL
Platelet Count 91000 150000 - 400000 /uL
RDW-SD 64.9 37 - 54 fL
RDW 17.5 10 - 15 %
''', {
        rbc: 4.21,
        hb: 14.9,
        hct: 44.7,
        mcv: 106.1,
        mch: 35.4,
        mchc: 33.3,
        rdw: 17.5,
      });
    });

    test('mixed panel — only CBC rows picked up', () {
      expectValues('''
White blood cells 1400 4000 - 11000 /uL
Red blood cells 2100000 4500000 - 6500000 /uL
Haemoglobin 7.1 g/dl 13 - 18
Hematocrit 20 % 40 - 54
MCV 92 fl 76 - 96
''', {
        hb: 7.1,
        hct: 20,
        mcv: 92,
      }, absent: {
        rbc, // expressed as absolute count, correctly ignored
        mch,
        mchc,
        rdw,
      });
    });
  });

  group('disambiguation & OCR robustness', () {
    test('MCH vs MCHC never cross-match', () {
      final got = CbcParser.parse('MCH 30.8\nMCHC 33.9');
      expect(got[mch], closeTo(30.8, 0.001));
      expect(got[mchc], closeTo(33.9, 0.001));
    });

    test('long-form MCH does not become Hemoglobin', () {
      final got = CbcParser.parse(
          'Hemoglobin 16.0 13.5 - 18.0\nMean Corpuscular Hemoglobin 30.8 27 - 33');
      expect(got[hb], closeTo(16.0, 0.001));
      expect(got[mch], closeTo(30.8, 0.001));
    });

    test('lost decimal point rescue (442 -> 44.2)', () {
      final got = CbcParser.parse('Hematocrit 442 % 36 - 46');
      expect(got[hct], closeTo(44.2, 0.001));
    });

    test('digit/letter OCR confusion inside numbers', () {
      final got = CbcParser.parse('Hemoglobin l6.0 13.5 - 18.0\nHematocrit 47.O %');
      expect(got[hb], closeTo(16.0, 0.001));
      expect(got[hct], closeTo(47.0, 0.001));
    });

    test('dash-less / glued reference ranges are skipped via plausibility', () {
      // Blurry OCR drops range dashes: "33-43" -> "3343", "25-31" -> "2531".
      // The impossible glued number is skipped and the real result is taken.
      expect(CbcParser.parse('HCT 3343 29')[hct], closeTo(29, 0.001));
      expect(CbcParser.parse('MCH 2531 pg 15')[mch], closeTo(15, 0.001));
      expect(CbcParser.parse('Total RBC 45.3 x10^12/l 5.1')[rbc],
          closeTo(5.1, 0.001));
      expect(CbcParser.parse('MCHC 3035 g/dl 27')[mchc], closeTo(27, 0.001));
    });

    test('impossible values are rejected, not fabricated', () {
      // RBC of 9.2 (really a WBC/TLC value on a misaligned row) is out of range.
      final got = CbcParser.parse('RBC 9.2 4.0 - 11.0 x10^9/L');
      expect(got[rbc], isNull);
    });
  });

  group('alias diversity — every name variant maps to the right parameter', () {
    // key -> (list of label variants, a valid value for that parameter)
    final cases = <String, MapEntry<List<String>, double>>{
      hb: MapEntry(
          ['Hb', 'HB', 'Hgb', 'HGB', 'Hemoglobin', 'Haemoglobin'], 13.4),
      rbc: MapEntry([
        'RBC',
        'RBC Count',
        'Red Blood Cell Count',
        'Total RBC Count',
        'Total RBC',
        'Red Cell Count',
      ], 4.6),
      hct: MapEntry([
        'HCT',
        'Hct',
        'Hematocrit',
        'Haematocrit',
        'Hematocrit Value',
        'PCV',
        'Packed Cell Volume',
      ], 42.0),
      mcv: MapEntry(
          ['MCV', 'Mean Corpuscular Volume', 'Mean Cell Volume'], 88.0),
      mch: MapEntry([
        'MCH',
        'Mean Corpuscular Hemoglobin',
        'Mean Corpuscular Haemoglobin',
        'Mean Cell Haemoglobin',
      ], 29.0),
      mchc: MapEntry([
        'MCHC',
        'Mean Corpuscular Hemoglobin Concentration',
        'Mean Corpuscular Haemoglobin Concentration',
        'Mean Cell Haemoglobin Concentration',
      ], 33.0),
      rdw: MapEntry(
          ['RDW', 'RDW-CV', 'RDW CV', 'Red Cell Distribution Width'], 13.0),
    };

    cases.forEach((key, entry) {
      final labels = entry.key;
      final value = entry.value;
      for (final label in labels) {
        test('"$label" -> $key', () {
          final got = CbcParser.parse('$label $value');
          expect(got[key], isNotNull,
              reason: '"$label" should map to $key');
          expect(got[key]!, closeTo(value, 0.001));
          // It must not leak into any OTHER parameter.
          for (final other in cases.keys) {
            if (other == key) continue;
            expect(got[other], isNull,
                reason: '"$label" must not be read as $other');
          }
        });
      }
    });
  });
}
