/* LA PANTALLA DE LOGIN — rehecha 2026-09-08 sobre la maqueta de escritorio.
   node pruebas/login-screen.mjs

   Se prueba en las dos formas: la tarjeta simple del teléfono (que no puede
   perder nada de lo que ya tenía) y el panel partido del computador (lo
   nuevo). Y las tres cosas que dejaron de ser solo dibujo: mostrar la
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

let ok=0, mal=0;
const caso = async (n, fn) => {
  try { const r = await fn(); if(r===true){ok++;console.log('  ✓ '+n);}
        else {mal++;console.log('  ✗ '+n+'  → '+r);} }
  catch(e){ mal++; console.log('  ✗ '+n+'  → '+e.message.split('\n')[0]); }
};

console.log('\nEN EL TELÉFONO · la tarjeta simple, sin el panel decorativo:');
await page.setViewportSize({width:390, height:844});
await montar();
await caso('la pantalla de login está a la vista (no hay sesión previa)', async () =>
  await page.isVisible('#login-gate') || 'no se ve el login');
await caso('el logo del teléfono está', async () =>
  await page.isVisible('.login-marca-tel') || 'no se ve el logo del teléfono');
await caso('el panel decorativo NO se dibuja acá', async () =>
  !(await page.isVisible('.login-visual')) || 'el panel de escritorio se coló en el teléfono');
await caso('los tres campos y el botón están', async () => {
  const falt = [];
  for(const id of ['login-email','login-pass','login-btn']) if(!(await page.isVisible('#'+id))) falt.push(id);
  return falt.length === 0 || 'falta: ' + falt.join(', ');
});
await caso('nada se sale del ancho de la pantalla', async () =>
  (await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1))
  || 'hay scroll horizontal');

console.log('\nEN EL COMPUTADOR · el panel partido de la maqueta:');
await page.setViewportSize({width:1440, height:900});
await montar();
await caso('aparece el panel de la izquierda', async () =>
  await page.isVisible('.login-visual') || 'no se ve');
await caso('con el logo grande y el nombre', async () =>
  (await page.isVisible('.login-visual-logo')) && (await page.isVisible('.login-visual-marca'))
  || 'falta el logo o el nombre del panel');
await caso('"Bienvenido" está, que en el teléfono no hace falta', async () =>
  ((await page.textContent('.login-h1')) || '').includes('Bienvenido') || 'no dice Bienvenido');
await caso('el logo del teléfono no se duplica acá', async () =>
  !(await page.isVisible('.login-marca-tel')) || 'se ven dos logos a la vez');

console.log('\nEL NOMBRE, MÁS FINO — lo que pidió Jhon:');
await caso('ya no es el sans-serif grueso de antes', async () => {
  const peso = await page.evaluate(() => getComputedStyle(document.querySelector('.login-visual-marca')).fontWeight);
  return (peso === '400' || peso === 'normal') || 'sigue en negrita: ' + peso;
});
await caso('es una serif, no la sans del resto de la app', async () => {
  const f = await page.evaluate(() => getComputedStyle(document.querySelector('.login-visual-marca')).fontFamily);
  return /georgia|serif/i.test(f) || 'quedó en: ' + f;
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
im = Image.open(${JSON.stringify(join(raiz,'icons','icon-192.png'))}).convert('RGB')
w,h = im.size
print(im.getpixel((int(w*0.5), int(h*0.08))))
`]).toString().trim();
  const [r,g,b] = salida.replace(/[()]/g,'').split(',').map(n=>+n.trim());
  const esVerde = g > r && g > b;
  return !esVerde || `sigue viéndose verde arriba: rgb(${r},${g},${b})`;
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

console.log('\nY NINGÚN ERROR DE JAVASCRIPT:');
await caso('la consola quedó limpia', async () => errores.length === 0 || errores[0]);

console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();
process.exit(mal ? 1 : 0);
