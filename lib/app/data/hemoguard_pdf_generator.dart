import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Dependency-free, one-page PDF 1.4 generator for HemoGuard's clinical summary.
/// Does not change the prediction model or upload any scanned photograph.
/// Patient names outside WinAnsi/Latin-1 require a bundled Unicode font in a
/// future full PDF package integration; here they are transliterated safely.
class HemoGuardPdfGenerator {
  HemoGuardPdfGenerator._();
  static Future<File> generate(Map<String,dynamic> report,{String? patientPublicId}) async {
    final id=report['id']?.toString()??'unknown';
    final publicId=patientPublicId??report['public_id']?.toString()??'unassigned';
    final cbc=Map<String,dynamic>.from(report['cbc'] as Map);
    final prediction=Map<String,dynamic>.from(report['prediction'] as Map);
    final lines=<String>[
      'HEMOGUARD | CBC SCREENING REPORT',
      'Patient: ${report['patient_name_snapshot']??'Unknown'}',
      'Patient ID: $publicId',
      'Age at test: ${report['patient_age_at_test']??'Not provided'}    Sex: ${report['patient_sex_at_test']??'unknown'}',
      'Laboratory / individual: ${report['account_name_snapshot']??''}',
      'Sample date: ${report['sample_date']??'Not provided'}',
      'Laboratory report number: ${report['source_report_number']??'Not provided'}',
      'Completed (UTC): ${report['created_at']??''}',
      '', 'CBC MEASUREMENTS',
      'Hemoglobin (g/dL): ${cbc['hemoglobin']}',
      'RBC (million/cmm): ${cbc['rbc']}',
      'Hematocrit (%): ${cbc['hematocrit']}',
      'MCV (fL): ${cbc['mcv']}',
      'MCH (pg): ${cbc['mch']}',
      'MCHC (g/dL): ${cbc['mchc']}',
      'RDW-CV (%): ${cbc['rdw_cv']}',
      '', 'AI-ASSISTED SCREENING',
      prediction['is_thalassemia']==true?'Thalassemia indicators detected':'No thalassemia indicators detected',
      'Model version: ${prediction['model_version']??''}',
      'Result probability: ${((prediction['probability'] as num?)??0).toDouble().toStringAsFixed(4)}',
      '', 'PATIENT CONSENT',
      'Operator attestation recorded (not a patient signature).',
      'Consent reference: ${report['consent_id']??''}',
      '', 'Screening aid only - NOT a diagnostic test.',
      'Report ID: $id',
    ];
    final stream=StringBuffer();
    stream.writeln('0.09 0.52 0.30 rg 45 743 505 43 re f');
    stream.writeln('1 1 1 rg');
    stream.writeln('BT /F1 17 Tf 57 759 Td (${_pdfText(lines[0])}) Tj ET');
    stream.writeln('0.12 0.17 0.16 rg');
    double y=724;
    for(var i=1;i<lines.length;i++) {
      final line=lines[i];
      if(line.isEmpty) { y-=9;continue; }
      if(i==9 || i==18 || i==23) {
        stream.writeln('0.09 0.52 0.30 rg');
        stream.writeln('BT /F1 11 Tf 55 ${y.toStringAsFixed(1)} Td (${_pdfText(line)}) Tj ET');
        stream.writeln('0.12 0.17 0.16 rg');
      } else {
        stream.writeln('BT /F1 10 Tf 55 ${y.toStringAsFixed(1)} Td (${_pdfText(line)}) Tj ET');
      }
      y-=19;
    }
    final content=latin1.encode(stream.toString());
    final objects=<List<int>>[
      latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'),
      latin1.encode('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
      latin1.encode('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>'),
      [...latin1.encode('<< /Length ${content.length} >>\nstream\n'),...content,...latin1.encode('endstream')],
      latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'),
    ];
    final result=<int>[];
    void write(String data)=>result.addAll(latin1.encode(data));
    write('%PDF-1.4\n%HGPD\n');
    final offsets=<int>[0];
    for(var i=0;i<objects.length;i++) {
      offsets.add(result.length);
      write('${i+1} 0 obj\n');
      result.addAll(objects[i]);
      write('\nendobj\n');
    }
    final xref=result.length;
    write('xref\n0 ${objects.length+1}\n0000000000 65535 f \n');
    for(final offset in offsets.skip(1))write('${offset.toString().padLeft(10,'0')} 00000 n \n');
    write('trailer\n<< /Size ${objects.length+1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    final root=await getApplicationDocumentsDirectory();
    final dir=Directory('${root.path}/HemoGuardReports');
    await dir.create(recursive:true);
    final safeId=publicId.replaceAll(RegExp('[^a-zA-Z0-9-]'),'_');
    final safeReport=id.replaceAll(RegExp('[^a-zA-Z0-9-]'),'_');
    final file=File('${dir.path}/${safeId}_$safeReport.pdf');
    return file.writeAsBytes(result,flush:true);
  }
  static String _pdfText(String text) {
    final buffer=StringBuffer();
    for(final r in text.runes) {
      final c= r>=32 && r<=126 ? String.fromCharCode(r) :
        r>=160 && r<=255 ? String.fromCharCode(r) : '?';
      if(c=='\\' || c=='(' || c==')')buffer.write('\\');
      buffer.write(c);
    }
    return buffer.toString();
  }
}
