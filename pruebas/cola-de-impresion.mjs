/* LA COLA DE IMPRESIÓN · lo que la app le deja al puente.
   node pruebas/cola-de-impresion.mjs

   LO QUE MÁS IMPORTA es la TERCERA comanda, la que Jhon nombró el 2026-09-05
   y no existía: cuando se anula algo YA COMANDADO tiene que salir un papel.
   Sin él **la cocina sigue preparando lo que ya no va** — la primera comanda
   dijo "hacé esto" y nada la contradijo nunca.

   Y el caso hermano vale igual: anular algo que NUNCA salió a la cocina **no
   imprime nada**. Un papel que dice "no prepares esto" sobre algo que nadie
   estaba preparando es ruido, y el ruido enseña a ignorar los papeles que sí
   importan. Los dos se prueban, porque un aviso que aparece siempre y uno que
   no aparece nunca fallan igual de feo.                                   */
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await abrirNavegador();
if (!browser) { console.log('\n(se salta: no hay navegador instalado)\n'); process.exit(0); }

const MESAS = Array.from({length:8}, (_,i)=>({
  id:100+i, sede:'plaza', salon:'Salón', numero:i+1, orden:i+1, activa:true }));
const CUENTAS = [
  {id:900, sede:'plaza', mesa_id:101, estado:'abierta', total:9400, abierta_por:'jhon@cafe.cl'},
];
/* Uno ya enviado, uno todavía pendiente y uno ya anulado: los tres estados
   se ven de entrada, sin tener que provocarlos. */
const ITEMS = [
  {id:1, cuenta_id:900, fudo_product_id:'F-40', nombre:'Café Cortado', cantidad:1,
   precio:3000, estado:'confirmado', comentario:null, anulado_at:null},
  {id:2, cuenta_id:900, fudo_product_id:'F-38', nombre:'Café Latte', cantidad:1,
   precio:3400, estado:'confirmado', comentario:null, anulado_at:null},
  {id:3, cuenta_id:900, fudo_product_id:'F-33', nombre:'Americano', cantidad:1,
   precio:3000, estado:'nuevo', comentario:null, anulado_at:null},
];
const CARTA = [
  {fudo_product_id:'F-33', sede:'plaza', nombre:'Americano',    precio:3000, activo:true},
  {fudo_product_id:'F-38', sede:'plaza', nombre:'Café Latte',   precio:3400, activo:true},
  {fudo_product_id:'F-40', sede:'plaza', nombre:'Café Cortado', precio:3000, activo:true},
];
const MOTIVOS_ANU = [
  {codigo:'error_registro', nombre:'Error de registro',      orden:1, pide_comentario:false, activo:true},
  {codigo:'no_disponible',  nombre:'Producto no disponible', orden:2, pide_comentario:false, activo:true},
  {codigo:'cambio',         nombre:'Cambio de producto',     orden:3, pide_comentario:false, activo:true},
  {codigo:'cliente',        nombre:'Cancelado por cliente',  orden:4, pide_comentario:false, activo:true},
  {codigo:'prueba',         nombre:'Prueba',                 orden:5, pide_comentario:false, activo:true},
  {codigo:'otro',           nombre:'Otro',                   orden:9, pide_comentario:true,  activo:true},
];

const page = await browser.newPage();
await page.setViewportSize({width:1280, height:900});

async function montar({conMigracion = true} = {}){
  await page.addInitScript(({MESAS, CUENTAS, ITEMS, CARTA, MOTIVOS_ANU, conMigracion}) => {
    window.__rpc = [];
    window.__esc = [];
    const SES = {user:{id:'u1', email:'jhon@cafe.cl', user_metadata:{nombre:'Jhon'}}};
    /* La base de mentira guarda los items en vivo: anular tiene que poder
       marcar la fila y que la siguiente lectura la traiga marcada. Sin eso no
       se estaría probando nada. */
    const VIVOS = JSON.parse(JSON.stringify(ITEMS));
    const T = {
      productos:[], mesas:MESAS, cuentas:CUENTAS, cuenta_items:VIVOS, comandas:[],
      fudo_productos:CARTA,
      lama_medios_pago:[], lama_motivos_descuento:[],
      /* Sin la migración corrida esta tabla NO existe: es el estado real de
         la base hasta que Jhon pegue el .sql. */
      lama_motivos_anulacion: conMigracion ? MOTIVOS_ANU : null,
      lama_impresiones: [],
      app_permisos:[{correo:'jhon@cafe.cl', nombre:'Jhon', puede_ajustes:true,
                     puede_editar:true, puede_fudo:true, puede_lama:true, fudo_bloqueos:[]}],
      producto_enlace:[], fudo_stock_push:[], fudo_sync:[], secciones:[], movimientos:[],
      ajustes:[], metas:[], historial:[], historial_auto:[], restauraciones:[], fusiones:[],
      recetas:[], receta_items:[], producto_lotes:[], repartos:[], reparto_items:[],
      mermas:[], tareas:[], fudo_categorias:[], envios_franquicia:[], envios_franquicia_items:[]};
    let seq = 7000;
    const q = (n) => {
      const falta = T[n] === null;
      let filas = falta ? [] : JSON.parse(JSON.stringify(T[n]||[]));
      const err = falta
        ? {message:'relation "public.'+n+'" does not exist', code:'42P01'} : null;
      const api = {
        select(){return api;}, eq(c,v){ filas=filas.filter(f=>String(f[c])===String(v)); return api;},
        neq(c,v){ filas=filas.filter(f=>String(f[c])!==String(v)); return api;},
        in(c,vs){ filas=filas.filter(f=>vs.map(String).includes(String(f[c]))); return api;},
        order(){return api;}, limit(){return api;}, gte(){return api;}, lte(){return api;},
        is(){return api;}, not(){return api;}, or(){return api;}, ilike(){return api;},
        maybeSingle(){return Promise.resolve({data:filas[0]||null,error:err});},
        single(){return Promise.resolve({data:filas[0]||null,error:err});},
        insert(v){ window.__esc.push({tabla:n, op:'insert', datos:v});
          /* La cola guarda de verdad: la pantalla de Ajustes tiene que poder
             listar lo que se acaba de encolar, o probaríamos media cosa. */
          if(n === 'lama_impresiones'){
            (Array.isArray(v)?v:[v]).forEach(r =>
              T.lama_impresiones.unshift({id:++seq, estado:'pendiente',
                creada_at:new Date().toISOString(), ...r}));
          } const rows=(Array.isArray(v)?v:[v]).map(r=>({id:++seq, ...r}));
          const e={select:()=>e, single:()=>Promise.resolve({data:rows[0],error:null}),
                   then:f=>Promise.resolve({data:rows,error:null}).then(f)}; return e; },
        update(){const e={eq:()=>e,in:()=>e,select:()=>e,
                 single:()=>Promise.resolve({data:filas[0]||null,error:null}),
                 then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        upsert(){const e={select:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        delete(){ let cond=null;
          const e={eq:(c,v)=>{cond={c,vs:[String(v)]};return e;},
                   in:(c,vs)=>{cond={c,vs:vs.map(String)};return e;},
                   then:f=>{ if(n==='cuenta_items' && cond){
                       for(let k=VIVOS.length-1;k>=0;k--)
                         if(cond.vs.includes(String(VIVOS[k][cond.c]))) VIVOS.splice(k,1);
                     }
                     return Promise.resolve({data:[],error:null}).then(f); }};
          return e; },
        then(f){return Promise.resolve({data: falta?null:filas, error:err, count:filas.length}).then(f);},
      };
      return api;
    };
    window.supabase = { createClient: () => ({
      from:q,
      rpc:(nombre, args)=>{
        window.__rpc.push({nombre, args});
        if(nombre === 'item_anular'){
          if(!conMigracion)
            return Promise.resolve({data:null,
              error:{message:'function public.item_anular(...) does not exist', code:'42883'}});
          const it = VIVOS.find(x => x.id === args.p_item_id);
          if(!it) return Promise.resolve({data:null, error:{message:'no existe'}});
          it.anulado_at = new Date().toISOString();
          it.anulado_por = args.p_quien;
          it.anulado_motivo = args.p_motivo;
          it.anulado_comentario = args.p_comentario;
          return Promise.resolve({data:JSON.parse(JSON.stringify(it)), error:null});
        }
        if(nombre === 'cuenta_agregar'){
          const fila = {id:++seq, cuenta_id:args.p_cuenta_id, fudo_product_id:args.p_fudo_id,
                        nombre:args.p_nombre, cantidad:1, precio:args.p_precio,
                        estado:'nuevo', comentario:args.p_comentario, anulado_at:null};
          VIVOS.push(fila);
          return Promise.resolve({data:JSON.parse(JSON.stringify(fila)), error:null});
        }
        if(nombre === 'cuenta_recalcular') return Promise.resolve({data:0, error:null});
        /* La comanda que devuelve la base al confirmar. Sin esto `lamaConfirmar`
           se va sin encolar nada, y la prueba culparía al código en vez del
           simulacro. */
        if(nombre === 'cuenta_confirmar'){
          const nuevos = VIVOS.filter(x => x.estado === 'nuevo' && !x.anulado_at);
          nuevos.forEach(x => { x.estado = 'confirmado'; });
          return Promise.resolve({data:{id:1, cuenta_id:args.p_cuenta_id, numero:1,
            quien:args.p_quien, created_at:new Date().toISOString(),
            contenido:nuevos.map(x => ({nombre:x.nombre, cantidad:x.cantidad,
                                        precio:x.precio, comentario:x.comentario}))},
            error:null});
        }
        if(nombre === 'cuenta_precuenta')
          return Promise.resolve({data:{id:args.p_cuenta_id, mesa_id:101, sede:'plaza',
                                        estado:'precuenta', total:6400}, error:null});
        return Promise.resolve({data:null, error:null});
      },
      auth:{ getSession:async()=>({data:{session:SES}}), getUser:async()=>({data:{user:SES.user}}),
             onAuthStateChange(cb){setTimeout(()=>cb&&cb('SIGNED_IN',SES),0);return {data:{subscription:{unsubscribe(){}}}};},
             signInWithPassword:async()=>({data:{session:SES},error:null}), signOut:async()=>({}) },
      channel:()=>({on(){return this;},subscribe(cb){cb&&cb('SUBSCRIBED');return this;},track:async()=>{},presenceState:()=>({})}),
      removeChannel(){}, functions:{invoke:async()=>({data:{ok:true},error:null})},
    })};
  }, {MESAS, CUENTAS, ITEMS, CARTA, MOTIVOS_ANU, conMigracion});
  await page.route('**/supabase-js*', r=>r.fulfill({status:200,contentType:'application/javascript',body:''}));
  await page.goto(pathToFileURL(join(raiz,'index.html')).href);
  await page.waitForTimeout(400);
  await page.click('.gate-btn[data-sede="plaza"]');
  await page.waitForTimeout(700);
  await page.click('#tabLama'); await page.waitForTimeout(500);
  await page.click('[data-lamamesa="101"]'); await page.waitForTimeout(450);
}


const errores = [];
page.on('pageerror', e=>errores.push(String(e)));

let ok=0, mal=0;
const caso = async (n, fn) => {
  try { const r = await fn(); if(r===true){ok++;console.log('  ✓ '+n);}
        else {mal++;console.log('  ✗ '+n+'  → '+r);} }
  catch(e){ mal++; console.log('  ✗ '+n+'  → '+e.message.split('\n')[0]); }
};
/* El buzón del puente: lo que se le pidió guardar a `lama_impresiones`. */
const cola = () => page.evaluate(() =>
  window.__esc.filter(x => x.tabla === 'lama_impresiones' && x.op === 'insert')
              .map(x => x.datos));
const limpiar = () => page.evaluate(() => { window.__esc = []; });
const anular = async (itemId, motivo) => {
  await page.click(`[data-lamaquitar="${itemId}"]`); await page.waitForTimeout(450);
  await page.click(`[data-anumotivo="${motivo}"]`);  await page.waitForTimeout(250);
  await page.click('[data-lamaacc="anu-confirmar"]'); await page.waitForTimeout(700);
};

await montar();
await page.click('[data-lamamesa="101"]');
await page.waitForTimeout(600);

console.log('\nLA COMANDA · lo que va a la cocina:');
await limpiar();
await page.click('[data-lamaacc="confirmar"]');
await page.waitForTimeout(700);
await caso('se encola un papel, y uno solo', async () =>
  (await cola()).length === 1 || 'se encolaron ' + (await cola()).length);
await caso('marcado como comanda', async () => (await cola())[0].tipo === 'comanda' || (await cola())[0].tipo);
await caso('con la sede, para que el puente del OTRO local no lo saque', async () =>
  (await cola())[0].sede === 'plaza' || (await cola())[0].sede);
await caso('lleva el número de mesa', async () =>
  (await cola())[0].contenido.includes('MESA 2') || (await cola())[0].contenido.slice(0,60));
await caso('y queda escrito quién lo mandó', async () =>
  !!(await cola())[0].quien || 'nadie firma la comanda');

console.log('\n🔴 LA TERCERA COMANDA · anular algo YA COMANDADO imprime:');
await limpiar();
await anular(2, 'no_disponible');       // el Café Latte, que está confirmado
const anu = await cola();
await caso('sale un papel', async () => anu.length === 1 || 'salieron ' + anu.length);
await caso('marcado como anulación', async () => anu[0] && anu[0].tipo === 'anulacion' || (anu[0]||{}).tipo);
await caso('grita ANULADO, no se disimula', async () =>
  anu[0].contenido.includes('ANULADO') || anu[0].contenido.slice(0,80));
await caso('nombra SOLO el producto anulado', async () =>
  (anu[0].contenido.includes('Café Latte') && !anu[0].contenido.includes('Café Cortado'))
  || 'trae de más o de menos: ' + anu[0].contenido.slice(0,120));
await caso('dice el motivo con palabras, no con un código', async () =>
  anu[0].contenido.includes('Producto no disponible') || anu[0].contenido);
await caso('y dice qué hacer: NO PREPARAR', async () =>
  anu[0].contenido.includes('NO PREPARAR') || 'no dice qué hacer con eso');

console.log('\nEL CASO HERMANO · lo que NUNCA salió a la cocina no imprime:');
/* Un producto en "nuevo" ni siquiera pide motivo: se quita y ya. Lo que se
   comprueba es que ese camino tampoco encole un papel. */
await montar();
await page.click('[data-lamamesa="101"]');
await page.waitForTimeout(600);
await limpiar();
await page.click('[data-lamaquitar="3"]');   // el Americano, en "nuevo"
await page.waitForTimeout(700);
await caso('se quita sin pedir motivo', async () =>
  !(await page.isVisible('.lama-anu-caja')) || 'pidió motivo por algo que nadie preparó');
await caso('y no se encola nada', async () =>
  (await cola()).length === 0 || 'imprimió ' + (await cola()).length + ' papel(es) de más');
/* ⚠️ ESTE CASO ENSEÑÓ ALGO. Al escribirlo, el código traía un `if (estado ===
   'confirmado')` antes de encolar la anulación — y al invertirlo a propósito
   la prueba SIGUIÓ EN VERDE. No fallaba porque ese `if` no protegía nada: a
   esa función sólo se llega por lo confirmado, así que era código muerto. Se
   sacó, y el caso se queda: sigue siendo la red que atrapa a quien mañana
   agregue un `lamaEncolar` en el camino del borrado. */

console.log('\nLA PRECUENTA:');
await montar();
await page.click('[data-lamamesa="101"]');
await page.waitForTimeout(600);
await limpiar();
await page.click('[data-lamaacc="precuenta"]');
await page.waitForTimeout(700);
await caso('se encola', async () => (await cola()).length === 1 || 'se encolaron ' + (await cola()).length);
await caso('marcada como precuenta y NO como comanda', async () =>
  (await cola())[0].tipo === 'precuenta' || (await cola())[0].tipo);
await caso('se distingue de la comanda al leerla', async () =>
  (await cola())[0].contenido.toLowerCase().includes('precuenta') || (await cola())[0].contenido.slice(0,80));


console.log('\nLA PANTALLA · Ajustes → Impresión, que es como se prueba sin impresora:');
await page.click('#btnMenu'); await page.waitForTimeout(300);
await page.click('[data-accion="ajustes"]'); await page.waitForTimeout(600);
await page.click('[data-aj="impresion"]'); await page.waitForTimeout(700);
await caso('la sección existe y se abre', async () =>
  await page.isVisible('#aj-imp') || 'no aparece');
await caso('lista los papeles que se mandaron', async () =>
  (await page.locator('[data-lamaimp]').count()) > 0 ||
  'no lista ninguno de los que se encolaron');
await caso('cada uno dice si salió o está esperando', async () =>
  ((await page.textContent('#aj-imp')) || '').includes('esperando') || 'no dice el estado');
await caso('tocar uno muestra el papel ENTERO, como sale', async () => {
  await page.click('[data-lamaimp]'); await page.waitForTimeout(400);
  const t = await page.textContent('.imp-papel').catch(()=>null);
  return (t && t.includes('MESA')) || 'no se ve el papel';
});
await caso('y ofrece reimprimirlo', async () =>
  await page.isVisible('[data-lamaacc="imp-reimprimir"]') || 'no se puede reimprimir');
await caso('reimprimir manda una COPIA, no revive la vieja', async () => {
  await limpiar();
  await page.click('[data-lamaacc="imp-reimprimir"]'); await page.waitForTimeout(700);
  const c = await cola();
  const u = await page.evaluate(() =>
    window.__esc.filter(x => x.tabla === 'lama_impresiones' && x.op === 'update').length);
  if(u) return 'revivió la fila vieja en vez de copiarla';
  return c.length === 1 || 'encoló ' + c.length;
});
await caso('el papel de prueba se puede mandar sin tocar ninguna mesa', async () => {
  await limpiar();
  await page.click('[data-lamaacc="imp-prueba"]'); await page.waitForTimeout(700);
  const c = await cola();
  return (c.length === 1 && c[0].tipo === 'prueba') || JSON.stringify(c.map(x=>x.tipo));
});
await caso('y lleva acentos y ñ, que es lo que se viene a comprobar', async () => {
  const c = await cola();
  return /[áéíóúñ]/.test(c[0].contenido) || 'sin acentos no prueba nada';
});

console.log('\nY NINGÚN ERROR DE JAVASCRIPT:');
await caso('la consola quedó limpia', async () => errores.length === 0 || errores[0]);

console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();
process.exit(mal ? 1 : 0);
