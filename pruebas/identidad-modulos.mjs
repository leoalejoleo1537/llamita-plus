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
await page.evaluate(()=>pickTab('inv'));
await verificar(()=>page.evaluate(()=>Math.abs(document.querySelector('.tabs').getBoundingClientRect().width-72)<1),
  'Inventario usa el riel compacto de 72 px en escritorio');
await page.mouse.move(36,220);await page.waitForTimeout(260);
await verificar(()=>page.evaluate(()=>{
  const rail=document.querySelector('.tabs').getBoundingClientRect();
  const main=document.querySelector('#view-inv').getBoundingClientRect();
  const label=document.querySelector('.tab.active .nav-label');
  return Math.abs(rail.width-208)<1&&Math.abs(main.left-72)<1
    &&Number(getComputedStyle(label).opacity)>0.9;
}),'el riel se expande sobre el contenido sin moverlo');
if(capturas)await page.screenshot({path:join(capturas,'riel-desplegado-escritorio.png')});
await page.mouse.move(520,220);await page.waitForTimeout(260);
await verificar(()=>page.evaluate(()=>{
  const rail=document.querySelector('.tabs').getBoundingClientRect();
  const label=document.querySelector('.tab.active .nav-label');
  return Math.abs(rail.width-72)<1&&Number(getComputedStyle(label).opacity)<0.1;
}),'al retirar el puntero el riel se repliega sin desorden');
for(const [ruta,titulo] of Object.entries({
  lama:'Mesas',arqueo:'Arqueo',movcaja:'Movimientos de caja',productos:'Panel de productos',reparto:'Reparto',
  recetas:'Recetas',hist:'Historial',mermas:'Mermas',ajustes:'Ajustes'
})){
  await page.evaluate(r=>pickTab(r),ruta);
  await page.waitForTimeout(60);
  await verificar(()=>page.evaluate(t=>!document.getElementById('uxModuleHead').hidden &&
    document.getElementById('uxModuleTitle').textContent===t,titulo),`${ruta}: título visible`);
  await verificar(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),
    `${ruta}: sin desborde horizontal en escritorio`);
  await verificar(()=>page.evaluate(()=>Math.abs(document.querySelector('.tabs').getBoundingClientRect().width-72)<1),
    `${ruta}: riel conserva el mismo ancho compacto que Inventario`);
  if(capturas)await page.screenshot({path:join(capturas,`${ruta}-escritorio.png`)});
}
await page.evaluate(()=>{
  PERMISOS.puede_ajustes=true;
  AJ_AREAS=[
    {id:'area-cafe',nombre:'Cafetería',estado:'activa',orden:10,productos_preferidos:12,unidades:34,ubicacion_activa:true},
    {id:'area-barra',nombre:'Barra',estado:'activa',orden:20,productos_preferidos:8,unidades:11,ubicacion_activa:true}
  ];
  AJ_AREA_SEC_AREA='area-cafe';
  AJ_AREA_SEC_FILAS=[
    {id:'sec-1',nombre:'Refrigerador',estado:'activa',orden:10,turno:'am',productos_configurados:5},
    {id:'sec-2',nombre:'Vitrina',estado:'activa',orden:20,turno:'pm',productos_configurados:7}
  ];
  pickTab('ajustes');ajActual='areas';pintarAjustes();
});
if(capturas)await page.screenshot({path:join(capturas,'ajustes-areas-escritorio.png')});
await verificar(()=>page.evaluate(()=>{
  const titulo=document.querySelector('#view-ajustes .aj-cab h2'),fila=document.querySelector('.area-admin-row'),
    nombre=fila?.querySelector('.area-admin-name-field'),orden=fila?.querySelector('.area-admin-order'),
    acciones=fila?.querySelector('.area-admin-actions');
  const rn=nombre?.getBoundingClientRect(),ro=orden?.getBoundingClientRect(),ra=acciones?.getBoundingClientRect();
  return titulo&&getComputedStyle(titulo).color===getComputedStyle(document.body).color&&
    fila&&getComputedStyle(fila).borderRadius==='16px'&&rn&&ro&&ra&&
    rn.right<=ro.left+1&&ra.top>=ro.bottom-1&&fila.getBoundingClientRect().right<=innerWidth&&
    document.documentElement.scrollWidth<=innerWidth+2;
}),'Ajustes usa tarjetas alineadas para Áreas de inventario');
await page.setViewportSize({width:390,height:844});
await page.waitForTimeout(280);
await verificar(()=>page.evaluate(()=>{
  const fila=document.querySelector('.area-admin-row'),nombre=fila?.querySelector('.area-admin-name-field'),
    orden=fila?.querySelector('.area-admin-order'),acciones=fila?.querySelector('.area-admin-actions');
  const rf=fila?.getBoundingClientRect(),rn=nombre?.getBoundingClientRect(),ro=orden?.getBoundingClientRect(),ra=acciones?.getBoundingClientRect();
  return rf&&rn&&ro&&ra&&rf.right<=innerWidth&&rn.right<=ro.left+1&&
    ra.top>=Math.max(rn.bottom,ro.bottom)-1&&document.documentElement.scrollWidth<=innerWidth+2;
}),'Áreas de inventario conserva tarjetas legibles en teléfono');
if(capturas)await page.screenshot({path:join(capturas,'ajustes-areas-movil.png')});
await page.setViewportSize({width:1440,height:900});
await page.evaluate(()=>{ajActual='secciones';pintarAjustes()});
await verificar(()=>page.evaluate(()=>{
  const fila=document.querySelector('.area-section-admin-row');
  return fila&&fila.getBoundingClientRect().right<=innerWidth&&document.documentElement.scrollWidth<=innerWidth+2;
}),'Secciones y turnos no superpone campos en escritorio');
if(capturas)await page.screenshot({path:join(capturas,'ajustes-secciones-escritorio.png')});
await page.evaluate(()=>pickTab('productos'));
await verificar(()=>page.evaluate(()=>document.body.classList.contains('ux-module-active')&&
  document.getElementById('uxModuleTitle').textContent==='Panel de productos'),
  'Productos conserva la identidad al volver a entrar');
await page.evaluate(()=>pickTab('movcaja'));
await page.waitForTimeout(180);
await page.evaluate(()=>{
  LAMA_ARQ={id:901,sede:'plaza',estado:'abierta',abierto_at:new Date().toISOString()};
  MOVCAJA_LISTA=[{id:1,tipo:'egreso',monto:12500,nota:'Compra de hielo',creado_por:'Prueba',created_at:new Date().toISOString()}];
  movCajaPintarForm();movCajaPintarLista();
});
await verificar(()=>page.evaluate(()=>!!document.querySelector('[data-movcaja="nuevo"]')&&
  document.querySelector('#view-movcaja .movcaja-lista-head')?.textContent.includes('Historial')),
  'Movimientos muestra una acción permanente y el historial rediseñado');
await page.click('[data-movcaja="nuevo"]');
await page.waitForTimeout(80);
await verificar(()=>page.evaluate(()=>document.querySelector('#movcaja-overlay [role="dialog"]')?.getAttribute('aria-modal')==='true'&&
  document.activeElement?.id==='movcaja-monto'),'Nuevo movimiento abre el formulario y lleva el foco al monto');
await verificar(()=>page.evaluate(()=>['egreso','ingreso'].every(tipo=>
  !!document.querySelector(`[data-movcaja-tipo="${tipo}"]`))),'el formulario conserva ingreso y egreso');
if(capturas)await page.screenshot({path:join(capturas,'movimientos-modal-escritorio.png')});
await page.click('#movcaja-overlay .movcaja-x');
await verificar(()=>page.evaluate(()=>!document.getElementById('movcaja-overlay')),
  'Cancelar cierra sin escribir un movimiento');
await verificar(()=>page.evaluate(()=>{
  const s=document.createElement('span');s.className='repc-bod';s.textContent='bodega: 8';
  const caja=document.createElement('div');caja.style.background='var(--card)';caja.append(s);document.body.append(caja);
  const color=getComputedStyle(s).color,fondo=getComputedStyle(caja).backgroundColor;
  caja.remove();return color!==fondo&&color==='rgb(153, 64, 14)';
}),'el texto de stock de Bodega usa tinta legible, no el color del fondo');
await page.evaluate(()=>pickTab('lama'));
await verificar(()=>page.evaluate(()=>{
  const lateral=getComputedStyle(document.querySelector('.tabs'));
  return getComputedStyle(document.body).backgroundColor==='rgb(246, 255, 248)' &&
    lateral.backgroundColor==='rgb(255, 255, 255)' &&
    getComputedStyle(document.querySelector('.tab.active')).color==='rgb(23, 23, 23)';
}),'Mesas comparte el fondo hueso, lateral claro y texto del selector de áreas');
await page.waitForSelector('#lama-mesas .lama-mesa');
await page.locator('#lama-mesas .lama-mesa').first().click();
await verificar(()=>page.evaluate(()=>document.querySelector('#lama-panel')?.textContent.includes('Mesa 1')),
  'Mesas abre su panel real sin crear una cuenta');
if(capturas)await page.screenshot({path:join(capturas,'lama-mesa-seleccionada-escritorio.png')});
await page.click('#uxThemeToggle');
await verificar(()=>page.evaluate(()=>document.body.classList.contains('identidad-oscura') &&
  document.getElementById('uxThemeToggle').getAttribute('aria-pressed')==='true'),
  'modo oscuro aplicado y anunciado');
await page.evaluate(()=>pickTab('lama'));
await verificar(()=>page.evaluate(()=>{
  const lateral=getComputedStyle(document.querySelector('.tabs'));
  return getComputedStyle(document.body).backgroundColor==='rgb(16, 21, 18)' &&
    lateral.backgroundColor==='rgb(12, 16, 14)';
}),'Mesas comparte los tonos oscuros del selector de áreas');
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
await page.keyboard.press('Escape');
await verificar(()=>page.evaluate(()=>{
  const cols=getComputedStyle(document.querySelector('#lama-mesas')).gridTemplateColumns;
  return cols.split(' ').length===3;
}),'Mesas en teléfono muestra el plano en tres columnas');
await page.locator('#lama-mesas .lama-mesa').first().click();
if(capturas)await page.screenshot({path:join(capturas,'lama-mesa-seleccionada-telefono.png')});
await verificar(()=>page.evaluate(()=>{
  return document.querySelector('#lama-panel').getAttribute('role')==='dialog' &&
    !document.getElementById('lama-panel-scrim').hidden;
}),'seleccionar una mesa abre su ficha inferior');
await verificar(()=>page.evaluate(()=>{
  const panel=document.querySelector('#lama-panel'),nav=document.getElementById('mobileBottom');
  return panel.getBoundingClientRect().bottom<=nav.getBoundingClientRect().top+1;
}),'la ficha queda por encima de la navegación inferior');
await verificar(()=>page.evaluate(()=>!document.querySelector('#lama-fab .lama-fab')?.getClientRects().length),
  'la ficha evita que el botón flotante se superponga al detalle');
await page.keyboard.press('Escape');
await verificar(()=>page.evaluate(()=>document.getElementById('lama-panel-scrim').hidden),
  'Escape cierra la ficha y devuelve el plano');
await page.locator('#lama-mesas .lama-mesa').first().click();
await page.locator('#lama-panel-scrim').click();
await verificar(()=>page.evaluate(()=>document.getElementById('lama-panel-scrim').hidden),
  'tocar fuera de la ficha también la cierra');
for(const ruta of ['lama','arqueo','movcaja','reparto','recetas','hist','mermas','ajustes']){
  await page.evaluate(r=>pickTab(r),ruta);
  await page.waitForTimeout(220);
  await verificar(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),
    `${ruta}: sin desborde horizontal en teléfono`);
  if(capturas)await page.screenshot({path:join(capturas,`${ruta}-telefono.png`)});
}
await page.evaluate(()=>pickTab('movcaja'));
await page.waitForTimeout(180);
await page.evaluate(()=>{
  LAMA_ARQ={id:902,sede:'plaza',estado:'abierta',abierto_at:new Date().toISOString()};
  movCajaPintarForm();movCajaPintarLista();
});
await page.click('[data-movcaja="nuevo"]');
await page.waitForTimeout(240);
await verificar(()=>page.evaluate(()=>{
  const dialog=document.querySelector('#movcaja-overlay .movcaja-dialog');
  return !!dialog&&Math.abs(dialog.getBoundingClientRect().bottom-innerHeight)<1&&
    document.documentElement.scrollWidth<=innerWidth+2;
}),'Nuevo movimiento es una hoja inferior sin desborde en teléfono');
if(capturas)await page.screenshot({path:join(capturas,'movimientos-modal-telefono.png')});
await page.keyboard.press('Escape');
await verificar(()=>page.evaluate(()=>!document.getElementById('movcaja-overlay')),
  'Escape cierra Nuevo movimiento sin guardar');
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
await verificar(()=>page.evaluate(()=>!renderRepartoResults.toString().includes('tl-pista')),
  'buscar en Reparto no agrega el texto auxiliar encima de los resultados');
await page.evaluate(()=>{
  DATA=[{id:701,sede:'plaza',producto:'Salsa de caramelo',rubro:'Cafetería',stock_actual:8,stock_min:2,stock_max:12,activo:'SÍ'}];
  carrito=[];rqEl.value='salsa';renderRepartoResults();
});
await verificar(()=>page.evaluate(()=>{
  const fila=document.querySelector('#reparto-results .rep-result');
  return fila?.tagName==='BUTTON'&&!fila.querySelector('.rs')&&
    !fila.textContent.includes('mín')&&!fila.textContent.includes('máx')&&
    fila.getBoundingClientRect().height<=50&&document.documentElement.scrollWidth<=innerWidth+2;
}),'búsqueda de Reparto reduce el resultado a producto, disponibilidad y acción en teléfono');
await page.locator('#reparto-results .rep-result').click();
await verificar(()=>page.evaluate(()=>carrito.length===1&&carrito[0].id===701),
  'el resultado compacto agrega al carrito con el handler existente');
await page.setViewportSize({width:1440,height:900});
await page.evaluate(()=>{carrito=[];renderCarrito();rqEl.value='salsa';renderRepartoResults();});
await verificar(()=>page.evaluate(()=>{
  const fila=document.querySelector('#reparto-results .rep-result');
  return fila&&fila.getBoundingClientRect().height<=58&&
    fila.querySelector('.rep-hay')?.textContent.trim()==='8'&&
    document.documentElement.scrollWidth<=innerWidth+2;
}),'búsqueda de Reparto mantiene una fila concisa y legible en escritorio');
if(capturas)await page.screenshot({path:join(capturas,'reparto-busqueda-escritorio.png')});
await page.setViewportSize({width:390,height:844});
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
await page.click('#uxBodegaTabs [data-ux-tab="envios"]');
await page.waitForTimeout(80);
await page.evaluate(()=>{
  F2_RESULTADOS=[{producto:'Salsa de caramelo',producto_bodega_id:2,producto_plaza_id:7,configurado_en_area:true,
    buckets:[{etiqueta:'Lote 10/12',cantidad:8,lote_id:4,vencimiento:'2026-12-10'}]}];
  F2_CARRITO=[{producto:'Azúcar blanca',producto_bodega_id:3,producto_plaza_id:8,etiqueta:'Sin lote',disponible:12,cantidad:4}];
  F2_CARRITO_AREA='area-cafe';f2PintarResultados();f2PintarCarrito();
});
await verificar(()=>page.evaluate(()=>{
  const texto=document.getElementById('f2-resultados').textContent,qty=document.querySelector('#f2-lineas .f2-qty');
  const activas=[...document.querySelectorAll('#uxBodegaTabs button.active')].map(b=>b.dataset.uxTab);
  const enviar=document.querySelector('#uxBodegaTabs [data-ux-tab="envios"]'),enlaces=document.querySelector('#uxBodegaTabs [data-ux-tab="enlaces"]');
  return activas.length===1&&activas[0]==='envios'&&getComputedStyle(enviar).backgroundColor!==getComputedStyle(enlaces).backgroundColor&&
    !texto.includes('Bodega #')&&qty&&getComputedStyle(qty).borderRadius==='12px'&&
    document.documentElement.scrollWidth<=innerWidth+2;
}),'Bodega Enviar evita identificadores técnicos y cantidades en píldora');
if(capturas)await page.screenshot({path:join(capturas,'bodega-envios-lista-telefono.png')});
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
