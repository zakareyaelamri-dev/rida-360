/* Every page renderer, both languages, with an injection payload in every
   user-controlled field. Fails if the payload survives into the HTML. */
const P = '<img src=x onerror=';
const X = P + "alert(1)>\"'&";
DB.employees = [
  {id:'RTS-001', name:'Zack '+X, title:'HR '+X, role:'Dept Manager', division:'RSS', dept:'HR '+X,
   isAdmin:true, email:'a@b.c', phone:'1', perms:{employees:1,raters:1,approvals:1,allResults:1,org:1}},
  {id:'RTS-000', name:'CEO '+X, title:'CEO', role:'CEO', division:'RSS', dept:'Executive', isCEO:true},
  {id:'E1', name:'Ali '+X,  title:'Eng '+X, role:'Employee '+X, division:'RSS', dept:'HR '+X},
  {id:'E2', name:'Sara '+X, title:'Eng',    role:'Employee '+X, division:'RSS', dept:'HR '+X}];
const full = {}; BEHAV_AXES.forEach(a => {if(!a.leadersOnly) full[a.id] = a.qs.map(() => 4);});
DB.evaluations = [
  {id:'v1', targetId:'E1', raterId:'RTS-001', type:'manager', scores:full,
   tech:{T1:'90',T2:'90',T3:'90',T4:'90'},
   devPlan:{strengths:X, areas:X, goals:'line1\n'+X, recommend:X}, status:'confirmed', date:'2026-10-01'+X},
  {id:'v2', targetId:'E1', raterId:'E1', type:'self', scores:full, status:'confirmed', date:'2026-10-01'},
  {id:'v3', targetId:'E1', raterId:'E2', type:'peer', scores:full, status:'pending',   date:'2026-10-01'}];
DB.trainings = [{id:'t1', empId:'E1', name:'Course '+X, axis:'A1', level:'basic', type:'course',
  provider:'Prov '+X, startDate:'2026-01-01'+X, durVal:3, durUnit:'days', status:'planned',
  notes:X, createdBy:'RTS-001'}];
USER = DB.employees[0];

function check(name, fn){
  let h;
  try { h = fn() || ''; }
  catch(e){ console.log('THROW ' + name + ': ' + e.message); failures++; return; }
  if(typeof h === 'string' && h.includes(P)){
    const i = h.indexOf(P);
    console.log('XSS  ' + name + '  >> ...' + h.slice(Math.max(0, i-80), i).replace(/\s+/g,' '));
    failures++; return;
  }
  console.log('ok   ' + name);
}
const modal = () => MODAL.html;
showModal = h => {MODAL.html = h;};

for(const lang of ['en','ar']){
  LANG = lang; console.log('--- LANG=' + lang);
  check('pgDashboard',        () => pgDashboard());
  check('pgEvalForm/self',    () => pgEvalForm('RTS-001','self'));
  check('pgEvalForm/manager', () => pgEvalForm('E1','manager'));
  check('pgEvalForm/peer',    () => pgEvalForm('E1','peer'));
  check('pgEvalForm/sub',     () => pgEvalForm('E1','subordinate'));
  check('pgRateOthers',       () => pgRateOthers());
  check('pgResults/self',     () => pgResults('E1', true));
  check('pgResults/manager',  () => pgResults('E1', false));
  check('pgTeam',             () => pgTeam());
  check('pgTrainings',        () => pgTrainings());
  check('pgEmployees',        () => pgEmployees());
  check('pgRaters',           () => pgRaters());
  check('pgApprovals',        () => pgApprovals());
  check('pgOrg',              () => pgOrg());
  check('pgAllResults',       () => pgAllResults());
  check('trainTable',         () => trainTable(DB.trainings, true));
  check('openEmpModal',       () => {openEmpModal('E1'); return modal();});
  check('openTrainModal/new', () => {openTrainModal(); return modal();});
  check('openTrainModal/edit',() => {openTrainModal('E1','t1'); return modal();});
  check('openPeers',          () => {openPeers('E1'); return modal();});
  check('openOverride',       () => {openOverride('E1'); return modal();});
  check('openPwModal',        () => {openPwModal(); return modal();});
  check('printReport',        () => {PRINTED.html=''; printReport('E1'); return PRINTED.html;});
}
