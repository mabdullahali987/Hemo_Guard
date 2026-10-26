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
function activeAccount(id) {
  const u = core.userById(id);
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
function startConsent(accountId,input) {
  activeAccount(accountId);
  if (input?.accepted !== true || input?.version !== CONSENT_VERSION) fail('Read and confirm the current consent statement');
  const id = randomUUID(), at = now();
  const expires = new Date(Date.now()+30*60*1000).toISOString();
  db.prepare(`INSERT INTO consent_intents(id,account_id,consent_version,method,accepted_at,expires_at)
              VALUES(?,?,?,'operator_checkbox',?,?)`).run(id,accountId,CONSENT_VERSION,at,expires);
  core.audit(accountId,accountId,'patient.consent_attested',{intent_id:id,consent_version:CONSENT_VERSION});
  return { consent_intent_id:id, expires_at:expires };
}
function matchPatient(accountId,input) {
  activeAccount(accountId);
  const p=person(input);
  let matched=null, candidates=[];
  if (p.publicId) {
    matched=db.prepare('SELECT id,public_id,name,age_at_registration,sex FROM patients WHERE account_id=? AND public_id=?').get(accountId,p.publicId) || null;
    if (!matched) fail('Patient ID not found in your account',404);
    // A typed/scanned ID needs explicit confirmation if demographics conflict.
    if (nameKey(matched.name)!==p.name_key) candidates=[matched];
  } else if (p.labNumber) {
    matched=db.prepare('SELECT id,public_id,name,age_at_registration,sex FROM patients WHERE account_id=? AND lab_patient_number=?').get(accountId,p.labNumber) || null;
    if (matched && nameKey(matched.name)!==p.name_key) candidates=[matched];
  }
  if (!matched) candidates=db.prepare(`SELECT id,public_id,name,age_at_registration,sex FROM patients
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
function serialize(r) {
  if (!r) return null;
  return {...r,cbc:JSON.parse(r.cbc_json),prediction:JSON.parse(r.prediction_json),cbc_json:undefined,prediction_json:undefined};
}
function createUniquePatientId() {
  // 80 bits random to make guessing and collisions impractical; verify UNIQUE in SQLite.
  return 'HG-P-'+randomBytes(10).toString('hex').toUpperCase();
}
function finalize(accountId,input) {
  const user=activeAccount(accountId);
  if (!input || typeof input !== 'object') fail('Report information missing');
  const p=person(input.patient);
  const cbc=validateCbc(input.cbc);
  const prediction=validatePrediction(input.prediction);
  const consentId=safe(input.consent_intent_id,80);
  const authId=safe(input.authorization_id,80);
  const requestId=safe(input.request_id,100) || null;
  const existingId=safe(input.existing_patient_id,80) || null;
  const reportNumber=optionalReference(input.source_report_number);
  const sampleDate=optionalReference(input.sample_date);
  if (sampleDate && (!/^\d{4}-\d{2}-\d{2}$/.test(sampleDate) || Number.isNaN(Date.parse(sampleDate+'T00:00:00Z')))) fail('Use YYYY-MM-DD for sample date');
  return db.transaction(() => {
    const old=requestId
      ? db.prepare('SELECT * FROM clinical_reports WHERE client_request_id=? AND account_id=?').get(requestId,accountId)
      : db.prepare('SELECT * FROM clinical_reports WHERE authorization_id=? AND account_id=?').get(authId,accountId);
    if (old) return { already_recorded:true,report:serialize(old),patient:db.prepare('SELECT * FROM patients WHERE id=?').get(old.patient_id) };
    const authorization=db.prepare('SELECT * FROM reports WHERE id=? AND user_id=?').get(authId,accountId);
    if (!authorization) fail('Report authorization not found',404);
    if (authorization.completed_at) fail('This authorization was completed without a clinical record',409);
    if (authorization.expires_at<=now()) fail('Report authorization expired. Analyze again',403);
    const intent=db.prepare('SELECT * FROM consent_intents WHERE id=? AND account_id=?').get(consentId,accountId);
    if (!intent || intent.consumed_at || intent.expires_at<=now() || intent.consent_version!==CONSENT_VERSION) fail('Consent confirmation missing or expired; reconfirm before scanning',403);
    let patient;
    if (existingId) {
      patient=db.prepare('SELECT * FROM patients WHERE id=? AND account_id=?').get(existingId,accountId);
      if (!patient) fail('Patient not found in your account',404);
      // Preserve prior demographic snapshots; only change with a separate audited correction.
      if (p.publicId && p.publicId !== patient.public_id) fail('Patient ID does not match selected record',409);
    } else {
      if (p.publicId) fail('Select the matched HemoGuard patient or clear the old ID for a new patient',409);
      // Prevent unintentional duplicate profiles for a verified lab identifier.
      if (p.labNumber && db.prepare('SELECT id FROM patients WHERE account_id=? AND lab_patient_number=?').get(accountId,p.labNumber))
        fail('Patient already exists for this laboratory identifier; select the existing record',409);
      const pid=randomUUID(), patientPublicId=createUniquePatientId(), time=now();
      db.prepare(`INSERT INTO patients(id,public_id,account_id,name,name_key,age_at_registration,sex,lab_patient_number,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?)`).run(pid,patientPublicId,accountId,p.name,p.name_key,p.age,p.sex,p.labNumber,time,time);
      patient=db.prepare('SELECT * FROM patients WHERE id=?').get(pid);
    }
    if (reportNumber && db.prepare(`SELECT id FROM clinical_reports WHERE account_id=? AND patient_id=? AND source_report_number=?`).get(accountId,patient.id,reportNumber))
      fail('This laboratory report is already saved for this patient; open history instead',409);
    const time=now(), patientConsentId=randomUUID(), rid=randomUUID();
    db.prepare(`INSERT INTO patient_consents(id,intent_id,patient_id,account_id,consent_version,method,recorded_at)
      VALUES(?,?,?,?,?,'operator_checkbox',?)`).run(patientConsentId,intent.id,patient.id,accountId,intent.consent_version,intent.accepted_at);
    db.prepare('UPDATE consent_intents SET consumed_at=? WHERE id=? AND consumed_at IS NULL').run(time,intent.id);
    db.prepare(`INSERT INTO clinical_reports(id,authorization_id,client_request_id,patient_id,account_id,account_name_snapshot,account_type_snapshot,
      patient_name_snapshot,patient_age_at_test,patient_sex_at_test,source_report_number,sample_date,cbc_json,prediction_json,consent_id,created_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(rid,authId,requestId,patient.id,accountId,user.display_name,user.account_type,
        p.name,p.age,p.sex,reportNumber,sampleDate,JSON.stringify(cbc),JSON.stringify(prediction),patientConsentId,time);
    db.prepare('UPDATE reports SET completed_at=? WHERE id=? AND completed_at IS NULL').run(time,authId);
    core.audit(accountId,accountId,'report.generated',{mode:authorization.mode,report_id:authId,clinical_report_id:rid,patient_id:patient.public_id});
    return {already_recorded:false, patient,report:serialize(db.prepare('SELECT * FROM clinical_reports WHERE id=?').get(rid))};
  })();
}
function listPatients(accountId,search='',limit=100) {
  activeAccount(accountId);
  const q=safe(search,100).replace(/[\\%_]/g, '\\$&');
  const rows=db.prepare(`SELECT p.id,p.public_id,p.name,p.age_at_registration,p.sex,p.created_at,
    COUNT(c.id) AS reports_count,MAX(c.created_at) AS last_report_at
    FROM patients p LEFT JOIN clinical_reports c ON c.patient_id=p.id
    WHERE p.account_id=? AND (?='' OR p.public_id LIKE ? ESCAPE '\\' OR p.name LIKE ? ESCAPE '\\')
    GROUP BY p.id ORDER BY COALESCE(MAX(c.created_at),p.created_at) DESC LIMIT ?`)
    .all(accountId,q,`%${q}%`,`%${q}%`,Math.min(100,Math.max(1,Number(limit)||50)));
  return {patients:rows};
}
function patientReports(accountId,id) {
  activeAccount(accountId);
  const patient=db.prepare('SELECT id,public_id,name,age_at_registration,sex,created_at FROM patients WHERE id=? AND account_id=?').get(id,accountId);
  if (!patient) fail('Patient not found',404);
  const rows=db.prepare('SELECT * FROM clinical_reports WHERE patient_id=? AND account_id=? ORDER BY created_at DESC,id DESC LIMIT 200').all(id,accountId).map(serialize);
  core.audit(accountId,accountId,'patient.history_viewed',{patient_id:patient.public_id});
  return {patient,reports:rows};
}
function reportDetail(actorId,id,admin=false) {
  const actor=core.userById(actorId);
  if (!actor) fail('Not signed in',401);
  if (!admin) activeAccount(actorId);
  if (admin && actor.account_type!=='superadmin') fail('Superadmin required',403);
  const report=db.prepare(`SELECT c.*,p.public_id FROM clinical_reports c JOIN patients p ON p.id=c.patient_id
    WHERE c.id=? ${admin?'':'AND c.account_id=?'}`).get(...(admin?[id]:[id,actorId]));
  if (!report) fail('Report not found',404);
  core.audit(actorId,report.account_id,'patient.report_viewed',{clinical_report_id:id,admin});
  const consent=db.prepare('SELECT id,consent_version,method,recorded_at FROM patient_consents WHERE id=?').get(report.consent_id);
  return {report:serialize(report),consent};
}
function adminReports(adminId,limit=100,offset=0) {
  const actor=core.userById(adminId);
  if (!actor || actor.account_type!=='superadmin') fail('Superadmin required',403);
  const take=Math.max(1,Math.min(200,Number(limit)||100));
  const skip=Math.max(0,Math.floor(Number(offset)||0));
  const reports=db.prepare(`SELECT c.id,c.patient_name_snapshot,c.created_at,c.sample_date,c.account_id,
    c.account_name_snapshot,c.account_type_snapshot,c.patient_age_at_test,p.public_id,r.mode
    FROM clinical_reports c JOIN patients p ON p.id=c.patient_id JOIN reports r ON r.id=c.authorization_id
    ORDER BY c.created_at DESC,c.rowid DESC LIMIT ? OFFSET ?`).all(take,skip);
  const total=db.prepare('SELECT COUNT(*) AS count FROM clinical_reports').get().count;
  core.audit(adminId,adminId,'patient.admin_list_viewed',{limit:take,offset:skip});
  return {reports,total,limit:take,offset:skip};
}
module.exports={consentCurrent,startConsent,matchPatient,finalize,listPatients,patientReports,reportDetail,adminReports};
