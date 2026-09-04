/* LLAMITA LAMA · la limpieza del 2026-09-03 — siete correcciones de pantalla.
   node pruebas/lama-limpieza.mjs

   Todas salieron de Jhon mirando la app desplegada en su teléfono, no de leer
   el código. Es otra vez el argumento de desplegar siempre.

   LO QUE SE PRUEBA ACÁ NO ES QUE LOS ELEMENTOS EXISTAN: es lo que se VE.
   Colores calculados, rectángulos medidos, y en dos casos la comparación
   entre dos elementos que tienen que verse iguales. Una prueba que solo
   comprueba que un `<span>` está en el DOM habría pasado con todos estos
   errores puestos — de hecho, las que ya existían pasaban.

   Las siete:
     1 · el "+ comentario" de debajo de cada producto se fue
     2 · "Total a confirmar" dejó de estar dentro de una cápsula gris
     3 · el lápiz mide lo mismo que la impresora y el %
     4 · el panel es UN recuadro, no tarjetas dentro de tarjetas
     5 · el resplandor de la mesa elegida ya no lo recorta el riel
     6 · en 1, el − de la carta es un basurero
     7 · el hogar de la app es Mesas; el inventario es una sección más     */
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await abrirNavegador();
if (!browser) { console.log('\n(se salta: no hay navegador instalado)\n'); process.exit(0); }

const MESAS = Array.from({length:12}, (_,i)=>({
  id:100+i, sede:'plaza', salon:'Salón', numero:i+1, orden:i+1, activa:true }));
const CUENTAS = [
  {id:900, sede:'plaza', mesa_id:101, estado:'abierta', total:7700, abierta_por:'jhon@cafe.cl'},
];
/* Uno CON comentario y uno sin: así se prueba en las dos direcciones que el
   que se fue es el cartel de invitación, no el comentario de verdad — que es
   lo que lee la cocina y no se puede perder. */
const ITEMS = [
  {id:1, cuenta_id:900, nombre:'Affogato', cantidad:1, precio:5500,
   estado:'nuevo', comentario:'sin azúcar'},
  {id:2, cuenta_id:900, nombre:'Agua Benedictino c/gas', cantidad:1, precio:2200,
   estado:'nuevo', comentario:null},
];
const CARTA = [
  {fudo_product_id:'F-33', sede:'plaza', nombre:'Affogato',               precio:5500, activo:true},
  {fudo_product_id:'F-38', sede:'plaza', nombre:'Cortado',                precio:2600, activo:true},
  {fudo_product_id:'F-99', sede:'plaza', nombre:'Agua Benedictino c/gas', precio:2200, activo:true},
];
const MEDIOS = [
  {codigo:'efectivo', nombre:'Efectivo', orden:1, es_cobro:true, activo:true},
];
const MOTIVOS = [
  {codigo:'empleado', nombre:'Descuento de empleado', orden:1, activo:true},
];

const page = await browser.newPage();
await page.setViewportSize({width:390, height:900});

async function montar({puedeLama = true, sede = 'plaza'} = {}){
  await page.addInitScript(({MESAS, CUENTAS, ITEMS, CARTA, MEDIOS, MOTIVOS, puedeLama}) => {
    window.__rpc = [];
    const SES = {user:{id:'u1', email:'jhon@cafe.cl', user_metadata:{nombre:'Jhon'}}};
    const T = {
      productos:[], mesas:MESAS, cuentas:CUENTAS, cuenta_items:ITEMS, comandas:[],
      fudo_productos:CARTA,
      lama_medios_pago:MEDIOS, lama_motivos_descuento:MOTIVOS, lama_motivos_anulacion:[],
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
        neq(c,v){ filas=filas.filter(f=>String(f[c])!==String(v)); return api;},
        in(c,vs){ filas=filas.filter(f=>vs.map(String).includes(String(f[c]))); return api;},
        order(){return api;}, limit(){return api;}, gte(){return api;}, lte(){return api;},
        is(){return api;}, not(){return api;}, or(){return api;}, ilike(){return api;},
        maybeSingle(){return Promise.resolve({data:filas[0]||null,error:null});},
        single(){return Promise.resolve({data:filas[0]||null,error:null});},
        insert(v){ const rows=(Array.isArray(v)?v:[v]).map(r=>({id:++seq, ...r}));
          const e={select:()=>e, single:()=>Promise.resolve({data:rows[0],error:null}),
                   then:f=>Promise.resolve({data:rows,error:null}).then(f)}; return e; },
        update(v){
          const e = {
            eq(col, val){
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
      from:q,
      rpc:(nombre, args)=>{ window.__rpc.push({nombre, args});
        return Promise.resolve({data:null, error:null}); },
      auth:{ getSession:async()=>({data:{session:SES}}), getUser:async()=>({data:{user:SES.user}}),
             onAuthStateChange(cb){setTimeout(()=>cb&&cb('SIGNED_IN',SES),0);
               return {data:{subscription:{unsubscribe(){}}}};},
             signInWithPassword:async()=>({data:{session:SES},error:null}), signOut:async()=>({}) },
      channel:()=>({on(){return this;},subscribe(cb){cb&&cb('SUBSCRIBED');return this;},
                    track:async()=>{},presenceState:()=>({})}),
      removeChannel(){}, functions:{invoke:async()=>({data:{ok:true},error:null})},
    })};
  }, {MESAS, CUENTAS, ITEMS, CARTA, MEDIOS, MOTIVOS, puedeLama});
  await page.route('**/supabase-js*', r=>r.fulfill({status:200,contentType:'application/javascript',body:''}));
  await page.goto(pathToFileURL(join(raiz,'index.html')).href);
  await page.waitForTimeout(400);
  await page.click(`.gate-btn[data-sede="${sede}"]`);
  await page.waitForTimeout(800);
}

const abrirMesa2 = async () => {
  if(!(await page.isVisible('#view-lama'))) { await page.click('#tabLama'); await page.waitForTimeout(400); }
  await page.click('[data-lamamesa="101"]');
  await page.waitForTimeout(500);
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
   7 · EL HOGAR. Va primero porque decide dónde arranca todo lo demás.
   ================================================================ */
console.log('\nEL HOGAR DE LA APP ES MESAS:');
await montar({puedeLama:true});

await caso('la casita lleva a Mesas, no al inventario', async () => {
  const t = await page.getAttribute('#tabLama', 'data-tab');
  return t === 'lama' || 'la casita apunta a: ' + t;
});
await caso('y la app abre ahí sola, sin tocar nada', async () =>
  (await page.isVisible('#view-lama')) || 'abrió en otra pantalla');
await caso('el subtítulo de arriba dice Mesas', async () => {
  const t = (await page.textContent('#topSede')).trim();
  return t === 'Mesas' || 'dice: ' + t;
});
await caso('el inventario quedó como una pestaña más, con su nombre', async () => {
  const v = await page.isVisible('#tabInv');
  const t = v ? (await page.textContent('#tabInv')).trim() : '';
  return (v && t === 'Inventario') || 'visible=' + v + ' texto=' + t;
});
await caso('y sigue llevando al inventario', async () => {
  await page.click('#tabInv'); await page.waitForTimeout(400);
  return (await page.isVisible('#view-inv')) || 'no abrió el inventario';
});
/* LA MITAD QUE IMPORTA DEL CAMBIO: volver a Mesas no puede depender de que
   quede una segunda puerta. La casita es la única, y tiene que funcionar. */
await caso('desde el inventario, la casita vuelve a Mesas', async () => {
  await page.click('#tabLama'); await page.waitForTimeout(400);
  return (await page.isVisible('#view-lama')) || 'la casita no volvió a Mesas';
});
/* Y que no queden DOS puertas a lo mismo en una barra que ya hace scroll. */
await caso('no hay una segunda pestaña "Mesas" de texto', async () => {
  const n = await page.evaluate(()=>[...document.querySelectorAll('.tab')]
    .filter(t=>t.dataset.tab==='lama').length);
  return n === 1 || 'hay ' + n + ' pestañas que llevan a Mesas';
});

/* ⚠️ SIN PERMISO NO PUEDE QUEDAR UN HUECO. Es §2.2: apagado significa volver
   a lo de antes, no dejar la barra sin primera pestaña. */
console.log('\nSIN el permiso, la barra empieza en Inventario:');
await montar({puedeLama:false});
await caso('la casita de Mesas no está', async () =>
  !(await page.isVisible('#tabLama')) || 'la ve alguien que no tiene el permiso');
await caso('pero Inventario sí, y es lo primero', async () =>
  (await page.isVisible('#tabInv')) || 'la barra quedó sin su primera pestaña');
await caso('y la app abre en el inventario, como siempre', async () =>
  (await page.isVisible('#view-inv')) || 'no abrió en el inventario');

/* En Bodega no hay mesas: no vende. Mismo caso, otra razón. */
console.log('\nEn Bodega tampoco, porque Bodega no vende:');
await montar({puedeLama:true, sede:'central'});
await caso('la casita de Mesas no aparece', async () =>
  !(await page.isVisible('#tabLama')) || 'ofrece mesas en la bodega');
await caso('y abre en el inventario', async () =>
  (await page.isVisible('#view-inv')) || 'no abrió en el inventario');

/* ================================================================
   1 · EL "+ COMENTARIO"
   ================================================================ */
console.log('\n1 · EL "+ comentario" SE FUE (y el comentario de verdad se quedó):');
await montar({puedeLama:true});
await abrirMesa2();

await caso('ninguna línea invita a comentar con un cartel', async () => {
  const t = await page.textContent('#lama-panel');
  return !t.includes('+ comentario') || 'todavía dice "+ comentario"';
});
await caso('pero el comentario escrito SÍ se ve — lo lee la cocina', async () => {
  const t = await page.textContent('#lama-panel');
  return t.includes('sin azúcar') || 'se perdió el comentario del Affogato';
});
await caso('y sigue en ámbar, que es como se distingue', async () => {
  const c = await page.evaluate(()=>{
    const s=[...document.querySelectorAll('.lama-linea .nm span.con')]
      .find(x=>x.textContent.includes('sin azúcar'));
    return s ? getComputedStyle(s).color : null;});
  return c === 'rgb(156, 98, 9)' || 'el color es ' + c;
});
await caso('el producto sin comentario no arrastra un renglón vacío', async () => {
  const n = await page.evaluate(()=>{
    const l=[...document.querySelectorAll('.lama-linea')]
      .find(x=>x.textContent.includes('Agua Benedictino'));
    return l ? l.querySelectorAll('.nm span').length : -1;});
  return n === 0 || 'tiene ' + n + ' renglón(es) de más';
});

/* ================================================================
   2 · LA CÁPSULA DEL TOTAL
   ================================================================ */
console.log('\n2 · "Total a confirmar" ya no está metido en una cápsula:');
await caso('no tiene fondo propio', async () => {
  const b = await page.evaluate(()=>{
    const t=document.querySelector('.lama-pend .lama-tot');
    return t ? getComputedStyle(t).backgroundColor : 'NO EXISTE';});
  return (b === 'rgba(0, 0, 0, 0)' || b === 'transparent') || 'el fondo es ' + b;
});
await caso('ni esquinas de píldora', async () => {
  const r = await page.evaluate(()=>{
    const t=document.querySelector('.lama-pend .lama-tot');
    return t ? getComputedStyle(t).borderRadius : 'NO EXISTE';});
  return (r === '0px' || r === '') || 'el radio es ' + r;
});
/* LA CAUSA ERA UNA COLISIÓN DE NOMBRES con `.tot` de Stock, así que se prueba
   que el nombre nuevo esté puesto: si alguien lo devuelve a `tot`, la cápsula
   gris vuelve sola y sin que nadie toque una línea de CSS. */
await caso('la clase quedó con prefijo, para no volver a chocar con Stock', async () => {
  const hay = await page.evaluate(()=>!!document.querySelector('.lama-pend .lama-tot')
                                   && !document.querySelector('.lama-pend > .tot'));
  return hay || 'sigue usando la clase `tot` de Stock';
});
await caso('y el número se sigue leyendo', async () => {
  const t = await page.textContent('.lama-pend .lama-tot');
  return t.includes('7.700') || 'dice: ' + t;
});

/* ================================================================
   3 · EL LÁPIZ
   ================================================================ */
console.log('\n3 · El lápiz pesa lo mismo que sus compañeros:');
await caso('es un dibujo, no un carácter de la tipografía', async () => {
  const hay = await page.evaluate(()=>{
    const b=document.querySelector('.lama-trio [data-lamaacc="menu"]');
    return !!b && !!b.querySelector('svg');});
  return hay || 'sigue siendo el carácter ✎, que cada teléfono dibuja distinto';
});
await caso('mide exactamente lo mismo que la impresora', async () => {
  const r = await page.evaluate(()=>{
    const lap=document.querySelector('.lama-trio [data-lamaacc="menu"] svg');
    const imp=document.querySelector('.lama-trio [data-lamaacc="precuenta"] svg');
    if(!lap||!imp) return null;
    const a=lap.getBoundingClientRect(), b=imp.getBoundingClientRect();
    return {lap:Math.round(a.width), imp:Math.round(b.width)};});
  if(!r) return 'falta uno de los dos botones';
  return r.lap === r.imp || 'lápiz ' + r.lap + 'px vs impresora ' + r.imp + 'px';
});
await caso('y ocupa una parte seria de su botón, no un punto en el medio', async () => {
  const r = await page.evaluate(()=>{
    const b=document.querySelector('.lama-trio [data-lamaacc="menu"]');
    const s=b.querySelector('svg');
    return s.getBoundingClientRect().width / b.getBoundingClientRect().height;});
  return r > 0.3 || 'el dibujo ocupa solo el ' + Math.round(r*100) + '% del alto del botón';
});
/* En el computador el lápiz vive en la cabecera roja, al lado de la impresora.
   Es OTRO contenedor con otras reglas de CSS, así que arreglarlo en el trío
   del teléfono no prueba nada sobre este. */
await caso('en el computador también, junto a la impresora de la cabecera', async () => {
  await page.setViewportSize({width:1280, height:900});
  await page.waitForTimeout(500);
  const r = await page.evaluate(()=>{
    const lap=document.querySelector('.lama-cab [data-lamaacc="menu"] svg');
    const imp=document.querySelector('.lama-cab [data-lamaacc="precuenta"] svg');
    if(!lap||!imp) return null;
    return {lap:Math.round(lap.getBoundingClientRect().width),
            imp:Math.round(imp.getBoundingClientRect().width)};});
  if(!r) return 'los botones no están en la cabecera del computador';
  return (r.lap === r.imp && r.lap > 0) || 'lápiz ' + r.lap + 'px vs impresora ' + r.imp + 'px';
});

/* ================================================================
   4 · EL RECUADRO, NO LA PILA DE TARJETAS
   ================================================================ */
console.log('\n4 · El panel es un recuadro con líneas tenues, no tarjetas apiladas:');
await page.setViewportSize({width:390, height:900});
await page.waitForTimeout(450);
await caso('la línea de un producto no es una tarjeta con sombra', async () => {
  const s = await page.evaluate(()=>{
    const l=document.querySelector('.lama-linea');
    return l ? getComputedStyle(l).boxShadow : 'NO HAY';});
  return s === 'none' || 'todavía tiene sombra: ' + s;
});
await caso('lo que separa dos filas es una raya, y muy tenue', async () => {
  const b = await page.evaluate(()=>{
    const ls=[...document.querySelectorAll('.lama-pend .lama-linea')];
    if(ls.length < 2) return {falta:true};
    const cs=getComputedStyle(ls[1]);          // la SEGUNDA: es la que lleva raya
    const m=cs.borderTopColor.match(/[\d.]+/g);
    return {w:cs.borderTopWidth, alfa:m && m.length===4 ? +m[3] : 1};});
  if(b.falta) return 'hacen falta dos filas para probar esto';
  if(b.w === '0px') return 'no hay raya ninguna entre dos filas';
  return b.alfa <= 0.25 || 'la raya se nota demasiado (opacidad ' + b.alfa + ')';
});
/* ⚠️ ESTA ES LA QUE ATRAPÓ EL ERROR DE VERDAD, y por eso está escrita así.
   La primera versión ponía la raya DEBAJO de cada fila y se la quitaba a la
   última con `:last-child`. Dentro del bloque ámbar eso no alcanza: la última
   fila no es el último hijo —después viene "Total a confirmar", que ya trae su
   propia línea—, así que quedaban DOS rayas pegadas. Se mide el grupo entero:
   ni raya antes de la primera, ni después de la última. */
await caso('ni sobra al final ni falta al principio del grupo', async () => {
  const r = await page.evaluate(()=>{
    const ls=[...document.querySelectorAll('.lama-pend .lama-linea')];
    const w = el => ({ arriba:getComputedStyle(el).borderTopWidth,
                       abajo :getComputedStyle(el).borderBottomWidth });
    return {n:ls.length, primera:w(ls[0]), ultima:w(ls[ls.length-1])};});
  if(r.n < 2) return 'hacen falta dos filas para probar esto';
  if(r.primera.arriba !== '0px') return 'la primera lleva una raya arriba, pegada al rótulo';
  if(r.ultima.abajo  !== '0px') return 'la última lleva raya abajo, y el total ya trae la suya';
  return true;
});
await caso('lo pendiente sigue en ámbar — el color es el que avisa', async () => {
  const b = await page.evaluate(()=>getComputedStyle(
    document.querySelector('.lama-pend')).backgroundColor);
  return b === 'rgb(253, 240, 222)' || 'el ámbar cambió a ' + b;
});
await caso('pero ya no es una tarjeta dentro de la tarjeta del panel', async () => {
  const s = await page.evaluate(()=>getComputedStyle(
    document.querySelector('.lama-pend')).boxShadow);
  return s === 'none' || 'lo pendiente todavía tiene sombra: ' + s;
});

/* ================================================================
   5 · EL RESPLANDOR DE LA MESA ELEGIDA
   ================================================================ */
console.log('\n5 · El neón de la mesa elegida ya no choca contra las paredes del riel:');
await caso('el riel deja aire suficiente para el halo', async () => {
  const r = await page.evaluate(()=>{
    const cont=document.querySelector('.lama-mesas');
    const sel =document.querySelector('.lama-mesa.sel');
    if(!cont||!sel) return null;
    const c=cont.getBoundingClientRect(), s=sel.getBoundingClientRect();
    return {izq:Math.round(s.left-c.left), der:Math.round(c.right-s.right)};});
  if(!r) return 'no hay ninguna mesa elegida';
  /* El halo pide 6 px a los lados: `0 8px 24px -6px` da blur/2 − spread = 6,
     y el anillo `0 0 0 5px` da 5. Con menos que eso, se corta. */
  return (r.izq >= 6 && r.der >= 6) || 'aire izq ' + r.izq + 'px, der ' + r.der + 'px (hacen falta 6)';
});
await caso('y el halo sigue estando — no se arregló apagándolo', async () => {
  const s = await page.evaluate(()=>{
    const sel=document.querySelector('.lama-mesa.sel');
    return sel ? getComputedStyle(sel).boxShadow : 'NO HAY';});
  return s.includes('220, 68, 5') || 'el resplandor naranja desapareció: ' + s;
});

/* ================================================================
   6 · EL BASURERO
   ================================================================ */
console.log('\n6 · En 1, el − de la carta se vuelve un basurero:');
await page.click('.lama-fab'); await page.waitForTimeout(500);

await caso('con 1 unidad pendiente, muestra el basurero', async () => {
  const r = await page.evaluate(()=>{
    const f=[...document.querySelectorAll('.lama-prod')].find(p=>p.textContent.includes('Affogato'));
    const b=f && f.querySelector('[data-lamacartamenos]');
    return b ? {trash:b.classList.contains('is-trash'), svg:!!b.querySelector('svg')} : null;});
  if(!r) return 'no está la fila del Affogato';
  return (r.trash && r.svg) || 'is-trash=' + r.trash + ' svg=' + r.svg;
});
await caso('y lo dice también para quien no ve — aria-label', async () => {
  const l = await page.evaluate(()=>{
    const f=[...document.querySelectorAll('.lama-prod')].find(p=>p.textContent.includes('Affogato'));
    return f.querySelector('[data-lamacartamenos]').getAttribute('aria-label');});
  return /quitar/i.test(l || '') || 'dice: ' + l;
});
await caso('va en rojo, que en esta app es el color de lo que quita', async () => {
  const c = await page.evaluate(()=>{
    const f=[...document.querySelectorAll('.lama-prod')].find(p=>p.textContent.includes('Affogato'));
    return getComputedStyle(f.querySelector('[data-lamacartamenos]')).color;});
  return c === 'rgb(192, 57, 43)' || 'el color es ' + c;
});

/* ⚠️ LAS TRES QUE DE VERDAD IMPORTAN. Un basurero que aparece cuando el botón
   NO va a borrar es una promesa falsa, y se descubre después de apretarlo. */
console.log('\n   …y NO aparece cuando ese botón no borra:');
await caso('con 2 unidades, es un menos: todavía queda una', async () => {
  const r = await page.evaluate(()=>{
    LAMA_ITEMS.find(x=>x.nombre==='Affogato').cantidad = 2;
    return lamaMenosBorra('Affogato');});
  return r === false || 'promete borrar cuando solo va a restar';
});
await caso('si ya salió a la cocina, tampoco: ese − lleva a ANULAR', async () => {
  const r = await page.evaluate(()=>{
    const it=LAMA_ITEMS.find(x=>x.nombre==='Affogato');
    it.cantidad = 1; it.estado = 'confirmado';
    return lamaMenosBorra('Affogato');});
  return r === false || 'ofrece basurero para algo que ya se preparó';
});
await caso('y un producto que no está en la cuenta no promete nada', async () =>
  (await page.evaluate(()=>lamaMenosBorra('No existe'))) === false || 'promete borrar la nada');

/* La regla del dueño único: si el dibujo y el manejador eligieran líneas
   distintas, el basurero borraría otra cosa de la que está mirando. */
await caso('el dibujo y el clic miran la MISMA línea', async () => {
  const r = await page.evaluate(()=>{
    const it=LAMA_ITEMS.find(x=>x.nombre==='Affogato');
    it.cantidad = 1; it.estado = 'nuevo';
    const blanco = lamaBlancoDelMenos('Affogato');
    return blanco && blanco.id === it.id && lamaMenosBorra('Affogato') === true;});
  return r === true || 'el dibujo y el manejador no coinciden';
});

/* ================================================================
   8 · EL − Y EL + DE LA VENTANA DEL PRODUCTO — el bug del 2026-09-04
   ================================================================
   Jhon eligió un Agua Benedictino, tocó el producto para subirle la cantidad,
   y el botón no hacía nada. La causa: esos dos botones **no tenían manejador**
   — los atributos que se dibujaban (`data-lamappmas`) y los que se escuchaban
   (`data-lamamas`) se habían separado. Dos mitades huérfanas.
   ================================================================ */
console.log('\n8 · El − y el + de la ventana del producto:');
/* La sección 6 dejó la carta abierta y tapa el panel: se cierra antes de
   seguir, o los clics de acá caen sobre ella. */
await page.evaluate(()=>{ lamaCerrarCarta(); });
await page.setViewportSize({width:390, height:900});
await page.waitForTimeout(500);
await abrirMesa2();

const cantidadPP = () => page.evaluate(()=>{
  const b = document.querySelector('.lama-pp-paso b');
  return b ? +b.textContent.trim() : null;});

await caso('la ventana del producto se abre al tocar la fila', async () => {
  await page.click('[data-lamaprod]');
  await page.waitForTimeout(400);
  return (await cantidadPP()) !== null || 'no se abrió la ventana';
});
/* LA QUE IMPORTA. Antes esto daba 1 para siempre. */
await caso('el + SUBE la cantidad — antes no hacía nada', async () => {
  const antes = await cantidadPP();
  await page.click('[data-lamappmas]'); await page.waitForTimeout(300);
  const des = await cantidadPP();
  return des === antes + 1 || 'de ' + antes + ' pasó a ' + des;
});
await caso('y el − la baja', async () => {
  const antes = await cantidadPP();
  await page.click('[data-lamappmenos]'); await page.waitForTimeout(300);
  const des = await cantidadPP();
  return des === antes - 1 || 'de ' + antes + ' pasó a ' + des;
});
/* No baja de 1: para SACAR el producto está la ✕ de su fila. Bajar a cero
   desde una ventana que dice "Guardar" sería quitar algo por un camino que no
   lo anuncia. */
await caso('pero no baja de 1: quitar es otro gesto', async () => {
  await page.click('[data-lamappmenos]'); await page.waitForTimeout(250);
  await page.click('[data-lamappmenos]'); await page.waitForTimeout(250);
  return (await cantidadPP()) === 1 || 'bajó a ' + (await cantidadPP());
});
await caso('el precio de arriba acompaña a la cantidad', async () => {
  await page.click('[data-lamappmas]'); await page.waitForTimeout(300);
  const t = await page.evaluate(()=>document.querySelector('.lama-pp-caja .pr').textContent);
  return t.includes('11.000') || 'con 2 Affogato de $5.500 debería decir 11.000 · dice: ' + t;
});
/* Y NO viaja a la base hasta Guardar: la ventana trabaja sobre una copia, así
   que Cancelar tiene que dejar la línea como estaba. */
await caso('Cancelar no cambia la cantidad de la línea', async () => {
  await page.click('[data-lamaacc="pp-cancelar"]'); await page.waitForTimeout(400);
  const t = await page.evaluate(()=>{
    const l = [...document.querySelectorAll('.lama-linea')]
      .find(x => x.textContent.includes('Affogato'));
    return l ? l.querySelector('.q').textContent.trim() : null;});
  return t === '1' || 'la línea quedó en ' + t;
});

/* ================================================================
   9 · LA FRANJA DE "PRECUENTA IMPRESA" SE FUE
   ================================================================ */
console.log('\n9 · Con la precuenta impresa ya no va una franja explicando:');
await caso('no queda ningún cartel permanente', async () => {
  await page.evaluate(()=>{
    const c = LAMA_CUENTAS.find(x => x.mesa_id === 101);
    if(c) c.estado = 'precuenta';
    lamaPintar();
  });
  await page.waitForTimeout(400);
  const t = await page.evaluate(()=>document.getElementById('lama-panel').textContent);
  if(/Precuenta impresa/.test(t)) return 'sigue la franja';
  return !/volvé la mesa a Ocupada/.test(t) || 'sigue el texto de cómo volver';
});
/* ⚠️ LA MITAD QUE IMPORTA: sacar el cartel no puede dejar la pantalla muda.
   El estado se sigue viendo sin una palabra —la cabecera dice "Cobrando"— y
   el + sigue ahí, apagado, en vez de desaparecer. */
await caso('pero el estado se sigue viendo: la mesa dice Cobrando', async () => {
  const t = await page.evaluate(()=>document.getElementById('lama-panel').textContent);
  return t.includes('Cobrando') || 'no se ve en qué estado está la mesa';
});
await caso('y el + sigue existiendo, apagado — no desaparece', async () => {
  const r = await page.evaluate(()=>{
    const f = document.querySelector('.lama-fab');
    return f ? {hay:true, trabada:f.classList.contains('trabada')} : {hay:false};});
  if(!r.hay) return 'el + desapareció: quien lo busque va a creer que se rompió';
  return r.trabada === true || 'el + no se ve apagado';
});

console.log('\nSin errores de JavaScript:');
await caso('ninguno en toda la vuelta', async () =>
  errores.length === 0 || errores.join(' · '));

console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();
process.exit(mal ? 1 : 0);
