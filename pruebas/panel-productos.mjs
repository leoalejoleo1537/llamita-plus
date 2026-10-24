import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {dirname,join} from 'node:path';
import {abrirNavegador} from './navegador.mjs';
const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const js=readFileSync(join(raiz,'panel-productos.js'),'utf8');
assert(!/\.from\(|functions\.invoke/.test(js),'Panel sin DML ni Edge Functions');
const browser=await abrirNavegador();
if(!browser){console.log('P1 estático OK; navegador no disponible');process.exit(0);}
try{
const page=await browser.newPage({viewport:{width:1366,height:900}});
await page.addInitScript(()=>{
  const user={id:'p1-test',email:'panel@test.invalid'};
  const permiso={auth_uid:user.id,puede_editar:true,puede_ajustes:true,puede_fudo:false,puede_lama:false};
  const maestro={id:12,producto:'Leche entera',unidad:'litro',rubro:'Leches',costo_compra:0,costo_pendiente:true,catalogo_revision:0,
    representaciones:[{id:22,producto:'Leche antigua',activo:'SÍ'},{id:23,producto:'Otro envase',activo:'SÍ'}],configuraciones:[]};
  window.__panelCalls=[];window.__panelFail=false;
  const q=()=>{const api={};for(const k of ['select','eq','neq','in','order','limit','range','gte','lte','lt','is','not','or','ilike'])api[k]=()=>api;
    api.maybeSingle=api.single=async()=>({data:null,error:null});api.then=cb=>Promise.resolve({data:[],error:null}).then(cb);return api;};
  window.supabase={createClient:()=>({from:q,rpc:(name,args)=>{
    window.__panelCalls.push({name,args}); let data=[];let error=null;
    if(name==='permisos_mios')data=permiso;
    if(name==='panel_productos_listar')data={productos:[maestro],grupos:['Leches','Insumos']};
    if(name==='areas_operativas_listar')data=[{id:'area-1',codigo:'cafeteria',nombre:'Cafetería',estado:'activa',ubicacion_activa:true},{id:'area-2',codigo:'barra',nombre:'Barra',estado:'activa',ubicacion_activa:true}];
    if(name==='area_secciones_listar')data=[{id:'sec-1',nombre:'Refrigerador',estado:'activa'}];
    if(name==='panel_producto_guardar'){
      if(window.__panelFail){window.__panelFail=false;error={message:'Conexión interrumpida: reintenta'};}
      else data={maestro_id:args.p_maestro_id||40,representacion_id:22,revision:1,stock_movido:false};
    }
    return {maybeSingle:async()=>({data,error}),then:cb=>Promise.resolve({data,error}).then(cb)};
  },auth:{getSession:async()=>({data:{session:{user}}}),getUser:async()=>({data:{user}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
  channel:()=>({on(){return this;},subscribe(){return this;},track(){},presenceState(){return {};}}),removeChannel(){},functions:{invoke(){throw Error('P1 no invoca Edge Functions');}}})};
});
await page.route('https://**/*',r=>r.fulfill({status:200,contentType:'application/javascript',body:'/* sin red */'}));
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
await page.goto(pathToFileURL(join(raiz,'index.html')).href);
await page.evaluate(()=>{pickSede('plaza');AJUSTES_VAL={};PERMISOS.puede_editar=true;LAMA_ATERRIZAR=false;aplicarPermisos();});
await page.click('#tabProductos');
await page.locator('[data-panel-id="12"]').waitFor();
assert.equal(await page.evaluate(()=>vistaActual),'productos');
await page.click('#panel-nuevo');
await page.locator('#panel-guardar:not(:disabled)').waitFor();
await page.fill('#panel-nombre','Pulpa de mango');
await page.fill('#panel-unidad','kg');
await page.selectOption('#panel-grupo','Insumos');
await page.check('[data-area="area-1"] .panel-area-usar');
await page.check('[data-area="area-2"] .panel-area-usar');
await page.selectOption('[data-area="area-1"] .panel-seccion','sec-1');
await page.selectOption('[data-area="area-2"] .panel-seccion','sec-1');
await page.fill('[data-area="area-1"] .panel-min','1.5');
await page.fill('[data-area="area-1"] .panel-max','5');
await page.check('[data-area="area-1"] [type=radio]');
await page.evaluate(()=>window.__panelFail=true);
await page.click('#panel-guardar');
await page.getByText('Conexión interrumpida: reintenta',{exact:true}).waitFor();
await page.click('#panel-guardar');
await page.getByText(/Nuevas fichas con saldo cero/).waitFor();
let calls=await page.evaluate(()=>window.__panelCalls.filter(c=>c.name==='panel_producto_guardar'));
assert.equal(calls.length,2);assert.deepEqual(calls[0],calls[1],'Reintento idéntico mantiene referencia y contenido');
assert.equal(calls[0].args.p_datos.areas.length,2);assert.equal(calls[0].args.p_datos.areas[0].stock_min,1.5);
assert.equal(calls[0].args.p_datos.costo_pendiente,true);assert.equal(calls[0].args.p_datos.costo_compra,0);
await page.click('[data-panel-id="12"]');
await page.locator('#panel-guardar:not(:disabled)').waitFor();
await page.check('[data-area="area-1"] .panel-area-usar');
await page.selectOption('[data-area="area-1"] .panel-seccion','sec-1');
await page.click('#panel-guardar');
await page.getByText('Elige explícitamente la representación de Local 1.').waitFor();
assert.equal(await page.evaluate(()=>window.__panelCalls.filter(c=>c.name==='panel_producto_guardar').length),2);
await page.selectOption('#panel-representacion','22');
await page.locator('#panel-guardar:not(:disabled)').waitFor();
await page.check('[data-area="area-1"] .panel-area-usar');
await page.selectOption('[data-area="area-1"] .panel-seccion','sec-1');
await page.fill('#panel-costo','1200.5');
await page.fill('#panel-nombre','Leche entera actualizada');
if(process.env.P1_SCREENSHOTS)await page.screenshot({path:process.env.P1_SCREENSHOTS+'/p1-desktop.png',fullPage:true});
await page.setViewportSize({width:390,height:844});
await page.waitForTimeout(350); // termina la transición del menú al cambiar breakpoint
assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Sin scroll horizontal móvil');
if(process.env.P1_SCREENSHOTS)await page.screenshot({path:process.env.P1_SCREENSHOTS+'/p1-mobile.png',fullPage:true});
await page.click('#panel-guardar');
await page.getByText(/Nombre, unidad y costo sincronizados/).waitFor();
await page.click('#mobileMenuTrigger');
await page.click('#tabProductos');
assert.equal(await page.evaluate(()=>vistaActual),'productos','El menú móvil abre el Panel');
calls=await page.evaluate(()=>window.__panelCalls.filter(c=>c.name==='panel_producto_guardar'));
assert.equal(calls[2].args.p_datos.representacion_id,22);assert.equal(calls[2].args.p_datos.costo_compra,1200.5);
await page.evaluate(()=>{PERMISOS.puede_editar=false;aplicarPermisos();pickTab('productos');});
assert.equal(await page.evaluate(()=>vistaActual),'inv');assert(!await page.locator('#tabProductos').isVisible());
assert.deepEqual(errors,[]);
console.log('P1 navegador OK: alta multiárea, edición, elección explícita, reintento, permisos y móvil/escritorio.');
}finally{await browser.close();}
