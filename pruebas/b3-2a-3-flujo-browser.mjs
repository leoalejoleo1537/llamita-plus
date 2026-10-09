import {fileURLToPath,pathToFileURL} from 'node:url';
import {dirname,join} from 'node:path';
import {abrirNavegador} from './navegador.mjs';

const browser=await abrirNavegador();
if(!browser){console.log('(se salta B3.2a.3 visual: no hay Chromium instalado)');process.exit(0);}
const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const page=await browser.newPage({viewport:{width:390,height:844}});
await page.addInitScript(()=>{
  const user={id:'root-test',email:'root@test.invalid',user_metadata:{nombre:'Raíz'}};
  const session={user};
  const productos=[
    {id:11,sede:'plaza',producto:'Helado de vainilla',rubro:'Congelador',tipo:'Helados',unidad:'un',stock_actual:1,stock_min:0,stock_max:5,activo:'SÍ',origen:'INV',perecedero:true,urgente:false},
    {id:20,sede:'plaza',producto:'Limpiador',rubro:'Limpieza',tipo:'Envasados',unidad:'un',stock_actual:2,stock_min:0,stock_max:5,activo:'SÍ',origen:'INV',perecedero:false,urgente:false},
  ];
  const catalogo=[
    ['fria','Cocina fría'],['caliente','Cocina caliente'],['barra','Barra'],['cafeteria','Cafetería'],['heladeria','Heladería']
  ].map(([codigo,nombre],i)=>({id:'area-'+codigo,sede:'plaza',codigo,nombre,estado:'activa',orden:i+1,productos_preferidos:0,productos_con_saldo:0,unidades:0}));
  const lectura=[...catalogo.map(a=>({codigo:a.codigo,nombre:a.nombre,orden:a.orden})),{codigo:'sin_asignar',nombre:'Sin asignar',orden:999}]
    .flatMap(a=>productos.map(p=>({area_codigo:a.codigo,area_nombre:a.nombre,area_orden:a.orden,producto_id:p.id,
      producto:p.producto,rubro:p.rubro,tipo:p.tipo,unidad:p.unidad,cantidad:a.codigo==='sin_asignar'&&p.id===11?1:0})));
  const permisos={auth_uid:user.id,correo:user.email,nombre:'Raíz',puede_editar:true,puede_fudo:false,puede_ajustes:true,puede_lama:false,es_propietario_raiz:true,fudo_bloqueos:[]};
  const prefs=new Map();window.__rpcWrites=[];window.__tableWrites=[];window.__fudoCalls=[];window.__prefs=prefs;
  const wrap=(data,error=null)=>({maybeSingle:()=>Promise.resolve({data:Array.isArray(data)?data[0]||null:data,error}),
    single:()=>Promise.resolve({data:Array.isArray(data)?data[0]||null:data,error}),
    then:done=>Promise.resolve({data,error}).then(done)});
  function query(name){
    let rows=name==='productos'?structuredClone(productos):name==='sede_registro'?
      [{codigo:'plaza',nombre_visible:'Local 1',tipo:'local',estado:'activa'},{codigo:'central',nombre_visible:'Bodega',tipo:'bodega',estado:'activa'}]:[];
    const api={select(){return api;},eq(k,v){rows=rows.filter(r=>String(r[k])===String(v));return api;},neq(){return api;},in(){return api;},
      order(){return api;},limit(n){rows=rows.slice(0,n);return api;},gte(){return api;},lte(){return api;},is(){return api;},not(){return api;},or(){return api;},ilike(){return api;},
      maybeSingle(){return Promise.resolve({data:rows[0]||null,error:null});},single(){return Promise.resolve({data:rows[0]||null,error:null});},
      insert(v){window.__tableWrites.push({name,op:'insert',v});return wrap([]);},update(v){window.__tableWrites.push({name,op:'update',v});return api;},
      upsert(v){window.__tableWrites.push({name,op:'upsert',v});return wrap([]);},delete(){window.__tableWrites.push({name,op:'delete'});return api;},
      then:done=>Promise.resolve({data:rows,error:null,count:rows.length}).then(done)};return api;
  }
  window.supabase={createClient:()=>({from:query,rpc:(name,args={})=>{
    if(name==='permisos_mios')return wrap(permisos);
    if(name==='stock_leer_areas')return wrap(lectura);
    if(name==='areas_operativas_listar')return wrap(catalogo);
    if(name==='producto_area_preferencia_leer'){
      const area=prefs.get(+args.p_producto_id)||null;
      const cat=catalogo.find(a=>a.id===area);
      return wrap({producto_id:+args.p_producto_id,area_id:area,estado:area?'asignado':'sin_asignar',area_codigo:cat?.codigo||null,area_nombre:cat?.nombre||null,
        ubicaciones:+args.p_producto_id===11?[{codigo:'sin_asignar',nombre:'Sin asignar',cantidad:1}]:[]});
    }
    if(name==='producto_area_preferencia_guardar'){
      window.__rpcWrites.push({name,args});prefs.set(+args.p_producto_id,args.p_area_id||null);
      return wrap({producto_id:+args.p_producto_id,area_id:args.p_area_id||null});
    }
    if(name==='producto_plaza_crear'){window.__rpcWrites.push({name,args});return wrap({producto_id:99,stock_actual:0});}
    return wrap([]);
  },auth:{getSession:async()=>({data:{session}}),getUser:async()=>({data:{user}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({})},
    channel:()=>({on(){return this;},subscribe(cb){cb?.('SUBSCRIBED');return this;},track:async()=>{},presenceState:()=>({})}),removeChannel(){},
    functions:{invoke:async(name)=>{window.__fudoCalls.push(name);return {data:{ok:true},error:null};}}})};
});
await page.route('**/supabase-js*',r=>r.fulfill({status:200,contentType:'application/javascript',body:'/* mock */'}));
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
await page.goto(pathToFileURL(join(raiz,'index.html')).href);
await page.click('.gate-btn[data-sede="plaza"]');
await page.waitForSelector('[data-area-manage]');
const check=async(name,fn)=>{const ok=await fn();console.log(`${ok?'✓':'✗'} ${name}`);if(!ok)throw Error(name);};

await check('raíz encuentra Gestionar áreas',async()=>page.locator('[data-area-manage]').isVisible());
await page.click('[data-area-manage]');
await page.waitForSelector('#aj-area-nombre');
await check('Ajustes muestra Nueva área y Crear área',async()=>{
  const t=await page.locator('#aj-pane').innerText();return t.includes('Nueva área')&&t.includes('Crear área');
});
await page.evaluate(()=>pickTab('inv'));
await page.waitForSelector('[data-area-assign="heladeria"]');
await page.click('[data-area-assign="heladeria"]');
await page.fill('#area-producto-q','vainilla');
await page.click('[data-area-producto="11"]');
await page.waitForFunction(()=>document.getElementById('area-producto-guardar').disabled===false);
await check('producto existente muestra preferencia y saldo físico',async()=>{
  const t=await page.locator('#area-producto-detalle').innerText();return t.includes('Área preferida actual')&&t.includes('Sin asignar · 1')&&t.includes('no se moverán');
});
await page.click('#area-producto-guardar');
await page.waitForFunction(()=>window.__rpcWrites.some(x=>x.name==='producto_area_preferencia_guardar'));
await check('asigna por RPC a Heladería sin duplicar producto',async()=>page.evaluate(()=>{
  const w=window.__rpcWrites;return w.filter(x=>x.name==='producto_area_preferencia_guardar').length===1&&
    w.filter(x=>x.name==='producto_plaza_crear').length===0&&window.__prefs.get(11)==='area-heladeria';
}));
if(await page.locator('#overlay-ask.open').count())await page.click('#ask-ok');
await page.evaluate(()=>abrirNuevoProducto('heladeria'));
await check('Área operativa no mezcla categorías heredadas',async()=>{
  const t=await page.locator('#n-area').innerText();return t.includes('Heladería')&&!t.includes('Limpieza')&&!t.includes('Vitrina')&&!t.includes('Sándwiches');
});
await page.fill('#n-nombre','Helado de vainilla');
await page.click('#n-guardar');
await page.waitForSelector('#overlay-area-producto.open');
await check('duplicado ofrece usar la ficha coincidente',async()=>{
  const t=await page.locator('#overlay-area-producto').innerText();return t.includes('Este producto ya existe')&&t.includes('Helado de vainilla')&&t.includes('Usar producto existente')&&t.includes('no se creará una copia');
});
await page.click('#area-producto-cancelar');
await page.evaluate(()=>abrirNuevoProducto('heladeria'));
await page.fill('#n-nombre','Paleta de menta sintética');
await page.click('#n-guardar');
await page.waitForFunction(()=>window.__rpcWrites.some(x=>x.name==='producto_plaza_crear'));
await check('producto verdaderamente nuevo usa la RPC con área y saldo cero',async()=>page.evaluate(()=>{
  const x=window.__rpcWrites.find(w=>w.name==='producto_plaza_crear');
  return x?.args.p_area_id==='area-heladeria'&&!('p_stock_actual' in x.args);
}));
await page.evaluate(()=>{PERMISOS.puede_ajustes=false;PERMISOS.puede_editar=false;aplicarPermisos();pickTab('inv');render();});
await check('usuario común no ve gestión ni asignación',async()=>
  (await page.locator('[data-area-manage]').count())===0&&(await page.locator('[data-area-assign]').count())===0);
await page.evaluate(()=>{PERMISOS.puede_ajustes=true;PERMISOS.puede_editar=true;PERMISOS.es_propietario_raiz=false;aplicarPermisos();render();});
await check('administrador operativo conserva gestión sin gobierno de usuarios',async()=>
  (await page.locator('[data-area-manage]').count())===1&&page.evaluate(()=>!PERMISOS.es_propietario_raiz));
await check('sin escrituras directas, Fudo ni errores JavaScript',async()=>page.evaluate(()=>
  window.__tableWrites.length===0&&window.__fudoCalls.length===0).then(ok=>ok&&errors.length===0));
await check('móvil sin scroll horizontal accidental',async()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
await page.setViewportSize({width:1280,height:800});await page.waitForTimeout(100);
await check('escritorio conserva navegación y gestión visible',async()=>
  page.evaluate(()=>getComputedStyle(document.getElementById('mobileBottom')).display==='none')&&page.locator('[data-area-manage]').isVisible());

await browser.close();
