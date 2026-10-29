'use strict';
// Contract test of the production SQL adapter without requiring Supabase access.
const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
const originalLoad = Module._load;
const calls = [];
const query = async (sql, params) => { calls.push({sql, params}); return {rows:[{count:2, id:'sample'}],rowCount:1}; };
Module._load = function(name, parent, isMain) {
  if (name === 'pg') return {
    types:{setTypeParser(){}},
    Pool:class {
      on(){}
      async query(sql,params){return query(sql,params);}
      async connect(){return {query,release(){}};}
      async end(){}
    }
  };
  return originalLoad.apply(this,arguments);
};
process.env.NODE_ENV='production';
process.env.DATABASE_URL='postgresql://example.invalid/example';
const db = require('../src/db');
Module._load = originalLoad;
test('PostgreSQL adapter binds parameters and explicitly scopes clinical tables',async()=>{
  await db.prepare('SELECT c.id FROM clinical_reports c JOIN patients p ON p.id=c.patient_id WHERE c.id=? AND p.account_id=?').get('a','b');
  assert.equal(calls.at(-1).sql,'SELECT c.id FROM hemoguard.clinical_reports c JOIN hemoguard.patients p ON p.id=c.patient_id WHERE c.id=$1 AND p.account_id=$2');
  assert.deepEqual(calls.at(-1).params,['a','b']);
  await db.prepare('INSERT INTO reports(id,user_id,mode) VALUES(?,?,?)').run('1','2','image');
  assert.match(calls.at(-1).sql,/INSERT INTO hemoguard.reports/);
});
test('async queries within a transaction use a single connection and rollback errors',async()=>{
  await db.transaction(async()=>{
    await db.prepare('UPDATE users SET can_view_results=? WHERE id=?').run(0,'abc');
  });
  const sequence=calls.slice(-3).map(x=>x.sql);
  assert.deepEqual(sequence,['BEGIN','UPDATE hemoguard.users SET can_view_results=$1 WHERE id=$2','COMMIT']);
  await assert.rejects(()=>db.transaction(async()=>{await db.prepare('DELETE FROM reports WHERE id=?').run('x');throw new Error('test');}),/test/);
  assert.equal(calls.at(-1).sql,'ROLLBACK');
});
