/* LLAMITA LAMA · F3 — la pantalla de configuración.
   node pruebas/lama-config.mjs

   QUE ADRIANA CREE Y EDITE ELLA los medios de pago, los motivos de descuento y
   los motivos de anulación, sin que nadie toque la base.

   LO QUE SE PRUEBA ACÁ NO ES QUE LOS BOTONES EXISTAN. Es:

   · que **apagar un medio lo saque de la ventana de cobro** — que es el punto
     entero de apagarlo, y lo único que el garzón va a notar
   · que **apagar NO borre**: la fila sigue ahí, tachada, y se puede encender
   · que **el orden que se elige sea el orden que se guarda**, mirando el
     `update` que sale a la base y no el HTML
   · que **renombrar no toque el código interno**, porque es con lo que
     quedaron guardadas las ventas viejas
   · que la pantalla **no exista sin `puede_lama`** — la primera prueba de Lama
     desde el primer día, en las dos direcciones
   · y el **interruptor apagado en sus dos mitades**: que la pestaña no esté, y
     que el cobro siga funcionando igual                                     */
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await abrirNavegador();
if (!browser) { console.log('\n(se salta: no hay navegador instalado)\n'); process.exit(0); }

const MESAS = Array.from({length:12}, (_,i)=>({
  id:100+i, sede:'plaza', salon:'Salón', numero:i+1, orden:i+1, activa:true }));
/* Una mesa abierta con un producto: hace falta para poder abrir el cobro y
   comprobar que lo apagado desapareció de ahí. */
const CUENTAS = [
  {id:900, sede:'plaza', mesa_id:101, estado:'abierta', total:3200, abierta_por:'jhon@cafe.cl'},
];
const ITEMS = [
  {id:1, cuenta_id:900, nombre:'Café Latte', cantidad:1, precio:3200,
   estado:'confirmado', comentario:null},
];
const MEDIOS = [
  {codigo:'efectivo',  nombre:'Efectivo',               orden:1, es_cobro:true,  descuento_pct:0,  activo:true},
  {codigo:'debito',    nombre:'Tarjeta de débito',      orden:2, es_cobro:true,  descuento_pct:0,  activo:true},
  {codigo:'garzones',  nombre:'Consumo garzones',       orden:3, es_cobro:false, descuento_pct:50, activo:true},
  {codigo:'pedidosya', nombre:'Pedidos Ya',             orden:4, es_cobro:true,  descuento_pct:0,  activo:false},
];
const MOTIVOS = [
  {codigo:'empleado', nombre:'Descuento de empleado', orden:1, activo:true},
];
const MOT_ANU = [
  {codigo:'error_registro', nombre:'Error de registro', orden:1, pide_comentario:false, activo:true},
  {codigo:'otro',           nombre:'Otro',              orden:2, pide_comentario:true,  activo:true},
];

const page = await browser.newPage();
await page.setViewportSize({width:390, height:1000});

async function montar({puedeLama = true, archivo = 'index.html'} = {}){
  await page.addInitScript(({MESAS, CUENTAS, ITEMS, MEDIOS, MOTIVOS, MOT_ANU, puedeLama}) => {
    window.__esc = [];               // lo que se le ESCRIBE a la base
    const SES = {user:{id:'u1', email:'jhon@cafe.cl', user_metadata:{nombre:'Jhon'}}};
    const T = {
      productos:[], mesas:MESAS, cuentas:CUENTAS, cuenta_items:ITEMS, comandas:[],
      fudo_productos:[{fudo_product_id:'F-38', sede:'plaza', nombre:'Café Latte', precio:3200, activo:true}],
      lama_medios_pago:JSON.parse(JSON.stringify(MEDIOS)),
      lama_motivos_descuento:JSON.parse(JSON.stringify(MOTIVOS)),
      lama_motivos_anulacion:JSON.parse(JSON.stringify(MOT_ANU)),
      app_permisos:[{correo:'jhon@cafe.cl', nombre:'Jhon', puede_ajustes:true,
                     puede_editar:true, puede_fudo:true, puede_lama:puedeLama, fudo_bloqueos:[]}],
      producto_enlace:[], fudo_stock_push:[], fudo_sync:[], secciones:[], movimientos:[],
      ajustes:[], metas:[], historial:[], historial_auto:[], restauraciones:[], fusiones:[],
      recetas:[], receta_items:[], producto_lotes:[], repartos:[], reparto_items:[],
      mermas:[], tareas:[], fudo_categorias:[], envios_franquicia:[], envios_franquicia_items:[],
      cuenta_pagos:[], cuenta_propinas:[], cuenta_pago_items:[]};
    let seq = 7000;
    const q = (n) => {
      let filas = JSON.parse(JSON.stringify(T[n]||[]));
      const api = {
        select(){return api;}, eq(c,v){ filas=filas.filter(f=>String(f[c])===String(v)); return api;},
        neq(){return api;}, in(){return api;}, order(){return api;}, limit(){return api;},
        /* ⚠️ `not` y `gte` FILTRAN DE VERDAD, y no es un lujo del simulacro.
           "Anulados de hoy" se arma con `.not('anulado_at','is',null)`: si el
           simulacro los ignorara, la lista mostraría TODOS los productos y la
           prueba pasaría igual sin comprobar nada. Es la trampa de siempre —
           una prueba que no puede fallar. */
        gte(c,v){ filas=filas.filter(f=>f[c] != null && String(f[c]) >= String(v)); return api;},
        not(c,op,v){ if(op==='is' && v===null) filas=filas.filter(f=>f[c] != null); return api;},
        lte(){return api;}, is(){return api;},
        or(){return api;}, ilike(){return api;},
        maybeSingle(){return Promise.resolve({data:filas[0]||null,error:null});},
        single(){return Promise.resolve({data:filas[0]||null,error:null});},
        insert(v){
          const rows=(Array.isArray(v)?v:[v]).map(r=>({id:++seq, ...r}));
          window.__esc.push({op:'insert', tabla:n, filas:rows});
          (T[n]||[]).push(...rows);
          const e={select:()=>e, single:()=>Promise.resolve({data:rows[0],error:null}),
                   then:f=>Promise.resolve({data:rows,error:null}).then(f)}; return e;
        },
        /* EL update SIMULADO APLICA EL CAMBIO DE VERDAD y además lo anota. Sin
           lo primero, apagar un medio no haría nada y parecería un bug de la
           app; sin lo segundo no se puede comprobar QUÉ se guardó. */
        update(v){
          const e = {
            eq(col, val){
              window.__esc.push({op:'update', tabla:n, col, val, datos:v});
              const tocadas = (T[n]||[]).filter(f => String(f[col]) === String(val));
              tocadas.forEach(f => Object.assign(f, v));
              filas = JSON.parse(JSON.stringify(tocadas));
              return e;
            },
            in:()=>e, select:()=>e,
            single:()=>Promise.resolve({data:filas[0]||null,error:null}),
            then:f=>Promise.resolve({data:filas,error:null}).then(f)};
          return e;
        },
        upsert(){const e={select:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        delete(){const e={eq:()=>e,in:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        then(f){return Promise.resolve({data:filas,error:null,count:filas.length}).then(f);},
      };
      return api;
    };
    window.supabase = { createClient: () => ({
      from:q, rpc:()=>Promise.resolve({data:null, error:null}),
      auth:{ getSession:async()=>({data:{session:SES}}), getUser:async()=>({data:{user:SES.user}}),
             onAuthStateChange(cb){setTimeout(()=>cb&&cb('SIGNED_IN',SES),0);
               return {data:{subscription:{unsubscribe(){}}}};},
             signInWithPassword:async()=>({data:{session:SES},error:null}), signOut:async()=>({}) },
      channel:()=>({on(){return this;},subscribe(cb){cb&&cb('SUBSCRIBED');return this;},
                    track:async()=>{},presenceState:()=>({})}),
      removeChannel(){}, functions:{invoke:async()=>({data:{ok:true},error:null})},
    })};
  }, {MESAS, CUENTAS, ITEMS, MEDIOS, MOTIVOS, MOT_ANU, puedeLama});
  await page.route('**/supabase-js*', r=>r.fulfill({status:200,contentType:'application/javascript',body:''}));
  await page.goto(pathToFileURL(join(raiz, archivo)).href);
  await page.waitForTimeout(400);
  await page.click('.gate-btn[data-sede="plaza"]');
  await page.waitForTimeout(800);
}

/* A Ajustes se entra por el menú lateral, no por un botón de la barra. */
const abrirAjustes = async () => {
  await page.click('#btnMenu');                 await page.waitForTimeout(350);
  await page.click('[data-accion="ajustes"]');  await page.waitForTimeout(650);
};
/* En Ajustes la barra de pestañas se esconde —se entró a otra zona—, así que
   para volver a Mesas hay que salir por el botón de arriba. */
const irAMesas = async () => {
  if(await page.isVisible('#aj-volver')){
    await page.click('#aj-volver'); await page.waitForTimeout(500);
  }
  await page.click('#tabLama'); await page.waitForTimeout(500);
};

/* La configuración se mudó a Ajustes -> Mesas el 2026-09-04. Se llega por la
   tuerca de la barra de arriba, igual que cualquier otra zona de ajustes. */
const irACfg = async () => {
  await abrirAjustes();
  await page.click('[data-aj="mesas"]');
  await page.waitForTimeout(700);
};

const errores = [];
page.on('pageerror', e=>errores.push(String(e)));

let ok=0, mal=0;
const caso = async (n, fn) => {
  try { const r = await fn(); if(r===true){ok++;console.log('  ✓ '+n);}
        else {mal++;console.log('  ✗ '+n+'  → '+r);} }
  catch(e){ mal++; console.log('  ✗ '+n+'  → '+e.message.split('\n')[0]); }
};

/* ================================================================
   LA PUERTA. Va primera, como en todas las pruebas de Lama.
   ================================================================ */
console.log('\nLA PUERTA · sin permiso no existe nada de esto:');
await montar({puedeLama:false});
await caso('sin `puede_lama` no hay sección Mesas en Ajustes', async () => {
  await abrirAjustes();
  return !(await page.isVisible('[data-aj="mesas"]')) || 'la ve alguien sin permiso';
});
await caso('ni la pantalla de configuración', async () =>
  !(await page.isVisible('#lama-cfg')) || 'la pantalla está abierta sin permiso');

/* ================================================================
   LA PANTALLA
   ================================================================ */
console.log('\nCON permiso, la configuración está y se abre:');
await montar({puedeLama:true});
await caso('la sección Mesas aparece en Ajustes', async () => {
  await abrirAjustes();
  return (await page.isVisible('[data-aj="mesas"]')) || 'no aparece con el permiso puesto';
});
/* ⚠️ El rail de Ajustes se cachea. Antes bastaba `dataset.hecho` porque la
   lista era siempre la misma; desde que "Mesas" depende del permiso, esa
   caché lo dejaría congelado con la lista de la primera vez — y el permiso
   llega DESPUÉS de elegir la sede. */
await caso('y el área de ventas sigue siendo sólo el plano', async () => {
  await irAMesas();
  const t = await page.evaluate(()=>document.getElementById('view-lama').textContent);
  return !t.includes('Medios de pago') || 'la configuración quedó también dentro de Mesas';
});

await irACfg();
await caso('la configuración se ve dentro de Ajustes', async () =>
  (await page.isVisible('#lama-cfg')) || 'no se pintó la configuración');
await caso('y arriba está el tamaño de las mesas, que también se mudó', async () =>
  (await page.isVisible('#lama-tam-r')) || 'no está el control del tamaño');
await caso('están las tres listas más los anulados', async () => {
  const n = await page.evaluate(()=>document.querySelectorAll('[data-lamacfgtab]').length);
  return n === 4 || 'hay ' + n + ' pestañas';
});
await caso('se ven los medios, incluidos los apagados', async () => {
  const n = await page.evaluate(()=>document.querySelectorAll('.cfg-fila').length);
  return n === 4 || 'se ven ' + n + ' de 4';
});
/* Los cargadores del cobro filtran `activo !== false`, y hacen bien. Pero acá
   hay que ver lo apagado para poder volver a encenderlo. */
await caso('el apagado se ve tachado, no escondido', async () => {
  const r = await page.evaluate(()=>{
    const f=[...document.querySelectorAll('.cfg-fila')].find(x=>x.textContent.includes('Pedidos Ya'));
    if(!f) return {no:true};
    return {off:f.classList.contains('off'),
            tachado:getComputedStyle(f.querySelector('.cfg-nom b')).textDecorationLine};});
  if(r.no) return 'no aparece el medio apagado';
  return (r.off && r.tachado.includes('line-through')) || 'off=' + r.off + ' deco=' + r.tachado;
});
await caso('el descuento sólo se muestra en los que NO cobran', async () => {
  const r = await page.evaluate(()=>{
    const fila = t => [...document.querySelectorAll('.cfg-fila')].find(x=>x.textContent.includes(t));
    return {consumo:!!fila('Consumo garzones').querySelector('.cfg-pct'),
            efectivo:!!fila('Efectivo').querySelector('.cfg-pct')};});
  return (r.consumo && !r.efectivo)
    || 'consumo=' + r.consumo + ' efectivo=' + r.efectivo + ' (Efectivo no debería tenerlo)';
});

/* ================================================================
   APAGAR — lo que de verdad importa
   ================================================================ */
console.log('\nAPAGAR UN MEDIO lo saca del cobro, y NO lo borra:');
await caso('el interruptor guarda `activo:false` en la base', async () => {
  await page.evaluate(()=>{ window.__esc = []; });
  await page.click('[data-lamacfgsw="debito"]');
  await page.waitForTimeout(500);
  const e = await page.evaluate(()=>window.__esc.filter(x=>x.op==='update'
    && x.tabla==='lama_medios_pago' && x.val==='debito'));
  if(!e.length) return 'no salió ningún update para ese medio';
  return e[0].datos.activo === false || 'guardó ' + JSON.stringify(e[0].datos);
});
await caso('la fila sigue ahí, tachada — apagar no es borrar', async () => {
  const r = await page.evaluate(()=>{
    const f=[...document.querySelectorAll('.cfg-fila')].find(x=>x.textContent.includes('Tarjeta de débito'));
    return f ? f.classList.contains('off') : null;});
  if(r === null) return 'la fila DESAPARECIÓ: se borró en vez de apagarse';
  return r === true || 'sigue mostrándose como encendida';
});
/* EL PUNTO ENTERO DE APAGAR ALGO. Si esto fallara, la pantalla diría que el
   medio está apagado y el garzón lo seguiría viendo al cobrar. */
await caso('y deja de ofrecerse en la ventana de cobro', async () => {
  await irAMesas();
  await page.click('[data-lamamesa="101"]');    await page.waitForTimeout(500);
  await page.click('[data-lamaacc="cobrar"]');  await page.waitForTimeout(600);
  const hay = await page.evaluate(()=>{
    const t=document.getElementById('lama-cob');
    return t ? t.textContent.includes('Tarjeta de débito') : null;});
  if(hay === null) return 'no se pudo abrir el cobro';
  return hay === false || 'el medio apagado se sigue ofreciendo al cobrar';
});
await caso('pero el efectivo, que quedó encendido, sí está', async () => {
  const hay = await page.evaluate(()=>
    document.getElementById('lama-cob').textContent.includes('Efectivo'));
  return hay === true || 'se llevó puestos también los encendidos';
});
await caso('y se puede volver a encender', async () => {
  await page.keyboard.press('Escape'); await page.waitForTimeout(300);
  await irACfg();
  await page.click('[data-lamacfgsw="debito"]');
  await page.waitForTimeout(500);
  const r = await page.evaluate(()=>{
    const f=[...document.querySelectorAll('.cfg-fila')].find(x=>x.textContent.includes('Tarjeta de débito'));
    return f && !f.classList.contains('off');});
  return r === true || 'no volvió a encenderse';
});

/* ================================================================
   EL ORDEN
   ================================================================ */
console.log('\nEL ORDEN es el que ve el garzón al cobrar:');
await caso('bajar una fila la mueve en pantalla', async () => {
  const antes = await page.evaluate(()=>
    [...document.querySelectorAll('.cfg-fila .cfg-nom b')].map(x=>x.textContent));
  await page.click('[data-lamacfgbaja="efectivo"]');
  await page.waitForTimeout(600);
  const des = await page.evaluate(()=>
    [...document.querySelectorAll('.cfg-fila .cfg-nom b')].map(x=>x.textContent));
  return (antes[0] === des[1] && antes[1] === des[0])
    || 'antes: ' + antes.slice(0,2) + ' · después: ' + des.slice(0,2);
});
/* SE REESCRIBE TODA LA LISTA, no sólo los dos que se cruzan: las filas
   heredadas traen números con huecos (1, 2, 5, 9…) y un intercambio a ciegas
   ahí adentro deja el orden peor de como estaba. */
await caso('y guarda un `orden` correlativo para TODAS', async () => {
  const e = await page.evaluate(()=>window.__esc.filter(x=>x.op==='update'
    && x.tabla==='lama_medios_pago' && x.datos && x.datos.orden !== undefined));
  if(e.length < 4) return 'sólo escribió ' + e.length + ' órdenes, y son 4 filas';
  const n = e.slice(-4).map(x=>x.datos.orden).sort((a,b)=>a-b);
  return JSON.stringify(n) === '[1,2,3,4]' || 'guardó los órdenes ' + JSON.stringify(n);
});
await caso('la primera no puede subir ni la última bajar', async () => {
  const r = await page.evaluate(()=>{
    const f=[...document.querySelectorAll('.cfg-fila')];
    return {arriba:f[0].querySelector('[data-lamacfgsube]').disabled,
            abajo:f[f.length-1].querySelector('[data-lamacfgbaja]').disabled};});
  return (r.arriba && r.abajo) || 'arriba=' + r.arriba + ' abajo=' + r.abajo;
});

/* ================================================================
   RENOMBRAR Y AGREGAR
   ================================================================ */
console.log('\nRENOMBRAR no toca el código interno:');
await caso('la ficha muestra el código y dice que no se cambia', async () => {
  await page.click('[data-lamacfged="garzones"]');
  await page.waitForTimeout(400);
  const t = await page.evaluate(()=>document.querySelector('.cfg-ficha .fijo')?.textContent || '');
  return (t.includes('garzones') && /no se puede cambiar/.test(t)) || 'dice: ' + t;
});
/* LA MÁS IMPORTANTE DE ESTE BLOQUE. `garzones` es con lo que quedaron
   guardadas las ventas viejas: si el renombre lo tocara, esas ventas se
   quedarían sin nada que las explique. Es la regla de la casa — las cosas se
   unen por identificador, nunca por nombre. */
await caso('al guardar un nombre nuevo, el código NO viaja en el update', async () => {
  await page.evaluate(()=>{ window.__esc = []; });
  await page.fill('#cfg-nombre', 'Consumo del personal');
  await page.click('[data-lamaacc="cfg-guardar"]');
  await page.waitForTimeout(700);
  const e = await page.evaluate(()=>window.__esc.filter(x=>x.op==='update'
    && x.tabla==='lama_medios_pago' && x.datos && x.datos.nombre));
  if(!e.length) return 'no salió ningún update con el nombre';
  const d = e[0].datos;
  if(d.codigo !== undefined) return 'el update intenta cambiar el código: ' + d.codigo;
  return (d.nombre === 'Consumo del personal' && e[0].val === 'garzones')
    || 'guardó ' + JSON.stringify(d) + ' sobre ' + e[0].val;
});
await caso('y el nombre nuevo se ve en la lista', async () => {
  const t = await page.evaluate(()=>document.getElementById('lama-cfg').textContent);
  return t.includes('Consumo del personal') || 'la lista no se puso al día';
});

console.log('\nAGREGAR uno nuevo:');
await caso('se inserta con un código sacado del nombre', async () => {
  await page.evaluate(()=>{ window.__esc = []; });
  await page.click('[data-lamacfgnuevo]');
  await page.waitForTimeout(400);
  await page.fill('#cfg-nombre', 'Transferencia BCI');
  await page.click('[data-lamaacc="cfg-guardar"]');
  await page.waitForTimeout(700);
  const e = await page.evaluate(()=>window.__esc.filter(x=>x.op==='insert'
    && x.tabla==='lama_medios_pago'));
  if(!e.length) return 'no se insertó nada';
  const f = e[0].filas[0];
  return (f.codigo === 'transferencia_bci' && f.nombre === 'Transferencia BCI' && f.activo === true)
    || 'insertó ' + JSON.stringify(f);
});
await caso('un nombre en blanco no crea nada', async () => {
  await page.evaluate(()=>{ window.__esc = []; });
  await page.click('[data-lamacfgnuevo]');
  await page.waitForTimeout(400);
  await page.click('[data-lamaacc="cfg-guardar"]');
  await page.waitForTimeout(500);
  const n = await page.evaluate(()=>window.__esc.filter(x=>x.op==='insert').length);
  /* `avisar()` abre la ventana modal de la app y tapa todo hasta que alguien
     la cierre — no es un toast. Hay que cerrarla o la prueba siguiente
     arranca con la pantalla tapada. */
  const okb = await page.$('#ask-ok'); if(okb) await okb.click();
  await page.waitForTimeout(300);
  return n === 0 || 'creó ' + n + ' con el nombre vacío';
});
/* Y la ficha SE QUEDA ABIERTA, que es lo correcto: uno viene a ponerle el
   nombre que falta, no a empezar de nuevo. Se cierra a mano acá. */
await caso('y la ficha queda abierta para poder corregir', async () => {
  const abierta = await page.isVisible('.cfg-ficha');
  await page.click('[data-lamaacc="cfg-cancelar"]');
  await page.waitForTimeout(400);
  return abierta === true || 'se cerró sola y perdió lo que había escrito';
});
await caso('Cancelar cierra la ficha sin guardar', async () => {
  await page.evaluate(()=>{ window.__esc = []; });
  await page.click('[data-lamacfged="efectivo"]'); await page.waitForTimeout(400);
  await page.fill('#cfg-nombre', 'NO GUARDAR ESTO');
  await page.click('[data-lamaacc="cfg-cancelar"]'); await page.waitForTimeout(400);
  const n = await page.evaluate(()=>window.__esc.length);
  const abierta = await page.isVisible('.cfg-ficha');
  if(abierta) return 'la ficha quedó abierta';
  return n === 0 || 'escribió ' + n + ' cosas igual';
});

/* ================================================================
   LAS OTRAS DOS LISTAS
   ================================================================ */
console.log('\nLas otras dos listas usan la misma pantalla:');
await caso('los motivos de anulación se cargan de su propia tabla', async () => {
  await page.click('[data-lamacfgtab="anulacion"]'); await page.waitForTimeout(600);
  const t = await page.evaluate(()=>document.getElementById('lama-cfg').textContent);
  return (t.includes('Error de registro') && t.includes('Otro')) || 'no se ven los motivos';
});
await caso('y el que pide comentario lo dice', async () => {
  const r = await page.evaluate(()=>{
    const f=[...document.querySelectorAll('.cfg-fila')].find(x=>x.textContent.includes('Otro'));
    return f ? f.textContent.includes('pide comentario') : null;});
  return r === true || 'no avisa cuál pide comentario';
});
await caso('los motivos de descuento también', async () => {
  await page.click('[data-lamacfgtab="descuentos"]'); await page.waitForTimeout(600);
  const t = await page.evaluate(()=>document.getElementById('lama-cfg').textContent);
  return t.includes('Descuento de empleado') || 'no se ven los motivos de descuento';
});
/* LO ANULADO DEL DÍA · atlas C2, y el arqueo lo va a pedir.
   Se prueba en las DOS direcciones: que un producto normal NO se cuele en esa
   lista, y que uno anulado sí aparezca con su motivo. Sin la primera mitad,
   la pantalla podría estar listando la cuenta entera y nadie lo notaría. */
await caso('sin nada anulado, lo dice y no lista productos normales', async () => {
  await page.click('[data-lamacfgtab="anulados"]'); await page.waitForTimeout(700);
  const t = await page.evaluate(()=>document.getElementById('lama-cfg').textContent);
  if(t.includes('Café Latte')) return 'está listando un producto que NADIE anuló';
  return /no se anuló nada/.test(t) || 'dice: ' + t.slice(0, 90);
});
await caso('y uno anulado hoy sí aparece, con su motivo y su monto', async () => {
  /* Se agrega un ítem YA anulado usando el mismo `insert` que usa la app —
     tal como lo dejaría `item_anular`: la fila no se borra, se le pone encima
     quién, cuándo y por qué. Así se prueba el camino de lectura completo. */
  await page.evaluate(async (hoy)=>{
    await sb.from('cuenta_items').insert({
      id:2, cuenta_id:900, nombre:'Torta de zanahoria', cantidad:2, precio:3600,
      estado:'confirmado', comentario:null,
      anulado_at:hoy, anulado_por:'jhon@cafe.cl',
      anulado_motivo:'error_registro', anulado_comentario:null});
  }, new Date().toISOString());
  await page.click('[data-lamacfgtab="descuentos"]'); await page.waitForTimeout(400);
  await page.click('[data-lamacfgtab="anulados"]');   await page.waitForTimeout(700);
  const t = await page.evaluate(()=>document.getElementById('lama-cfg').textContent);
  if(!t.includes('Torta de zanahoria')) return 'no apareció el producto anulado';
  if(!t.includes('Error de registro'))  return 'no muestra el motivo';
  if(t.includes('Café Latte'))          return 'se coló un producto sin anular';
  return t.includes('7.200') || 'el monto no es 2 × 3.600: ' + t.slice(0, 120);
});

/* ================================================================
   EL INTERRUPTOR (§2.2) — en sus dos mitades
   ================================================================ */
console.log('\nEL INTERRUPTOR apagado deja LO ANTERIOR, no un hueco:');
{
  const fs = await import('node:fs/promises');
  const src = await fs.readFile(join(raiz, 'index.html'), 'utf8');
  const off = src.replace('const LAMA_CONFIG = true;', 'const LAMA_CONFIG = false;');
  await fs.writeFile(join(raiz, 'pruebas', '.cfg-apagado.html'), off);

  await caso('el código tiene el interruptor donde se lo busca', async () =>
    src.includes('const LAMA_CONFIG = true;') || 'no está `const LAMA_CONFIG = true;`');

  await montar({puedeLama:true, archivo:'pruebas/.cfg-apagado.html'});
  await caso('apagado, no hay pestañas de vista', async () =>
    !(await page.isVisible('[data-lamavista="cfg"]')) || 'la pestaña sigue ahí');
  /* LA MITAD QUE SE OLVIDA: que lo de antes siga funcionando. */
  await caso('pero el plano de mesas está intacto', async () =>
    (await page.isVisible('#lama-mesas')) || 'se llevó puesto el plano');
  await caso('y el cobro sigue ofreciendo los medios de la base', async () => {
    await page.click('[data-lamamesa="101"]');   await page.waitForTimeout(500);
    await page.click('[data-lamaacc="cobrar"]'); await page.waitForTimeout(600);
    const t = await page.evaluate(()=>document.getElementById('lama-cob').textContent);
    return t.includes('Efectivo') || 'el cobro se quedó sin medios de pago';
  });
  await fs.unlink(join(raiz, 'pruebas', '.cfg-apagado.html'));
}

console.log('\nSin errores de JavaScript:');
await caso('ninguno en toda la vuelta', async () =>
  errores.length === 0 || errores.join(' · '));

console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();
process.exit(mal ? 1 : 0);
