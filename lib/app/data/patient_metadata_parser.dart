/// Reads only explicitly-labelled demographics and laboratory identifiers.
/// Missing/uncertain fields remain empty for operator correction. Never infer
/// patient identity from CBC numeric columns or manufacture demographics.
class PatientMetadataParser {
  static Map<String, String> parse(String text) {
    final result = <String, String>{
      'name': '', 'age_at_test': '', 'sex': 'unknown',
      'lab_patient_number': '', 'public_id': '',
      'source_report_number': '', 'sample_date': '',
    };
    final lines = text.replaceAll('\r', '').split('\n');
    String? extract(RegExp re) {
      for (final line in lines) {
        final match = re.firstMatch(line.trim());
        if (match != null) {
          final value = match.group(1)?.trim() ?? '';
          if (value.isNotEmpty) return value;
        }
      }
      return null;
    }
    // Require a clear label. OCR often places numeric table labels nearby.
    final name = extract(RegExp(r'^(?:patient\s*name|name\s*of\s*patient|name)\s*[:\-]\s*([A-Za-z][A-Za-z .\x27-]{1,100})\s*$', caseSensitive:false));
    if (name != null) result['name'] = name.replaceAll(RegExp(r'\s+'), ' ');
    final age = extract(RegExp(r'^(?:patient\s*age|age)\s*[:\-]\s*(\d{1,3})(?:\s*(?:y|yrs|years))?\b',caseSensitive:false));
    if (age != null && int.tryParse(age) != null && int.parse(age) <= 125) result['age_at_test'] = age;
    final sex = extract(RegExp(r'^(?:sex|gender)\s*[:\-]\s*(male|female|m|f|other)\b',caseSensitive:false))?.toLowerCase();
    if (sex == 'male' || sex == 'm') result['sex'] = 'male';
    if (sex == 'female' || sex == 'f') result['sex'] = 'female';
    if (sex == 'other') result['sex'] = 'other';
    final hgId=RegExp(r'\bHG-P-[A-Z0-9]{6,20}\b',caseSensitive:false).firstMatch(text)?.group(0);
    if (hgId != null) result['public_id'] = hgId.toUpperCase();
    // Lab's stable *patient* number is different from one-time sample/report ID.
    result['lab_patient_number'] = extract(RegExp(r'^(?:lab\s*patient\s*(?:id|number)|patient\s*(?:id|no\.?|number)|mrn)\s*[:#\-]\s*([A-Za-z0-9/-]{3,45})\s*$',caseSensitive:false)) ?? '';
    result['source_report_number'] = extract(RegExp(r'^(?:report\s*(?:id|no\.?|number)|accession\s*(?:id|no\.?|number)|sample\s*(?:id|no\.?|number))\s*[:#\-]\s*([A-Za-z0-9/-]{3,65})\s*$',caseSensitive:false)) ?? '';
    final date=extract(RegExp(r'^(?:sample\s*date|collected\s*(?:on|date)|collection\s*date)\s*[:\-]\s*(\d{4}-\d{2}-\d{2}|\d{1,2}[/-]\d{1,2}[/-]\d{4})',caseSensitive:false));
    if (date != null) {
      if (RegExp(r'^\d{4}-').hasMatch(date)) result['sample_date']=date;
      else {
        final parts=date.split(RegExp(r'[/-]'));
        if (parts.length==3) result['sample_date']='${parts[2]}-${parts[1].padLeft(2,'0')}-${parts[0].padLeft(2,'0')}';
      }
    }
    return result;
  }
}
