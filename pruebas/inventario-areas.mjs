/* Portada y navegación de lectura por ubicación. Ejecutar con:
   CHROME_PATH=/ruta/al/chromium node pruebas/inventario-areas.mjs */
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const browser=await abrirNavegador();
if(!browser){console.log('(se salta: no hay Chromium instalado)');process.exit(0);}

const productos=[
  {id:1,sede:'plaza',producto:'Leche entera',rubro:'Lácteos',tipo:'Envasados',unidad:'L',stock_actual:999,stock_min:1,activo:'SÍ'},
  {id:2,sede:'plaza',producto:'Azúcar blanca',rubro:'Endulzantes',tipo:'Envasados',unidad:'kg',stock_actual:999,stock_min:1,activo:'SÍ'},
  {id:3,sede:'central',producto:'Leche Bodega',rubro:'Lácteos',tipo:'Envasados',unidad:'L',stock_actual:17,stock_min:1,activo:'SÍ'},
];
const areas=['cocina_fria','cocina_caliente','barra','cafeteria','heladeria','sin_asignar'];
const nombres={cocina_fria:'Cocina fría',cocina_caliente:'Cocina caliente',barra:'Barra',cafeteria:'Cafetería',heladeria:'Heladería',sin_asignar:'Sin asignar'};
const catalogo=areas.filter(x=>x!=='sin_asignar').map((codigo,i)=>({id:`area-${i}`,sede:'plaza',codigo,nombre:nombres[codigo],estado:'activa',orden:i,productos_preferidos:0,productos_con_saldo:0,unidades:0}));
const saldos={'1|cafeteria':3,'1|barra':2,'1|sin_asignar':5,'2|sin_asignar':7};
const lectura=areas.flatMap((codigo,i)=>productos.filter(p=>p.sede==='plaza').map(p=>({
  area_codigo:codigo,area_nombre:nombres[codigo],area_orden:i,
  area_id:codigo==='sin_asignar'?null:catalogo.find(a=>a.codigo===codigo)?.id||null,
  ubicacion_id:`loc-${codigo}`,configurado:codigo==='cafeteria',es_principal:codigo==='cafeteria',
  producto_id:p.id,producto:p.producto,rubro:p.rubro,tipo:p.tipo,unidad:p.unidad,
  cantidad:saldos[`${p.id}|${codigo}`]||0,
})));
const permisos=[{correo:'lectura@test.invalid',nombre:'Lectura',puede_editar:true,puede_fudo:false,puede_ajustes:true,puede_lama:false}];
const page=await browser.newPage();
await page.addInitScript(({productos,permisos,lectura,catalogo})=>{
  window.__writes=[];window.__rpc=[];window.__rpcArgs=[];
  const SES={user:{id:'b3-read-user',email:'lectura@test.invalid',user_metadata:{nombre:'Lectura'}}};
  const tables={productos,app_permisos:permisos,secciones:[],ajustes:[],metas:[],tareas:[],
    fudo_sync:[],producto_lotes:[],repartos:[],reparto_items:[],mermas:[],recetas:[],
    receta_items:[],movimientos:[],fudo_productos:[],fudo_categorias:[],producto_enlace:[]};
  function query(name){
    let rows=JSON.parse(JSON.stringify(tables[name]||[]));
    const api={select(){return api;},eq(k,v){rows=rows.filter(r=>r[k]===v);return api;},neq(){return api;},in(){return api;},
      order(){return api;},limit(){return api;},gte(){return api;},lte(){return api;},is(){return api;},not(){return api;},
      ilike(){return api;},or(){return api;},maybeSingle(){return Promise.resolve({data:rows[0]||null,error:null});},
      single(){return Promise.resolve({data:rows[0]||null,error:null});},
      update(value){window.__writes.push({table:name,op:'update',value});return api;},
      insert(value){window.__writes.push({table:name,op:'insert',value});return api;},
      upsert(value){window.__writes.push({table:name,op:'upsert',value});return api;},
      delete(){window.__writes.push({table:name,op:'delete'});return api;},
      then(resolve){return Promise.resolve({data:rows,error:null}).then(resolve);}};
    return api;
  }
  window.supabase={createClient:()=>({
    from:query,
    rpc:(name,args)=>{
      window.__rpc.push(name);window.__rpcArgs.push({name,args});
      if(name==='stock_ajuste_desglose_leer'){
        const central=args?.p_ubicacion_id==null;
        const cantidad=central?17:(args?.p_producto_id===1?3:0);
        return Promise.resolve({data:{producto_id:args?.p_producto_id,sede:central?'central':'plaza',ubicacion_id:args?.p_ubicacion_id||'loc-bodega',tiene_lotes:false,saldo_total:cantidad,lotes:[{clave:'sin_lote',lote_id:null,vencimiento:null,etiqueta:'Stock físico',cantidad}]},error:null});
      }
      if(name==='stock_ajuste_guardar')return Promise.resolve({data:{repetido:false,lineas:[{diferencia:0.25}]},error:null});
      return Promise.resolve({data:name==='stock_leer_areas'?lectura:name==='areas_operativas_listar'?catalogo:[],error:null});
    },
    auth:{getSession:async()=>({data:{session:SES}}),getUser:async()=>({data:{user:SES.user}}),
      onAuthStateChange(cb){setTimeout(()=>cb&&cb('SIGNED_IN',SES),0);return {data:{subscription:{unsubscribe(){}}}};},
      signInWithPassword:async()=>({data:{session:SES},error:null}),signOut:async()=>({})},
    channel:()=>({on(){return this;},subscribe(cb){cb&&cb('SUBSCRIBED');return this;},track:async()=>{},presenceState:()=>({})}),
    removeChannel(){},functions:{invoke:async()=>({data:{ok:true},error:null})},
  })};
},{productos,permisos,lectura,catalogo});
await page.route('**/supabase-js*',r=>r.fulfill({status:200,contentType:'application/javascript',body:'/* mock */'}));
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
await page.goto(pathToFileURL(join(raiz,'index.html')).href);
await page.waitForTimeout(250);

const failures=[];
const check=async(name,fn)=>{try{const ok=await fn();if(!ok)failures.push(name);console.log(`${ok?'✓':'✗'} ${name}`);}catch(e){failures.push(name);console.log(`✗ ${name}: ${e.message}`);}};

await page.click('.gate-btn[data-sede="plaza"]');
await page.waitForSelector('[data-area-open="cafeteria"]');
await check('portada muestra las áreas físicas y separa las vistas generales',async()=>
  await page.locator('.area-portal-card').count()===5
  && await page.locator('.area-secondary-view').count()===2);
await check('portada evita cifras y alertas sin contexto',async()=>{
  const t=await page.locator('.area-cover').innerText();
  return ['Cocina fría','Cocina caliente','Barra','Cafetería','Heladería'].every(n=>t.includes(n))
    && !t.includes('unidades')&&!t.includes('críticos')&&!t.includes('sin mínimos configurados');
});
await check('modo oscuro cambia la portada y conserva la elección',async()=>{
  await page.click('[data-area-theme-toggle]');
  const activo=await page.evaluate(()=>document.body.classList.contains('area-portada-oscura')
    &&localStorage.getItem('llamita_areas_tema')==='dark');
  await page.click('[data-area-theme-toggle]');
  return activo&&await page.evaluate(()=>!document.body.classList.contains('area-portada-oscura'));
});
await check('el botón aparece al señalar la tarjeta y el dibujo no lleva texto funcional',async()=>{
  const boton=page.locator('[data-area-open="cafeteria"] .area-portal-card-enter');
  const reposo=await boton.evaluate(el=>getComputedStyle(el.parentElement).opacity);
  await page.locator('[data-area-open="cafeteria"]').hover();
  await page.waitForTimeout(250);
  const visible=await boton.evaluate(el=>getComputedStyle(el.parentElement).opacity);
  return reposo==='0'&&visible==='1'
    &&await page.locator('[data-area-open="cafeteria"] .area-portal-art[aria-hidden="true"]').count()===1;
});
await page.setViewportSize({width:390,height:844});
await page.waitForTimeout(250);
await check('en teléfono hay una columna, acción visible y ningún desborde',async()=>page.evaluate(()=>{
  const grid=document.querySelector('.area-portal-grid');
  const card=document.querySelector('.area-portal-card');
  const reveal=card.querySelector('.area-portal-card-reveal');
  return getComputedStyle(grid).gridTemplateColumns.split(' ').length===1
    &&getComputedStyle(reveal).opacity==='1'
    &&document.documentElement.scrollWidth<=innerWidth;
}));
await page.setViewportSize({width:1280,height:900});
await page.waitForTimeout(250);
if(process.env.CAPTURE_AREAS_SCREENSHOT){
  await page.setViewportSize({width:1600,height:900});
  await page.locator('[data-area-open="cafeteria"]').hover();
  await page.waitForTimeout(300);
  await page.screenshot({path:'/tmp/llamita-areas-desktop.png',fullPage:true});
  await page.click('[data-area-theme-toggle]');
  await page.locator('[data-area-open="cafeteria"]').hover();
  await page.waitForTimeout(300);
  await page.screenshot({path:'/tmp/llamita-areas-desktop-dark.png',fullPage:true});
  await page.click('[data-area-theme-toggle]');
  await page.setViewportSize({width:390,height:844});
  await page.waitForTimeout(350);
  await page.screenshot({path:'/tmp/llamita-areas-mobile.png',fullPage:true});
  await page.setViewportSize({width:1280,height:900});
  await page.waitForTimeout(350);
}
await page.click('[data-area-open="sin_asignar"]');
await check('Sin asignar conserva su lectura de saldos',async()=>{
  const texto=await page.locator('#list').innerText();
  return texto.includes('12 unidades físicas')&&texto.includes('2 con saldo');
});
await page.click('#tabInv');

await page.click('[data-area-open="cocina_fria"]');
await check('el área muestra solo el nombre y oculta la barra redundante',async()=>page.evaluate(()=>
  document.querySelector('#area-page-heading h2')?.textContent==='Cocina fría'
  &&getComputedStyle(document.querySelector('.topbar')).display==='none'
  &&!document.querySelector('[data-area-home]')
  &&!document.querySelector('#area-page-heading').innerText.includes('Inventario del área')
  &&!document.querySelector('#area-page-heading').innerText.includes('Cantidades físicas del área')
  &&!document.querySelector('#list').innerText.includes('con saldo ·')));
await page.click('.area-page-controls [data-area-theme-toggle]');
await check('el modo oscuro se conserva dentro del área y no recupera la barra superior',async()=>page.evaluate(()=>
  document.body.classList.contains('area-portada-oscura')
  &&getComputedStyle(document.querySelector('.topbar')).display==='none'
  &&document.querySelector('#mobileMenuTrigger')));
await page.click('.area-page-controls [data-area-theme-toggle]');
await check('un área sin saldo no muestra el catálogo de otras ubicaciones',async()=>
  (await page.locator('#list .area-read-row').count())===0
  && !(await page.locator('#list').innerText()).includes('Leche entera'));
await page.evaluate(()=>{PERMISOS.puede_editar=true;renderAreaLista()});
if(process.env.CAPTURE_AREAS_SCREENSHOT)await page.screenshot({path:'/tmp/llamita-area-interior-desktop.png',fullPage:true});
await page.setViewportSize({width:390,height:844});
await page.waitForTimeout(250);
if(process.env.CAPTURE_AREAS_SCREENSHOT)await page.screenshot({path:'/tmp/llamita-area-interior-telefono.png'});
await check('en móvil el menú sigue accesible y el botón flotante queda sobre la navegación',async()=>page.evaluate(()=>{
  const fab=document.querySelector('.area-add-fab'),nav=document.querySelector('.mobile-bottom');
  return getComputedStyle(document.querySelector('.topbar')).display==='none'
    &&!document.body.classList.contains('mobile-menu-open')
    &&getComputedStyle(document.querySelector('#mobileMenuTrigger')).display!=='none'
    &&fab?.getAttribute('aria-label')==='Agregar producto de Bodega'
    &&fab?.getBoundingClientRect().bottom<nav.getBoundingClientRect().top
    &&document.documentElement.scrollWidth<=innerWidth;
}));
await page.setViewportSize({width:1280,height:900});
await page.evaluate(()=>{PERMISOS.puede_editar=false;renderAreaLista()});

await page.click('#tabInv');
await page.click('[data-area-open="cafeteria"]');
await page.evaluate(()=>{PERMISOS.puede_editar=true;renderAreaLista()});
await page.fill('#q','leche');
await page.waitForTimeout(30);
await check('buscar leche en Cafetería aísla la lectura a esa ubicación',async()=>{
  const t=await page.locator('#list').innerText();
  const leche=page.locator('#list .row[data-row="1"]');
  return (await page.locator('#topSede').innerText())==='Inventario · Cafetería'
    && t.includes('Leche entera')&&(await leche.locator('input[type="number"]').inputValue())==='3'
    &&(await leche.locator('.area-unit').innerText())==='L'
    &&!t.includes('Azúcar blanca')&&!t.includes('999');
});
await page.locator('#list .row[data-row="1"] [data-quick-stock]').click();
await page.locator('#list .row[data-row="1"] [data-quick-stock]').fill('3.25');
await page.locator('#q').click();
await page.waitForTimeout(30);
await check('la edición rápida guarda al tocar fuera, por ledger, con motivo fijo y sin DML directo',async()=>{
  const llamada=await page.evaluate(()=>window.__rpcArgs.findLast(x=>x.name==='stock_ajuste_guardar'));
  return llamada?.args?.p_producto_id===1&&llamada.args.p_ubicacion_id==='loc-cafeteria'
    &&llamada.args.p_conteos.sin_lote===3.25
    &&llamada.args.p_motivo==='Conteo/corrección manual desde inventario'
    &&await page.locator('#list .row[data-row="1"] [data-quick-stock]').inputValue()==='3.25'
    &&await page.evaluate(()=>window.__writes.length===0);
});
await page.evaluate(()=>{
  REPARTOS_AREA=[
    {id:'rep-abierto',estado:'enviado',nombre:'Reposición cafetería',creado_at:new Date().toISOString(),items:[
      {id:'item-1',producto:'Salsa de caramelo',cantidad_preparada:2,vencimiento:'2026-12-10'},
      {id:'item-2',producto:'Azúcar blanca',cantidad_preparada:4,vencimiento:null}
    ]},
    {id:'rep-cerrado',estado:'recibido',nombre:'Reparto anterior',resultado:{total_recibido:3,total_ajustado:0}}
  ];
  pintarRepartosArea();
});
await check('recepción usa lista compacta e historial plegado',async()=>page.evaluate(()=>
  document.querySelectorAll('.f2-receipt-line').length===2&&
  !document.querySelector('.f2-history').open&&
  !document.getElementById('areaRepartos').textContent.includes('Solo envíos destinados a')&&
  document.documentElement.scrollWidth<=innerWidth));
if(process.env.CAPTURE_AREAS_SCREENSHOT)await page.screenshot({path:'/tmp/llamita-recepcion-area-escritorio.png',fullPage:true});
await page.setViewportSize({width:390,height:844});
await page.waitForTimeout(120);
await check('recepción conserva acciones legibles en teléfono',async()=>page.evaluate(()=>{
  const acciones=document.querySelector('.f2-receipt-actions');
  return acciones&&acciones.getBoundingClientRect().right<=innerWidth&&document.documentElement.scrollWidth<=innerWidth;
}));
if(process.env.CAPTURE_AREAS_SCREENSHOT)await page.screenshot({path:'/tmp/llamita-recepcion-area-telefono.png'});
await page.setViewportSize({width:1280,height:900});
await page.click('[data-f2-rechazar="item-2"]');
await check('la X marca cero sin cerrar ni escribir el reparto',async()=>page.evaluate(()=>
  document.querySelector('[data-f2-recibida="item-2"]').value==='0'&&
  document.querySelector('[data-f2-item="item-2"]').classList.contains('is-rejected')&&
  !window.__rpcArgs.some(x=>x.name==='reparto_area_recibir')));
await page.locator('#list .row[data-row="1"] [data-open]').click();
await page.waitForSelector('#m-ajuste-panel:not([hidden])');
await check('ficha de área ofrece cantidad decimal sin texto técnico ni motivo visible',async()=>
  await page.locator('#m-ajuste-lineas').innerText().then(t=>t.trim()==='Cantidad')
  &&await page.locator('#m-ajuste-motivo').inputValue()==='Conteo/corrección manual'
  &&await page.locator('#m-ajuste-motivo').isHidden()
  &&await page.locator('#m-area-ficha-resumen').isHidden()
  &&await page.locator('#m-ajuste-lineas input').getAttribute('step')==='any'
  &&await page.locator('#m-stock').isDisabled());
if(process.env.CAPTURE_AREAS_SCREENSHOT)await page.screenshot({path:'/tmp/llamita-producto-modal-simplificado.png'});
await page.locator('#m-ajuste-lineas input[data-ajuste-clave="sin_lote"]').fill('3.25');
await page.locator('#m-ajuste-guardar').click();
await page.waitForFunction(()=>!document.getElementById('overlay').classList.contains('open'));
await check('guardar usa la RPC protegida con ubicación, decimal y no hace DML directo',async()=>{
  const llamada=await page.evaluate(()=>window.__rpcArgs.findLast(x=>x.name==='stock_ajuste_guardar'));
  return llamada?.args?.p_producto_id===1&&llamada.args.p_ubicacion_id==='loc-cafeteria'
    &&llamada.args.p_conteos.sin_lote===3.25
    &&await page.evaluate(()=>window.__writes.length===0);
});

await page.evaluate(()=>cambiarArea(null));
await page.click('.area-secondary-view[data-area-open="__todas__"]');
await check('vista global separa las cantidades por área',async()=>{
  const fila=page.locator('.area-global-product').filter({hasText:'Leche entera'});
  const t=await fila.innerText();
  return t.includes('Cafetería')&&t.includes('3.25')&&t.includes('Barra')&&t.includes('2')&&t.includes('Sin asignar')&&t.includes('5');
});
await page.locator('.area-global-link[data-area-open="cafeteria"][data-area-product="Leche entera"]').click();
await check('desde global se abre el producto filtrado dentro de su área',async()=>
  (await page.locator('#topSede').innerText())==='Inventario · Cafetería'
  && (await page.locator('#q').inputValue())==='Leche entera'
  && (await page.locator('#list .row[data-row="1"] input[type="number"]').inputValue())==='3.25');
await check('la navegación de áreas no escribe datos',async()=>
  (await page.evaluate(()=>window.__writes.length))===0);
await check('la lectura usa la RPC del libro, no un RPC de escritura',async()=>
  (await page.evaluate(()=>window.__rpc.includes('stock_leer_areas')))
  && !(await page.evaluate(()=>window.__rpc.includes('stock_transferir'))));

await page.evaluate(()=>pickSede('central'));
await page.waitForTimeout(1000);
await page.locator('#list .sec-btn').first().click();
await check('Bodega conserva la lista de Inventario y su saldo actual',async()=>
  (await page.locator('#list').innerText()).includes('Leche Bodega')
  && !(await page.locator('#areaNav').isVisible()));
await page.locator('#list [data-open="3"]').click();
await page.waitForSelector('#m-ajuste-panel:not([hidden])');
await check('Bodega muestra la cantidad del ledger sin texto técnico y bloquea el campo legacy',async()=>
  (await page.locator('#m-ajuste-lineas').innerText()).trim()==='Cantidad'
  &&(await page.locator('#m-ajuste-lineas input').inputValue())==='17'
  &&await page.locator('#m-stock').isDisabled()
  &&(await page.evaluate(()=>window.__rpcArgs.findLast(x=>x.name==='stock_ajuste_desglose_leer').args.p_ubicacion_id))===null);
await check('sin errores de JavaScript en navegador',async()=>errors.length===0||errors.join('; '));

await browser.close();
if(failures.length)process.exit(1);
