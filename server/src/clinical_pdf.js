'use strict';
// Small dependency-free PDF export for restricted admin report downloads.
// Actual record comes from the same auditable, authenticated detail accessor.
const latin = s => Buffer.from([...String(s)].map(ch => {
  const cp=ch.codePointAt(0); const c=cp>=32&&cp<=255?ch:'?';
  return c==='('||c===')'||c==='\\'?`\\${c}`:c;
}).join(''),'latin1');
function makePdf(report) {
  const cbc=report.cbc,p=report.prediction;
  const lines=[
    'HEMOGUARD | CLINICAL SCREENING REPORT',
    `Patient: ${report.patient_name_snapshot}`,
    `Patient ID: ${report.public_id}`,
    `Age: ${report.patient_age_at_test??'N/A'}  Sex: ${report.patient_sex_at_test}`,
    `Originating account: ${report.account_name_snapshot} (${report.account_type_snapshot})`,
    `Completed (UTC): ${report.created_at}`,
    `Sample date: ${report.sample_date||'Not provided'}`,
    `Source report reference: ${report.source_report_number||'Not provided'}`,
    '', 'CBC MEASUREMENTS',
    `Hemoglobin (g/dL): ${cbc.hemoglobin}`,`RBC (mil/cmm): ${cbc.rbc}`,
    `Hematocrit (%): ${cbc.hematocrit}`,`MCV (fL): ${cbc.mcv}`,
    `MCH (pg): ${cbc.mch}`,`MCHC (g/dL): ${cbc.mchc}`,`RDW-CV (%): ${cbc.rdw_cv}`,
    '', 'AI-ASSISTED SCREENING',
    p.is_thalassemia?'Thalassemia indicators detected':'No thalassemia indicators detected',
    `Model: ${p.model_version}`,
    '', 'CONSENT RECORD',
    'Laboratory/individual operator confirmed patient permission.',
    'Operator attestation only - not an independent patient signature.',
    `Consent ID: ${report.consent_id}`,
    '', 'Screening aid only - NOT a diagnosis.',
    `Report ID: ${report.id}`,
  ];
  const content=[];
  content.push('0.10 0.47 0.35 rg 45 747 505 43 re f\n1 1 1 rg\n');
  content.push('BT /F1 16 Tf 55 765 Td (',latin(lines[0]),') Tj ET\n0.1 0.15 0.13 rg\n');
  let y=728;
  lines.slice(1).forEach(line=>{
    if(!line){y-=8;return;}
    content.push(`BT /F1 10 Tf 55 ${y} Td (`,latin(line),') Tj ET\n');
    y-=19;
  });
  const bytes=Buffer.concat(content.map(c=>Buffer.isBuffer(c)?c:Buffer.from(c,'latin1')));
  const objs=[
    Buffer.from('<< /Type /Catalog /Pages 2 0 R >>'),
    Buffer.from('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
    Buffer.from('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>'),
    Buffer.concat([Buffer.from(`<< /Length ${bytes.length} >>\nstream\n`),bytes,Buffer.from('\nendstream')]),
    Buffer.from('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'),
  ];
  const chunks=[Buffer.from('%PDF-1.4\n')];
  let size=chunks[0].length;
  const offsets=[0];
  for(let i=0;i<objs.length;i++){
    offsets.push(size);
    const obj=Buffer.concat([Buffer.from(`${i+1} 0 obj\n`),objs[i],Buffer.from('\nendobj\n')]);
    chunks.push(obj);size+=obj.length;
  }
  const xref=size;
  const refs=offsets.slice(1).map(offset=>`${String(offset).padStart(10,'0')} 00000 n \n`).join('');
  chunks.push(Buffer.from(`xref\n0 ${objs.length+1}\n0000000000 65535 f \n${refs}trailer\n<< /Size ${objs.length+1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`));
  return Buffer.concat(chunks);
}
module.exports={makePdf};
