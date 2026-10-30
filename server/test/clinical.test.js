'use strict';
// Run with npm test on a platform with a working better-sqlite3 native build.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {randomUUID}=require('node:crypto');
const bcrypt=require('bcryptjs');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'hemoguard-patient-test-'));
process.env.DATABASE_PATH=path.join(dir,'test.sqlite');
process.env.NODE_ENV='test';
const core=require('../src/core');
const app=require('../src/server');
let server,origin,admin,adminId,lab,other,labId,otherId;
async function req(method,path,token,body) {
  const r=await fetch(origin+path,{method,headers:{...(token?{authorization:`Bearer ${token}`}:{}) , ...(body?{'content-type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});
  const raw=await r.text();return {status:r.status,data:raw?JSON.parse(raw):{}};
}
async function createLogin(name,email,type,canViewResults=false){
  const acc=await core.createUser({display_name:name,email,account_type:type,password:'secret-password-12345',access_plan:'trial',duration:30,unit:'days',can_view_results:canViewResults},adminId);
  const logged=await req('POST','/api/auth/login',null,{email,password:'secret-password-12345'});
  assert.equal(logged.status,200);return {id:acc.id,token:logged.data.token};
}
const patient={name:'Ahmed Ali',age_at_test:24,sex:'male',lab_patient_number:'CITY-92'};
const cbc={hemoglobin:11.2,rbc:5.8,hematocrit:35.4,mcv:65,mch:22.1,mchc:31.6,rdw_cv:16.8};
const prediction={is_thalassemia:true,probability:0.85,raw_score:1.73,model_version:'test-model-v1'};
async function save(token,existing,reportNo){
  const current=await req('GET','/api/consent/current',token);
  const consent=await req('POST','/api/consent/intents',token,{accepted:true,version:current.data.version});
  assert.equal(consent.status,201);
  const authorization=await req('POST','/api/reports/authorize',token,{mode:'image'});
  assert.equal(authorization.status,201);
  return req('POST','/api/clinical-reports/finalize',token,{
    authorization_id:authorization.data.authorization_id,request_id:randomUUID(),consent_intent_id:consent.data.consent_intent_id,
    existing_patient_id:existing||null,patient,hematologist_carrier:'yes',hematologist_name:'Dr Test',cbc,prediction,source_report_number:reportNo,sample_date:'2026-10-23'});
}
test.before(async()=>{
  const at=core.now();
  await core.db.prepare(`INSERT INTO users(id,display_name,email,account_type,password_hash,is_active,created_at,updated_at)
    VALUES(?,?,?,?,?,1,?,?)`).run(randomUUID(),'Administrator','admin-patients@test.invalid','superadmin',bcrypt.hashSync('admin-pass-12345',12),at,at);
  server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
  origin=`http://127.0.0.1:${server.address().port}`;
  const adminLogin=await req('POST','/api/auth/login',null,{email:'admin-patients@test.invalid',password:'admin-pass-12345'});
  admin=adminLogin.data.token;adminId=adminLogin.data.user.id;
  ({id:labId,token:lab}=await createLogin('City Laboratory','city@test.invalid','lab',true));
  ({id:otherId,token:other}=await createLogin('Other Clinic','other@test.invalid','person'));
});
test.after(async()=>{if(server)await new Promise(resolve=>server.close(resolve));await core.db.close();fs.rmSync(dir,{recursive:true,force:true});});
test('consent cannot be bypassed; automatic patient and first report are saved',async()=>{
  const current=await req('GET','/api/consent/current',lab);
  assert.equal(current.status,200);
  const declined=await req('POST','/api/consent/intents',lab,{accepted:false,version:current.data.version});
  assert.equal(declined.status,400);
  const matched=await req('POST','/api/patients/match',lab,patient);
  assert.deepEqual(matched.data.matches,[]);
  const saved=await save(lab,null,'LAB-CBC-001');
  assert.equal(saved.status,201,JSON.stringify(saved.data));
  assert.equal(saved.data.report.patient_name_snapshot,patient.name);
  assert.match(saved.data.patient.public_id,/^HG-P-[A-Z0-9]+$/);
  assert.equal(saved.data.report.cbc.mcv,65);
  assert.equal((await core.summary()).reports_total,1);
});
test('returning patient reuses ID; past reports are append-only',async()=>{
  const search=await req('POST','/api/patients/match',lab,patient);
  assert.equal(search.status,200);
  assert.equal(search.data.matches.length,1);
  assert.equal(search.data.verified,true);
  const id=search.data.matches[0].id;
  const before=await req('GET',`/api/patients/${id}/reports`,lab);
  assert.equal(before.data.reports.length,1);
  const saved=await save(lab,id,'LAB-CBC-002');
  assert.equal(saved.status,201,JSON.stringify(saved.data));
  assert.equal(saved.data.patient.id,id);
  const after=await req('GET',`/api/patients/${id}/reports`,lab);
  assert.equal(after.data.reports.length,2);
  assert.equal(after.data.reports[1].id,before.data.reports[0].id);
  assert.equal(after.data.reports[1].cbc.mcv,65);
  assert.equal((await core.summary()).reports_total,2);
  const duplicate=await save(lab,id,'LAB-CBC-002');
  assert.equal(duplicate.status,409);
  assert.equal((await core.summary()).reports_total,2);
});
test('other accounts cannot read patient records or clinical details',async()=>{
  const owned=await req('GET','/api/patients',lab);
  const id=owned.data.patients[0].id;
  const history=await req('GET',`/api/patients/${id}/reports`,lab);
  const reportId=history.data.reports[0].id;
  assert.equal((await req('GET','/api/patients',other)).data.patients.length,0);
  assert.equal((await req('GET',`/api/patients/${id}/reports`,other)).status,404);
  assert.equal((await req('GET',`/api/clinical-reports/${reportId}`,other)).status,404);
  assert.equal((await req('GET','/api/admin/clinical-reports',other)).status,403);
  assert.equal((await req('POST','/api/patients/match',other,{...patient,public_id:owned.data.patients[0].public_id})).status,404);
});
test('superadmin can see originating account and download patient PDF',async()=>{
  const index=await req('GET','/api/admin/clinical-reports',admin);
  assert.equal(index.status,200);
  assert.equal(index.data.total,2);
  const r=index.data.reports[0];
  assert.equal(r.account_id,labId);
  assert.equal(r.account_name_snapshot,'City Laboratory');
  const detail=await req('GET',`/api/admin/clinical-reports/${r.id}`,admin);
  assert.equal(detail.status,200);
  assert.equal(detail.data.report.cbc.hemoglobin,11.2);
  assert.equal(detail.data.consent.method,'operator_checkbox');
  const response=await fetch(`${origin}/api/admin/clinical-reports/${r.id}/pdf`,{headers:{authorization:`Bearer ${admin}`}});
  assert.equal(response.status,200);
  assert.equal(response.headers.get('content-type'),'application/pdf');
  assert.equal(Buffer.from(await response.arrayBuffer()).subarray(0,8).toString(),'%PDF-1.4');
  const audit=await req('GET','/api/admin/audit',admin);
  assert.ok(audit.data.events.some(e=>e.action==='patient.report_viewed'));
});

test('admin-only reports stay saved and hidden until superadmin grants viewing rights',async()=>{
  const secret=await createLogin('Restricted Lab','restricted@test.invalid','lab');
  const me=await req('GET','/api/auth/me',secret.token);
  assert.equal(me.data.user.can_view_results,false);
  const saved=await save(secret.token,null,'SEC-CBC-001');
  assert.equal(saved.status,201,JSON.stringify(saved.data));
  assert.equal(saved.data.result_visible,false);
  assert.equal(saved.data.report.result_visible,false);
  assert.equal('prediction' in saved.data.report,false);
  assert.equal('cbc' in saved.data.report,false);
  const owned=await req('GET','/api/patients',secret.token);
  assert.equal(owned.data.patients[0].reports_count,1);
  const patientId=owned.data.patients[0].id;
  const first=await req('GET',`/api/patients/${patientId}/reports`,secret.token);
  assert.equal(first.status,200);
  assert.equal(first.data.reports.length,1);
  assert.equal(first.data.reports[0].result_visible,false);
  assert.equal('prediction' in first.data.reports[0],false);
  assert.equal('cbc' in first.data.reports[0],false);
  assert.equal((await req('GET',`/api/clinical-reports/${saved.data.report.id}`,secret.token)).status,403);
  assert.equal((await req('PATCH',`/api/admin/users/${secret.id}`,secret.token,{can_view_results:true})).status,403);
  const adminReport=await req('GET',`/api/admin/clinical-reports/${saved.data.report.id}`,admin);
  assert.equal(adminReport.data.report.prediction.is_thalassemia,true);
  const user=core.publicUser(await core.userById(secret.id));
  const input={display_name:user.display_name,email:user.email,account_type:user.account_type,is_active:true,can_view_results:true};
  const allowed=await req('PATCH',`/api/admin/users/${secret.id}`,admin,input);
  assert.equal(allowed.status,200,JSON.stringify(allowed.data));
  assert.equal(allowed.data.user.can_view_results,true);
  const visible=await req('GET',`/api/patients/${patientId}/reports`,secret.token);
  assert.equal(visible.data.reports[0].prediction.is_thalassemia,true);
  assert.equal((await req('GET',`/api/clinical-reports/${saved.data.report.id}`,secret.token)).status,200);
  const blocked=await req('PATCH',`/api/admin/users/${secret.id}`,admin,{...input,can_view_results:false});
  assert.equal(blocked.status,200);
  assert.equal(blocked.data.user.can_view_results,false);
  const hiddenAgain=await req('GET',`/api/patients/${patientId}/reports`,secret.token);
  assert.equal('prediction' in hiddenAgain.data.reports[0],false);
  assert.equal((await req('GET',`/api/clinical-reports/${saved.data.report.id}`,secret.token)).status,403);
});
