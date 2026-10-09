/* M1: la barra inferior y el menú comparten las rutas reales. Sin datos remotos. */
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const browser=await abrirNavegador();
if(!browser){console.log('(se salta M1: no hay Chromium instalado)');process.exit(0);}
const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const page=await browser.newPage({viewport:{width:390,height:844}});
await page.addInitScript(()=>{
  const user={id:'m1-user',email:'m1@test.invalid',user_metadata:{nombre:'Prueba'}};
  const session={user};
  const permiso={auth_uid:user.id,correo:user.email,nombre:'Prueba',puede_editar:true,
    puede_ajustes:true,puede_fudo:false,puede_lama:true,fudo_bloqueos:[]};
  const q=(name)=>{
    const rows=name==='productos'?[{id:1,sede:'plaza',producto:'Leche',stock_actual:0,activo:'SÍ'}]:[];
    const api={select(){return api;},eq(){return api;},neq(){return api;},in(){return api;},
      order(){return api;},limit(){return api;},gte(){return api;},lte(){return api;},
      is(){return api;},not(){return api;},or(){return api;},ilike(){return api;},
      maybeSingle(){return Promise.resolve({data:rows[0]||null,error:null});},
      single(){return Promise.resolve({data:rows[0]||null,error:null});},
      then(done){return Promise.resolve({data:rows,error:null}).then(done);}};
    return api;
  };
  window.supabase={createClient:()=>({
    from:q,
    rpc:(name)=>{
      const data=name==='permisos_mios'?permiso:[];
      return {maybeSingle:()=>Promise.resolve({data,error:null}),
        then:done=>Promise.resolve({data,error:null}).then(done)};
    },
    auth:{getSession:async()=>({data:{session}}),getUser:async()=>({data:{user}}),
      onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({})},
    channel:()=>({on(){return this;},subscribe(cb){cb?.('SUBSCRIBED');return this;},
      track:async()=>{},presenceState:()=>({})}),removeChannel(){},
    functions:{invoke:async()=>({data:{ok:true},error:null})},
  })};
});
await page.route('**/supabase-js*',r=>r.fulfill({status:200,contentType:'application/javascript',body:'/* mock */'}));
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
await page.goto(pathToFileURL(join(raiz,'index.html')).href);
await page.evaluate(()=>{pickSede('plaza');AJUSTES_VAL={};PERMISOS.puede_lama=true;aplicarPermisos();});
await page.waitForTimeout(150);
const check=async(label,ok)=>{if(!await ok())throw Error(label);console.log('✓ '+label);};
await check('móvil sin ancho reservado a la izquierda',async()=>
  page.evaluate(()=>getComputedStyle(document.body).paddingLeft==='0px'));
await check('Mesas, Inventario, Reparto, Mermas y Más visibles',async()=>
  page.locator('#mobileBottom button:visible').count().then(n=>n===5));
if(process.env.M1_SCREENSHOT) await page.screenshot({path:process.env.M1_SCREENSHOT,fullPage:true});
await page.click('#mobileMenuTrigger');
await check('menú abierto con foco y estado accesible',async()=>
  page.evaluate(()=>document.body.classList.contains('mobile-menu-open') &&
    document.activeElement.id==='mobileNavClose' &&
    document.getElementById('mobileMenuTrigger').getAttribute('aria-expanded')==='true'));
await page.keyboard.press('Escape');
await check('Escape cierra y devuelve el foco',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open') &&
    document.activeElement.id==='mobileMenuTrigger'));
await page.click('#mobileMenuTrigger');
await page.click('#mobileNavScrim',{position:{x:380,y:200}});
await check('toque fuera cierra el menú',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open')));
await page.click('#mobileBottom [data-mobile-more]');
await page.click('#mobileNavClose');
await check('Más abre y el botón cierra el mismo menú',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open')));
await page.click('[data-mobile-tab="inv"]');
await check('barra inferior usa la ruta original',async()=>
  page.evaluate(()=>vistaActual==='inv' && document.querySelector('.tab[data-tab="inv"]').classList.contains('active')));
await page.evaluate(()=>{PERMISOS.puede_lama=false;aplicarPermisos();});
await check('permiso retirado oculta Mesas también abajo',async()=>
  page.locator('[data-mobile-tab="lama"]').count().then(n=>n===0));
await page.evaluate(()=>{AJUSTES_VAL={'modo_demostracion|':true};aplicarNavegacionDemo();});
await check('modo demostración filtra accesos inferiores',async()=>
  page.locator('[data-mobile-tab="lama"]').count().then(n=>n===0));
await page.evaluate(()=>{AJUSTES_VAL={};pickSede('central');});
await check('Bodega ofrece Recibir y Enviar, no Mesas',async()=>
  page.evaluate(()=>!!document.querySelector('[data-mobile-tab="recepcion"]') &&
    !!document.querySelector('[data-mobile-tab="envios"]') &&
    !document.querySelector('[data-mobile-tab="lama"]')));
await page.setViewportSize({width:1280,height:800});
await page.waitForTimeout(100);
await check('escritorio conserva el riel y oculta la barra inferior',async()=>
  page.evaluate(()=>getComputedStyle(document.body).paddingLeft!=='0px' &&
    getComputedStyle(document.getElementById('mobileBottom')).display==='none' &&
    !document.getElementById('mobileNav').inert));
await check('sin errores JavaScript',async()=>errors.length===0);
await browser.close();
