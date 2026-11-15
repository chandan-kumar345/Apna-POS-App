const crypto = require('crypto');

module.exports = function metaSignupPage(req, res) {
  const nonce = crypto.randomBytes(18).toString('base64');
  const config = JSON.stringify({ appId: process.env.META_APP_ID || '', configId: process.env.META_EMBEDDED_SIGNUP_CONFIG_ID || '',
    version: process.env.META_GRAPH_VERSION || 'v23.0' }).replace(/</g, '\\u003c');
  res.set('Cache-Control', 'no-store');
  res.set('Referrer-Policy', 'no-referrer');
  res.set('Cross-Origin-Opener-Policy', 'same-origin-allow-popups');
  res.set('Content-Security-Policy', `default-src 'self'; script-src 'nonce-${nonce}' https://connect.facebook.net; connect-src 'self' https://*.facebook.com; frame-src https://*.facebook.com; img-src 'self' https://*.facebook.com data:; style-src 'unsafe-inline'; frame-ancestors 'none'`);
  res.type('html').send(`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Connect WhatsApp · Apna POS</title><style>body{font:16px system-ui;background:#f4f7fc;color:#14243b;display:grid;place-items:center;min-height:90vh;margin:20px}main{background:white;padding:36px;border:1px solid #e3e9f2;border-radius:24px;max-width:460px}small{color:#065bee;letter-spacing:2px}h1{font-size:30px}p{line-height:1.6;color:#66758a}button{background:#065bee;border:0;border-radius:12px;color:white;padding:14px 20px;font:600 16px system-ui;cursor:pointer}button:disabled{opacity:.5}</style>
<main><small>APNA POS</small><h1>Connect WhatsApp</h1><p>Choose your business and phone number in Meta. Your password stays with Meta.</p><button id="connect" disabled>Continue with Meta</button><p id="status" role="status">Loading secure signup…</p></main>
<script nonce="${nonce}">
const config=${config};
const sessionToken=new URLSearchParams(location.hash.slice(1)).get('session');
history.replaceState(null,'',location.pathname);
const status=document.getElementById('status'),button=document.getElementById('connect');
let code,assets,sending=false;
async function finish(){
 if(!code||!assets?.waba_id||!assets?.phone_number_id||sending)return;
 sending=true;button.disabled=true;status.textContent='Verifying your WhatsApp account…';
 try{const response=await fetch('./onboarding/complete',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({sessionToken,code,wabaId:assets.waba_id,phoneNumberId:assets.phone_number_id})});
 const result=await response.json();if(!response.ok||result.success===false)throw Error(result.error?.message||result.message||'Connection failed. Start again in Apna POS.');
 status.textContent='Account connected. Return to Apna POS to finish number registration and incoming messages.';
 }catch(error){status.textContent=error.message+' Return to Apna POS and restart signup.';}
}
window.addEventListener('message',event=>{
 let origin;try{origin=new URL(event.origin);}catch(_){return;}
 if(origin.protocol!=='https:'||!['www.facebook.com','web.facebook.com','business.facebook.com'].includes(origin.hostname))return;
 let data=event.data;try{if(typeof data==='string')data=JSON.parse(data);}catch(_){return;}
 if(data?.type!=='WA_EMBEDDED_SIGNUP')return;
 if(data.event==='FINISH'){assets=data.data;finish();}
 if(data.event==='CANCEL'||data.event==='ERROR'){status.textContent='Signup was not completed. You can try again.';button.disabled=false;}
});
window.fbAsyncInit=()=>{FB.init({appId:config.appId,version:config.version,cookie:false,xfbml:false});
 button.disabled=!sessionToken||!config.appId||!config.configId;
 status.textContent=button.disabled?'Open a new connection session from Apna POS.':'Ready to connect your business.';};
button.onclick=()=>{code=null;assets=null;status.textContent='Complete the steps in the Meta window.';FB.login(result=>{
 code=result.authResponse?.code;if(code)finish();else status.textContent='Signup cancelled. Your account was not changed.';
},{config_id:config.configId,auth_type:'rerequest',response_type:'code',override_default_response_type:true,extras:{setup:{}}});};
</script><script nonce="${nonce}" async defer src="https://connect.facebook.net/en_US/sdk.js"></script></html>`);
};
