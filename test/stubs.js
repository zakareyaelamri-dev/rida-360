/* Browser + Supabase stubs, prepended to the app source so index.html runs
   unmodified under Node. Anything the app touches at load time lives here. */
const store = {};
var localStorage = {getItem:k=>k in store?store[k]:null, setItem:(k,v)=>{store[k]=String(v);}, removeItem:k=>{delete store[k];}};
var PRINTED = {html:''};
function el(id){
  return {id, innerHTML:'', value:'', textContent:'', dataset:{}, style:{},
    addEventListener(){}, querySelectorAll:()=>[], classList:{add(){},remove(){},toggle(){}},
    parentElement:{querySelectorAll:()=>[]}, select(){}, checked:false};
}
var MODAL = {html:''};
var document = {
  getElementById(id){
    if(id==='print-area')return {set innerHTML(v){PRINTED.html=v;}, get innerHTML(){return PRINTED.html;}, style:{}};
    return el(id);
  },
  querySelectorAll:()=>[], documentElement:{}, body:{}
};
function Chart(){} Chart.getChart=()=>null;
var alert=()=>{};
var window = {
  print(){}, location:{origin:'http://test', pathname:'/'},
  supabase:{createClient:()=>({
    auth:{ onAuthStateChange(){}, getSession:async()=>({data:{session:null}}),
           getUser:async()=>({data:{user:null}}), signInWithPassword:async()=>({error:'stub'}),
           signOut:async()=>({}), updateUser:async()=>({}), resetPasswordForEmail:async()=>({}) },
    from(){ const q={select:()=>q, insert:()=>q, update:()=>q, upsert:()=>q, delete:()=>q,
                     eq:()=>q, in:()=>q, single:()=>q, then:r=>r({data:[],error:null})}; return q; },
    functions:{invoke:async()=>({data:null,error:'stub'})}
  })}
};
