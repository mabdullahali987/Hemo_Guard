'use strict';
// Patient records are account-scoped. Only superadmin can query across accounts.
// Consent is an authenticated operator attestation, NOT a patient signature.
const { randomUUID, randomBytes } = require('node:crypto');
const db = require('./db');
const core = require('./core');
const { accessState } = require('./time');
const CONSENT_VERSION = 'clinical-screening-storage-v1';
const CONSENT_TEXT = 'I confirm the patient or their authorized representative has been informed and has agreed to HemoGuard using the CBC report for AI-assisted screening and securely retaining the patient record for authorized future reference. This confirmation is a laboratory/operator attestation, not a patient signature. Research or model-training permission is not included.';
const fail = core.fail;
const now = core.now;
async function activeAccount(id) {
  const u = await core.userById(id);
  if (!u || u.account_type === 'superadmin' || accessState(u) !== 'active') fail('Active laboratory or individual access is required',403);
  return u;
}
const safe = (v,max=120) => typeof v === 'string' ? v.trim().slice(0,max) : '';
const nameKey = s => s.trim().replace(/\s+/g,' ').toLocaleLowerCase('en-US');
function person(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) fail('Patient details are required');
  const name = safe(input.name);
  if (name.length < 2 || name.length > 120) fail('Enter a patient name (2–120 characters)');
  const rawAge = input.age_at_test;
  const age = rawAge === null || rawAge === '' || rawAge === undefined ? null : Number(rawAge);
  if (age !== null && (!Number.isInteger(age) || age < 0 || age > 125)) fail('Age must be 0–125 years');
  const sex = safe(input.sex,20).toLowerCase() || 'unknown';
  if (!['male','female','other','unknown'].includes(sex)) fail('Invalid patient sex');
  const labNumber = safe(input.lab_patient_number,80) || null;
  const publicId = safe(input.public_id,45).toUpperCase() || null;
  if (publicId && !/^HG-P-[A-Z0-9]{6,20}$/.test(publicId)) fail('Invalid HemoGuard ID');
  return { name, name_key:nameKey(name), age, sex, labNumber, publicId };
}
function optionalReference(v) {
  const s = safe(v,80);
  return s || null;
}
function consentCurrent() { return { version:CONSENT_VERSION, text:CONSENT_TEXT }; }
async function startConsent(accountId,input) {
  await activeAccount(accountId);
  if (input?.accepted !== true || input?.version !== CONSENT_VERSION) fail('Read and confirm the current consent statement');
  const id = randomUUID(), at = now();
  const expires = new Date(Date.now()+30*60*1000).toISOString();
  await db.prepare(`INSERT INTO consent_intents(id,account_id,consent_version,method,accepted_at,expires_at)
              VALUES(?,?,?,'operator_checkbox',?,?)`).run(id,accountId,CONSENT_VERSION,at,expires);
  await core.audit(accountId,accountId,'patient.consent_attested',{intent_id:id,consent_version:CONSENT_VERSION});
  return { consent_intent_id:id, expires_at:expires };
}
async function matchPatient(accountId,input) {
  await activeAccount(accountId);
  const p=person(input);
  let matched=null, candidates=[];
  if (p.publicId) {
    matched=await db.prepare('SELECT id,public_id,name,age_at_registration,sex FROM patients WHERE account_id=? AND public_id=?').get(accountId,p.publicId) || null;
    if (!matched) fail('Patient ID not found in your account',404);
    // A typed/scanned ID needs explicit confirmation if demographics conflict.
    if (nameKey(matched.name)!==p.name_key) candidates=[matched];
  } else if (p.labNumber) {
    matched=await db.prepare('SELECT id,public_id,name,age_at_registration,sex FROM patients WHERE account_id=? AND lab_patient_number=?').get(accountId,p.labNumber) || null;
    if (matched && nameKey(matched.name)!==p.name_key) candidates=[matched];
  }
  if (!matched) candidates=await db.prepare(`SELECT id,public_id,name,age_at_registration,sex FROM patients
    WHERE account_id=? AND name_key=? ORDER BY created_at DESC LIMIT 5`).all(accountId,p.name_key);
  return { verified: Boolean(matched && nameKey(matched.name)===p.name_key),
    matches: matched && !candidates.some(c=>c.id===matched.id) ? [matched,...candidates] : candidates };
}
const CBC_KEYS=['hemoglobin','rbc','hematocrit','mcv','mch','mchc','rdw_cv'];
function validateCbc(cbc) {
  if (!cbc || typeof cbc !== 'object' || Array.isArray(cbc)) fail('CBC measurements missing');
  const result={};
  for (const key of CBC_KEYS) {
    const value=cbc[key];
    if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0 || value > 1000) fail(`Invalid CBC value: ${key}`);
    result[key]=value;
  }
  return result;
}
function validatePrediction(p) {
  if (!p || typeof p !== 'object' || typeof p.is_thalassemia !== 'boolean' ||
      typeof p.probability !== 'number' || !Number.isFinite(p.probability) || p.probability<0 || p.probability>1 ||
      typeof p.raw_score !== 'number' || !Number.isFinite(p.raw_score)) fail('Invalid prediction result');
  const version = safe(p.model_version,60);
  if (!version) fail('Model version is required');
  return {is_thalassemia:p.is_thalassemia,probability:p.probability,raw_score:p.raw_score,model_version:version};
}
// Every response is filtered using the CURRENT account permission, not a client flag.
// A restricted account receives audit-safe metadata only, never CBC or predictions.
function serialize(r, visible = true) {
  if (!r) return null;
  const {cbc_json, prediction_json, ...meta} = r;
  if (!visible) {
    const {hematologist_carrier,hematologist_name,hematologist_notes,...safeMeta}=meta;
    return {...safeMeta, result_visible:false};
  }
  return {...meta, cbc:JSON.parse(cbc_json), prediction:JSON.parse(prediction_json), result_visible:true};
}
async function accountCanView(accountId) {
  const u = await core.userById(accountId);
  return Boolean(u && u.can_view_results === 1);
}
function createUniquePatientId() {
  // 80 bits random to make guessing and collisions impractical; verify UNIQUE in PostgreSQL.
  return 'HG-P-'+randomBytes(10).toString('hex').toUpperCase();
}
async function finalize(accountId,input) {
  const user=await activeAccount(accountId);
  if (!input || typeof input !== 'object') fail('Report information missing');
  const p=person(input.patient);
  // Explicit hematologist opinion is recorded separately from the AI result.
  const carrier=safe(input.hematologist_carrier,8).toLowerCase();
  if (!['yes','no'].includes(carrier)) fail('Select whether the hematologist considers the patient a carrier (Yes or No)');
  const hematologistName=safe(input.hematologist_name,120) || null;
  const hematologistNotes=safe(input.hematologist_notes,500) || null;
  if (p.age === null || p.sex === 'unknown') fail('Patient age and sex are required');
  const cbc=validateCbc(input.cbc);
  const prediction=validatePrediction(input.prediction);
  const consentId=safe(input.consent_intent_id,80);
  const authId=safe(input.authorization_id,80);
  const requestId=safe(input.request_id,100) || null;
  const existingId=safe(input.existing_patient_id,80) || null;
  const reportNumber=optionalReference(input.source_report_number);
  const sampleDate=optionalReference(input.sample_date);
  if (sampleDate && (!/^\d{4}-\d{2}-\d{2}$/.test(sampleDate) || Number.isNaN(Date.parse(sampleDate+'T00:00:00Z')))) fail('Use YYYY-MM-DD for sample date');
  try { return await db.transaction(async () => {
    const old=requestId
      ? await db.prepare('SELECT * FROM clinical_reports WHERE client_request_id=? AND account_id=?').get(requestId,accountId)
      : await db.prepare('SELECT * FROM clinical_reports WHERE authorization_id=? AND account_id=?').get(authId,accountId);
    if (old) return { already_recorded:true,result_visible:await accountCanView(accountId),
      report:serialize(old,await accountCanView(accountId)),patient:await db.prepare('SELECT * FROM patients WHERE id=?').get(old.patient_id) };
    const authorization=await db.prepare('SELECT * FROM reports WHERE id=? AND user_id=? FOR UPDATE').get(authId,accountId);
    if (!authorization) fail('Report authorization not found',404);
    if (authorization.completed_at) {
      // Another request may have finalized while this transaction waited for the row lock.
      // Return the original report on an exact retry; never create a second report.
      const committed=await db.prepare('SELECT * FROM clinical_reports WHERE authorization_id=? AND account_id=?').get(authId,accountId);
      if (committed && (!requestId || committed.client_request_id===requestId)) {
        const allowed=await accountCanView(accountId);
        return { already_recorded:true, result_visible:allowed, report:serialize(committed,allowed),
          patient:await db.prepare('SELECT * FROM patients WHERE id=?').get(committed.patient_id) };
      }
      fail('This authorization was completed without a matching clinical record',409);
    }
    if (authorization.expires_at<=now()) fail('Report authorization expired. Analyze again',403);
    const intent=await db.prepare('SELECT * FROM consent_intents WHERE id=? AND account_id=? FOR UPDATE').get(consentId,accountId);
    if (!intent || intent.consumed_at || intent.expires_at<=now() || intent.consent_version!==CONSENT_VERSION) fail('Consent confirmation missing or expired; reconfirm before scanning',403);
    let patient;
    if (existingId) {
      patient=await db.prepare('SELECT * FROM patients WHERE id=? AND account_id=?').get(existingId,accountId);
      if (!patient) fail('Patient not found in your account',404);
      // Preserve prior demographic snapshots; only change with a separate audited correction.
      if (p.publicId && p.publicId !== patient.public_id) fail('Patient ID does not match selected record',409);
    } else {
      if (p.publicId) fail('Select the matched HemoGuard patient or clear the old ID for a new patient',409);
      // Prevent unintentional duplicate profiles for a verified lab identifier.
      if (p.labNumber && await db.prepare('SELECT id FROM patients WHERE account_id=? AND lab_patient_number=?').get(accountId,p.labNumber))
        fail('Patient already exists for this laboratory identifier; select the existing record',409);
      const pid=randomUUID(), patientPublicId=createUniquePatientId(), time=now();
      await db.prepare(`INSERT INTO patients(id,public_id,account_id,name,name_key,age_at_registration,sex,lab_patient_number,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?)`).run(pid,patientPublicId,accountId,p.name,p.name_key,p.age,p.sex,p.labNumber,time,time);
      patient=await db.prepare('SELECT * FROM patients WHERE id=?').get(pid);
    }
    if (reportNumber && await db.prepare(`SELECT id FROM clinical_reports WHERE account_id=? AND patient_id=? AND source_report_number=?`).get(accountId,patient.id,reportNumber))
      fail('This laboratory report is already saved for this patient; open history instead',409);
    const time=now(), patientConsentId=randomUUID(), rid=randomUUID();
    await db.prepare(`INSERT INTO patient_consents(id,intent_id,patient_id,account_id,consent_version,method,recorded_at)
      VALUES(?,?,?,?,?,'operator_checkbox',?)`).run(patientConsentId,intent.id,patient.id,accountId,intent.consent_version,intent.accepted_at);
    await db.prepare('UPDATE consent_intents SET consumed_at=? WHERE id=? AND consumed_at IS NULL').run(time,intent.id);
    await db.prepare(`INSERT INTO clinical_reports(id,authorization_id,client_request_id,patient_id,account_id,account_name_snapshot,account_type_snapshot,
      patient_name_snapshot,patient_age_at_test,patient_sex_at_test,source_report_number,sample_date,cbc_json,prediction_json,consent_id,created_at,
      hematologist_carrier,hematologist_name,hematologist_notes)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(rid,authId,requestId,patient.id,accountId,user.display_name,user.account_type,
        p.name,p.age,p.sex,reportNumber,sampleDate,JSON.stringify(cbc),JSON.stringify(prediction),patientConsentId,time,
        carrier,hematologistName,hematologistNotes);
    // Attach evidence uploaded for this consent intent to this immutable report.
    await db.prepare('UPDATE clinical_attachments SET report_id=? WHERE consent_intent_id=? AND account_id=? AND report_id IS NULL')
      .run(rid,intent.id,accountId);
    await db.prepare('UPDATE reports SET completed_at=? WHERE id=? AND completed_at IS NULL').run(time,authId);
    await core.audit(accountId,accountId,'report.generated',{mode:authorization.mode,report_id:authId,clinical_report_id:rid,patient_id:patient.public_id});
    return {already_recorded:false, result_visible:await accountCanView(accountId),patient,
      report:serialize(await db.prepare('SELECT * FROM clinical_reports WHERE id=?').get(rid),await accountCanView(accountId))};
  }); } catch (e) {
    if (e.code === '23505') fail('A patient or report with this identifier already exists. Open patient history instead',409);
    throw e;
  }
}
async function listPatients(accountId,search='',limit=100) {
  await activeAccount(accountId);
  const q=safe(search,100).replace(/[\\%_]/g, '\\$&');
  const rows=await db.prepare(`SELECT p.id,p.public_id,p.name,p.age_at_registration,p.sex,p.created_at,
    COUNT(c.id) AS reports_count,MAX(c.created_at) AS last_report_at
    FROM patients p LEFT JOIN clinical_reports c ON c.patient_id=p.id
    WHERE p.account_id=? AND (?='' OR p.public_id ILIKE ? ESCAPE '\\' OR p.name ILIKE ? ESCAPE '\\')
    GROUP BY p.id ORDER BY COALESCE(MAX(c.created_at),p.created_at) DESC LIMIT ?`)
    .all(accountId,q,`%${q}%`,`%${q}%`,Math.min(100,Math.max(1,Number(limit)||50)));
  return {patients:rows};
}
async function patientReports(accountId,id) {
  await activeAccount(accountId);
  const patient=await db.prepare('SELECT id,public_id,name,age_at_registration,sex,created_at FROM patients WHERE id=? AND account_id=?').get(id,accountId);
  if (!patient) fail('Patient not found',404);
  const visible=await accountCanView(accountId);
  const rows=(await db.prepare('SELECT * FROM clinical_reports WHERE patient_id=? AND account_id=? ORDER BY created_at DESC,id DESC LIMIT 200').all(id,accountId))
    .map(r=>serialize(r,visible));
  await core.audit(accountId,accountId,'patient.history_viewed',{patient_id:patient.public_id});
  return {patient,reports:rows};
}
async function reportDetail(actorId,id,admin=false) {
  const actor=await core.userById(actorId);
  if (!actor) fail('Not signed in',401);
  if (!admin) await activeAccount(actorId);
  if (admin && actor.account_type!=='superadmin') fail('Superadmin required',403);
  const report=await db.prepare(`SELECT c.*,p.public_id,p.lab_patient_number FROM clinical_reports c JOIN patients p ON p.id=c.patient_id
    WHERE c.id=? ${admin?'':'AND c.account_id=?'}`).get(...(admin?[id]:[id,actorId]));
  if (!report) fail('Report not found',404);
  if (!admin && !await accountCanView(actorId)) fail('Result viewing is restricted by your administrator',403);
  await core.audit(actorId,report.account_id,'patient.report_viewed',{clinical_report_id:id,admin});
  const consent=await db.prepare('SELECT id,consent_version,method,recorded_at FROM patient_consents WHERE id=?').get(report.consent_id);
  const attachments=await db.prepare('SELECT id,kind,filename,mime_type,byte_length,uploaded_at FROM clinical_attachments WHERE report_id=? ORDER BY kind').all(id);
  return {report:serialize(report),consent,attachments};
}
async function adminReports(adminId,limit=100,offset=0) {
  const actor=await core.userById(adminId);
  if (!actor || actor.account_type!=='superadmin') fail('Superadmin required',403);
  const take=Math.max(1,Math.min(200,Number(limit)||100));
  const skip=Math.max(0,Math.floor(Number(offset)||0));
  const reports=await db.prepare(`SELECT c.id,c.patient_name_snapshot,c.created_at,c.sample_date,c.account_id,
    c.account_name_snapshot,c.account_type_snapshot,c.patient_age_at_test,p.public_id,r.mode
    FROM clinical_reports c JOIN patients p ON p.id=c.patient_id JOIN reports r ON r.id=c.authorization_id
    ORDER BY c.created_at DESC,c.id DESC LIMIT ? OFFSET ?`).all(take,skip);
  const total=(await db.prepare('SELECT COUNT(*) AS count FROM clinical_reports').get()).count;
  await core.audit(adminId,adminId,'patient.admin_list_viewed',{limit:take,offset:skip});
  return {reports,total,limit:take,offset:skip};
}
// Small, authenticated evidence uploads go to a private database table. Never return data to an ordinary account.
const MAX_EVIDENCE_BYTES=1200000;
function validatedEvidence(input) {
  const kind=safe(input?.kind,40);
  if (!['consent_document','electrophoresis'].includes(kind)) fail('Invalid document type');
  const mime=safe(input?.mime_type,70).toLowerCase();
  if (!['image/jpeg','image/png','image/webp','application/pdf'].includes(mime)) fail('Upload a JPEG, PNG, WebP or PDF document');
  const filename=safe(input?.filename,150).replace(/[\\/\x00-\x1f]/g,'_') || 'medical-document';
  const encoded=input?.data_base64;
  if (typeof encoded!=='string' || encoded.length>Math.ceil(MAX_EVIDENCE_BYTES*4/3)+32 || !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded))
    fail('Document is missing, invalid or too large (maximum 1.2 MB)');
  const data=Buffer.from(encoded,'base64');
  if (!data.length || data.length>MAX_EVIDENCE_BYTES || data.toString('base64')!==encoded) fail('Document encoding is invalid');
  const isPdf=data.subarray(0,5).toString('ascii')==='%PDF-';
  const isJpeg=data[0]===0xff&&data[1]===0xd8&&data[2]===0xff;
  const isPng=data.subarray(0,8).equals(Buffer.from('89504e470d0a1a0a','hex'));
  const isWebp=data.subarray(0,4).toString()==='RIFF' && data.subarray(8,12).toString()==='WEBP';
  if (!((mime==='application/pdf'&&isPdf)||(mime==='image/jpeg'&&isJpeg)||(mime==='image/png'&&isPng)||(mime==='image/webp'&&isWebp)))
    fail('Document content does not match its file type');
  return {kind,mime,filename,data};
}
async function uploadEvidence(accountId,intentId,input) {
  await activeAccount(accountId);
  const doc=validatedEvidence(input);
  const intent=await db.prepare('SELECT * FROM consent_intents WHERE id=? AND account_id=?').get(intentId,accountId);
  if (!intent || intent.consumed_at || intent.expires_at<=now()) fail('Confirm patient consent again before attaching documents',403);
  const existing=await db.prepare('SELECT id FROM clinical_attachments WHERE consent_intent_id=? AND kind=?').get(intentId,doc.kind);
  const id=existing?.id || randomUUID();
  if (existing) await db.prepare('UPDATE clinical_attachments SET filename=?,mime_type=?,byte_length=?,data=?,uploaded_at=? WHERE id=? AND account_id=? AND report_id IS NULL')
    .run(doc.filename,doc.mime,doc.data.length,doc.data,now(),id,accountId);
  else await db.prepare(`INSERT INTO clinical_attachments(id,account_id,consent_intent_id,kind,filename,mime_type,byte_length,data,uploaded_at)
    VALUES(?,?,?,?,?,?,?,?,?)`).run(id,accountId,intentId,doc.kind,doc.filename,doc.mime,doc.data.length,doc.data,now());
  await core.audit(accountId,accountId,'patient.evidence_uploaded',{kind:doc.kind,attachment_id:id});
  return {id,kind:doc.kind,filename:doc.filename};
}
async function adminEvidence(adminId,attachmentId) {
  const actor=await core.userById(adminId);
  if (!actor || actor.account_type!=='superadmin') fail('Superadmin required',403);
  const item=await db.prepare('SELECT * FROM clinical_attachments WHERE id=? AND report_id IS NOT NULL').get(attachmentId);
  if (!item) fail('Document not found',404);
  await core.audit(adminId,item.account_id,'patient.evidence_downloaded',{attachment_id:attachmentId,report_id:item.report_id});
  return item;
}
async function adminCsv(adminId) {
  const actor=await core.userById(adminId);
  if (!actor || actor.account_type!=='superadmin') fail('Superadmin required',403);
  const records=await db.prepare(`SELECT c.*,p.public_id,p.lab_patient_number,p.created_at AS patient_created_at,
    pc.method AS consent_method,pc.consent_version,pc.recorded_at AS consent_recorded_at,
    r.mode AS screening_mode
    FROM clinical_reports c JOIN patients p ON p.id=c.patient_id
    JOIN patient_consents pc ON pc.id=c.consent_id
    JOIN reports r ON r.id=c.authorization_id ORDER BY c.created_at DESC`).all();
  const attachments=await db.prepare(`SELECT report_id,kind,id,filename,mime_type,byte_length FROM clinical_attachments
    WHERE report_id IS NOT NULL`).all();
  const byReport=new Map();
  for (const a of attachments) {if (!byReport.has(a.report_id)) byReport.set(a.report_id,{}); byReport.get(a.report_id)[a.kind]=a;}
  const columns=['report_id','patient_id','patient_public_id','lab_patient_number','patient_name','patient_age_at_test',
    'patient_sex_at_test','hematologist_carrier','hematologist_name','hematologist_notes','account_id','account_name',
    'account_type','screening_mode','authorization_id','client_request_id','source_report_number','sample_date',
    'hemoglobin','rbc','hematocrit','mcv','mch','mchc','rdw_cv',
    'ai_is_thalassemia','ai_probability','ai_raw_score','ai_model_version',
    'consent_id','consent_method','consent_version','consent_recorded_at',
    'consent_document_id','consent_document_filename','consent_document_mime',
    'electrophoresis_id','electrophoresis_filename','electrophoresis_mime',
    'patient_created_at','report_created_at'];
  const cell=v=>{
    const text=v==null?'':String(v);
    // Prevent spreadsheet formula injection when CSV is opened in Excel / Sheets.
    const safeText=typeof v==='number'||typeof v==='boolean'?text:/^[\s]*[=+@-]/.test(text)?`'${text}`:text;
    return `"${safeText.replace(/"/g,'""')}"`;
  };
  const lines=[columns.map(cell).join(',')];
  for (const r of records) {
    const cbc=JSON.parse(r.cbc_json),model=JSON.parse(r.prediction_json),a=byReport.get(r.id)||{};
    const d=a.consent_document||{},e=a.electrophoresis||{};
    const data=[r.id,r.patient_id,r.public_id,r.lab_patient_number,r.patient_name_snapshot,r.patient_age_at_test,
      r.patient_sex_at_test,r.hematologist_carrier,r.hematologist_name,r.hematologist_notes,r.account_id,
      r.account_name_snapshot,r.account_type_snapshot,r.screening_mode,r.authorization_id,r.client_request_id,
      r.source_report_number,r.sample_date,...CBC_KEYS.map(k=>cbc[k]),model.is_thalassemia,model.probability,
      model.raw_score,model.model_version,r.consent_id,r.consent_method,r.consent_version,r.consent_recorded_at,
      d.id,d.filename,d.mime_type,e.id,e.filename,e.mime_type,r.patient_created_at,r.created_at];
    lines.push(data.map(cell).join(','));
  }
  await core.audit(adminId,adminId,'patient.csv_exported',{row_count:records.length});
  return '\uFEFF'+lines.join('\r\n')+'\r\n';
}
module.exports={consentCurrent,startConsent,matchPatient,finalize,listPatients,patientReports,reportDetail,adminReports,uploadEvidence,adminEvidence,adminCsv};
