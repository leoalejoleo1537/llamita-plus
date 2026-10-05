/* LA PANTALLA DE LOGIN — presentación sobria sin marca gráfica.
   node pruebas/login-screen.mjs

   Se prueba en teléfono y computador: una misma tarjeta centrada, sin logos
   ni panel decorativo. También mostrar la
   contraseña, "olvidaste tu contraseña" pidiéndole a Supabase el correo de
   verdad, y que la sesión se cierre sola si "mantener sesión" queda
   destildado.

   El simulacro de Supabase acá es a propósito MÁS CHICO que el de las otras
   pruebas: alcanza con que `getSession` diga que no hay nadie logueado, para
   que la pantalla de login se quede a la vista y no salte sola a elegir
   sede. */
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readFileSync } from 'node:fs';
import jsQR from 'jsqr';
import { abrirNavegador } from './navegador.mjs';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await abrirNavegador();
if (!browser) { console.log('\n(se salta: no hay navegador instalado)\n'); process.exit(0); }

const page = await browser.newPage();
page.on('dialog', d => d.dismiss().catch(()=>{}));

async function montar(){
  await page.addInitScript(() => {
    window.__reset = null;
    window.__cerrada = false;
    window.__clipboardText = null;
    Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>{window.__clipboardText=text;}}});
    window.supabase = { createClient: () => ({
      from(){ const a={select:()=>a,eq:()=>a,order:()=>a,limit:()=>a,in:()=>a,is:()=>a,not:()=>a,
        or:()=>a,ilike:()=>a,gte:()=>a,lte:()=>a,neq:()=>a,
        maybeSingle:()=>Promise.resolve({data:null,error:null}),
        single:()=>Promise.resolve({data:null,error:null}),
        then:f=>Promise.resolve({data:[],error:null,count:0}).then(f)}; return a; },
      rpc:()=>Promise.resolve({data:null,error:null}),
      auth:{
        getSession: async () => ({data:{session:null}}),
        getUser: async () => ({data:{user:null}}),
        onAuthStateChange(cb){ return {data:{subscription:{unsubscribe(){}}}}; },
        signInWithPassword: async ({email}) =>
          ({data:{user:{id:'u1', email, user_metadata:{nombre:'Jhon'}}}, error:null}),
        resetPasswordForEmail: async (email) => { window.__reset = email; return {data:{}, error:null}; },
        signOut: async () => { window.__cerrada = true; return {}; },
      },
      channel:()=>({on(){return this;},subscribe(cb){cb&&cb('SUBSCRIBED');return this;},
        track:async()=>{},presenceState:()=>({})}),
      removeChannel(){}, functions:{invoke:async()=>({data:{ok:true},error:null})},
    })};
  });
  await page.route('**/supabase-js*', r=>r.fulfill({status:200,contentType:'application/javascript',body:''}));
  await page.goto(pathToFileURL(join(raiz,'index.html')).href);
  await page.waitForTimeout(500);
}

const errores = [];
page.on('pageerror', e=>errores.push(String(e)));
page.on('console', m=>{if(m.type()==='error')errores.push(m.text());});

let ok=0, mal=0;
const caso = async (n, fn) => {
  try { const r = await fn(); if(r===true){ok++;console.log('  ✓ '+n);}
        else {mal++;console.log('  ✗ '+n+'  → '+r);} }
  catch(e){ mal++; console.log('  ✗ '+n+'  → '+e.message.split('\n')[0]); }
};

console.log('\nEN EL TELÉFONO · acceso prioritario y logo oficial:');
await page.setViewportSize({width:390, height:844});
await montar();
if(process.env.CAPTURA_LOGIN) await page.screenshot({path:`${process.env.CAPTURA_LOGIN}-login-movil.png`});
await caso('la pantalla de login está a la vista (no hay sesión previa)', async () =>
  await page.isVisible('#login-gate') || 'no se ve el login');
await caso('el logo oficial aparece arriba y carga sin deformarse', async () => page.evaluate(()=>{
  const img=document.querySelector('.login-logo-tel');
  return img?.complete&&img.naturalWidth===512&&img.naturalHeight===512
    &&getComputedStyle(img).display!=='none'
    &&Math.abs(img.getBoundingClientRect().width/img.getBoundingClientRect().height-1)<.01;
}));
await caso('el panel visual se simplifica en móvil', async () =>
  !(await page.isVisible('.login-visual')) || 'el panel de escritorio se coló en el teléfono');
await caso('los tres campos y el botón están', async () => {
  const falt = [];
  for(const id of ['login-email','login-pass','login-btn']) if(!(await page.isVisible('#'+id))) falt.push(id);
  return falt.length === 0 || 'falta: ' + falt.join(', ');
});
await caso('nada se sale del ancho de la pantalla', async () =>
  (await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1))
  || 'hay scroll horizontal');
await caso('el QR del teléfono abre solo la URL canónica y se puede copiar',async()=>{
  await page.click('#login-qr-open');
  await page.waitForSelector('#login-qr-overlay.open');
  await page.screenshot({path:'/tmp/llamita-login-qr-movil.png'});
  const decodificado=await page.evaluate(async()=>{
    const svg=document.querySelector('#login-qr-code svg');
    if(!svg)return null;
    const texto=new XMLSerializer().serializeToString(svg),blob=new Blob([texto],{type:'image/svg+xml'});
    const url=URL.createObjectURL(blob),img=new Image();img.src=url;await img.decode();
    const canvas=document.createElement('canvas');canvas.width=420;canvas.height=420;
    const contexto=canvas.getContext('2d',{willReadFrequently:true});contexto.drawImage(img,0,0,420,420);
    URL.revokeObjectURL(url);
    const imagen=contexto.getImageData(0,0,420,420);
    return Array.from(imagen.data);
  });
  const contenido=decodificado&&jsQR(Uint8ClampedArray.from(decodificado),420,420);
  await page.click('#login-qr-copy');
  await page.waitForFunction(()=>document.querySelector('#login-qr-feedback')?.textContent==='Enlace copiado');
  const valores=await page.evaluate(()=>({copiado:window.__clipboardText,url:document.querySelector('#login-qr-url').textContent,
    instruccion:document.querySelector('#login-qr-instruction').textContent,ancho:document.querySelector('#login-qr-dialog')?.getBoundingClientRect().width,
    abierto:document.querySelector('#login-qr-overlay').classList.contains('open'),viewport:innerWidth}));
  return contenido?.data==='https://llamita-plus.vercel.app/'&&valores.copiado===contenido.data
    &&valores.url===contenido.data&&!/[?#](token|access_token|code|session)/i.test(contenido.data)
    &&valores.instruccion==='Escanea este código con la cámara de tu teléfono para abrir Llamita Plus.'
    &&valores.abierto&&valores.ancho<=valores.viewport;
});
await caso('en móvil el QR se cierra al tocar fuera y restaura el foco',async()=>{
  await page.mouse.click(4,4);
  return !(await page.locator('#login-qr-overlay.open').count())
    &&await page.evaluate(()=>document.activeElement.id==='login-qr-open');
});
await caso('el botón cerrar también cierra el panel QR',async()=>{
  await page.click('#login-qr-open');await page.click('#login-qr-close');
  return !(await page.locator('#login-qr-overlay.open').count())
    &&await page.evaluate(()=>document.activeElement.id==='login-qr-open');
});

console.log('\nEN EL COMPUTADOR · dos columnas y logo oficial:');
await page.setViewportSize({width:1440, height:900});
await montar();
if(process.env.CAPTURA_LOGIN) await page.screenshot({path:`${process.env.CAPTURA_LOGIN}-login-escritorio.png`});
await caso('el formulario y el panel oficial forman dos columnas amplias', async () => page.evaluate(()=>{
  const card=document.querySelector('.login-card'), form=document.querySelector('.login-form');
  const visual=document.querySelector('.login-visual'), logo=visual.querySelector('img');
  return card.getBoundingClientRect().width>800&&getComputedStyle(visual).display==='flex'
    &&form.getBoundingClientRect().left<visual.getBoundingClientRect().left
    &&logo.complete&&logo.naturalWidth===512&&logo.naturalHeight===512
    &&Math.abs(logo.getBoundingClientRect().width/logo.getBoundingClientRect().height-1)<.01;
}));
await caso('"Bienvenido" está, que en el teléfono no hace falta', async () =>
  ((await page.textContent('.login-h1')) || '').includes('Bienvenido') || 'no dice Bienvenido');
await caso('en escritorio el panel QR abre y Escape lo cierra',async()=>{
  await page.click('#login-qr-open');
  const ancho=await page.locator('#login-qr-dialog').evaluate(e=>e.getBoundingClientRect().width);
  await page.screenshot({path:'/tmp/llamita-login-qr-escritorio.png'});
  await page.keyboard.press('Shift+Tab');
  const ciclo=await page.evaluate(()=>document.activeElement.id==='login-qr-copy');
  await page.keyboard.press('Tab');
  const vuelve=await page.evaluate(()=>document.activeElement.id==='login-qr-close');
  await page.keyboard.press('Escape');
  return ciclo&&vuelve&&ancho<=360&&!(await page.locator('#login-qr-overlay.open').count())
    &&await page.evaluate(()=>document.activeElement.id==='login-qr-open');
});
console.log('\nEL LOGO ORIGINAL, de vuelta:');
await caso('el mosaico tiene azules y rojos de verdad, no es el de hojas verdes', async () => {
  /* Se lee el pixel con Python/PIL, AFUERA del navegador: bajo `file://`
     Chromium marca cualquier imagen como "tainted" y no deja leer el canvas,
     sin importar que sea el mismo origen. Es más simple preguntarle al
     archivo directo que pelear con esa restricción. */
  const { execFileSync } = await import('node:child_process');
  const salida = execFileSync('python3', ['-c', `
from PIL import Image
im = Image.open(${JSON.stringify(join(raiz,'icons','icon-512.png'))}).convert('RGBA')
blue=red=0
pixels=im.tobytes()
for i in range(0,len(pixels),4):
    r,g,b,a=pixels[i:i+4]
    if a<160: continue
    blue += b>r*1.25 and b>g*1.1
    red += r>g*1.25 and r>b*1.25
print(blue,red)
`]).toString().trim();
  const [azules,rojos] = salida.split(' ').map(Number);
  return azules>1000&&rojos>100 || `el asset ya no contiene el mosaico azul/rojo: ${salida}`;
});


console.log('\nMOSTRAR LA CONTRASEÑA:');
await page.fill('#login-pass', 'unaClave123');
await caso('nace oculta', async () => (await page.getAttribute('#login-pass','type')) === 'password' || 'nace visible');
await page.click('#login-ver');
await caso('el ojo la muestra', async () => (await page.getAttribute('#login-pass','type')) === 'text' || 'no cambió');
await page.click('#login-ver');
await caso('y la vuelve a esconder', async () => (await page.getAttribute('#login-pass','type')) === 'password' || 'quedó visible');
await page.fill('#login-pass', '');

console.log('\n"¿OLVIDASTE TU CONTRASEÑA?" — de verdad, no un adorno:');
await caso('sin correo, pide que lo escribas primero y NO llama a Supabase', async () => {
  await page.click('#login-olvide'); await page.waitForTimeout(300);
  const dijo = await page.textContent('#login-err');
  const llamo = await page.evaluate(() => window.__reset);
  return (dijo.includes('correo') && !llamo) || `dijo "${dijo}", llamó con "${llamo}"`;
});
await page.fill('#login-email', 'jhon@cafe.cl');
await caso('con el correo puesto, sí llama a Supabase con ESE correo', async () => {
  await page.click('#login-olvide'); await page.waitForTimeout(400);
  return (await page.evaluate(() => window.__reset)) === 'jhon@cafe.cl' || 'no lo mandó';
});
await caso('y el mensaje no delata si la cuenta existe o no', async () =>
  ((await page.evaluate(() => document.getElementById('toast').textContent)) || '').includes('Si ese correo tiene cuenta')
  || 'el aviso podría estar confirmando o negando la cuenta');

console.log('\n"MANTENER SESIÓN INICIADA" — se cierra sola si se destilda:');
await caso('nace marcada', async () => await page.isChecked('#login-recordar') || 'nace destildada');
/* Login de verdad y no un `window.USER` de mentira: `USER` es una variable
   de módulo del propio guion, no una propiedad de `window` — asignarla desde
   afuera no toca la que lee el manejador de `beforeunload`. La única forma
   honesta de dejarla en el estado real es iniciar sesión de verdad. */
await page.fill('#login-pass', 'unaClave123');
await page.click('#login-btn');
await page.waitForTimeout(400);
await caso('marcada, cerrar la pestaña NO cierra la sesión', async () => {
  await page.evaluate(() => window.dispatchEvent(new Event('beforeunload')));
  await page.waitForTimeout(100);
  return !(await page.evaluate(() => window.__cerrada)) || 'cerró sesión estando marcada';
});
/* Para probar el caso destildado hace falta un login nuevo: una vez adentro
   la casilla ya no está a la vista (§ el cajón de sesión se esconde), así
   que se destilda ANTES de entrar, en una vuelta limpia. */
await montar();
await page.click('#login-recordar');
await page.fill('#login-email', 'jhon@cafe.cl');
await page.fill('#login-pass', 'unaClave123');
await page.click('#login-btn');
await page.waitForTimeout(400);
await caso('destildada, sí se cierra al cerrar la pestaña', async () => {
  await page.evaluate(() => window.dispatchEvent(new Event('beforeunload')));
  await page.waitForTimeout(100);
  return (await page.evaluate(() => window.__cerrada)) || 'no se cerró';
});


await montar();
await page.fill('#login-email','jhon@cafe.cl');await page.fill('#login-pass','unaClave123');
await page.click('#login-btn');await page.waitForTimeout(350);
for(const [width,height,nombre] of [[1440,900,'escritorio'],[390,844,'móvil']]){
  await page.setViewportSize({width,height});
  if(process.env.CAPTURA_LOGIN) await page.screenshot({path:`${process.env.CAPTURA_LOGIN}-sede-${nombre}.png`});
  await caso(`selector de sede en ${nombre}: logo y tres opciones visibles sin desborde`,async()=>page.evaluate(()=>{
    const gate=document.querySelector('#gate'),img=gate.querySelector('.selector-marca'),r=img.getBoundingClientRect();
    return getComputedStyle(gate).display!=='none'&&img.complete&&img.naturalWidth===512
      &&Math.abs(r.width/r.height-1)<.01
      &&[...gate.querySelectorAll('.gate-btn')].map(x=>x.textContent.trim()).join('|')==='Local 1|Local 2|Bodega'
      &&document.documentElement.scrollWidth<=document.documentElement.clientWidth
      &&document.documentElement.scrollHeight<=document.documentElement.clientHeight;
  })||'logo, opciones o espacio incorrectos');
}
await caso('la sidebar sigue sin contener el logo oficial',async()=>await page.locator('#drawer img').count()===0);

console.log('\nY NINGÚN ERROR DE JAVASCRIPT:');
await caso('la consola quedó limpia', async () => errores.length === 0 || errores[0]);

console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();
process.exit(mal ? 1 : 0);
