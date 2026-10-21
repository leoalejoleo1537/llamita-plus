import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {dirname,join} from 'node:path';
import {abrirNavegador} from './navegador.mjs';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const html=readFileSync(join(raiz,'index.html'),'utf8');
const js=readFileSync(join(raiz,'panel-productos-venta.js'),'utf8');
const migration=readFileSync(join(raiz,'supabase/migrations/20261021181318_p3_catalogo_comercial_recetas_manuales.sql'),'utf8');
assert(html.includes('>Insumos</button>')&&html.includes('>Productos de venta</button>'),'el Panel no tiene las dos pestañas');
assert(!/\.from\(|functions\.invoke/.test(js),'P3 no debe hacer DML ni llamar Edge Functions desde el navegador');
assert(migration.includes('create table catalogo_internal.productos_venta'));
assert(migration.includes('create table catalogo_internal.recetas_venta'));
assert(migration.includes('create table catalogo_internal.receta_venta_componentes'));
assert(!/insert into public\.(recetas|receta_items|fudo_productos)/i.test(migration),'P3 no escribe recetas/Fudo heredados');

const browser=await abrirNavegador();
if(!browser){console.log('P3 estático OK; navegador no disponible');process.exit(0);}
try{
  const page=await browser.newPage({viewport:{width:1180,height:820}});
  await page.addInitScript(()=>{
    const user={id:'p3-root',email:'panel-p3@test.invalid'};
    const permiso={auth_uid:user.id,puede_editar:true,puede_ajustes:true,puede_fudo:false,puede_lama:false};
    window.__calls=[];window.__ventas=[];window.__ventaId=0;
    window.__local=[{id:21,producto:'Coca-Cola',rubro:'Bebidas',sede:'plaza',activo:'SÍ',stock_actual:0,unidad:'unidad'}];
    window.__masters=[{id:11,producto:'Coca-Cola',unidad:'unidad',rubro:'Bebidas',costo_compra:0,costo_pendiente:true,catalogo_revision:1,
      representaciones:[{id:21,producto:'Coca-Cola',activo:'SÍ'}],configuraciones:[]}];
    window.__ingredients=[
      {asignacion_id:'cfg-coca-barra',producto_id:21,maestro_id:11,producto:'Coca-Cola',unidad:'unidad',area_id:'area-barra',area:'Barra',seccion:'Refrigerador'},
      {asignacion_id:'cfg-limon-barra',producto_id:22,maestro_id:12,producto:'Limón',unidad:'unidad',area_id:'area-barra',area:'Barra',seccion:null},
      {asignacion_id:'cfg-menta-cafe',producto_id:23,maestro_id:13,producto:'Menta',unidad:'g',area_id:'area-cafe',area:'Cafetería',seccion:'Refrigerador'}
    ];
    const consulta=tabla=>{
      let datos=tabla==='productos'?window.__local:[];const api={};
      for(const k of ['select','eq','neq','in','order','limit','range','gte','lte','lt','is','not','or','ilike'])api[k]=()=>api;
      api.maybeSingle=api.single=async()=>({data:null,error:null});api.then=cb=>Promise.resolve({data:datos,error:null}).then(cb);return api;
    };
    window.supabase={createClient:()=>({from:consulta,rpc:(name,args)=>{
      window.__calls.push({name,args});let data=[];let error=null;
      if(name==='permisos_mios')data=permiso;
      if(name==='panel_productos_listar'){
        const filas=args?.p_maestro_id?window.__masters.filter(x=>x.id===Number(args.p_maestro_id)):window.__masters;
        data={productos:filas,grupos:['Bebidas','Insumos']};
      }
      if(name==='areas_operativas_listar')data=[
        {id:'area-cafe',codigo:'cafeteria',nombre:'Cafetería',estado:'activa',ubicacion_activa:true},
        {id:'area-barra',codigo:'barra',nombre:'Barra',estado:'activa',ubicacion_activa:true}
      ];
      if(name==='area_secciones_listar')data=[];
      if(name==='stock_leer_areas'||name==='producto_area_urgencias_listar')data=[];
      if(name==='panel_ingredientes_listar')data={ingredientes:window.__ingredients};
      if(name==='panel_ventas_listar'){
        const productos=args?.p_producto_venta_id?window.__ventas.filter(x=>x.id===args.p_producto_venta_id):window.__ventas;
        data={productos};
      }
      if(name==='panel_venta_guardar'){
        let id=args.p_producto_venta_id;if(!id)id=`venta-${++window.__ventaId}`;
        const previa=window.__ventas.find(x=>x.id===id),revision=(previa?.revision||0)+1;
        const componentes=args.p_datos.componentes.map((c,i)=>{
          const f=window.__ingredients.find(x=>x.asignacion_id===c.asignacion_id);return {...f,orden:i+1,cantidad:c.cantidad};
        });
        const fila={id,nombre:args.p_datos.nombre,precio_venta:args.p_datos.precio_venta,estado:args.p_datos.estado,revision,
          ingredientes:componentes.length,componentes,receta_id:componentes.length?`rec-${id}-${revision}`:null,receta_version:componentes.length?revision:null};
        window.__ventas=window.__ventas.filter(x=>x.id!==id).concat(fila);data={producto_venta_id:id,revision,estado:fila.estado,ingredientes:componentes.length,stock_movido:false,reserva_creada:false};
      }
      if(name==='panel_producto_guardar'){
        const mid=30,lid=40;const area=args.p_datos.areas[0];
        if(!window.__masters.some(x=>x.id===mid))window.__masters.push({id:mid,producto:args.p_datos.nombre,unidad:args.p_datos.unidad,rubro:args.p_datos.rubro,costo_compra:0,costo_pendiente:true,catalogo_revision:1,representaciones:[{id:lid,producto:args.p_datos.nombre,activo:'SÍ'}],configuraciones:[]});
        window.__ingredients.push({asignacion_id:'cfg-nuevo',producto_id:lid,maestro_id:mid,producto:args.p_datos.nombre,unidad:args.p_datos.unidad,area_id:area.area_id,area:area.area_id==='area-cafe'?'Cafetería':'Barra',seccion:null});
        data={maestro_id:mid,representacion_id:lid,revision:1,stock_movido:false};
      }
      return {maybeSingle:async()=>({data,error}),then:cb=>Promise.resolve({data,error}).then(cb)};
    },auth:{getSession:async()=>({data:{session:{user}}}),getUser:async()=>({data:{user}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
    channel:()=>({on(){return this;},subscribe(){return this;},track(){},presenceState(){return {};}}),removeChannel(){},functions:{invoke(){throw Error('P3 no invoca Edge Functions');}}})};
  });
  await page.route('https://**/*',r=>r.fulfill({status:200,contentType:'application/javascript',body:'/* sin red */'}));
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto(pathToFileURL(join(raiz,'index.html')).href);
  await page.evaluate(()=>{pickSede('plaza');PERMISOS.puede_editar=true;aplicarPermisos();abrirPanelProductos({origen:'inventario'});});
  await page.click('#panel-tab-ventas');
  await page.locator('#panel-venta-nuevo').waitFor();

  // Borrador vacío: no inventa receta.
  await page.click('#panel-venta-nuevo');
  await page.fill('#panel-venta-nombre','Bebida borrador');await page.fill('#panel-venta-precio','2500');
  await page.click('#panel-venta-borrador');
  await page.waitForFunction(()=>window.__ventas.length===1);
  assert.equal((await page.evaluate(()=>window.__ventas[0])).ingredientes,0);

  // Receta manual de tres líneas, decimal, dos áreas y orden explícito.
  await page.click('#panel-venta-nuevo');await page.fill('#panel-venta-nombre','Coca-Cola cubana');await page.fill('#panel-venta-precio','4800');
  for(let i=0;i<3;i++)await page.click('#panel-venta-agregar');
  const filas=page.locator('.panel-componente');
  await filas.nth(0).locator('.pv-insumo').selectOption('11');await filas.nth(0).locator('.pv-origen').selectOption('cfg-coca-barra');
  await filas.nth(1).locator('.pv-insumo').selectOption('12');await filas.nth(1).locator('.pv-origen').selectOption('cfg-limon-barra');await filas.nth(1).locator('.pv-cantidad').fill('0.5');
  await filas.nth(2).locator('.pv-insumo').selectOption('13');await filas.nth(2).locator('.pv-origen').selectOption('cfg-menta-cafe');
  await page.click('#panel-venta-listo');await page.waitForFunction(()=>window.__ventas.length===2);
  const compuesto=await page.evaluate(()=>window.__ventas.find(x=>x.nombre==='Coca-Cola cubana'));
  assert.equal(compuesto.estado,'listo');assert.deepEqual(compuesto.componentes.map(x=>x.cantidad),[1,.5,1]);
  assert.deepEqual(compuesto.componentes.map(x=>x.area),['Barra','Barra','Cafetería']);

  // Crear insumo conserva el borrador comercial y vuelve con origen seleccionado.
  await page.click('#panel-venta-nuevo');await page.fill('#panel-venta-nombre','Producto con insumo nuevo');
  await page.click('#panel-venta-crear-insumo');await page.click('#panel-nuevo');
  await page.locator('#panel-guardar:not(:disabled)').waitFor();
  await page.fill('#panel-nombre','Jarabe nuevo');await page.fill('#panel-unidad','ml');await page.selectOption('#panel-grupo','Insumos');
  await page.check('[data-area="area-cafe"] .panel-area-usar');await page.click('#panel-guardar');
  await page.locator('#panel-ventas:not([hidden])').waitFor();
  assert.equal(await page.locator('.panel-componente .pv-insumo').inputValue(),'30');
  assert.equal(await page.locator('.panel-componente .pv-origen').inputValue(),'cfg-nuevo');
  await page.setViewportSize({width:390,height:844});
  const movil=await page.evaluate(()=>({ancho:document.documentElement.scrollWidth,ventana:innerWidth,tabs:!document.querySelector('#panel-ventas').hidden}));
  assert.equal(movil.tabs,true);assert(movil.ancho<=movil.ventana,'el editor P3 no debe producir scroll horizontal en teléfono');
  const llamadas=await page.evaluate(()=>window.__calls.map(x=>x.name));
  assert(llamadas.includes('panel_venta_guardar')&&llamadas.includes('panel_producto_guardar'));
  assert(!llamadas.some(x=>['fudo-crear-producto','lama_confirmar_comanda_stock'].includes(x)));
  assert.deepEqual(errors,[]);
  console.log('P3 navegador OK: dos pestañas, borrador, receta manual multiárea y retorno de insumo.');
}finally{await browser.close();}
