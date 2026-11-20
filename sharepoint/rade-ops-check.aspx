<!DOCTYPE html>
<!--
  RADE SharePoint ops check (the Administrator, 2026-11-20: "an ops check on making a sharepoint .ASPX page that's
  formatted like .html so i can host my apps on a dod website").

  What it is: a plain HTML page saved with the .aspx extension. Upload it to a SharePoint Online library and open it.
  It answers one question: can a RADE-style page (HTML, CSS and inline script) run from SharePoint Online on this site?

  What it does: it runs 8 checks inside the browser only and shows the result of each.
  What it never does: no network request of any kind (no fetch, no XHR, no image or script from another place), no
  read of SharePoint lists or files, no write, no cookie, and it does not show the page address (the address names the
  site). RADE project rule "No reconnaissance": every check reads only this browser's own features.

  How to read it: each row starts as "Not run". Only the inline script below can change a row. So if every row still
  says "Not run", SharePoint served the page but blocked its script.

  SharePoint Online parses .aspx files as ASP.NET pages, so this file holds no server code: no server tags, no server
  attributes, no page directive. Text only in ASCII, so a save in Notepad cannot change it.
-->
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RADE ops check</title>
<style>
/* RADE page colors (engine/ui-tokens.json, UI standard v1), copied here: the file must stand alone. */
:root{--bg:#ffffff;--navy:#0b2545;--text:#1b2430;--gray:#5a6573;--action:#00539f;--turn:#ffd520;--fail:#8b1a1a;--pass:#2e8540;--edge:#7a8794}
@media (prefers-color-scheme:dark){:root{--bg:#0e141c;--navy:#dde8f3;--text:#e6ebf1;--gray:#a5b1c0;--fail:#f0a3a3;--pass:#6cc487;--edge:#8794a6;color-scheme:dark}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:1rem/1.5 "Segoe UI",system-ui,sans-serif}
.band{background:linear-gradient(100deg,#0b2545,#00539f);color:#fff;border-bottom:3px solid var(--turn);padding:18px 16px}
.band p{margin:0;max-width:860px;margin-inline:auto}
.band .name{font-size:1.375rem;font-weight:650}
.band .sub{font-size:.875rem;color:#dde8f3}
main{max-width:860px;margin:0 auto;padding:16px}
h1{margin:0 0 8px;font-size:1.8rem;line-height:1.2;font-weight:600;color:var(--navy)}
.caps{margin:0;font-size:.8125rem;font-weight:600;letter-spacing:.08em;text-transform:uppercase;color:var(--gray)}
table{border-collapse:collapse;width:100%;margin-top:12px}
th,td{text-align:left;vertical-align:top;padding:8px 10px;border-bottom:1px solid var(--edge)}
th{font-size:.875rem;color:var(--gray);font-weight:600}
td.r{font-weight:700;white-space:nowrap}
.pass{color:var(--pass)}.fail{color:var(--fail)}.wait{color:var(--gray)}
#css-proof{display:none}
.second{color:var(--gray);font-size:.875rem}
@media (forced-colors:active){.band{background:Canvas;color:CanvasText;border-bottom-color:CanvasText}.band .sub{color:CanvasText}}
</style></head><body>
<header class="band"><p class="name">RADE</p><p class="sub">SharePoint ops check</p></header>
<main>
<p class="caps">Ops check</p>
<h1 id="sum">The script did not run. SharePoint blocked it.</h1>
<p id="css-proof">CSS did not load: this line shows only when the style block above is blocked.</p>
<p>Each row starts as "Not run". Only the script on this page can change a row.</p>
<table><thead><tr><th scope="col">Check</th><th scope="col">Result</th><th scope="col">What it means for a RADE app</th></tr></thead>
<tbody id="rows">
<tr><td>1. Page opens as a web page</td><td class="r pass">Pass</td><td>You can read this, so SharePoint shows the file and does not only download it.</td></tr>
<tr><td>2. Inline script runs</td><td class="r fail">Not run</td><td>A RADE page needs script. "Not run" here: ask the SharePoint administrator about custom script.</td></tr>
</tbody></table>
<p class="second" id="when"></p>
</main>
<script>
(function(){
'use strict';
// One row per check: [name, test, meaning]. A test gives true (pass), false (fail) or a string (pass, with this detail).
// A test that throws is a fail. All tests read this browser only (see the note at the top of the file).
var CHECKS=[
  ['2. Inline script runs',function(){return true},'Script runs on this site. A RADE page can run here.'],
  ['3. Styles (CSS) apply',function(){var p=document.getElementById('css-proof');return getComputedStyle(p).display==='none'},'The page looks as designed.'],
  ['4. Secure page (HTTPS)',function(){return window.isSecureContext===true},'Copy to the clipboard and the hash check need a secure page.'],
  ['5. Clipboard copy is available',function(){return !!(navigator.clipboard&&navigator.clipboard.writeText)||(document.queryCommandSupported&&document.queryCommandSupported('copy'))},'The "Copy script" button can work.'],
  ['6. SHA-256 hash (Web Crypto)',function(){return !!(window.crypto&&crypto.subtle&&window.TextEncoder)},'The page can check a script against its hash before you copy it.'],
  ['7. Text file in the browser (Blob)',function(){var u=URL.createObjectURL(new Blob(['RADE'],{type:'text/plain'}));URL.revokeObjectURL(u);return true},'"View as .txt" and "Save as .txt" can work.'],
  ['8. Local storage',function(){var k='rade-ops-check';localStorage.setItem(k,'1');var ok=localStorage.getItem(k)==='1';localStorage.removeItem(k);return ok},'The page can remember the last app you chose (this browser only).'],
  ['9. Page frame',function(){return window.top===window.self?'not in a frame':'in a frame'},'Information only: "in a frame" means SharePoint shows the page inside another page.']
];
function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
var rows=document.getElementById('rows'),html='',pass=0,fail=0;
rows.rows[1].parentNode.removeChild(rows.rows[1]);   // row 2 is the static "Not run" row: the script ran, so replace it
CHECKS.forEach(function(c){
  var r;try{r=c[1]()}catch(e){r=false}
  var ok=r!==false&&r!==null&&r!==undefined;
  if(ok){pass++}else{fail++}
  html+='<tr><td>'+esc(c[0])+'</td><td class="r '+(ok?'pass':'fail')+'">'+(ok?'Pass':'Fail')+(typeof r==='string'?'<br><span class="second">'+esc(r)+'</span>':'')+'</td><td>'+esc(ok?c[2]:'Not available here. Tell the Teams channel which row failed.')+'</td></tr>';
});
rows.insertAdjacentHTML('beforeend',html);
pass++;   // row 1 (the page opens) passed: you can read it
document.getElementById('sum').textContent=fail?pass+' of '+(pass+fail)+' checks passed. '+fail+' failed: see the rows marked Fail.':'All '+pass+' checks passed. A RADE page can run on this site.';
var t=new Date();document.getElementById('when').textContent='Checked at '+('0'+t.getHours()).slice(-2)+':'+('0'+t.getMinutes()).slice(-2)+' on this computer. Nothing was sent anywhere.';
})();
</script>
</body></html>
