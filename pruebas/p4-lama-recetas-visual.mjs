import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {dirname,join} from 'node:path';
import {abrirNavegador} from './navegador.mjs';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const browser=await abrirNavegador();
if(!browser){console.log('P4 visual se salta: no hay Chromium instalado');process.exit(0);}
try{
  const page=await browser.newPage({viewport:{width:1180,height:820}});
  await page.addInitScript(()=>{
    const user={id:'p4-root',email:'p4@test.invalid'};
    const permiso={auth_uid:user.id,puede_lama:true,puede_editar:true,puede_ajustes:true};
    window.__rpc=[];window.__items=[];let seq=8000;
    const T={
      mesas:[{id:101,sede:'plaza',salon:'Salón',numero:1,orden:1,activa:true,forma:'cuadrada',tam:'normal'}],
      cuentas:[{id:201,sede:'plaza',mesa_id:101,estado:'abierta',total:0,abierta_por:'Alejo',abierta_at:new Date().toISOString()}],
      cuenta_items:window.__items,lama_areas:[],fudo_productos:[],lama_medios_pago:[],lama_motivos_descuento:[],
      lama_motivos_anulacion:[{codigo:'error_registro',nombre:'Error',activo:true,pide_comentario:false}],
      cuenta_pagos:[],lama_arqueos:[],lama_caja_movimientos:[],lama_impresiones:[],
      productos:[],areas_operativas:[],producto_area_asignacion:[],producto_lotes:[],
      recetas:[],receta_items:[],repartos:[],reparto_items:[],mermas:[],historial:[],tareas:[]
    };
    const q=n=>{let filas=T[n]||[];const api={};
      api.select=()=>api;api.eq=(c,v)=>{filas=filas.filter(x=>String(x[c])===String(v));return api;};
      api.neq=(c,v)=>{filas=filas.filter(x=>String(x[c])!==String(v));return api;};
      for(const k of ['order','limit','range','gte','lte','lt','is','not','or','ilike','in'])api[k]=()=>api;
      api.maybeSingle=api.single=async()=>({data:filas[0]||null,error:null});
      api.insert=v=>{const rows=(Array.isArray(v)?v:[v]).map(x=>({id:++seq,...x}));return {select(){return this},single:async()=>({data:rows[0],error:null}),then:f=>Promise.resolve({data:rows,error:null}).then(f)}};
      api.update=()=>({eq(){return this},in(){return this},select(){return this},then:f=>Promise.resolve({data:[],error:null}).then(f)});
      api.delete=()=>({eq(){return this},in(){return this},then:f=>Promise.resolve({data:[],error:null}).then(f)});
      api.then=f=>Promise.resolve({data:filas,error:null,count:filas.length}).then(f);return api;};
    window.supabase={createClient:()=>({from:q,rpc:(name,args)=>{
      window.__rpc.push({name,args});let data=[];
      if(name==='permisos_mios')data=permiso;
      if(name==='lama_productos_venta_listar')data=[
        {producto_venta_id:'pv-listo',nombre:'Coca-Cola cubana',precio:4500,estado:'listo',receta_id:'rv-1',receta_version:1,ingredientes:3,disponible:4,areas:'Barra, Cafetería',receta_valida:true,vendible:true,motivo:null},
        {producto_venta_id:'pv-borrador',nombre:'Mojito borrador',precio:3900,estado:'borrador',ingredientes:0,disponible:0,areas:'',receta_valida:false,vendible:false,motivo:'Borrador · completa y marca la receta como lista'},
        {producto_venta_id:'pv-sin-stock',nombre:'Lomo sin stock',precio:8000,estado:'listo',ingredientes:2,disponible:0,areas:'Cocina caliente',receta_valida:true,vendible:false,motivo:'Stock insuficiente para una unidad'}
      ];
      if(name==='lama_fuentes_directas_listar')data=[];
      if(name==='lama_stock_alertas_listar')data=[];
      if(name==='cuenta_producto_venta_agregar'){
        const p={id:++seq,cuenta_id:args.p_cuenta_id,producto_venta_id:args.p_producto_venta_id,
          fudo_product_id:null,nombre:'Coca-Cola cubana',cantidad:1,precio:4500,estado:'nuevo',comentario:null};
        window.__items.push(p);data=p;
      }
      if(name==='cuenta_recalcular')data=4500;
      return {maybeSingle:async()=>({data,error:null}),then:f=>Promise.resolve({data,error:null}).then(f)};
    },auth:{getSession:async()=>({data:{session:{user}}}),getUser:async()=>({data:{user}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
    channel:()=>({on(){return this},subscribe(){return this},track(){},presenceState(){return {}}}),removeChannel(){},functions:{invoke:async()=>({data:{},error:null})}})};
  });
  await page.route('https://**/*',r=>r.fulfill({status:200,contentType:'application/javascript',body:''}));
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto(pathToFileURL(join(raiz,'index.html')).href);
  await page.evaluate(async()=>{await pickSede('plaza');PERMISOS.puede_lama=true;aplicarPermisos();pickTab('lama');await lamaCargar(true);});
  await page.click('[data-lamamesa="101"]');
  await page.fill('#lama-qp','coca');
  const listo=page.locator('.lama-prod[data-lamaadd="venta:pv-listo"]').first();
  await listo.waitFor();
  assert.equal(await listo.isEnabled(),true,'el producto listo debe poder venderse');
  assert.match(await listo.textContent(),/Receta manual · 4 vendibles · Barra, Cafetería/);
  await listo.click();
  assert(await page.evaluate(()=>window.__rpc.some(x=>x.name==='cuenta_producto_venta_agregar'&&x.args.p_producto_venta_id==='pv-listo')),
    'la UI no usó la RPC neutral');
  await page.evaluate(async()=>{LAMA_QP='';lamaPintarPanel();await lamaMas();});
  await page.locator('.lama-prod[data-lamaadd="venta:pv-borrador"]').waitFor();
  assert.equal(await page.locator('.lama-prod[data-lamaadd="venta:pv-borrador"]').isDisabled(),true);
  assert.equal(await page.locator('.lama-prod[data-lamaadd="venta:pv-sin-stock"]').isDisabled(),true);
  await page.setViewportSize({width:390,height:844});
  const movil=await page.evaluate(()=>({w:document.documentElement.scrollWidth,v:innerWidth,
    mesas:getComputedStyle(document.querySelector('#view-lama')).display}));
  assert(movil.w<=movil.v,'Mesas P4 genera scroll horizontal en teléfono');
  assert.notEqual(movil.mesas,'none','Mesas no permanece visible en móvil');
  assert.deepEqual(errors,[]);
  console.log('P4 visual OK: catálogo neutral, borrador bloqueado, stock visible y móvil 390×844.');
}finally{await browser.close();}
