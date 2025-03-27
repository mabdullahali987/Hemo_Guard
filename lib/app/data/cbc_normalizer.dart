/// Normalizes raw OCR text before it reaches the CBC parser: fixes comma
/// decimal separators, common O/0 and l/1 confusions, strips non-printable
/// stray characters and collapses runs of whitespace.
class CbcNormalizer {
  static String normalize(String raw) {
    return raw
        .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}')
        .replaceAllMapped(
            RegExp(r'\b[Oo](?=\d)|(?<=\d)[Oo]\b'), (_) => '0')
        .replaceAll(RegExp(r'[^\x20-\x7E\n]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }
}
