/* Runs a test case against the live index.html — nothing is copied, so the
   tests cannot go stale. */
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..');

function appSource(){
  const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  const blocks = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]);
  if(!blocks.length) throw new Error('no inline <script> block found in index.html');
  return blocks.join('\n');
}

function run(caseName){
  const src = [
    fs.readFileSync(path.join(__dirname, 'stubs.js'), 'utf8'),
    appSource(),
    fs.readFileSync(path.join(__dirname, 'cases', caseName + '.js'), 'utf8')
  ].join('\n;\n');
  const ctx = {console, setTimeout, clearTimeout, process, failures: 0};
  vm.createContext(ctx);
  vm.runInContext(src, ctx, {filename: caseName});
  return ctx.failures;
}

module.exports = {run, appSource};

if(require.main === module){
  const cases = process.argv.slice(2).length ? process.argv.slice(2)
              : fs.readdirSync(path.join(__dirname, 'cases')).map(f => f.replace(/\.js$/, ''));
  let total = 0;
  for(const c of cases){ console.log('\n### ' + c); total += run(c); }
  console.log(total ? `\nFAILED: ${total}` : '\nALL TESTS PASS');
  process.exit(total ? 1 : 0);
}
