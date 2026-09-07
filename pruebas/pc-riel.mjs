/* PC · EL RIEL DE LA IZQUIERDA.
   node pruebas/pc-riel.mjs

   Jhon, 2026-09-05: "ampliame la pantalla para el pc de todo Llamita Plus…
   manten siempre desplegado el panel de la izquierda, mete ahi recetas y
   mermas".

   QUÉ SE PRUEBA, Y POR QUÉ EN LAS DOS DIRECCIONES. Lo que hace peligroso a un
   cambio de disposición es que arregla una pantalla y rompe otra sin que
   nadie mire: el teléfono es donde trabaja el equipo, y es justamente donde
   nadie va a probar esto. Así que cada caso se comprueba ancho Y angosto.

   Y se prueba el INTERRUPTOR apagado (§2.2): apagado tiene que quedar
   exactamente la barra horizontal de siempre, no un hueco.                */
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
    window.__rpc = [];
    const SES = {user:{id:'u1', email:'jhon@cafe.cl', user_metadata:{nombre:'Jhon'}}};
    const T = {
      productos:[{id:1, sede:'plaza', producto:'Medialuna manjar', rubro:'Vitrina', stock_actual:20, activo:'SÍ'}],
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
        insert(v){ const rows=(Array.isArray(v)?v:[v]).map(r=>({id:++seq, ...r}));
          const e={select:()=>e, single:()=>Promise.resolve({data:rows[0],error:null}),
                   then:f=>Promise.resolve({data:rows,error:null}).then(f)}; return e; },
        update(){const e={eq:()=>e,in:()=>e,select:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        upsert(){const e={select:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        delete(){const e={eq:()=>e,in:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
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
  await page.click('.gate-btn[data-sede="plaza"]');
  await page.waitForTimeout(700);
}


const errores = [];
page.on('pageerror', e=>errores.push(String(e)));

let ok=0, mal=0;
const caso = async (n, fn) => {
  try { const r = await fn(); if(r===true){ok++;console.log('  ✓ '+n);}
        else {mal++;console.log('  ✗ '+n+'  → '+r);} }
  catch(e){ mal++; console.log('  ✗ '+n+'  → '+e.message.split('\n')[0]); }
};

const medir = () => page.evaluate(() => {
  const tabs = document.querySelector('.tabs');
  const car  = document.getElementById('tabCarril');
  const act  = document.querySelector('.tab.active');
  const inv  = document.getElementById('view-inv');
  return {
    clase:   document.body.classList.contains('pc-ancho'),
    pos:     getComputedStyle(tabs).position,
    padL:    parseFloat(getComputedStyle(document.body).paddingLeft),
    anchoTabs: tabs.getBoundingClientRect().width,
    invW:    inv ? Math.round(inv.getBoundingClientRect().width) : 0,
    invLeft: inv ? Math.round(inv.getBoundingClientRect().left) : 0,
    carrilY: car.style.transform.includes('translateY'),
    carrilAlto: car.style.height,
    carrilTapa: (()=>{ if(!act) return false;
      const a = act.getBoundingClientRect(), c = car.getBoundingClientRect();
      return Math.abs(a.top - c.top) < 2 && Math.abs(a.left - c.left) < 2
          && Math.abs(a.height - c.height) < 2; })(),
    marca:   !!document.querySelector('.riel-marca') &&
             getComputedStyle(document.querySelector('.riel-marca')).display !== 'none',
    verTabs: [...document.querySelectorAll('.tab')]
               .filter(t => t.offsetParent !== null)
               .map(t => t.dataset.tab),
    scrollX: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    /* ¿Hace falta deslizar la barra para llegar a la última pestaña? Es
       exactamente lo que molestaba. */
    /* ¿Se ve todo sin deslizar? En el riel eso significa que ninguna
       pestaña se sale por el costado y que no hace falta scroll vertical.
       Antes esto miraba `inner.scrollWidth`, que en una columna no mide lo
       que uno cree — una comprobación que no comprueba lo que dice es peor
       que no tenerla. */
    seVeTodo: (()=>{
      const t = document.querySelector('.tabs');
      const caja = t.getBoundingClientRect();
      /* ⚠️ Mirar el rectángulo NO alcanza: en el riel las pestañas se
         estiran al ancho de la columna, así que la CAJA nunca se sale — el
         que se sale es el TEXTO. Se comprobó estrechando el riel a 96 px:
         con la comprobación vieja seguía en verde. Por eso se mira
         `scrollWidth`, que sí ve el texto que no entra. */
      const salen = [...document.querySelectorAll('.tab')]
        .filter(x => x.offsetParent !== null)
        .filter(x => x.getBoundingClientRect().right > caja.right + 1
                  || x.scrollWidth > x.clientWidth + 1);
      return salen.length === 0 && t.scrollHeight <= t.clientHeight + 1;
    })(),
  };
});

const ir = async (w,h) => { await page.setViewportSize({width:w, height:h});
                            await page.waitForTimeout(250); };

await montar({puedeLama:true});
/* Con permiso de Lama la app aterriza en Mesas, así que el inventario está
   escondido y mediría 0. Se entra a Inventario, que es la pantalla cuyo
   ancho estamos probando. */
await page.click('.tab[data-tab="inv"]');
await page.waitForTimeout(350);

console.log('\nEN EL COMPUTADOR (1440 px) · el riel:');
await ir(1440, 900);
let m = await medir();
await caso('la clase `pc-ancho` está puesta', async () => m.clase || 'no se puso');
await caso('la barra se paró: es un riel fijo a la izquierda', async () =>
  (m.pos === 'fixed' && m.anchoTabs > 180 && m.anchoTabs < 240) || `pos=${m.pos} ancho=${m.anchoTabs}`);
await caso('el contenido se corre y NO queda debajo del riel', async () =>
  (m.padL >= 200 && m.invLeft >= 200) || `padL=${m.padL} left=${m.invLeft}`);
await caso('el inventario aprovecha el ancho (era 900)', async () =>
  m.invW > 1000 || `mide ${m.invW}`);
await caso('la marca "Llamita Plus" aparece arriba del riel', async () =>
  m.marca || 'no se ve');
await caso('NO hay que deslizar nada para ver todas las secciones', async () =>
  m.seVeTodo || 'alguna pestaña se sale del riel, o el riel pide scroll');
await caso('Recetas está a la vista', async () => m.verTabs.includes('recetas') || m.verTabs.join());
await caso('Mesas (la casita) está a la vista', async () => m.verTabs.includes('lama') || m.verTabs.join());
await caso('el carril viaja hacia abajo, no al costado', async () =>
  m.carrilY || `transform vertical ausente`);
await caso('y queda justo encima de la pestaña activa', async () => m.carrilTapa || 'descolocado');
await caso('la página no se desborda a lo ancho', async () => !m.scrollX || 'hay scroll horizontal');

console.log('\nAL CAMBIAR DE PESTAÑA · el carril sigue puesto:');
await page.click('.tab[data-tab="recetas"]');
await page.waitForTimeout(450);
m = await medir();
await caso('sigue encima de la nueva activa', async () => m.carrilTapa || 'quedó atrás');
await page.click('.tab[data-tab="inv"]');
await page.waitForTimeout(400);

console.log('\nEN EL TELÉFONO (390 px) · TODO como antes:');
await ir(390, 844);
m = await medir();
await caso('la barra vuelve a ser horizontal y pegajosa', async () =>
  m.pos === 'sticky' || `pos=${m.pos}`);
await caso('el contenido no se corre', async () => m.padL === 0 || `padL=${m.padL}`);
await caso('la marca del riel NO se ve', async () => !m.marca || 'se coló en el teléfono');
await caso('el carril vuelve a viajar al costado', async () => !m.carrilY || 'quedó vertical');
await caso('y sigue encima de la activa', async () => m.carrilTapa || 'descolocado');
await caso('sin scroll horizontal', async () => !m.scrollX || 'la página se desborda');

console.log('\nJUSTO DEBAJO DEL UMBRAL (1079 px) · todavía es teléfono:');
await ir(1079, 800);
m = await medir();
await caso('la barra sigue horizontal', async () => m.pos === 'sticky' || `pos=${m.pos}`);
await caso('el carril sigue al costado', async () => !m.carrilY || 'se puso vertical antes de tiempo');

console.log('\nJUSTO ENCIMA (1080 px) · ya es riel:');
await ir(1080, 800);
m = await medir();
await caso('la barra se paró', async () => m.pos === 'fixed' || `pos=${m.pos}`);
await caso('el carril se puso vertical', async () => m.carrilY || 'siguió horizontal');
await caso('y encima de la activa', async () => m.carrilTapa || 'descolocado');

console.log('\nDOS COLUMNAS · recién a los 1400, no antes:');
await ir(1200, 900);
let cols = await page.evaluate(() => getComputedStyle(document.getElementById('list')).gridTemplateColumns);
await caso('a 1200 el inventario va en una columna', async () =>
  !cols.includes(' ') || `son varias: ${cols}`);
await ir(1500, 900);
cols = await page.evaluate(() => getComputedStyle(document.getElementById('list')).gridTemplateColumns);
await caso('a 1500 se parte en dos', async () =>
  cols.split(' ').length === 2 || `da ${cols}`);

console.log('\nEL INTERRUPTOR APAGADO · vuelve exactamente a lo de antes (§2.2):');
/* ⚠️ EL ORDEN IMPORTA, y este caso lo aprendió a la mala. `PC_ANCHO` es una
   constante y no se puede apagar desde acá, así que se simula sacándole la
   clase al cuerpo. Pero desde el 2026-09-07 hay un manejador de `resize` que
   la vuelve a poner: quitarla ANTES de cambiar el tamaño no servía de nada.
   Primero se acomoda la ventana, y recién después se apaga. */
await ir(1440, 900);
await page.evaluate(() => document.body.classList.remove('pc-ancho'));
await page.waitForTimeout(200);
m = await medir();
await caso('la barra vuelve a ser horizontal', async () => m.pos === 'sticky' || `pos=${m.pos}`);
await caso('el contenido vuelve a su ancho de siempre', async () =>
  m.invW === 900 || `mide ${m.invW}`);
await caso('no queda un hueco a la izquierda', async () => m.padL === 0 || `padL=${m.padL}`);
await caso('la marca del riel desaparece', async () => !m.marca || 'quedó colgada');


console.log('\n🔴 LA CHINCHETA · fijar y soltar el panel:');
await ir(1440, 900);
await page.evaluate(() => { try{ localStorage.removeItem('llamita_menu_fijo'); }catch{} });
await page.reload(); await page.waitForTimeout(600);
await page.click('.gate-btn[data-sede="plaza"]').catch(()=>{});
await page.waitForTimeout(700);

await caso('de fábrica el panel viene fijo', async () =>
  await page.evaluate(() => document.body.classList.contains('menu-fijo')) || 'nace suelto');
await caso('el menú entero se mudó adentro del panel', async () =>
  await page.evaluate(() =>
    document.getElementById('drawer').closest('.tabs') !== null)
  || 'el cajón sigue colgando del cuerpo de la página');
await caso('y es el MISMO cajón, no una copia', async () =>
  await page.evaluate(() => document.querySelectorAll('#drawer, .drawer').length) === 1
  || 'hay dos menús: se van a desincronizar');
await caso('con el panel fijo, las tres rayas desaparecen', async () =>
  !(await page.isVisible('#btnMenu')) || 'ofrece abrir algo que ya está abierto');
await caso('Actualizar, Historial y Cambiar sede están a la vista', async () => {
  const faltan = [];
  for(const a of ['actualizar','historial','cambiar-sede'])
    if(!(await page.isVisible(`[data-accion="${a}"]`))) faltan.push(a);
  return faltan.length === 0 || 'no se ven: ' + faltan.join(', ');
});
await caso('el nombre de la sede se lee (no quedó en "—")', async () =>
  ((await page.textContent('#drawerSede')) || '').includes('Plaza')
  || 'dice: ' + (await page.textContent('#drawerSede')));
await caso('la chincheta está, chiquita y a la vista', async () =>
  await page.isVisible('#fijarRiel') || 'no hay cómo soltarlo');

console.log('\nAL SOLTARLO · el panel se va ENTERO, no se queda a medias:');
await page.click('#fijarRiel'); await page.waitForTimeout(500);
await caso('el riel desaparece', async () =>
  await page.evaluate(() => getComputedStyle(document.querySelector('.tabs')).position) === 'sticky'
  || 'el panel sigue puesto');
await caso('las pestañas vuelven arriba, horizontales', async () =>
  await page.isVisible('#tabInv') || 'se perdieron las pestañas');
await caso('el contenido recupera todo el ancho', async () =>
  await page.evaluate(() => parseFloat(getComputedStyle(document.body).paddingLeft)) === 0
  || 'quedó un hueco a la izquierda');
await caso('vuelven las tres rayas', async () =>
  await page.isVisible('#btnMenu') || 'no hay forma de abrir el menú');
await caso('el cajón vuelve a ser cajón', async () =>
  await page.evaluate(() =>
    document.getElementById('drawer').parentElement === document.body)
  || 'quedó colgando adentro del riel apagado');

console.log('\n🔴 Y SE PUEDE VOLVER · un camino de ida sería una trampa:');
await page.click('#btnMenu'); await page.waitForTimeout(400);
await caso('el "Fijar el panel" está adentro del menú', async () =>
  await page.isVisible('#fijarMenu') || 'no hay cómo volver a fijarlo');
await page.click('#fijarMenu'); await page.waitForTimeout(600);
await caso('y el panel vuelve', async () =>
  await page.evaluate(() => document.body.classList.contains('menu-fijo')) || 'no volvió');
await caso('se cierra el cajón al fijarlo, sin dejarlo abierto encima', async () =>
  !(await page.evaluate(() => document.getElementById('scrim').classList.contains('open')))
  || 'quedó el fondo oscuro puesto');

console.log('\nSE ACUERDA · es una preferencia de ESTE aparato:');
await caso('lo elegido queda guardado', async () =>
  await page.evaluate(() => { try{ return localStorage.getItem('llamita_menu_fijo'); }catch{ return null; } }) === 'si'
  || 'no se guardó');
await page.click('#fijarRiel'); await page.waitForTimeout(400);
await page.reload(); await page.waitForTimeout(700);
await page.click('.gate-btn[data-sede="plaza"]').catch(()=>{});
await page.waitForTimeout(700);
await caso('al recargar sigue suelto, no vuelve solo', async () =>
  !(await page.evaluate(() => document.body.classList.contains('menu-fijo')))
  || 'se volvió a fijar solo y perdió lo que el local eligió');

console.log('\nEN EL TELÉFONO la chincheta NO existe:');
await ir(390, 844);
await caso('no se ofrece fijar nada', async () =>
  !(await page.isVisible('#fijarMenu')) || 'ofrece algo que no se puede hacer en un teléfono');
await caso('y el menú sigue siendo el cajón de siempre', async () =>
  await page.isVisible('#btnMenu') || 'se quedó sin menú');
await ir(1440, 900);
await page.evaluate(() => { try{ localStorage.removeItem('llamita_menu_fijo'); }catch{} });

console.log('\nY NINGÚN ERROR DE JAVASCRIPT EN TODA LA SESIÓN:');
await caso('la consola quedó limpia', async () =>
  errores.length === 0 || errores[0]);

console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();
process.exit(mal ? 1 : 0);
