/// Pure-Dart parser that extracts CBC (Complete Blood Count) values from the
/// raw text produced by an OCR engine. It has **no Flutter dependency** so it
/// can be unit-tested on the host with `flutter test`.
///
/// Design goals (learned from the previous regex soup):
///  * Column/range aware — the *result* is the first standalone number after
///    the parameter label; reference ranges (`13.5 - 18.0`, `<16.4`) are
///    skipped, so a blank template yields nothing instead of range values.
///  * Word-boundary alias matching with longest-match-wins, so `MCH` never
///    steals an `MCHC` row and `Hemoglobin` never steals a
///    `Mean Corpuscular Hemoglobin` (MCH) row.
///  * Physiological sanity ranges reject garbage, with a conservative
///    "lost decimal point" rescue (e.g. `442` -> `44.2`).
///  * Never fabricates a value. A parameter that cannot be read is simply
///    absent from the result map.
library;

class CbcParameter {
  final String key; // canonical key shown in the UI
  final String short; // short label, e.g. "Hb"
  final String unit; // display unit
  final List<String> aliases; // names/abbreviations seen in reports
  final double min; // physiological lower bound (inclusive)
  final double max; // physiological upper bound (inclusive)

  const CbcParameter({
    required this.key,
    required this.short,
    required this.unit,
    required this.aliases,
    required this.min,
    required this.max,
  });
}

class CbcParser {
  CbcParser._();

  /// The seven parameters the Thalassemia model consumes. Aliases are ordered
  /// loosely from most-specific to least, though matching uses longest-match so
  /// order is not load-bearing.
  static const List<CbcParameter> parameters = [
    // Physiological ranges are deliberately WIDE. This is a Thalassemia
    // screener, so severe-but-real values (e.g. Hb 2.9, RBC 0.71, MCV 57 seen
    // in the benchmark reports) must be accepted. Ranges only reject values
    // that are physically impossible / clearly OCR garbage.
    CbcParameter(
      key: 'Hemoglobin Level (g/dL)',
      short: 'Hb',
      unit: 'g/dL',
      aliases: [
        'Haemoglobin',
        'Hemoglobin',
        'Hgb',
        'Hb',
        'HGB',
        'HB',
      ],
      min: 1.5,
      max: 25.0,
    ),
    CbcParameter(
      key: 'RBC Count (mil/cmm)',
      short: 'RBC',
      unit: 'mil/cmm',
      aliases: [
        'Red Blood Cell Count',
        'Total RBC Count',
        'Total RBC',
        'Red Cell Count',
        'RBC Count',
        'RBC',
      ],
      min: 0.5,
      max: 9.0,
    ),
    CbcParameter(
      key: 'Hematocrit (%)',
      short: 'HCT',
      unit: '%',
      aliases: [
        'Hematocrit Value',
        'Haematocrit',
        'Hematocrit',
        'Packed Cell Volume',
        'PCV',
        'HCT',
      ],
      min: 5.0,
      max: 70.0,
    ),
    CbcParameter(
      key: 'MCV (fL)',
      short: 'MCV',
      unit: 'fL',
      aliases: [
        'Mean Corpuscular Volume',
        'Mean Cell Volume',
        'MCV',
      ],
      min: 40.0,
      max: 160.0,
    ),
    CbcParameter(
      key: 'MCH (pg)',
      short: 'MCH',
      unit: 'pg',
      aliases: [
        'Mean Corpuscular Haemoglobin',
        'Mean Corpuscular Hemoglobin',
        'Mean Cell Haemoglobin',
        'Mean Cell Hemoglobin',
        'MCH',
      ],
      min: 10.0,
      max: 60.0,
    ),
    CbcParameter(
      key: 'MCHC (g/dL)',
      short: 'MCHC',
      unit: 'g/dL',
      aliases: [
        'Mean Corpuscular Haemoglobin Concentration',
        'Mean Corpuscular Hemoglobin Concentration',
        'Mean Cell Haemoglobin Concentration',
        'Mean Cell Haemoglobin CON',
        'MCHC',
      ],
      min: 20.0,
      max: 45.0,
    ),
    CbcParameter(
      key: 'RDW-CV (%)',
      short: 'RDW',
      unit: '%',
      aliases: [
        'Red Cell Distribution Width',
        'RDW-CV',
        'RDW CV',
        'RDW',
      ],
      min: 5.0,
      max: 45.0,
    ),
  ];

  /// Labels that collide with a tracked alias but are a *different* parameter.
  /// If one of these is the most specific match on a line, the line is skipped
  /// so it can't be mistaken for the tracked value. Examples from the
  /// benchmark set: "RDW-SD 64.9 fL" (not RDW-CV), "HB A2 1.9 %" (electrophoresis).
  static const List<String> ignoreAliases = [
    'RDW-SD',
    'RDW SD',
    'Hb A2',
    'HbA2',
    'HbA1c',
    'Hb A1c',
    'Hb A',
  ];

  static CbcParameter? parameterForKey(String key) {
    for (final p in parameters) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// The parameter this line's label refers to (respecting the ignore-list),
  /// or null. Exposed for spatial/column-based parsing.
  static CbcParameter? matchLabel(String line) =>
      _matchParameter(line)?.parameter;

  /// Like [matchLabel] but tolerant of OCR misspellings (REC→RBC,
  /// Hemotocrit→Hematocrit, HemogCbin→Hemoglobin). Falls back to fuzzy
  /// per-word matching only when the exact matcher finds nothing.
  static CbcParameter? matchLabelFuzzy(String line) {
    final exact = matchLabel(line);
    if (exact != null) return exact;

    final words = line
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toList();
    if (words.isEmpty) return null;

    CbcParameter? best;
    double bestSim = 0;
    for (final p in parameters) {
      for (final alias in p.aliases) {
        final a = alias.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
        if (a.length < 3) continue;
        for (final w in words) {
          if ((w.length - a.length).abs() > 3) continue;
          final maxLen = w.length > a.length ? w.length : a.length;
          final sim = 1 - _levenshtein(w, a) / maxLen;
          // 3–4 letter codes: allow ~1 edit; longer words: tighter ratio.
          final thr = a.length <= 4 ? 0.66 : 0.74;
          if (sim >= thr && sim > bestSim) {
            bestSim = sim;
            best = p;
          }
        }
      }
    }
    return best;
  }

  static int _levenshtein(String a, String b) {
    final n = b.length;
    if (a.isEmpty) return n;
    if (n == 0) return a.length;
    var prev = List<int>.generate(n + 1, (i) => i);
    var cur = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var m = cur[j - 1] + 1;
        if (prev[j] + 1 < m) m = prev[j] + 1;
        if (prev[j - 1] + cost < m) m = prev[j - 1] + cost;
        cur[j] = m;
      }
      final tmp = prev;
      prev = cur;
      cur = tmp;
    }
    return prev[n];
  }

  /// Range-validate a value for a parameter (with the lost-decimal rescue).
  /// Returns the accepted value, or null if implausible.
  static double? validate(CbcParameter p, double v) => _accept(p, v);

  /// If [s] is a single result value (exactly one number, not a reference
  /// range like "13.5 - 18.0"), return it. Used to find result-column cells.
  static double? resultNumber(String s) {
    final fixed = _fixDigits(s.trim());
    if (_rangeRe.hasMatch(fixed) || _cmpRe.hasMatch(fixed)) return null;
    final matches = _numRe.allMatches(fixed).toList();
    if (matches.length != 1) return null;
    return double.tryParse(matches.first.group(0)!);
  }

  /// Parse raw OCR text. Returns only the parameters that were confidently
  /// read; missing parameters are absent (never fabricated).
  static Map<String, double> parse(String rawText) {
    return parseLines(rawText.split('\n'));
  }

  static Map<String, double> parseLines(List<String> lines) {
    final Map<String, double> result = {};

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = _matchParameter(line);
      if (match == null) continue;
      final param = match.parameter;
      if (result.containsKey(param.key)) continue; // keep first good hit

      final after = _fixDigits(line.substring(match.end));
      // Take the first candidate number that is physiologically plausible. This
      // skips glued/dash-less range bounds (e.g. "33-43" OCR'd as "3343", which
      // is impossible) and lands on the real result value.
      for (final raw in _extractCandidates(after)) {
        final value = _accept(param, raw);
        if (value != null) {
          result[param.key] = value;
          break;
        }
      }
    }

    return result;
  }

  // ----- parameter/label matching -------------------------------------------

  static final Map<String, RegExp> _aliasRegexCache = {};

  static RegExp _aliasRegex(String alias) {
    return _aliasRegexCache.putIfAbsent(alias, () {
      final escaped = _escape(alias).replaceAll(RegExp(r'\s+'), r'\s+');
      // Bounded by non-alphanumeric so "MCH" never matches inside "MCHC" and
      // "Hb" never matches inside "HbA1c".
      return RegExp('(?<![A-Za-z0-9])$escaped(?![A-Za-z0-9])',
          caseSensitive: false);
    });
  }

  static _LabelMatch? _matchParameter(String line) {
    _LabelMatch? best;
    for (final param in parameters) {
      for (final alias in param.aliases) {
        final m = _aliasRegex(alias).firstMatch(line);
        if (m == null) continue;
        final len = m.end - m.start;
        if (best == null ||
            len > best.length ||
            (len == best.length && m.start < best.start)) {
          best = _LabelMatch(param, m.start, m.end, len);
        }
      }
    }
    if (best == null) return null;

    // If an ignore-label matches more specifically (longer) than the best
    // tracked alias, this row belongs to a different parameter → skip it.
    for (final alias in ignoreAliases) {
      final m = _aliasRegex(alias).firstMatch(line);
      if (m == null) continue;
      final len = m.end - m.start;
      if (len > best.length || (len == best.length && m.start <= best.start)) {
        return null;
      }
    }
    return best;
  }

  // ----- value extraction ----------------------------------------------------

  static final RegExp _rangeRe = RegExp(
      r'\d+(?:\.\d+)?\s*(?:[-–—]|to)\s*\d+(?:\.\d+)?',
      caseSensitive: false);
  static final RegExp _cmpRe = RegExp(r'[<>]\s*=?\s*\d+(?:\.\d+)?');
  static final RegExp _numRe = RegExp(r'\d+(?:\.\d+)?');

  /// Standalone number candidates in reading order, excluding reference ranges
  /// (`a - b`, `< a`) and scientific-notation units (`10^12`). The caller picks
  /// the first physiologically plausible one.
  static List<double> _extractCandidates(String s) {
    final excluded = <List<int>>[];
    for (final m in _rangeRe.allMatches(s)) {
      excluded.add([m.start, m.end]);
    }
    for (final m in _cmpRe.allMatches(s)) {
      excluded.add([m.start, m.end]);
    }

    final out = <double>[];
    for (final m in _numRe.allMatches(s)) {
      final inExcluded =
          excluded.any((e) => m.start >= e[0] && m.start < e[1]);
      if (inExcluded) continue;

      final token = m.group(0)!;
      // Skip the "10" in exponent units like 10^12/L or 10e9/L.
      if (token == '10' && m.end < s.length) {
        final next = s[m.end];
        if (next == '^' || next == 'e' || next == 'E') continue;
      }
      // Skip a number sitting on an exponent caret.
      if (m.start > 0 && s[m.start - 1] == '^') continue;

      final v = double.tryParse(token);
      if (v != null) out.add(v);
    }
    return out;
  }

  /// Range-check a candidate, with a conservative lost-decimal rescue.
  static double? _accept(CbcParameter p, double v) {
    if (v >= p.min && v <= p.max) return v;
    // OCR sometimes drops a decimal point: 442 -> 44.2, 882 -> 88.2. Only rescue
    // 3-digit integer reads: a 2-digit over-range value (e.g. RBC "10") is far
    // more likely a genuine misread than a lost decimal, so reject it rather
    // than fabricate 1.0. A value with a fractional part (9.2) is never rescued.
    if (v > p.max && v == v.roundToDouble() && v >= 100) {
      final divided = v / 10.0;
      if (divided >= p.min && divided <= p.max) return divided;
    }
    return null;
  }

  // ----- helpers -------------------------------------------------------------

  /// Convert letters commonly confused with digits back to digits, but only
  /// inside tokens that already look numeric (contain a digit). This never
  /// touches pure-letter units like "g/dL", "fL" or "pg".
  static String _fixDigits(String s) {
    return s.replaceAllMapped(
      RegExp(r'[0-9OolI]*[0-9][0-9OolI.,]*'),
      (m) {
        var t = m.group(0)!;
        if (!RegExp(r'[OolI]').hasMatch(t)) return t;
        return t
            .replaceAll('O', '0')
            .replaceAll('o', '0')
            .replaceAll('l', '1')
            .replaceAll('I', '1');
      },
    );
  }

  static String _escape(String s) {
    return s.replaceAllMapped(
        RegExp(r'[.*+?^${}()|[\]\\/-]'), (m) => '\\${m.group(0)}');
  }
}

class _LabelMatch {
  final CbcParameter parameter;
  final int start;
  final int end;
  final int length;
  _LabelMatch(this.parameter, this.start, this.end, this.length);
}
