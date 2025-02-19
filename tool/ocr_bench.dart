// Offline harness: measures value recall when MERGING the parser results across
// all OCR variants of an image (raw + improved preprocessing, multiple PSM),
// vs the current pick-one-best strategy. Not shipped.
import 'dart:io';
import 'package:hemo_guard/app/data/cbc_parser.dart';

Map<String, List<File>> byImage(List<String> dirs) {
  final map = <String, List<File>>{};
  for (final dir in dirs) {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      if (!f.path.endsWith('.txt')) continue;
      final id = f.uri.pathSegments.last.split('_').first;
      (map[id] ??= []).add(f);
    }
  }
  return map;
}

void main() {
  final map = byImage(['/tmp/ocr', '/tmp/ocr2']);
  final ids = map.keys.toList()..sort();
  var bestTot = 0, mergedTot = 0, bestEmpty = 0, mergedEmpty = 0;

  for (final id in ids) {
    var best = 0;
    final merged = <String, double>{};
    for (final f in map[id]!) {
      final parsed = CbcParser.parse(f.readAsStringSync());
      if (parsed.length > best) best = parsed.length;
      parsed.forEach((k, v) => merged.putIfAbsent(k, () => v));
    }
    bestTot += best;
    mergedTot += merged.length;
    if (best == 0) bestEmpty++;
    if (merged.isEmpty) mergedEmpty++;
    final flag = merged.length > best ? '  ↑+${merged.length - best}' : '';
    print('img $id   pick-best=$best/7   MERGED=${merged.length}/7$flag');
  }
  print('----');
  print('TOTAL values  pick-best=$bestTot  MERGED=$mergedTot');
  print('EMPTY images  pick-best=$bestEmpty  MERGED=$mergedEmpty  (of ${ids.length}, img18 is a blank template)');
}
