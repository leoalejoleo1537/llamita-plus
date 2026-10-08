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
  producto_id:p.id,producto:p.producto,rubro:p.rubro,tipo:p.tipo,unidad:p.unidad,
  cantidad:saldos[`${p.id}|${codigo}`]||0,
})));
const permisos=[{correo:'lectura@test.invalid',nombre:'Lectura',puede_editar:true,puede_fudo:false,puede_ajustes:true,puede_lama:false}];
const page=await browser.newPage();
await page.addInitScript(({productos,permisos,lectura,catalogo})=>{
  window.__writes=[];window.__rpc=[];
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
    rpc:(name)=>{window.__rpc.push(name);return Promise.resolve({data:name==='stock_leer_areas'?lectura:name==='areas_operativas_listar'?catalogo:[],error:null});},
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
await check('portada agrega automáticamente Heladería, Sin asignar y Todas las áreas',async()=>
  await page.locator('.area-card').count()===7);
await check('áreas físicas empiezan en cero y no inventan críticos',async()=>{
  const t=await page.locator('.area-cover').innerText();
  return ['Cocina fría','Cocina caliente','Barra','Cafetería','Heladería'].every(n=>t.includes(n))
    && (t.match(/0 productos con saldo/g)||[]).length===5
    && (t.match(/0 unidades/g)||[]).length===5
    && t.includes('sin mínimos configurados');
});
await check('Sin asignar y Todas las áreas muestran unidades del libro',async()=>{
  const sin=await page.locator('[data-area-open="sin_asignar"]').innerText();
  const all=await page.locator('.area-card[data-area-open="__todas__"]').innerText();
  return sin.includes('12 unidades')&&all.includes('17 unidades');
});

await page.click('[data-area-open="cocina_fria"]');
await check('un área sin saldo no muestra el catálogo de otras ubicaciones',async()=>
  (await page.locator('#list').innerText()).includes('No hay productos que coincidan.')
  && !(await page.locator('#list').innerText()).includes('Leche entera'));

await page.click('#areaNav [data-area-home]');
await page.click('[data-area-open="cafeteria"]');
await page.fill('#q','leche');
await page.waitForTimeout(30);
await check('buscar leche en Cafetería aísla la lectura a esa ubicación',async()=>{
  const t=await page.locator('#list').innerText();
  return (await page.locator('#topSede').innerText())==='Inventario · Cafetería'
    && t.includes('Leche entera')&&t.includes('3 L')&&!t.includes('Azúcar blanca')&&!t.includes('999');
});

await page.click('#areaNav [data-area-home]');
await page.click('.area-card[data-area-open="__todas__"]');
await check('vista global separa las cantidades por área',async()=>{
  const fila=page.locator('.area-global-product').filter({hasText:'Leche entera'});
  const t=await fila.innerText();
  return t.includes('Cafetería')&&t.includes('3')&&t.includes('Barra')&&t.includes('2')&&t.includes('Sin asignar')&&t.includes('5');
});
await page.locator('.area-global-link[data-area-open="cafeteria"][data-area-product="Leche entera"]').click();
await check('desde global se abre el producto filtrado dentro de su área',async()=>
  (await page.locator('#topSede').innerText())==='Inventario · Cafetería'
  && (await page.locator('#q').inputValue())==='Leche entera'
  && (await page.locator('#list').innerText()).includes('3 L'));
await check('la navegación de áreas no escribe datos',async()=>
  (await page.evaluate(()=>window.__writes.length))===0);
await check('la lectura usa la RPC del libro, no un RPC de escritura',async()=>
  (await page.evaluate(()=>window.__rpc.includes('stock_leer_areas')))
  && !(await page.evaluate(()=>window.__rpc.includes('stock_transferir'))));

await page.evaluate(()=>pickSede('central'));
await page.waitForSelector('#list .row');
await check('Bodega conserva la lista de Inventario y su saldo actual',async()=>
  (await page.locator('#list').innerText()).includes('Leche Bodega')
  && !(await page.locator('#areaNav').isVisible()));
await check('sin errores de JavaScript en navegador',async()=>errors.length===0||errors.join('; '));

await browser.close();
if(failures.length)process.exit(1);
