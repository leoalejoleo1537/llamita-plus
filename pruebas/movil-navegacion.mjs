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
const abrirPorGesto=async()=>{
  await page.mouse.move(8,260);await page.mouse.down();
  await page.mouse.move(96,260,{steps:6});await page.mouse.move(230,260,{steps:6});await page.mouse.up();
  await page.waitForTimeout(280);
};
const cerrarPorGesto=async()=>{
  await page.mouse.move(220,260);await page.mouse.down();
  await page.mouse.move(42,260,{steps:8});await page.mouse.up();
  await page.waitForTimeout(280);
};
await check('móvil sin ancho reservado a la izquierda',async()=>
  page.evaluate(()=>getComputedStyle(document.body).paddingLeft==='0px'));
await check('el viewport no dibuja bajo las barras translúcidas de iPhone',async()=>
  page.evaluate(()=>!document.querySelector('meta[name="viewport"]').content.includes('viewport-fit=cover')));
await check('Mesas, Inventario, Reparto y Mermas visibles sin Más',async()=>
  page.evaluate(()=>{
    const rutas=[...document.querySelectorAll('#mobileBottom button:not([hidden])')]
      .map(b=>b.dataset.mobileTab);
    return rutas.join(',')==='lama,inv,reparto,mermas' &&
      !document.querySelector('#mobileBottom [data-mobile-more]');
  }));
await check('iconos lineales propios de Mesas, Inicio, caja y basurero',async()=>
  page.evaluate(()=>['lama','inv','reparto','mermas'].every(ruta=>
    document.querySelector(`[data-mobile-tab="${ruta}"] svg`)?.getAttribute('viewBox')==='0 0 28 28')));
await page.mouse.move(8,260);await page.mouse.down();await page.mouse.move(24,260,{steps:2});await page.mouse.up();
await check('un gesto corto desde el borde no abre el menú',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open')));
await abrirPorGesto();
await check('menú abierto con foco y estado accesible',async()=>
  page.evaluate(()=>document.body.classList.contains('mobile-menu-open') &&
    document.getElementById('mobileMenuTrigger').getAttribute('aria-expanded')==='true'));
await check('el menú sigue el gesto y difumina la pantalla sin sumar botones',async()=>
  page.evaluate(()=>{
    const velo=document.getElementById('mobileNavScrim');
    return getComputedStyle(document.getElementById('mobileMenuTrigger')).width==='1px' &&
      getComputedStyle(velo).backdropFilter.includes('blur') &&
      Math.abs(document.getElementById('mobileNav').getBoundingClientRect().left)<1;
  }));
if(process.env.M1_MENU_SCREENSHOT)await page.screenshot({path:process.env.M1_MENU_SCREENSHOT});
await check('el menú lateral compacto da acceso a todos los módulos permitidos',async()=>
  page.evaluate(()=>['lama','arqueo','movcaja','inv','reparto','mermas','recetas'].every(ruta=>
    getComputedStyle(document.querySelector(`.tab[data-tab="${ruta}"]`)).display!=='none')));
await check('el menú móvil deja espacio para leer todas sus etiquetas',async()=>
  page.evaluate(()=>{
    const panel=document.getElementById('mobileNav'),items=[...panel.querySelectorAll('.inner .tab')];
    return panel.getBoundingClientRect().width<=innerWidth*.86+1 &&
      panel.getBoundingClientRect().width>=Math.min(344,innerWidth*.8) &&
      items.filter(b=>getComputedStyle(b).display!=='none')
        .every(b=>parseFloat(getComputedStyle(b).fontSize)>=14);
  }));
await check('Apariencia, presencia en línea y nombres de usuario se quitaron del lateral',async()=>
  page.evaluate(()=>['.drawer-appearance','#drawerOnlineLabel','#drawerOnline','.drawer-user']
    .every(sel=>getComputedStyle(document.querySelector(sel)).display==='none')));
await cerrarPorGesto();
await check('un gesto hacia la izquierda repliega el menú',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open')));
await abrirPorGesto();
await page.keyboard.press('Escape');
await check('Escape repliega el menú',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open')));
await abrirPorGesto();
await page.click('#mobileNavScrim',{position:{x:380,y:200}});
await check('toque fuera cierra el menú',async()=>
  page.evaluate(()=>!document.body.classList.contains('mobile-menu-open')));
await page.setViewportSize({width:320,height:700});
await abrirPorGesto();
await check('en un teléfono angosto el cajón conserva opciones legibles',async()=>
  page.evaluate(()=>{
    const panel=document.getElementById('mobileNav').getBoundingClientRect();
    return panel.width<=innerWidth*.86+1 && panel.width>=innerWidth*.8 &&
      [...document.querySelectorAll('#mobileNav .tab')]
        .filter(b=>getComputedStyle(b).display!=='none')
        .every(b=>parseFloat(getComputedStyle(b).fontSize)>=14);
  }));
await cerrarPorGesto();
await page.setViewportSize({width:390,height:844});
await page.evaluate(()=>{areaPortadaTema='dark';aparienciaPortada(true);sincronizarIdentidadUI();});
await abrirPorGesto();
await check('el cajón adopta la superficie y el texto del modo oscuro',async()=>
  page.evaluate(()=>{
    const estilo=getComputedStyle(document.getElementById('mobileNav'));
    return estilo.backgroundColor==='rgb(12, 16, 14)' && estilo.color==='rgb(246, 255, 248)';
  }));
await cerrarPorGesto();
await page.evaluate(()=>{areaPortadaTema='light';aparienciaPortada(true);sincronizarIdentidadUI();});
for(const ruta of ['lama','arqueo','movcaja','inv','reparto','mermas','recetas']){
  await abrirPorGesto();
  await page.click(`#mobileNav .tab[data-tab="${ruta}"]`);
  await check(`menú móvil abre ${ruta} por su ruta real`,async()=>page.evaluate(r=>
    vistaActual===r && !document.body.classList.contains('mobile-menu-open'),ruta));
}
await page.click('[data-mobile-tab="inv"]');
await check('barra inferior usa la ruta original',async()=>
  page.evaluate(()=>vistaActual==='inv' && document.querySelector('.tab[data-tab="inv"]').classList.contains('active')));
await check('etiqueta de Inventario no se alarga al cargar el modo',async()=>
  page.locator('[data-mobile-tab="inv"] span').textContent().then(t=>t==='Inventario'));
await page.click('[data-mobile-tab="lama"]');
await check('Mesas se abre pulsando el acceso móvil real',async()=>
  page.evaluate(()=>vistaActual==='lama'&&document.querySelector('[data-mobile-tab="lama"]').getAttribute('aria-current')==='page'));
await page.click('[data-mobile-tab="inv"]');
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
await page.setViewportSize({width:390,height:775});
const viewportReducido=await medirBarra();
await page.setViewportSize({width:390,height:844});
const viewportRestaurado=await medirBarra();
await check('Safari puede cambiar el viewport sin cambiar la altura de la barra',async()=>
  [inventario,viewportReducido,viewportRestaurado].every(m=>Math.abs(m.height-68)<1 && Math.abs(m.bottom)<1));
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
await check('menú e identidad de los módulos conservan el naranja de marca',async()=>
  page.evaluate(()=>getComputedStyle(document.querySelector('.mobile-bottom-item.active')).color===
    'rgb(243, 91, 4)'));
await page.evaluate(()=>{AJUSTES_VAL={'modo_demostracion|':true};PERMISOS.puede_lama=true;aplicarPermisos();pickTab('lama');});
await check('sesión de Local 1 conserva Mesas visible y navegable en modo demostración',async()=>
  page.evaluate(()=>vistaActual==='lama' && getComputedStyle(document.getElementById('tabLama')).display!=='none'));
await page.evaluate(()=>{PERMISOS.puede_lama=false;aplicarPermisos();});
await check('quitar el permiso administrativo no oculta la operación diaria de Mesas',async()=>
  page.evaluate(()=>document.getElementById('tabLama').style.display!=="none"));
await page.evaluate(()=>{pickTab('lama');});
await check('usuario autenticado de Local 1 abre Mesas por la ruta real',async()=>
  page.evaluate(()=>vistaActual==='lama'));
await page.evaluate(()=>{aplicarNavegacionDemo();});
await check('modo demostración mantiene rutas permitidas',async()=>
  page.locator('#mobileBottom button:visible').count().then(n=>n===4));
await page.evaluate(()=>{AJUSTES_VAL={};pickSede('central');});
await check('Bodega ofrece Recibir y Enviar, no Mesas',async()=>
  page.evaluate(()=>!!document.querySelector('[data-mobile-tab="recepcion"]:not([hidden])') &&
    !!document.querySelector('[data-mobile-tab="envios"]:not([hidden])') &&
    !document.querySelector('[data-mobile-tab="lama"]')));
await check('Bodega conserva Recibir y Enviar visibles también en el menú lateral',async()=>
  page.evaluate(()=>['recepcion','envios'].every(ruta=>
    getComputedStyle(document.querySelector(`.tab[data-tab="${ruta}"]`)).display!=='none')));
await page.setViewportSize({width:1280,height:800});
await page.waitForTimeout(100);
await check('escritorio conserva el riel y oculta la barra inferior',async()=>
  page.evaluate(()=>getComputedStyle(document.body).paddingLeft!=='0px' &&
    getComputedStyle(document.getElementById('mobileBottom')).display==='none' &&
    !document.getElementById('mobileNav').inert));
await check('Bodega conserva el mismo riel compacto que Inventario',async()=>
  page.evaluate(()=>{
    /* Esta página conserva un puntero táctil aunque se agrande su viewport.
       En un escritorio real el riel es 72; en una tablet ancha mantiene 208
       para no esconder rutas sin posibilidad de hover. */
    const compacto=matchMedia('(hover:hover) and (pointer:fine)').matches;
    const esperado=compacto?72:208;
    const riel=document.getElementById('mobileNav').getBoundingClientRect().width;
    const cuerpo=parseFloat(getComputedStyle(document.body).paddingLeft);
    return Math.abs(riel-esperado)<1 && Math.abs(cuerpo-esperado)<1
      || `fino=${compacto}; esperado=${esperado}; riel=${riel}; cuerpo=${cuerpo}`;
  }));
await check('sin errores JavaScript',async()=>{if(errors.length)console.error(errors);return errors.length===0;});
await browser.close();
