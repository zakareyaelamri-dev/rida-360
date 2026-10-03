/* Scoring engine + rater-anonymity threshold. */
function chk(name, got, want){
  const ok = String(got) === String(want);
  if(!ok) failures++;
  console.log((ok ? 'ok   ' : 'FAIL ') + name + '   got=' + got + ' want=' + want);
}
DB.employees = [
  {id:'M', name:'Mgr',  role:'Dept Manager', division:'RSS', dept:'HR'},
  {id:'E', name:'Emp',  role:'Employee',     division:'RSS', dept:'HR'},
  {id:'P1',name:'P1',   role:'Employee',     division:'RSS', dept:'HR'},
  {id:'P2',name:'P2',   role:'Employee',     division:'RSS', dept:'HR'},
  {id:'P3',name:'P3',   role:'Employee',     division:'RSS', dept:'HR'}];
const full = {}; BEHAV_AXES.forEach(a => {if(!a.leadersOnly) full[a.id] = a.qs.map(() => 4);});
const ev = (rater, type) => ({id:rater+type, targetId:'E', raterId:rater, type, scores:full, tech:null, status:'confirmed'});
DB.evaluations = [ev('M','manager'), ev('E','self'), ev('P1','peer')];

let r = computeResults('E');
chk('behavioural = 4/5',                 Math.round(r.behavioral360), 80);
chk('no final grade without KPIs',       r.final, 'null');
chk('1-peer group withheld from employee', anonHeld(r,'peer',true),  true);
chk('1-peer group shown to manager',     anonHeld(r,'peer',false), false);

DB.evaluations.push(ev('P2','peer'), ev('P3','peer'));
r = computeResults('E');
chk('3-peer group shown to employee',    anonHeld(r,'peer',true), false);

DB.evaluations[0].tech = {T1:'90',T2:'90',T3:'90',T4:'90'};
r = computeResults('E');
chk('final = 80*0.4 + 90*0.6',           r.final, 86);
chk('grade label (en)',                  gradeLabel(86).t, 'Very Good');
LANG='ar';
chk('grade label (ar)',                  gradeLabel(86).t, 'جيد جداً');
LANG='en';

/* redistribution when the target has no subordinates */
chk('weights redistributed',             computeResults('E').hasSubs, false);
