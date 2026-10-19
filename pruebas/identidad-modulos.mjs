/* Capa visual v1: rutas reales, modo oscuro, hojas móviles y navegación de Bodega.
   Solo datos sintéticos en memoria; ninguna llamada de escritura remota. */
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { mkdirSync } from 'node:fs';
import { abrirNavegador } from './navegador.mjs';

const browser=await abrirNavegador();
if(!browser){console.log('(se salta identidad: no hay Chromium)');process.exit(0);}
const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const capturas=process.env.UX_IDENTIDAD_SHOTS_DIR;
if(capturas)mkdirSync(capturas,{recursive:true});
const page=await browser.newPage({viewport:{width:1440,height:900}});
const errores=[];
page.on('pageerror',e=>errores.push(e.message));
await page.addInitScript(()=>{
  const user={id:'ux-user',email:'ux@test.invalid',user_metadata:{nombre:'Prueba'}};
  const session={user};
  const permiso={auth_uid:user.id,correo:user.email,nombre:'Prueba',puede_editar:true,
    puede_ajustes:true,puede_fudo:false,puede_lama:true,fudo_bloqueos:[]};
  const tablas={mesas:[
    {id:41,sede:'plaza',numero:1,salon:'Salón',orden:1,activa:true},
    {id:42,sede:'plaza',numero:2,salon:'Salón',orden:2,activa:true}
  ],productos:[
    {id:1,sede:'plaza',producto:'Leche entera',rubro:'Lácteos',tipo:'Leche',stock_actual:0,stock_min:3,stock_max:12,activo:'SÍ'},
    {id:2,sede:'central',producto:'Leche entera',rubro:'Lácteos',tipo:'Leche',stock_actual:8,stock_min:3,stock_max:12,activo:'SÍ'}
  ]};
  const q=name=>{
    let filas=JSON.parse(JSON.stringify(tablas[name]||[]));
    const api={select(){return api;},eq(c,v){filas=filas.filter(f=>String(f[c])===String(v));return api;},
      neq(){return api;},in(){return api;},order(){return api;},limit(){return api;},
      range(){return api;},gte(){return api;},lte(){return api;},lt(){return api;},
      is(){return api;},not(){return api;},or(){return api;},ilike(){return api;},
      maybeSingle(){return Promise.resolve({data:filas[0]||null,error:null});},
      single(){return Promise.resolve({data:filas[0]||null,error:null});},
      then(done){return Promise.resolve({data:filas,error:null}).then(done);}};
    return api;
  };
  window.supabase={createClient:()=>({
    from:q,
    rpc:name=>{
      const data=name==='permisos_mios'?permiso:[];
      return {maybeSingle:()=>Promise.resolve({data,error:null}),
        then:done=>Promise.resolve({data,error:null}).then(done)};
    },
    auth:{getSession:async()=>({data:{session}}),getUser:async()=>({data:{user}}),
      onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({})},
    channel:()=>({on(){return this;},subscribe(cb){cb?.('SUBSCRIBED');return this;},
      track:async()=>{},presenceState:()=>({})}),removeChannel(){},
    functions:{invoke:async()=>({data:{ok:true},error:null})}
  })};
});
await page.route('**/supabase-js*',r=>r.fulfill({status:200,contentType:'application/javascript',body:'/* simulador */'}));
await page.goto(pathToFileURL(join(raiz,'index.html')).href);
await page.evaluate(()=>{pickSede('plaza');PERMISOS.puede_lama=true;PERMISOS.puede_ajustes=true;aplicarPermisos();});
await page.waitForTimeout(250);

const verificar=async(condicion,mensaje)=>{
  if(!await condicion())throw Error(mensaje);
  console.log('✓ '+mensaje);
};
await verificar(()=>page.evaluate(()=>document.documentElement.dataset.paleta==='lapiz'),
  'Lápiz y papel es la paleta inicial');
for(const [ruta,titulo] of Object.entries({
  lama:'Mesas',arqueo:'Arqueo',movcaja:'Movimientos de caja',reparto:'Reparto',
  recetas:'Recetas',hist:'Historial',mermas:'Mermas',ajustes:'Ajustes'
})){
  await page.evaluate(r=>pickTab(r),ruta);
  await page.waitForTimeout(60);
  await verificar(()=>page.evaluate(t=>!document.getElementById('uxModuleHead').hidden &&
    document.getElementById('uxModuleTitle').textContent===t,titulo),`${ruta}: título visible`);
  await verificar(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),
    `${ruta}: sin desborde horizontal en escritorio`);
  if(capturas)await page.screenshot({path:join(capturas,`${ruta}-escritorio.png`)});
}
await page.evaluate(()=>pickTab('lama'));
await page.waitForSelector('#lama-mesas .lama-mesa');
await page.locator('#lama-mesas .lama-mesa').first().click();
await verificar(()=>page.evaluate(()=>document.querySelector('#lama-panel')?.textContent.includes('Mesa 1')),
  'Mesas abre su panel real sin crear una cuenta');
await page.click('#uxThemeToggle');
await verificar(()=>page.evaluate(()=>document.body.classList.contains('identidad-oscura') &&
  document.getElementById('uxThemeToggle').getAttribute('aria-pressed')==='true'),
  'modo oscuro aplicado y anunciado');
await page.evaluate(()=>pickTab('recetas'));
await verificar(()=>page.evaluate(()=>document.body.classList.contains('identidad-oscura')),
  'modo oscuro persiste al navegar');
if(capturas)await page.screenshot({path:join(capturas,'recetas-oscuro-escritorio.png')});
await page.evaluate(()=>pickTab('mermas'));
if(capturas)await page.screenshot({path:join(capturas,'mermas-oscuro-escritorio.png')});
for(const ruta of ['lama','arqueo','ajustes']){
  await page.evaluate(r=>pickTab(r),ruta);
  await page.waitForTimeout(80);
  if(capturas)await page.screenshot({path:join(capturas,`${ruta}-oscuro-escritorio.png`)});
}
await page.click('#uxThemeToggle');

await page.setViewportSize({width:390,height:844});
await page.waitForTimeout(260);
await page.evaluate(()=>pickTab('lama'));
await verificar(()=>page.evaluate(()=>{
  const fab=document.querySelector('#lama-fab .lama-fab')?.getBoundingClientRect();
  const nav=document.getElementById('mobileBottom').getBoundingClientRect();
  return !!fab&&fab.bottom<nav.top-5;
}),'la acción de Mesas no tapa la navegación inferior');
for(const ruta of ['lama','arqueo','movcaja','reparto','recetas','hist','mermas','ajustes']){
  await page.evaluate(r=>pickTab(r),ruta);
  await page.waitForTimeout(220);
  await verificar(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),
    `${ruta}: sin desborde horizontal en teléfono`);
  if(capturas)await page.screenshot({path:join(capturas,`${ruta}-telefono.png`)});
}
await page.evaluate(()=>pickTab('arqueo'));
await page.locator('#view-arqueo [data-arqp="nuevo"]').first().click();
await verificar(()=>page.evaluate(()=>!!document.querySelector('#arqd-monto')),
  'Arqueo abre su formulario existente sin guardar');
await page.locator('#view-arqueo [data-arqp="cancelar-nuevo"]').click();
await verificar(()=>page.evaluate(()=>!document.querySelector('#arqd-monto')),
  'Cancelar vuelve al arqueo sin escritura');
await page.evaluate(()=>pickTab('lama'));
await page.locator('#lama-arq-banner [data-lamaarq="abrir"]').click();
await verificar(()=>page.evaluate(()=>vistaActual==='arqueo'&&ARQPAG_SEL==='nuevo'),
  'el aviso de caja en Mesas lleva al arqueo real');
await page.evaluate(()=>pickTab('recetas'));
await page.waitForTimeout(180);
await page.evaluate(()=>{FUDOPROD=[{fudo_product_id:77,nombre:'Combo de prueba',code:'UX'}];});
await page.locator('#btnNuevaReceta').click();
await verificar(()=>page.evaluate(()=>document.getElementById('overlay-receta').classList.contains('open')),
  'Crear combo abre la ventana real');
await page.waitForTimeout(80);
await verificar(()=>page.evaluate(()=>document.getElementById('overlay-receta').contains(document.activeElement)),
  'el teclado entra al diálogo de Recetas');
if(capturas)await page.screenshot({path:join(capturas,'recetas-modal-telefono.png')});
await page.keyboard.press('Escape');
await verificar(()=>page.evaluate(()=>!document.getElementById('overlay-receta').classList.contains('open')),
  'Escape cierra Crear combo sin guardar');
await verificar(()=>page.evaluate(()=>document.activeElement?.id==='btnNuevaReceta'),
  'el foco vuelve a Crear combo');
await page.evaluate(()=>pickTab('reparto'));
await verificar(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),
  'Reparto sin desborde horizontal en teléfono');
await page.evaluate(()=>{preguntar('¿Continuar?','Prueba visual','Sí').then(v=>window.__uxRespuesta=v);});
await verificar(()=>page.evaluate(()=>document.getElementById('overlay-ask').classList.contains('open') &&
  getComputedStyle(document.getElementById('overlay-ask')).alignItems==='flex-end'),
  'confirmación como hoja inferior en teléfono');
await page.waitForTimeout(80);
await verificar(()=>page.evaluate(()=>document.getElementById('overlay-ask').contains(document.activeElement)),
  'el teclado entra a la confirmación');
if(capturas)await page.screenshot({path:join(capturas,'confirmacion-telefono.png')});
await page.keyboard.press('Escape');
await verificar(()=>page.evaluate(()=>!document.getElementById('overlay-ask').classList.contains('open') &&
  window.__uxRespuesta===false),'Escape cancela sin confirmar');
await page.evaluate(()=>{preguntar('¿Continuar?','Prueba visual','Sí').then(v=>window.__uxRespuesta=v);});
await page.locator('#overlay-ask').click({position:{x:4,y:4}});
await verificar(()=>page.evaluate(()=>!document.getElementById('overlay-ask').classList.contains('open') &&
  window.__uxRespuesta===false),'toque fuera cancela sin confirmar');
await page.evaluate(()=>pickTab('lama'));
await verificar(()=>page.evaluate(()=>document.getElementById('tabLama').style.display!=='none'),
  'Mesas conserva su acceso de menú móvil con permiso');
await page.evaluate(()=>{PERMISOS.puede_lama=false;aplicarPermisos();});
await verificar(()=>page.evaluate(()=>document.getElementById('tabLama').style.display==='none'),
  'Mesas se oculta al retirar permiso');

await page.evaluate(()=>pickSede('central'));
await page.waitForTimeout(150);
await verificar(()=>page.evaluate(()=>document.getElementById('uxModuleTitle').textContent==='Bodega' &&
  !document.getElementById('uxBodegaTabs').hidden),'Bodega agrupa sus cuatro vistas');
for(const ruta of ['inv','recepcion','envios','enlaces']){
  await page.click(`#uxBodegaTabs [data-ux-tab="${ruta}"]`);
  await page.waitForTimeout(100);
  await verificar(()=>page.evaluate(r=>vistaActual===r &&
    document.querySelector(`#uxBodegaTabs [data-ux-tab="${r}"]`).getAttribute('aria-current')==='page',ruta),
    `Bodega ${ruta}: subnavegación reutiliza la ruta real`);
  await verificar(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),
    `Bodega ${ruta}: sin desborde horizontal en teléfono`);
  if(capturas)await page.screenshot({path:join(capturas,`bodega-${ruta}-telefono.png`)});
}
await page.click('#uxThemeToggle');
await page.waitForTimeout(250);
await verificar(()=>page.evaluate(()=>document.body.classList.contains('identidad-oscura')&&
  document.documentElement.scrollWidth<=innerWidth+2),'Bodega mantiene modo oscuro sin desborde');
if(capturas)await page.screenshot({path:join(capturas,'bodega-enlaces-oscuro-telefono.png')});
await page.setViewportSize({width:1440,height:900});
for(const ruta of ['inv','recepcion','envios','enlaces']){
  await page.click(`#uxBodegaTabs [data-ux-tab="${ruta}"]`);
  await page.waitForTimeout(120);
  await verificar(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),
    `Bodega ${ruta}: sin desborde horizontal en escritorio`);
  if(capturas)await page.screenshot({path:join(capturas,`bodega-${ruta}-oscuro-escritorio.png`)});
}
if(process.env.UX_IDENTIDAD_SHOT)await page.screenshot({path:process.env.UX_IDENTIDAD_SHOT,fullPage:true});
await verificar(()=>Promise.resolve(errores.length===0),'sin errores JavaScript');
await browser.close();
