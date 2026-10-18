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
      order(){return api;},limit(){return api;},range(){return api;},gte(){return api;},lte(){return api;},lt(){return api;},
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
await check('Inventario, Reparto y Mermas visibles sin Más',async()=>
  page.evaluate(()=>{
    const rutas=[...document.querySelectorAll('#mobileBottom button:not([hidden])')]
      .map(b=>b.dataset.mobileTab);
    return rutas.join(',')==='inv,reparto,mermas' &&
      !document.querySelector('#mobileBottom [data-mobile-more]');
  }));
await check('iconos lineales propios de Inicio, caja y basurero',async()=>
  page.evaluate(()=>['inv','reparto','mermas'].every(ruta=>
    document.querySelector(`[data-mobile-tab="${ruta}"] svg`)?.getAttribute('viewBox')==='0 0 28 28')));
await page.click('#mobileMenuTrigger');
await check('menú abierto con foco y estado accesible',async()=>
  page.evaluate(()=>document.body.classList.contains('mobile-menu-open') &&
    document.activeElement.id==='mobileNavClose' &&
    document.getElementById('mobileMenuTrigger').getAttribute('aria-expanded')==='true'));
await check('menú conserva Mesas y no duplica accesos inferiores',async()=>
  page.evaluate(()=>getComputedStyle(document.getElementById('tabLama')).display!=='none' &&
    ['inv','reparto','mermas'].every(ruta=>
      getComputedStyle(document.querySelector(`.tab[data-tab="${ruta}"]`)).display==='none')));
await page.keyboard.press('Escape');
await check('Escape cierra y devuelve el foco',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open') &&
    document.activeElement.id==='mobileMenuTrigger'));
await page.click('#mobileMenuTrigger');
await page.click('#mobileNavScrim',{position:{x:380,y:200}});
await check('toque fuera cierra el menú',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open')));
await page.click('[data-mobile-tab="inv"]');
await check('barra inferior usa la ruta original',async()=>
  page.evaluate(()=>vistaActual==='inv' && document.querySelector('.tab[data-tab="inv"]').classList.contains('active')));
await check('etiqueta de Inventario no se alarga al cargar el modo',async()=>
  page.locator('[data-mobile-tab="inv"] span').textContent().then(t=>t==='Inventario'));
if(process.env.M1_SCREENSHOT) await page.screenshot({path:process.env.M1_SCREENSHOT});
const medirBarra=()=>page.evaluate(()=>{
  const barra=document.getElementById('mobileBottom').getBoundingClientRect();
  return {top:barra.top,height:barra.height,bottom:innerHeight-barra.bottom};
});
const inventario=await medirBarra();
await page.evaluate(()=>{window.__m1BotonInventario=document.querySelector('[data-mobile-tab="inv"]');});
await page.click('[data-mobile-tab="reparto"]');
if(process.env.M1_SCREENSHOT_REPARTO) await page.screenshot({path:process.env.M1_SCREENSHOT_REPARTO});
const reparto=await medirBarra();
await page.click('[data-mobile-tab="mermas"]');
const mermas=await medirBarra();
await check('barra a idéntica altura al pasar por Inventario, Reparto y Mermas',async()=>
  [reparto,mermas].every(m=>Math.abs(m.top-inventario.top)<1 &&
    Math.abs(m.height-inventario.height)<1 && Math.abs(m.bottom-inventario.bottom)<1));
await check('botones estables, anclados abajo y con destino activo',async()=>
  page.evaluate(()=>window.__m1BotonInventario===document.querySelector('[data-mobile-tab="inv"]') &&
    document.querySelector('[data-mobile-tab="mermas"]').getAttribute('aria-current')==='page' &&
    Math.abs(document.getElementById('mobileBottom').getBoundingClientRect().bottom-innerHeight)<1));
await page.setViewportSize({width:667,height:375});
await check('en horizontal conserva la altura y controles táctiles',async()=>
  page.evaluate(()=>{
    const barra=document.getElementById('mobileBottom').getBoundingClientRect();
    return Math.abs(barra.height-68)<1 && Math.abs(barra.bottom-innerHeight)<1 &&
      [...document.querySelectorAll('#mobileBottom button:not([hidden])')]
        .every(b=>b.getBoundingClientRect().height>=44);
  }));
await page.setViewportSize({width:390,height:844});
await page.evaluate(()=>{document.documentElement.dataset.paleta='esmeralda';});
await check('barra utiliza el acento de la paleta elegida',async()=>
  page.evaluate(()=>getComputedStyle(document.querySelector('.mobile-bottom-item.active')).color===
    getComputedStyle(document.documentElement).getPropertyValue('--orange-dark').trim()
      .replace(/^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i,(_,r,g,b)=>
        `rgb(${parseInt(r,16)}, ${parseInt(g,16)}, ${parseInt(b,16)})`)));
await page.evaluate(()=>{PERMISOS.puede_lama=false;aplicarPermisos();});
await check('permiso retirado oculta Mesas en el menú',async()=>
  page.evaluate(()=>document.getElementById('tabLama').style.display==='none'));
await page.evaluate(()=>{AJUSTES_VAL={'modo_demostracion|':true};aplicarNavegacionDemo();});
await check('modo demostración mantiene rutas permitidas',async()=>
  page.locator('#mobileBottom button:visible').count().then(n=>n===3));
await page.evaluate(()=>{AJUSTES_VAL={};pickSede('central');});
await check('Bodega ofrece Recibir y Enviar, no Mesas',async()=>
  page.evaluate(()=>!!document.querySelector('[data-mobile-tab="recepcion"]:not([hidden])') &&
    !!document.querySelector('[data-mobile-tab="envios"]:not([hidden])') &&
    !document.querySelector('[data-mobile-tab="lama"]')));
await check('Bodega no duplica Recibir ni Enviar en el menú móvil',async()=>
  page.evaluate(()=>['recepcion','envios'].every(ruta=>
    getComputedStyle(document.querySelector(`.tab[data-tab="${ruta}"]`)).display==='none')));
await page.setViewportSize({width:1280,height:800});
await page.waitForTimeout(100);
await check('escritorio conserva el riel y oculta la barra inferior',async()=>
  page.evaluate(()=>getComputedStyle(document.body).paddingLeft!=='0px' &&
    getComputedStyle(document.getElementById('mobileBottom')).display==='none' &&
    !document.getElementById('mobileNav').inert));
await check('sin errores JavaScript',async()=>{if(errors.length)console.error(errors);return errors.length===0;});
await browser.close();
