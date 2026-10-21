import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {dirname,join} from 'node:path';
import {abrirNavegador} from './navegador.mjs';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const html=readFileSync(join(raiz,'index.html'),'utf8');
const panel=readFileSync(join(raiz,'panel-productos.js'),'utf8');
assert(!/\.from\(|functions\.invoke/.test(panel),'el Panel no contiene DML ni Edge Functions');
assert(html.includes("abrirPanelProductos({origen:SEDE==='central'?'bodega':'inventario'"),'alta general redirigida al Panel');
assert(html.includes("abrirPanelProductos({origen:'area',areaCodigo:"),'alta desde área redirigida al Panel');
assert(html.includes("abrirPanelProductos({origen:'receta-editor'"),'Crear ingrediente redirigido al Panel');
assert(!html.includes("sb.rpc('crear_producto_enlazado'"),'la alta enlazada legacy ya no tiene invocación visible');
assert(!html.includes("sb.rpc('producto_plaza_crear'"),'la alta plaza legacy ya no tiene invocación visible');
const altaBodega=html.slice(html.indexOf("$('enl-crear').addEventListener"),html.indexOf("$('btnMermasExcel')"));
assert(!altaBodega.includes('functions.invoke'),'crear un insumo no publica en Fudo');

const browser=await abrirNavegador();
if(!browser){console.log('P2 estático OK; navegador no disponible');process.exit(0);}
try{
  const page=await browser.newPage({viewport:{width:1180,height:820}});
  await page.addInitScript(()=>{
    const user={id:'p2-root',email:'panel-p2@test.invalid'};
    const permiso={auth_uid:user.id,puede_editar:true,puede_ajustes:true,puede_fudo:false,puede_lama:false};
    window.__calls=[];
    window.__local=[{id:22,producto:'Leche entera',rubro:'Leches',sede:'plaza',activo:'SÍ',stock_actual:0,unidad:'litro'}];
    window.__masters=[{id:12,producto:'Leche entera',unidad:'litro',rubro:'Leches',costo_compra:0,costo_pendiente:true,catalogo_revision:1,
      representaciones:[{id:22,producto:'Leche entera',activo:'SÍ'}],configuraciones:[]}];
    const consulta=tabla=>{
      let datos=tabla==='productos'?window.__local:[];
      const api={};
      for(const k of ['select','eq','neq','in','order','limit','range','gte','lte','lt','is','not','or','ilike'])api[k]=()=>api;
      api.maybeSingle=api.single=async()=>({data:null,error:null});
      api.then=cb=>Promise.resolve({data:datos,error:null}).then(cb);
      return api;
    };
    window.supabase={createClient:()=>({from:consulta,rpc:(name,args)=>{
      window.__calls.push({name,args});let data=[];let error=null;
      if(name==='permisos_mios')data=permiso;
      if(name==='panel_productos_listar'){
        const filas=args?.p_maestro_id?window.__masters.filter(x=>x.id===Number(args.p_maestro_id)):window.__masters;
        data={productos:filas,grupos:['Leches','Insumos']};
      }
      if(name==='areas_operativas_listar')data=[
        {id:'area-cafe',codigo:'cafeteria',nombre:'Cafetería',estado:'activa',ubicacion_activa:true},
        {id:'area-barra',codigo:'barra',nombre:'Barra',estado:'activa',ubicacion_activa:true}
      ];
      if(name==='area_secciones_listar')data=[];
      if(name==='stock_leer_areas')data=[];
      if(name==='producto_area_urgencias_listar')data=[];
      if(name==='panel_producto_guardar'){
        const mid=args.p_maestro_id||40+window.__calls.filter(x=>x.name==='panel_producto_guardar').length;
        const lid=args.p_datos.crear_representacion?70+window.__calls.filter(x=>x.name==='panel_producto_guardar').length:null;
        if(lid&&!window.__local.some(x=>x.id===lid))window.__local.push({id:lid,producto:args.p_datos.nombre,rubro:args.p_datos.rubro,sede:'plaza',activo:'SÍ',stock_actual:0,unidad:args.p_datos.unidad});
        data={maestro_id:mid,representacion_id:lid,revision:1,stock_movido:false};
      }
      return {maybeSingle:async()=>({data,error}),then:cb=>Promise.resolve({data,error}).then(cb)};
    },auth:{getSession:async()=>({data:{session:{user}}}),getUser:async()=>({data:{user}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
    channel:()=>({on(){return this;},subscribe(){return this;},track(){},presenceState(){return {};}}),removeChannel(){},functions:{invoke(){throw Error('P2 no invoca Edge Functions');}}})};
  });
  await page.route('https://**/*',r=>r.fulfill({status:200,contentType:'application/javascript',body:'/* sin red */'}));
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto(pathToFileURL(join(raiz,'index.html')).href);
  await page.evaluate(()=>{pickSede('central');AJUSTES_VAL={};PERMISOS.puede_editar=true;LAMA_ATERRIZAR=false;aplicarPermisos();abrirPanelProductos({origen:'bodega'});});

  // Desde Bodega: crea únicamente el maestro, siempre mediante P1/P2.
  await page.click('#panel-nuevo');
  await page.locator('#panel-guardar:not(:disabled)').waitFor();
  await page.fill('#panel-nombre','Producto Bodega P2');
  await page.fill('#panel-unidad','kg');
  await page.selectOption('#panel-grupo','Insumos');
  await page.click('#panel-guardar');
  await page.waitForFunction(()=>vistaActual==='inv');
  let altas=await page.evaluate(()=>window.__calls.filter(x=>x.name==='panel_producto_guardar'));
  assert.equal(altas.length,1);assert.equal(altas[0].args.p_maestro_id,null);
  assert.equal(altas[0].args.p_datos.crear_representacion,false);assert.equal(altas[0].args.p_datos.areas.length,0);

  await page.evaluate(()=>{pickSede('plaza');PERMISOS.puede_editar=true;aplicarPermisos();areaActual='cafeteria';});

  // Desde un área: busca/reutiliza primero y el área queda preseleccionada.
  await page.evaluate(()=>abrirPanelProductos({origen:'area',areaCodigo:'cafeteria'}));
  await page.locator('[data-panel-id="12"]').waitFor();
  assert.match(await page.textContent('#panel-contexto'),/Cafetería/);
  await page.click('[data-panel-id="12"]');
  await page.locator('#panel-guardar:not(:disabled)').waitFor();
  assert(await page.isChecked('[data-area="area-cafe"] .panel-area-usar'),'área de origen preseleccionada');
  await page.click('#panel-guardar');
  await page.waitForFunction(()=>vistaActual==='inv'&&areaActual==='cafeteria');
  altas=await page.evaluate(()=>window.__calls.filter(x=>x.name==='panel_producto_guardar'));
  assert.equal(altas.length,2);assert.equal(altas[1].args.p_maestro_id,12);
  assert.equal(altas[1].args.p_datos.areas[0].area_id,'area-cafe');
  assert.equal(altas[1].args.p_datos.crear_representacion,true);

  // Desde Recetas: vuelve al editor con el insumo recién creado seleccionado.
  await page.evaluate(()=>{pickTab('recetas');FUDOPROD=[{fudo_product_id:'venta-1',nombre:'Venta manual'}];openReceta(null);});
  await page.click('#btnCrearInsumo');
  await page.click('#panel-nuevo');
  await page.locator('#panel-guardar:not(:disabled)').waitFor();
  await page.fill('#panel-nombre','Ingrediente P2');
  await page.fill('#panel-unidad','unidad');
  await page.selectOption('#panel-grupo','Insumos');
  await page.click('#panel-guardar');
  await page.locator('#overlay-receta.open').waitFor();
  const seleccionados=await page.evaluate(()=>[...document.querySelectorAll('#rec-insumos .rec-ins-prod')].map(x=>x._getValue?.()).filter(Boolean));
  assert.equal(seleccionados.length,1);assert.match(String(seleccionados[0]),/^7\d$/);
  altas=await page.evaluate(()=>window.__calls.filter(x=>x.name==='panel_producto_guardar'));
  assert.equal(altas.at(-1).args.p_datos.crear_representacion,true);
  assert.equal(altas.at(-1).args.p_datos.areas.length,0);
  assert(!await page.evaluate(()=>window.__calls.some(x=>['crear_producto_enlazado','producto_plaza_crear','producto_plaza_crear_configurado','bodega_producto_area_agregar'].includes(x.name))));
  assert.deepEqual(errors,[]);
  console.log('P2 navegador OK: reutilización, área preseleccionada y retorno a Recetas sin alta paralela.');
}finally{await browser.close();}
