/* Navegación y persistencia del modo demostración con la misma interfaz real.
   CHROME_PATH=/usr/bin/chromium PRUEBAS_HTTP_BASE=http://127.0.0.1:8765 node pruebas/modo-demostracion.mjs */
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await abrirNavegador();
if (!browser) { console.log('(se salta: no hay navegador instalado)'); process.exit(0); }
const page = await browser.newPage();
const errores = [];
page.on('pageerror', e => errores.push(e.message));
page.on('console',m=>{if(m.type()==='error')errores.push(m.text());});
await page.setViewportSize({width:1360, height:900});
await page.addInitScript(() => {
  const correo = 'jhon@prueba.cl';
  const usuario = {id:'u1', email:correo, user_metadata:{nombre:'Jhon'}};
  const sesion = {user:usuario};
  const otras = {
    productos:[{id:1, sede:'plaza', producto:'Torta de prueba', rubro:'Vitrina',
                stock_actual:8, stock_min:2, stock_max:15, activo:'SÍ'}],
    app_permisos:[{correo, nombre:'Jhon', puede_ajustes:true, puede_editar:true,
                   puede_fudo:true, puede_lama:true, fudo_bloqueos:[]}],
  };
  window.__writes = [];
  const filasDe = nombre => nombre === 'ajustes'
    ? JSON.parse(sessionStorage.getItem('ajustes_demo') || '[]') : (otras[nombre] || []);
  const consulta = nombre => {
    let filas = structuredClone(filasDe(nombre));
    const api = {
      select(){return api;},
      eq(c,v){filas=filas.filter(f=>String(f[c])===String(v));return api;},
      neq(c,v){filas=filas.filter(f=>String(f[c])!==String(v));return api;},
      in(c,vs){filas=filas.filter(f=>vs.map(String).includes(String(f[c])));return api;},
      order(){return api;}, limit(){return api;}, range(){return api;}, gte(){return api;},
      lte(){return api;}, lt(){return api;}, is(){return api;}, not(){return api;},
      or(){return api;}, ilike(){return api;},
      maybeSingle(){return Promise.resolve({data:filas[0] || null,error:null});},
      single(){return Promise.resolve({data:filas[0] || null,error:null});},
      upsert(valor){
        window.__writes.push({tabla:nombre, operacion:'upsert', valor});
        if(nombre === 'ajustes'){
          const todos = filasDe(nombre).filter(f => f.clave !== valor.clave || f.sede !== valor.sede);
          todos.push(valor);
          sessionStorage.setItem('ajustes_demo', JSON.stringify(todos));
        }
        return Promise.resolve({data:[valor],error:null});
      },
      insert(valor){window.__writes.push({tabla:nombre,operacion:'insert',valor});return api;},
      update(valor){window.__writes.push({tabla:nombre,operacion:'update',valor});return api;},
      delete(){window.__writes.push({tabla:nombre,operacion:'delete'});return api;},
      then(f){return Promise.resolve({data:filas,error:null,count:filas.length}).then(f);},
    };
    return api;
  };
  window.supabase = {createClient:()=>({
    from:consulta, rpc:()=>Promise.resolve({data:null,error:null}),
    auth:{getSession:async()=>({data:{session:sesion}}),
      getUser:async()=>({data:{user:usuario}}),
      onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}};},
      signOut:async()=>({})},
    channel:()=>({on(){return this;},subscribe(cb){cb?.('SUBSCRIBED');return this;},
      track:async()=>{},presenceState:()=>({})}),
    removeChannel(){}, functions:{invoke:async()=>({data:{ok:true},error:null})},
  })};
});
await page.route('**/supabase-js*', r=>r.fulfill({status:200,contentType:'application/javascript',body:''}));

let ok=0, mal=0;
async function caso(nombre, prueba){
  try { const pasa = await prueba(); if(pasa){ok++;console.log('  ✓ '+nombre);}
        else {mal++;console.log('  ✗ '+nombre);} }
  catch(e){mal++;console.log('  ✗ '+nombre+' → '+e.message.split('\n')[0]);}
}
async function abrir(){
  await page.goto(pathToFileURL(join(raiz,'index.html')).href);
  await page.click('.gate-btn[data-sede="plaza"]');
  await page.waitForFunction(() => AJUSTES_VAL !== null);
}
async function ajustes(){
  await page.evaluate(()=>pickTab('ajustes'));
  await page.click('#aj-rail [data-aj="interruptores"]');
}

await abrir();
await caso('apagado: Mesas aparece con su permiso', ()=>page.isVisible('#tabLama'));
await ajustes();
await caso('el interruptor aparece en Ajustes', ()=>page.isVisible('[data-ajint="modo_demostracion"]'));
await page.click('[data-ajint="modo_demostracion"]');
await caso('se guarda la clave global en ajustes', async()=>
  await page.evaluate(()=>__writes.length===1 && __writes[0].tabla==='ajustes'
    && __writes[0].valor.clave==='modo_demostracion'
    && __writes[0].valor.sede==='' && __writes[0].valor.valor===true));
await caso('la pantalla indica que está encendido', async()=>
  await page.getAttribute('[data-ajint="modo_demostracion"]','aria-checked')==='true');
await caso('Ajustes aparta las secciones de ventas y caja', async()=>
  await page.locator('#aj-rail [data-aj="fudo"], #aj-rail [data-aj="mesas"], #aj-rail [data-aj="impresion"], #aj-rail [data-aj="metas"]').count()===0);
await caso('Ajustes no ofrece atajos a pantallas ocultas', async()=>
  await page.locator('#aj-pane [data-ajir="enlaces"], #aj-pane [data-ajir="recetas"]').count()===0);
await page.evaluate(()=>pickTab('inv'));
await caso('Inicio e Inventario quedan visibles', async()=>
  await page.isVisible('#tabInv') && (await page.textContent('#tabInv')).includes('Inicio')
    && await page.isVisible('#view-inv'));
await caso('stock, movimientos, mermas e historial siguen accesibles', async()=>
  await page.isVisible('[data-tab="reparto"]') && await page.isVisible('#tabMermas')
    && await page.isVisible('[data-accion="historial"]'));
await caso('Mesas, Arqueo, Caja, Recetas y Enlaces no se ven', async()=>{
  for(const tab of ['lama','arqueo','movcaja','recetas','enlaces'])
    if(await page.isVisible(`.tab[data-tab="${tab}"]`)) return false;
  return true;
});
await caso('no quedan el atajo de sync ni la meta de ventas', async()=>
  !await page.isVisible('#btnActualizar') && !await page.isVisible('#metaPortada')
    && !await page.isVisible('#btnNuevo'));
await page.screenshot({path:'/tmp/llamita-demo-escritorio.png',fullPage:true});
await page.evaluate(()=>pickTab('arqueo'));
await caso('acceso directo a Arqueo vuelve a Inventario', async()=>
  await page.isVisible('#view-inv') && !await page.isVisible('#view-arqueo'));
await page.evaluate(()=>pickTab('enlaces'));
await caso('acceso interno a Enlaces vuelve a Inventario', ()=>page.isVisible('#view-inv'));
await page.evaluate(()=>pickSede('central'));
await page.waitForFunction(() => SEDE==='central' && AJUSTES_VAL !== null);
await caso('en Bodega se ven Recibir, Enviar y Mermas', async()=>
  await page.isVisible('#tabRecepcion') && await page.isVisible('#tabEnvios')
    && await page.isVisible('#tabMermas'));
await page.evaluate(()=>pickTab('mermas'));
await page.waitForFunction(()=>document.querySelector('#mermas-demo-badge')?.classList.contains('on'));
await caso('Mermas ofrece cuatro KPI, filtro y gráficos sin anillo',async()=>
  (await page.locator('#mermas-kpis .mermas-kpi').count())===4
    && await page.isVisible('#mermas-periodo')
    && await page.isVisible('#mermas-charts .mermas-motive-row')
    && await page.locator('#mermas-charts .mermas-donut').count()===0
    && (await page.textContent('#mermas-demo-badge')).includes('ficticios'));
await caso('la marca del riel se oculta durante Mermas',async()=>
  await page.evaluate(()=>document.body.classList.contains('vista-mermas')
    &&getComputedStyle(document.querySelector('.riel-marca')).display==='none'));
await caso('barras muestran categorías, motivos y registros de auditoría',async()=>
  (await page.textContent('#mermas-charts')).includes('Tortas')
    && (await page.textContent('#mermas-charts')).includes('Vencimiento')
    && await page.isVisible('#mermas-list table.mermas-table')
    && (await page.textContent('#mermas-list')).includes('Sándwich Pollo Palta'));
await caso('hover abre el tooltip contextual completo sin salirse del viewport',async()=>{
  await page.hover('[data-mermas-categoria="Bollería"]');
  const contenido=await page.textContent('#mermas-tooltip');
  const dentro=await page.evaluate(()=>{
    const t=document.querySelector('#mermas-tooltip').getBoundingClientRect();
    const charts=document.querySelector('#mermas-charts').getBoundingClientRect();
    return t.left>=0&&t.top>=charts.top&&t.right<=innerWidth&&t.bottom<=innerHeight;
  });
  return contenido.includes('Bollería')&&contenido.includes('Motivo principal:')
    &&contenido.includes('Producto más afectado:')&&contenido.includes('Registros:')&&dentro;
});
await caso('las barras de categoría también se pueden inspeccionar con teclado',async()=>{
  await page.focus('[data-mermas-categoria="Tortas"]');
  const abierto=(await page.textContent('#mermas-tooltip')).includes('Tortas');
  await page.keyboard.press('Escape');
  return abierto&&await page.locator('#mermas-tooltip.on').count()===0;
});
await caso('el ranking de motivos usa barras y porcentajes legibles',async()=>
  await page.evaluate(()=>{
    const rows=[...document.querySelectorAll('.mermas-motive-row')];
    return rows.length>0&&rows.every(r=>r.querySelector('.mermas-motive-fill').getBoundingClientRect().width>0&&r.textContent.includes('%'));
  }));
await caso('el filtro temporal actualiza la tabla y vuelve al rango de 30 días',async()=>{
  const tabla='#mermas-list tbody tr';
  const treinta=await page.locator(tabla).count();
  await page.selectOption('#mermas-periodo','7');
  await page.waitForTimeout(200);
  const siete=await page.locator(tabla).count();
  await page.selectOption('#mermas-periodo','30');
  await page.waitForTimeout(200);
  return treinta>=siete&&await page.locator(tabla).count()===treinta;
});
await caso('la tabla conserva la acción de deshacer para registros reales',async()=>{
  await page.evaluate(()=>{
    MERMAS_DEMO=false;MERMAS_ULTIMO_TOTAL=1;
    MERMAS=[{id:987,producto_id:987,producto:'Torta de prueba',cantidad:-1,motivo:'vencimiento',
      sede:'central',quien:'Jhon',created_at:new Date().toISOString(),deshecha_at:null}];
    pintarMermas();
  });
  const preservada=await page.locator('#mermas-list [data-desmerma="987"]').count()===1;
  await page.evaluate(()=>loadMermas());
  await page.waitForFunction(()=>document.querySelector('#mermas-demo-badge')?.classList.contains('on'));
  return preservada;
});
await caso('el registro queda contenido en una tarjeta con desplazamiento propio',async()=>
  await page.evaluate(()=>{
    const l=document.querySelector('#mermas-list'),s=getComputedStyle(l);
    return l.scrollHeight>l.clientHeight&&['auto','scroll'].includes(s.overflowY)
      &&s.backgroundColor!=='rgba(0, 0, 0, 0)';
  }));
await page.mouse.move(0,0);
await page.waitForTimeout(5000);
await page.screenshot({path:'/tmp/llamita-mermas-escritorio.png',fullPage:true});
await page.setViewportSize({width:390,height:844});
await page.screenshot({path:'/tmp/llamita-mermas-movil.png',fullPage:true});
await caso('Mermas móvil no desborda el ancho de pantalla',async()=>
  await page.evaluate(()=>document.documentElement.scrollWidth<=document.documentElement.clientWidth+1));
await page.setViewportSize({width:1360,height:900});
await caso('los fixtures no escriben datos en Supabase',async()=>
  await page.evaluate(()=>__writes.every(w=>w.tabla==='ajustes')));
await page.evaluate(()=>pickTab('reparto'));
await caso('Bodega redirige un reparto local que no le corresponde', ()=>page.isVisible('#view-inv'));
await page.evaluate(()=>pickSede('angamos'));
await page.waitForFunction(() => SEDE==='angamos' && AJUSTES_VAL !== null);
await caso('Angamos conserva el traslado a Mall Plaza', ()=>page.isVisible('#tabAPlaza'));
await page.evaluate(()=>pickTab('envios'));
await caso('Angamos redirige Enviar, exclusivo de Bodega', ()=>page.isVisible('#view-inv'));
await caso('activar no escribe productos, stock, mermas, ventas ni caja', async()=>
  await page.evaluate(()=>__writes.every(w=>w.tabla==='ajustes')));

await page.setViewportSize({width:390,height:844});
await page.reload();
await page.click('.gate-btn[data-sede="plaza"]');
await page.waitForFunction(() => AJUSTES_VAL !== null);
await caso('el modo persiste después de recargar en móvil', async()=>
  await page.isVisible('#view-inv') && !await page.isVisible('#tabLama')
    && await page.evaluate(()=>document.body.classList.contains('demo-activo')));
await caso('en móvil no hay desborde horizontal', async()=>
  await page.evaluate(()=>document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1));
await page.screenshot({path:'/tmp/llamita-demo-movil.png',fullPage:true});
await ajustes();
await page.screenshot({path:'/tmp/llamita-demo-ajustes-movil.png',fullPage:true});
await page.click('[data-ajint="modo_demostracion"]');
await page.evaluate(()=>pickTab('inv'));
await caso('apagado: la navegación normal vuelve', async()=>
  await page.isVisible('#tabLama') && await page.isVisible('#tabArqueo')
    && await page.evaluate(()=>!document.body.classList.contains('demo-activo')));
await ajustes();
await caso('apagado: vuelven también los Ajustes normales', async()=>
  await page.locator('#aj-rail [data-aj="fudo"]').count()===1);
await page.evaluate(()=>pickTab('arqueo'));
await caso('apagado: Arqueo vuelve a abrir', ()=>page.isVisible('#view-arqueo'));
await caso('sin nuevos errores de JavaScript', ()=>errores.length===0);

await browser.close();
console.log(`\n${ok} bien · ${mal} mal`);
if(mal) process.exit(1);
