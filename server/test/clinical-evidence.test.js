'use strict';
// Focused tests without external Supabase access or a native SQLite driver.
const test=require('node:test');
const assert=require('node:assert/strict');
const Module=require('node:module');
const load=Module._load;
const docs=[];
let csvRecord=null;
const patient={id:'u1',account_type:'lab',access_plan:'trial',plan_expires_at:'2999-01-01T00:00:00.000Z',is_active:1};
const admin={id:'admin',account_type:'superadmin'};
const sql={
  prepare(query) {return {
    async get(...args) {
      if(query.includes('FROM consent_intents')) return {id:'intent1',account_id:'u1',expires_at:'2999-01-01T00:00:00.000Z',consumed_at:null};
      if(query.includes('FROM clinical_attachments')) return docs.find(x=>x.consent_intent_id===args[0] && x.kind===args[1]);
    },
    async all() {
      if(query.includes('FROM clinical_reports c JOIN patients')) return csvRecord ? [csvRecord] : [];
      return [];
    },
    async run(...args) {
      if(query.includes('INSERT INTO clinical_attachments')) docs.push({id:args[0],account_id:args[1],consent_intent_id:args[2],kind:args[3]});
      return {changes:1};
    }
  }}
};
const core={userById:async id=>id==='admin'?admin:patient,audit:async()=>{},now:()=>new Date().toISOString(),fail:(msg,status)=>{const e=new Error(msg);e.status=status||400;throw e;}};
Module._load=function(name,parent,isMain) {
  if(parent?.filename?.endsWith('/src/clinical.js') && name==='./db')return sql;
  if(parent?.filename?.endsWith('/src/clinical.js') && name==='./core')return core;
  return load.apply(this,arguments);
};
const clinical=require('../src/clinical');
Module._load=load;
const png=Buffer.from('89504e470d0a1a0a1234567890','hex').toString('base64');
test('only valid image/PDF evidence is accepted; account-scoped consent is required',async()=>{
  await assert.rejects(()=>clinical.uploadEvidence('u1','intent1',{kind:'electrophoresis',mime_type:'application/pdf',filename:'fake.pdf',data_base64:png}),/content does not match/i);
  await assert.rejects(()=>clinical.uploadEvidence('u1','intent1',{kind:'wrong',mime_type:'image/png',filename:'ok.png',data_base64:png}),/Invalid document type/);
  const doc=await clinical.uploadEvidence('u1','intent1',{kind:'consent_document',mime_type:'image/png',filename:'consent.png',data_base64:png});
  assert.equal(doc.kind,'consent_document');
  assert.equal(docs.length,1);
});
test('admin CSV has column headings even with an empty reporting database',async()=>{
  const csv=await clinical.adminCsv('admin');
  assert.match(csv,/"patient_public_id"/);
  assert.match(csv,/"hematologist_carrier"/);
  assert.match(csv,/"ai_model_version"/);
  assert.match(csv,/"electrophoresis_filename"/);
});

test('CSV exports prediction, demographics, hematologist opinion, and protects spreadsheet formulas',async()=>{
  csvRecord={id:'r1',patient_id:'p1',public_id:'HG-P-TEST',lab_patient_number:'=HYPERLINK("bad")',
    patient_name_snapshot:'Jane Doe',patient_age_at_test:26,patient_sex_at_test:'female',
    hematologist_carrier:'no',hematologist_name:'Dr Demo',hematologist_notes:'Needs follow-up',
    account_id:'u1',account_name_snapshot:'Lab A',account_type_snapshot:'lab',screening_mode:'image',
    authorization_id:'auth',client_request_id:'req',source_report_number:'LAB-1',sample_date:'2026-10-30',
    cbc_json:JSON.stringify({hemoglobin:11,rbc:5,hematocrit:34,mcv:70,mch:21,mchc:30,rdw_cv:16}),
    prediction_json:JSON.stringify({is_thalassemia:true,probability:0.87,raw_score:1.9,model_version:'model-v1'}),
    consent_id:'c1',consent_method:'operator_checkbox',consent_version:'v1',consent_recorded_at:'2026-10-30',
    patient_created_at:'2026-10-30',created_at:'2026-10-30'};
  const csv=await clinical.adminCsv('admin');
  assert.match(csv,/HG-P-TEST/);
  assert.match(csv,/Dr Demo/);
  assert.match(csv,/model-v1/);
  assert.match(csv,/"'=HYPERLINK/);
  assert.match(csv,/"0.87"/);
  csvRecord=null;
});
