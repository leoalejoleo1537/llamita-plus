/* LLAMITA LAMA · la página de Arqueo, como la de Fudo.
   node pruebas/lama-arqueo.mjs

   LOS NÚMEROS NO SON INVENTADOS: son los del arqueo que estaba ABIERTO en el
   Fudo de verdad el 2026-09-22 (Jhon mandó la captura y el texto):

     Monto inicial $100.000
     Ingreso       $504.609
       Efectivo      $28.820  = propinas $2.420  + ventas $26.400
       Tarj. Débito $475.789  = propinas $40.109 + ventas $435.680
     Egreso        $0
     Total         $604.609
     Según usuario: Efectivo sistema $128.820 · Débito sistema $475.789
     Total usuario $0 · Diferencia -$604.609

   Si la pantalla no llega a esos mismos números con esos mismos datos, no
   está copiando a Fudo: está inventando otra cuenta.                    */
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await abrirNavegador();
if (!browser) { console.log('\n(se salta: no hay navegador instalado)\n'); process.exit(0); }

const HOY = '2026-09-22T';
const ARQUEOS = [
  {id:50, sede:'plaza', estado:'abierta', monto_inicial:100000, abierto_por:'Joan Ríos',
   abierto_at: HOY+'15:15:21-03:00'},
  {id:49, sede:'plaza', estado:'cerrada', monto_inicial:100000, abierto_por:'Joan Ríos',
   abierto_at: HOY+'09:04:43-03:00', cerrado_at: HOY+'15:14:26-03:00', cerrado_por:'Joan Ríos',
   total_esperado:720025, total_declarado:720025, diferencia_total:0,
   efectivo_esperado:150000, efectivo_contado:150000, diferencia:0, comentario:null},
  {id:48, sede:'plaza', estado:'cerrada', monto_inicial:100000, abierto_por:'Adriana',
   abierto_at:'2026-09-17T09:00:00-03:00', cerrado_at:'2026-09-17T15:05:06-03:00', cerrado_por:'Adriana',
   total_esperado:565659, total_declarado:565909, diferencia_total:250,
   efectivo_esperado:120000, efectivo_contado:120250, diferencia:250, comentario:'Sobró sencillo'},
  /* El que Jhon abrió de prueba el 21 a las 21:30 y eliminó: en Fudo se ve
     tachado, "$100.000 · Eliminado". */
  {id:47, sede:'plaza', estado:'eliminada', estado_previo:'abierta', monto_inicial:100000,
   abierto_por:'Jhon', abierto_at:'2026-09-21T21:30:42-03:00',
   eliminado_por:'Jhon', eliminado_at:'2026-09-21T21:40:00-03:00'},
];
const T0 = HOY+'16:00:00-03:00';
const CUENTAS = [{id:900, sede:'plaza', mesa_id:null, estado:'cerrada', total:0},
  /* Una mesa que sigue abierta: Finalizar tiene que AVISARLA, no frenarla. */
                 {id:901, sede:'plaza', mesa_id:1, estado:'abierta', total:0}];
const PAGOS = [
  {id:1, cuenta_id:900, medio:'efectivo', monto:26400,  created_at:T0, cuentas:{sede:'plaza'}},
  {id:2, cuenta_id:900, medio:'debito',   monto:435680, created_at:T0, cuentas:{sede:'plaza'}},
];
const PROPINAS = [
  {id:1, cuenta_id:900, medio:'efectivo', monto:2420,  created_at:T0, cuentas:{sede:'plaza'}},
  {id:2, cuenta_id:900, medio:'debito',   monto:40109, created_at:T0, cuentas:{sede:'plaza'}},
];
const CIERRE_49 = [
  {arqueo_id:49, medio:'efectivo', ventas:50000,  propinas:0, sistema:150000, usuario:150000, diferencia:0},
  {arqueo_id:49, medio:'debito',   ventas:570025, propinas:0, sistema:570025, usuario:570025, diferencia:0},
];
const MEDIOS = [
  {codigo:'efectivo', nombre:'Efectivo',     orden:1, es_cobro:true, descuento_pct:0, activo:true},
  {codigo:'debito',   nombre:'Tarj. Débito', orden:2, es_cobro:true, descuento_pct:0, activo:true},
];

const errores = [];
let ok = 0, mal = 0;
async function caso(nombre, fn){
  try{
    const r = await fn();
    if(r === true){ ok++; console.log('  ✓ ' + nombre); }
    else { mal++; console.log('  ✗ ' + nombre + '  → ' + r); }
  }catch(e){ mal++; console.log('  ✗ ' + nombre + '  → ' + e.message); }
}

async function montar(page, {ancho = 1400, ciego = false} = {}){
  await page.setViewportSize({width:ancho, height:1100});
  page.on('pageerror', e => errores.push(e.message));
  await page.addInitScript(({ARQUEOS, CUENTAS, PAGOS, PROPINAS, CIERRE_49, MEDIOS, ciego}) => {
    window.__rpc = [];
    const SES = {user:{id:'u1', email:'jhon@cafe.cl', user_metadata:{nombre:'Jhon'}}};
    const T = {
      productos:[], mesas:[], cuentas:CUENTAS, cuenta_items:[], comandas:[], lama_areas:[],
      fudo_productos:[], lama_medios_pago:MEDIOS, lama_motivos_descuento:[], lama_motivos_anulacion:[],
      app_permisos:[{correo:'jhon@cafe.cl', nombre:'Jhon', puede_ajustes:true, puede_editar:true,
                     puede_fudo:true, puede_lama:true, fudo_bloqueos:[]}],
      lama_arqueos:ARQUEOS, lama_caja_movimientos:[], lama_arqueo_declarado:[],
      lama_arqueo_cierre_medios:CIERRE_49, cuenta_pagos:PAGOS, cuenta_propinas:PROPINAS,
      ajustes: ciego ? [{clave:'arqueo_ciego', sede:'plaza', valor:true}] : [],
      producto_enlace:[], fudo_stock_push:[], fudo_sync:[], secciones:[], movimientos:[],
      metas:[], historial:[], historial_auto:[], restauraciones:[], fusiones:[], recetas:[],
      receta_items:[], producto_lotes:[], repartos:[], reparto_items:[], mermas:[], tareas:[],
      fudo_categorias:[], envios_franquicia:[], envios_franquicia_items:[], cuenta_pago_items:[]};
    window.__T = T;
    const q = (n) => {
      let filas = JSON.parse(JSON.stringify(T[n] || []));
      const api = {
        select(){return api;},
        /* `cuentas.sede` es el filtro por la tabla unida: los pagos del
           simulacro ya traen su `cuentas.sede` adentro. */
        eq(c,v){ filas = filas.filter(f => {
          const val = c.includes('.') ? c.split('.').reduce((o,k) => o && o[k], f) : f[c];
          return String(val) === String(v); }); return api; },
        gte(c,v){ filas = filas.filter(f => f[c] != null && new Date(f[c]) >= new Date(v)); return api; },
        lte(c,v){ filas = filas.filter(f => f[c] != null && new Date(f[c]) <= new Date(v)); return api; },
        gt(c,v){ filas = filas.filter(f => f[c] != null && new Date(f[c]) > new Date(v)); return api; },
        neq(){return api;}, in(){return api;}, order(){return api;}, limit(){return api;},
        not(){return api;}, is(){return api;}, or(){return api;}, ilike(){return api;},
        maybeSingle(){return Promise.resolve({data:filas[0] || null, error:null});},
        single(){return Promise.resolve({data:filas[0] || null, error:null});},
        insert(v){ const e = {select:()=>e, single:()=>Promise.resolve({data:v,error:null}),
                   then:f=>Promise.resolve({data:[v],error:null}).then(f)}; return e; },
        update(){ const e = {eq:()=>e, in:()=>e, select:()=>e, single:()=>Promise.resolve({data:null,error:null}),
                  then:f=>Promise.resolve({data:[],error:null}).then(f)}; return e; },
        upsert(){ const e = {select:()=>e, then:f=>Promise.resolve({data:[],error:null}).then(f)}; return e; },
        delete(){ const e = {eq:()=>e, in:()=>e, then:f=>Promise.resolve({data:[],error:null}).then(f)}; return e; },
        then(f){return Promise.resolve({data:filas, error:null, count:filas.length}).then(f);},
      };
      return api;
    };
    const rpc = (fn, args) => {
      window.__rpc.push({fn, args});
      if(fn === 'arqueo_declarar'){
        const d = T.lama_arqueo_declarado.filter(x => !(x.arqueo_id === args.p_arqueo_id && x.medio === args.p_medio));
        d.push({arqueo_id:args.p_arqueo_id, medio:args.p_medio, monto:args.p_monto});
        T.lama_arqueo_declarado = d;
        return Promise.resolve({data:{medio:args.p_medio, monto:args.p_monto}, error:null});
      }
      if(fn === 'arqueo_cerrar'){
        const a = T.lama_arqueos.find(x => x.id === args.p_arqueo_id);
        Object.assign(a, {estado:'cerrada', cerrado_at:'2026-09-22T20:56:42-03:00', cerrado_por:'Jhon',
          total_esperado:604609, total_declarado:604609, diferencia_total:0, comentario:args.p_comentario});
        T.lama_arqueo_cierre_medios.push(
          {arqueo_id:a.id, medio:'efectivo', ventas:26400,  propinas:2420,  sistema:128820, usuario:128820, diferencia:0},
          {arqueo_id:a.id, medio:'debito',   ventas:435680, propinas:40109, sistema:475789, usuario:475789, diferencia:0});
        return Promise.resolve({data:a, error:null});
      }
      if(fn === 'arqueo_eliminar'){
        const a = T.lama_arqueos.find(x => x.id === args.p_arqueo_id);
        Object.assign(a, {estado_previo:a.estado, estado:'eliminada', eliminado_por:args.p_quien,
                          eliminado_at:new Date().toISOString()});
        return Promise.resolve({data:a, error:null});
      }
      if(fn === 'arqueo_abrir'){
        const ahora = new Date().toISOString();
        const a = {id:51, sede:args.p_sede, estado:'abierta', monto_inicial:args.p_monto_inicial,
                   abierto_por:args.p_quien, abierto_at:args.p_abierto_at || ahora, creado_at:ahora};
        T.lama_arqueos.unshift(a);
        return Promise.resolve({data:a, error:null});
      }
      return Promise.resolve({data:null, error:null});
    };
    window.supabase = { createClient: () => ({
      from:q, rpc,
      auth:{ getSession:async()=>({data:{session:SES}}), getUser:async()=>({data:{user:SES.user}}),
             onAuthStateChange(cb){setTimeout(()=>cb&&cb('SIGNED_IN',SES),0);
               return {data:{subscription:{unsubscribe(){}}}};},
             signInWithPassword:async()=>({data:{session:SES},error:null}), signOut:async()=>({}) },
      channel:()=>({on(){return this;},subscribe(cb){cb&&cb('SUBSCRIBED');return this;},
                    track:async()=>{},presenceState:()=>({})}),
      removeChannel(){}, functions:{invoke:async()=>({data:{ok:true},error:null})},
    })};
  }, {ARQUEOS, CUENTAS, PAGOS, PROPINAS, CIERRE_49, MEDIOS, ciego});
  await page.route('**/supabase-js*', r => r.fulfill({status:200, contentType:'application/javascript', body:''}));
  await page.goto(pathToFileURL(join(raiz, 'index.html')).href);
  await page.waitForTimeout(400);
  await page.click('.gate-btn[data-sede="plaza"]');
  await page.waitForTimeout(900);
}

const txt = async (page, sel) => ((await page.innerText(sel)) || '').replace(/\s+/g, ' ').trim();
const irArqueo = async page => { await page.click('#tabArqueo'); await page.waitForTimeout(700); };

/* ------------------------------------------------------------------ */
const ZONA = {timezoneId:'America/Santiago', locale:'es-CL'};
const page = await browser.newPage(ZONA);
await montar(page);

console.log('\nLa pestaña y la lista:');
await caso('la pestaña Arqueo existe para quien tiene Mesas', async () =>
  await page.isVisible('#tabArqueo') || 'no aparece');
await irArqueo(page);
await caso('en el computador se ven las DOS mitades a la vez', async () =>
  (await page.isVisible('#arqpag-cuerpo .arqp-tabla') && await page.isVisible('#arqpag-detalle .arqd'))
  || 'falta la lista o el detalle');
await caso('el ABIERTO va primero en la lista', async () => {
  const est = await page.$$eval('#arqpag-cuerpo .arqp-fila[data-arqpagver] .c-est', e => e.map(x => x.textContent.trim()));
  return (est[0] === 'Abierto' && est.slice(1).every(x => x !== 'Abierto')) || 'quedó ' + est.join(',');
});
await caso('el abierto: Sistema en vivo, Usuario y Diferencia en "-"', async () => {
  const f = await txt(page, '.arqp-fila[data-arqpagver="50"]');
  return (/\$604\.609/.test(f) && (f.match(/ - /g) || []).length >= 1) || 'quedó ' + f;
});
await caso('un cerrado con sobrante se ve en verde', async () =>
  await page.$eval('.arqp-fila[data-arqpagver="48"] .c-dif', e => e.classList.contains('pos') && e.textContent.trim() === '$250')
  || 'no está verde o no dice $250');
await caso('las tarjetas de arriba: saldo actual y total de ventas', async () => {
  const r = await txt(page, '.arqp-resumen');
  return (/Saldo actual \$604\.609/.test(r) && /Total de ventas \$504\.609/.test(r)) || 'quedó ' + r;
});
await caso('y la tarjeta nueva: la propina del arqueo abierto ($2.420 + $40.109)', async () => {
  const r = await txt(page, '.arqp-resumen');
  return /Propinas \$42\.529/.test(r) || 'quedó ' + r;
});
await caso('el eliminado sigue en la lista: gris, tachado, "Eliminado"', async () => {
  const f = await page.$eval('.arqp-fila[data-arqpagver="47"]', e => ({
    c:e.className, td:getComputedStyle(e).textDecorationLine, est:e.querySelector('.c-est').textContent.trim(),
    sis:e.querySelector('.c-num').textContent.trim()}));
  return (/eliminado/.test(f.c) && f.td.includes('line-through') && f.est === 'Eliminado' && f.sis === '$100.000')
    || JSON.stringify(f);
});
await caso('el detalle NO es una tarjeta: es la columna derecha, pegada al borde', async () => {
  const r = await page.evaluate(() => {
    const d = document.getElementById('arqpag-detalle').getBoundingClientRect();
    const a = getComputedStyle(document.querySelector('#arqpag-detalle .arqd'));
    return {der: Math.round(d.right), ancho: innerWidth, radio: a.borderTopLeftRadius, alto: Math.round(d.height), vh: innerHeight};
  });
  return (Math.abs(r.der - r.ancho) <= 16 && r.radio === '0px' && r.alto >= r.vh - 2) || JSON.stringify(r);
});

console.log('\nEl detalle del abierto, en el orden de Fudo:');
const det = async () => txt(page, '#arqpag-detalle');
await caso('Caja · Hora de apertura · Creado por · Estado', async () => {
  const d = await det();
  const i = ['Caja Principal', 'Hora de apertura 22/09/26 15:15:21', 'Creado por Joan Ríos', 'Estado Abierto']
    .map(s => d.indexOf(s));
  return (i.every(x => x >= 0) && i.every((x,k) => k === 0 || x > i[k-1])) || 'orden o texto: ' + i.join(',');
});
await caso('Monto inicial $100.000 · Ingreso $504.609 · Egreso $0 · Total $604.609', async () => {
  const d = await det();
  return (/MONTO INICIAL \$100\.000/i.test(d) && /INGRESO \$504\.609/i.test(d)
       && /EGRESO \$0/i.test(d) && /Total \$604\.609/.test(d)) || d.slice(0, 400);
});
await caso('el Ingreso se abre por medio, y cada medio en Propinas y Ventas', async () => {
  const d = await det();
  return (/Efectivo \$28\.820 Propinas \$2\.420 Ventas \$26\.400/.test(d)
       && /Tarj\. Débito \$475\.789 Propinas \$40\.109 Ventas \$435\.680/.test(d)) || d.slice(0, 600);
});
await caso('Según usuario: el efectivo arrastra el monto inicial ($128.820)', async () => {
  const s = await txt(page, '.arqd-tabla');
  return (/Efectivo \* \$128\.820/.test(s) && /Tarj\. Débito \* \$475\.789/.test(s)) || s;
});
await caso('los campos nacen VACÍOS: Total $0 y Diferencia -$604.609 en rojo', async () => {
  const tot = await txt(page, '#arqd-tot-usr');
  const dif = await page.$eval('#arqd-dif', e => ({c:e.className, t:e.querySelector('.v').textContent}));
  return (tot === '$0' && /neg/.test(dif.c) && dif.t === '-$604.609') || JSON.stringify({tot, dif});
});
await caso('"Finalizar arqueo" está apagado hasta contar todo', async () =>
  await page.$eval('#arqd-fin', b => b.disabled) || 'se puede apretar sin contar');

console.log('\nContar:');
await page.fill('[data-arqvivmedio="efectivo"]', '128820');
await caso('al tipear, el Total y la Diferencia se mueven solos', async () => {
  const tot = await txt(page, '#arqd-tot-usr');
  const dif = await page.$eval('#arqd-dif .v', e => e.textContent);
  return (tot === '$128.820' && dif === '-$475.789') || JSON.stringify({tot, dif});
});
await caso('con un medio sin contar, Finalizar sigue apagado', async () =>
  await page.$eval('#arqd-fin', b => b.disabled) || 'se encendió antes de tiempo');
await page.fill('[data-arqvivmedio="debito"]', '475789');
await caso('todo contado y cuadrado: Diferencia $0, Finalizar encendido', async () => {
  const dif = await page.$eval('#arqd-dif', e => ({c:e.className, t:e.querySelector('.v').textContent}));
  const off = await page.$eval('#arqd-fin', b => b.disabled);
  return (/cero/.test(dif.c) && dif.t === '$0' && !off) || JSON.stringify({dif, off});
});
await page.click('.arqd-cab h3'); await page.waitForTimeout(300);   // sale del campo → se guarda
await caso('lo contado se GUARDA al salir del campo (Fudo lo pierde)', async () => {
  const r = await page.evaluate(() => window.__rpc.filter(x => x.fn === 'arqueo_declarar').map(x => x.args.p_medio + '=' + x.args.p_monto));
  return (r.includes('efectivo=128820') && r.includes('debito=475789')) || 'guardó ' + r.join(',');
});
await caso('plegar el Ingreso no borra lo tipeado', async () => {
  await page.click('[data-arqpleg="ingreso"]'); await page.waitForTimeout(250);
  const v = await page.inputValue('[data-arqvivmedio="debito"]');
  const d = await det();
  await page.click('[data-arqpleg="ingreso"]'); await page.waitForTimeout(250);
  return (v === '475789' && !/Propinas \$40\.109/.test(d)) || 'valor ' + v;
});

console.log('\nFinalizar:');
await page.fill('#arqd-coment', 'Todo en orden');
await page.click('#arqd-fin'); await page.waitForTimeout(300);
await caso('pregunta antes de cerrar, y dice que cuadra', async () =>
  /cuadra/i.test(await txt(page, '#ask-detalle')) || 'no preguntó o no lo dijo');
await caso('y avisa la mesa que sigue abierta (sin frenar el cierre)', async () =>
  /Quedan 1 mesa abierta/.test(await txt(page, '#ask-detalle')) || await txt(page, '#ask-detalle'));
await page.click('#ask-ok'); await page.waitForTimeout(900);
await caso('llama a arqueo_cerrar con el comentario', async () => {
  const c = await page.evaluate(() => window.__rpc.find(x => x.fn === 'arqueo_cerrar'));
  return (c && c.args.p_arqueo_id === 50 && c.args.p_comentario === 'Todo en orden') || JSON.stringify(c);
});
await caso('el arqueo queda Cerrado y su detalle se lee de lo congelado', async () => {
  const d = await det();
  return (/Estado Cerrado/.test(d) && /Cerrado por Jhon/.test(d) && /Diferencia \$0/.test(d)
       && !(await page.$('#arqd-fin'))) || d.slice(0, 500);
});
await caso('ya no hay caja abierta: aparece "+ Nuevo arqueo de caja"', async () =>
  await page.isVisible('[data-arqp="nuevo"]') || 'no aparece el botón');

console.log('\nAbrir uno nuevo, con fecha y hora:');
/* Una venta cobrada DESPUÉS de cerrar la caja de la tarde (20:56) y sin
   ninguna abierta: es la "huérfana" que Fudo deja recoger abriendo hacia atrás. */
await page.evaluate(() => window.__T.cuenta_pagos.push({id:9, cuenta_id:900, medio:'efectivo', monto:5000,
  created_at:'2026-09-22T21:10:00-03:00', cuentas:{sede:'plaza'}}));
await page.click('[data-arqp="nuevo"]'); await page.waitForTimeout(600);
const anchoMonto = await page.$eval('#arqd-monto', e => e.getBoundingClientRect().width);
await caso('pide la hora de apertura, y nace con la de ahora', async () => {
  /* Se compara ADENTRO de la página: el campo está en la hora del aparato
     (Chile) y el proceso de la prueba corre en UTC. */
  const r = await page.evaluate(() => { const v = document.getElementById('arqd-hora').value;
    return {v, dif: Math.abs(new Date(v) - Date.now())}; });
  return (r.dif < 120000) || 'nació con ' + r.v;
});
await caso('avisa lo cobrado SIN caja desde el último cierre', async () => {
  const h = await txt(page, '.arqd-hueco');
  return /20:56:42/.test(h) && /\$5\.000/.test(h) || 'dice: ' + h;
});
await page.click('[data-arqp="desde-hueco"]'); await page.waitForTimeout(150);
await caso('"Abrir desde esa hora" pone la hora del último cierre', async () =>
  (await page.inputValue('#arqd-hora')) === '2026-09-22T20:56:42' || await page.inputValue('#arqd-hora'));
await page.fill('#arqd-monto', '100000');
/* El campo trae `max` = ahora, así que el calendario del navegador ya no
   deja elegir el futuro (Playwright ni siquiera deja escribirlo). Se mete a
   la fuerza para probar la SEGUNDA red — la de la app —, que es la que
   cuenta cuando un navegador ignora el `max` al teclear. */
await page.evaluate(() => { const h = document.getElementById('arqd-hora');
  h.removeAttribute('max'); h.value = '2099-01-01T10:00:00';
  h.dispatchEvent(new Event('input', {bubbles:true})); });
await page.evaluate(() => { window.__rpc = []; });
await page.click('[data-arqp="iniciar"]'); await page.waitForTimeout(400);
await caso('una hora en el FUTURO se frena, y no llega a la base', async () => {
  const txtAviso = await page.isVisible('#overlay-ask') ? await txt(page, '#overlay-ask') : '';
  const r = await page.evaluate(() => window.__rpc.filter(x => x.fn === 'arqueo_abrir').length);
  return (/futuro/i.test(txtAviso) && r === 0) || JSON.stringify({txtAviso: txtAviso.slice(0, 80), r});
});
await page.click('#ask-ok').catch(() => {}); await page.waitForTimeout(250);
/* Hacia atrás hasta las 15:00: la franja se PISA con la caja de la tarde
   (15:15–20:56), que ya se cerró con sus $504.609. Esos no se vuelven a
   contar: solo entran los $5.000 huérfanos. */
await page.evaluate(() => { const h = document.getElementById('arqd-hora');
  h.value = '2026-09-22T15:00:00'; h.dispatchEvent(new Event('input', {bubbles:true})); });
await page.click('[data-arqp="iniciar"]'); await page.waitForTimeout(900);
await caso('llama a arqueo_abrir con el monto y la hora elegida', async () => {
  const c = await page.evaluate(() => window.__rpc.find(x => x.fn === 'arqueo_abrir'));
  return (c && c.args.p_monto_inicial === 100000 && c.args.p_sede === 'plaza'
          && c.args.p_abierto_at === new Date('2026-09-22T15:00:00-03:00').toISOString()) || JSON.stringify(c);
});
await caso('lo ya contado en la caja anterior NO se vuelve a contar', async () => {
  const d = await det();
  return (/INGRESO \$5\.000/i.test(d) && !/\$504\.609/.test(d)) || d.slice(0, 500);
});
await caso('muestra la hora elegida Y la hora real en que se apretó', async () => {
  const d = await det();
  return (/Hora de apertura 22\/09\/26 15:00:00/.test(d) && /Hora real de apertura/.test(d)) || d.slice(0, 300);
});
await caso('y queda abierto, primero en la lista', async () => {
  const est = await page.$$eval('#arqpag-cuerpo .arqp-fila[data-arqpagver] .c-est', e => e.map(x => x.textContent.trim()));
  return est[0] === 'Abierto' || est.join(',');
});

await caso('el campo del monto inicial es del tamaño de un dato, no una barra', async () =>
  anchoMonto <= 200 || 'mide ' + anchoMonto + ' px');

console.log('\nBorrar un arqueo:');
await page.click('.arqp-fila[data-arqpagver="51"]'); await page.waitForTimeout(400);
await page.click('[data-arqp="eliminar"]'); await page.waitForTimeout(300);
await caso('pregunta antes, y avisa que NO desaparece', async () =>
  /no desaparece/i.test(await txt(page, '#ask-detalle')) || 'no preguntó o no lo dijo');
await page.click('#ask-ok'); await page.waitForTimeout(900);
await caso('llama a arqueo_eliminar, nunca a un delete', async () => {
  const c = await page.evaluate(() => window.__rpc.find(x => x.fn === 'arqueo_eliminar'));
  return (c && c.args.p_arqueo_id === 51 && c.args.p_quien === 'Jhon') || JSON.stringify(c);
});
await caso('queda tachado en la lista, y la caja queda sin abrir', async () => {
  const cl = await page.$eval('.arqp-fila[data-arqpagver="51"]', e => e.className);
  return (/eliminado/.test(cl) && await page.isVisible('[data-arqp="nuevo"]')) || cl;
});
await caso('su detalle dice quién lo eliminó', async () =>
  /Estado Eliminado/.test(await det()) && /Eliminado por Jhon/.test(await det()) || (await det()).slice(0, 300));

console.log('\nEl aviso de Mesas lleva acá:');
await page.click('#tabLama'); await page.waitForTimeout(700);
await caso('Mesas ya no tiene su propia ventana de arqueo', async () =>
  !(await page.$('#lama-arqueo')) || 'sigue el contenedor viejo');
/* Recién se borró el abierto, así que el aviso dice "no está abierta · Abrir":
   ese botón tiene que llevar al formulario de un arqueo nuevo. */
await page.click('[data-lamaarq="abrir"]'); await page.waitForTimeout(800);
await caso('"Abrir" en el aviso de Mesas lleva al arqueo nuevo', async () =>
  (await page.isVisible('#view-arqueo .arqd') && await page.isVisible('#arqd-monto')) || 'no navegó');

console.log('\nEn el teléfono:');
const tel = await browser.newPage(ZONA);
await montar(tel, {ancho:390});
await tel.click('#tabLama'); await tel.waitForTimeout(600);
await tel.click('[data-lamaarq="turno"]'); await tel.waitForTimeout(800);
await caso('"Caja abierta" en Mesas lleva DIRECTO al detalle de la caja', async () =>
  (await tel.isVisible('#arqpag-detalle .arqd') && /Estado Abierto/.test(await txt(tel, '#arqpag-detalle')))
  || 'no llegó al detalle');
await tel.click('#tabArqueo'); await tel.waitForTimeout(700);
await caso('se ve la lista primero, sin el detalle', async () =>
  (await tel.isVisible('#arqpag-cuerpo .arqp-tabla') && !(await tel.isVisible('#arqpag-detalle .arqd'))) || 'no');
await tel.click('.arqp-fila[data-arqpagver="50"]'); await tel.waitForTimeout(500);
await caso('tocar un arqueo muestra su detalle, con cómo volver', async () =>
  (await tel.isVisible('#arqpag-detalle .arqd') && await tel.isVisible('.arqd-volver')
   && !(await tel.isVisible('#arqpag-cuerpo .arqp-tabla'))) || 'no');
await caso('nada se sale de la pantalla a lo ancho', async () => {
  const w = await tel.evaluate(() => document.documentElement.scrollWidth);
  return w <= 390 || 'mide ' + w;
});
await tel.click('.arqd-volver'); await tel.waitForTimeout(300);
await caso('y "← Todos los arqueos" vuelve a la lista', async () =>
  await tel.isVisible('#arqpag-cuerpo .arqp-tabla') || 'no volvió');

console.log('\nArqueo ciego (Ajustes → Interruptores):');
const ciega = await browser.newPage(ZONA);
await montar(ciega, {ciego:true});
await ciega.click('#tabArqueo'); await ciega.waitForTimeout(700);
await caso('con la caja abierta no se ve NADA de lo "según sistema"', async () => {
  const d = await txt(ciega, '#arqpag-detalle');
  return (!/\$604\.609/.test(d) && !/\$128\.820/.test(d) && !(await ciega.$('#arqd-dif'))
       && await ciega.isVisible('[data-arqvivmedio="efectivo"]')) || d.slice(0, 400);
});

console.log('\nSin errores de JavaScript:');
await caso('ninguno en toda la vuelta', async () => !errores.length || errores.join(' | '));

console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();
process.exit(mal ? 1 : 0);
