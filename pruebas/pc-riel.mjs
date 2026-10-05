/* Navegación fija, paletas locales y filtros: solo fixtures, sin base real. */
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await abrirNavegador();
if (!browser) { console.log('\n(se salta: no hay navegador instalado)\n'); process.exit(0); }

const MESAS = Array.from({length:12}, (_,i)=>({
  id:100+i, sede:'plaza', salon:'Salón', numero:i+1, orden:i+1, activa:true }));

/* La mesa 2 nace ocupada y la 3 cobrando: así los tres colores se ven sin
   tener que abrir nada, y se prueba que el estado manda sobre el color. */
const CUENTAS = [
  {id:900, sede:'plaza', mesa_id:101, estado:'abierta',   total:2900, abierta_por:'adriana@cafe.cl'},
  {id:901, sede:'plaza', mesa_id:102, estado:'precuenta', total:6800, abierta_por:'adriana@cafe.cl'},
];
const ITEMS = [
  {id:1, cuenta_id:900, nombre:'Medialuna manjar', cantidad:1, precio:2900, estado:'confirmado', comentario:null},
];
const CARTA = [
  {fudo_product_id:'F-33', sede:'plaza', nombre:'Americano',        precio:2500, activo:true},
  {fudo_product_id:'F-38', sede:'plaza', nombre:'Café Latte',       precio:3400, activo:true},
  {fudo_product_id:'F-99', sede:'plaza', nombre:'Medialuna manjar', precio:2900, activo:true},
  /* Sin precio: NO tiene que aparecer en la carta. Un producto a $0 en una
     comanda es una venta que nadie cobra. */
  {fudo_product_id:'F-00', sede:'plaza', nombre:'Producto interno', precio:0,    activo:true},
];

const page = await browser.newPage();
await page.setViewportSize({width:390, height:900});

async function montar({puedeLama}){
  await page.addInitScript(({MESAS, CUENTAS, ITEMS, CARTA, puedeLama}) => {
    window.__rpc = []; window.__writes=[]; localStorage.setItem("llamita_menu_fijo","no");
    const SES = {user:{id:'u1', email:'jhon@cafe.cl', user_metadata:{nombre:'Jhon'}}};
    const T = {
      productos:[{id:2,sede:'plaza',producto:'Torta Matilda',rubro:'Vitrina',tipo:'Tortas',stock_actual:0,stock_min:2,activo:'SÍ'}, {id:1, sede:'plaza', producto:'Medialuna manjar', rubro:'Vitrina', stock_actual:20, stock_min:2, tipo:'Bollería', activo:'SÍ'}],
      mesas:MESAS, cuentas:CUENTAS, cuenta_items:ITEMS, comandas:[],
      fudo_productos:CARTA,
      app_permisos:[{correo:'jhon@cafe.cl', nombre:'Jhon', puede_ajustes:true,
                     puede_editar:true, puede_fudo:true, puede_lama:puedeLama, fudo_bloqueos:[]}],
      producto_enlace:[], fudo_stock_push:[], fudo_sync:[], secciones:[], movimientos:[],
      ajustes:[], metas:[], historial:[], historial_auto:[], restauraciones:[], fusiones:[],
      recetas:[], receta_items:[], producto_lotes:[], repartos:[], reparto_items:[],
      mermas:[], tareas:[], fudo_categorias:[], envios_franquicia:[], envios_franquicia_items:[]};
    let seq = 7000;
    const q = (n) => {
      let filas = JSON.parse(JSON.stringify(T[n]||[]));
      const api = {
        select(){return api;}, eq(c,v){ filas=filas.filter(f=>String(f[c])===String(v)); return api;},
        neq(c,v){ filas=filas.filter(f=>String(f[c])!==String(v)); return api;},
        in(c,vs){ filas=filas.filter(f=>vs.map(String).includes(String(f[c]))); return api;},
        order(){return api;}, limit(){return api;}, gte(){return api;}, lte(){return api;},
        is(){return api;}, not(){return api;}, or(){return api;}, ilike(){return api;},
        maybeSingle(){return Promise.resolve({data:filas[0]||null,error:null});},
        single(){return Promise.resolve({data:filas[0]||null,error:null});},
        insert(v){ window.__writes.push(n); const rows=(Array.isArray(v)?v:[v]).map(r=>({id:++seq, ...r}));
          const e={select:()=>e, single:()=>Promise.resolve({data:rows[0],error:null}),
                   then:f=>Promise.resolve({data:rows,error:null}).then(f)}; return e; },
        update(){window.__writes.push(n);const e={eq:()=>e,in:()=>e,select:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        upsert(){window.__writes.push(n);const e={select:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        delete(){window.__writes.push(n);const e={eq:()=>e,in:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        then(f){return Promise.resolve({data:filas,error:null,count:filas.length}).then(f);},
      };
      return api;
    };
    window.supabase = { createClient: () => ({
      from:q,
      /* Se anota QUÉ se le pidió a la base. Lo que se prueba es que la
         pantalla llame a la función correcta con los datos correctos — la
         lógica de las funciones ya está probada contra Postgres. */
      rpc:(nombre, args)=>{
        window.__rpc.push({nombre, args});
        if(nombre === 'mesa_abrir')
          return Promise.resolve({data:{id:950, sede:'plaza', mesa_id:args.p_mesa_id,
                                        estado:'abierta', total:0, abierta_por:'Jhon'}, error:null});
        if(nombre === 'cuenta_agregar')
          return Promise.resolve({data:{id:++seq, cuenta_id:args.p_cuenta_id, nombre:args.p_nombre,
                                        cantidad:1, precio:args.p_precio, estado:'nuevo'}, error:null});
        if(nombre === 'cuenta_confirmar')
          return Promise.resolve({data:{id:1, cuenta_id:args.p_cuenta_id, numero:1, quien:'Jhon',
                                        created_at:new Date().toISOString(),
                                        contenido:[{nombre:'Café Latte', cantidad:1, precio:3400, comentario:null}]}, error:null});
        if(nombre === 'cuenta_precuenta')
          return Promise.resolve({data:{id:args.p_cuenta_id, mesa_id:101, sede:'plaza',
                                        estado:'precuenta', total:2900}, error:null});
        if(nombre === 'cuenta_cerrar')
          return Promise.resolve({data:{id:args.p_cuenta_id, estado:'cerrada'}, error:null});
        return Promise.resolve({data:null, error:null});
      },
      auth:{ getSession:async()=>({data:{session:SES}}), getUser:async()=>({data:{user:SES.user}}),
             onAuthStateChange(cb){setTimeout(()=>cb&&cb('SIGNED_IN',SES),0);return {data:{subscription:{unsubscribe(){}}}};},
             signInWithPassword:async()=>({data:{session:SES},error:null}), signOut:async()=>({}) },
      channel:()=>({on(){return this;},subscribe(cb){cb&&cb('SUBSCRIBED');return this;},track:async()=>{},presenceState:()=>({})}),
      removeChannel(){}, functions:{invoke:async()=>({data:{ok:true},error:null})},
    })};
  }, {MESAS, CUENTAS, ITEMS, CARTA, puedeLama});
  await page.route('**/supabase-js*', r=>r.fulfill({status:200,contentType:'application/javascript',body:''}));
  await page.goto(pathToFileURL(join(raiz,'index.html')).href);
  await page.waitForTimeout(400);
  if(process.env.CAPTURA_SIDEBAR) await page.screenshot({path:`${process.env.CAPTURA_SIDEBAR}-login.png`,fullPage:true});
  await page.click('.gate-btn[data-sede="plaza"]');
  await page.waitForTimeout(700);
}


const errores = [];
page.on('pageerror', e=>errores.push(String(e)));
page.on('console', m=>{if(m.type()==='error') errores.push(m.text());});

let ok=0, mal=0;
const caso = async (n, fn) => {
  try { const r = await fn(); if(r===true){ok++;console.log('  ✓ '+n);}
        else {mal++;console.log('  ✗ '+n+'  → '+r);} }
  catch(e){ mal++; console.log('  ✗ '+n+'  → '+e.message.split('\n')[0]); }
};

await montar({puedeLama:true});
await page.click('#tabInv');
for(const width of [1440,1080,1079,768,390,320]){
  await page.setViewportSize({width,height:900});
  await page.waitForTimeout(200);
  await caso(`${width}px: panel fijo sin superponer contenido ni desbordar`,async()=>page.evaluate(()=>{
    const rail=document.querySelector('.tabs').getBoundingClientRect();
    const main=document.querySelector('#view-inv').getBoundingClientRect();
    return getComputedStyle(document.querySelector('.tabs')).position==='fixed'
      && rail.top===0 && rail.height===innerHeight && main.left>=rail.right
      && document.documentElement.scrollWidth<=innerWidth;
  }));
  await caso(`${width}px: encabezado centrado en el área útil`,async()=>page.evaluate(()=>{
    const rail=document.querySelector('.tabs').getBoundingClientRect();
    const title=document.querySelector('.top-tit').getBoundingClientRect();
    return Math.abs((title.left+title.right)/2-(rail.right+innerWidth)/2)<2;
  }));
  await caso(`${width}px: una sola navegación, sin marca ni controles de despliegue`,async()=>page.evaluate(()=>
    document.querySelectorAll('.tabs #drawer').length===1
    &&!document.querySelector('#fijarMenu,#fijarRiel,#btnMenu,.riel-marca')));
  await page.click('#paleta-trigger');
  await caso(`${width}px: selector visible dentro de la ventana y sobre el contenido`,async()=>page.evaluate(()=>{
    const panel=document.querySelector('#paleta-popover'),r=panel.getBoundingClientRect();
    return !panel.hidden && r.left>=0 && r.top>=0 && r.right<=innerWidth && r.bottom<=innerHeight
      && panel.contains(document.elementFromPoint(r.left+30,r.top+30));
  }));
  await page.keyboard.press('Escape');
  if(process.env.CAPTURA_SIDEBAR && [1440,390].includes(width))
    await page.screenshot({path:`${process.env.CAPTURA_SIDEBAR}-${width}.png`,fullPage:true});
}
await page.setViewportSize({width:1440,height:900});
await page.evaluate(()=>{window.__writes=[];window.__rpc=[];});
const fondos=new Set();
for(const paleta of ['tierra','cacao','olivo','arcilla','petroleo']){
  const antes=await page.locator('#view-inv').boundingBox();
  await page.click('#paleta-trigger');
  await page.click(`.paleta-opcion[data-paleta="${paleta}"]`);
  await caso(`${paleta}: aplica, guarda localmente y cierra sin mover el layout`,async()=>{
    const despues=await page.locator('#view-inv').boundingBox();
    return JSON.stringify(antes)===JSON.stringify(despues) && await page.evaluate(p=>
      document.documentElement.dataset.paleta===p && localStorage.getItem('llamita_paleta')===p
      && document.querySelector('#paleta-popover').hidden,paleta);
  });
  fondos.add(await page.evaluate(()=>getComputedStyle(document.body).backgroundColor));
}
await caso('cinco fondos distintos sin escrituras ni RPC al cambiar paleta',async()=>
  fondos.size===5 && await page.evaluate(()=>!window.__writes.length&&!window.__rpc.length));
await page.reload();await page.waitForTimeout(500);
await page.click('.gate-btn[data-sede="plaza"]');await page.waitForTimeout(500);await page.click('#tabInv');
await caso('la preferencia de paleta sobrevive recarga; el antiguo panel suelto se ignora',async()=>page.evaluate(()=>
  document.documentElement.dataset.paleta==='petroleo'
  && getComputedStyle(document.querySelector('.tabs')).position==='fixed'
  && localStorage.getItem('llamita_menu_fijo')==='no'));
await page.click('#paleta-trigger');await page.click('#q');
await caso('clic fuera cierra el selector',async()=>!await page.isVisible('#paleta-popover'));
await page.click('#paleta-trigger');await page.keyboard.press('Escape');
await caso('Escape cierra y devuelve foco',async()=>page.evaluate(()=>
  document.querySelector('#paleta-popover').hidden&&document.activeElement.id==='paleta-trigger'));
await page.click('#paleta-trigger');await page.click('#paleta-trigger');
await caso('el botón también cierra el selector',async()=>!await page.isVisible('#paleta-popover'));
await page.selectOption('#tipos','Tortas');
await page.selectOption('#inv-estado','critico');
await page.click('.sec-btn');
await caso('categoría y estado filtran las filas existentes',async()=>
  (await page.locator('#list .row').count())===1&&(await page.textContent('#list')).includes('Torta Matilda'));
await page.click('#inv-limpiar');
await caso('Limpiar reinicia búsqueda, categoría, estado y métricas',async()=>page.evaluate(()=>
  !document.querySelector('#tipos').value&&!document.querySelector('#inv-estado').value
  &&!document.querySelector('#q').value&&!document.querySelector('.mcard.sel')));
await page.fill('#q','medialuna');
await caso('el buscador conserva su comportamiento',async()=>
  (await page.locator('#list .row').count())===1&&(await page.textContent('#list')).includes('Medialuna'));
await page.click('[data-accion="ajustes"]');
await caso('Ajustes mantiene navegación accesible y estado activo',async()=>
  await page.isVisible('#view-ajustes')&&await page.isVisible('#tabInv')
  && await page.locator('[data-accion="ajustes"]').evaluate(b=>b.classList.contains('active')));
await page.click('#tabInv');
await caso('se vuelve a Inventario por el mismo panel',async()=>await page.isVisible('#view-inv'));
await caso('sin errores de JavaScript ni consola',async()=>errores.length===0||errores.join('\n'));
console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();process.exit(mal?1:0);
