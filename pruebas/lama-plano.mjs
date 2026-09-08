/* EL PLANO DE MESAS · páginas, secciones y modo edición.
   node pruebas/lama-plano.mjs

   Sale de la maqueta que Jhon aprobó el 2026-09-05
   (`docs/propuesta-lama-mesas.html`).

   LO QUE MÁS IMPORTA acá no es que el plano se dibuje lindo: es que
   **el modo edición no pueda romper una cuenta viva**. Una mesa quitada o
   movida con gente sentada manda el pedido al lugar equivocado, y eso se
   descubre en el mesón, no en la pantalla.

   Y se prueba EN LAS DOS DIRECCIONES: con el `.sql` corrido (hay áreas) y
   SIN correr (no hay tabla). Lo segundo es lo que garantiza que publicar
   esto antes de que Jhon pegue el SQL no deje la pantalla en blanco — la
   falla silenciosa que este proyecto ya pagó dos veces.                    */
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { abrirNavegador } from './navegador.mjs';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await abrirNavegador();
if (!browser) { console.log('\n(se salta: no hay navegador instalado)\n'); process.exit(0); }

/* EL PLANO NUEVO. Dos secciones dentro de una página, como quedó Mall Plaza
   después del .sql: mesas 1-5 en un ala y 6-12 en la otra. */
const AREAS = [
  {id:10, sede:'plaza', nombre:'Salón',        padre_id:null, color:'a', orden:0, activa:true},
  {id:11, sede:'plaza', nombre:'Ala izquierda', padre_id:10,  color:'a', orden:0, activa:true},
  {id:12, sede:'plaza', nombre:'Ala derecha',   padre_id:10,  color:'b', orden:1, activa:true},
];
const MESAS = Array.from({length:12}, (_,i)=>({
  id:100+i, sede:'plaza', salon:'Salón', numero:i+1, orden:i+1, activa:true,
  area_id: i < 5 ? 11 : 12,
  /* Una de cada forma y una de cada tamaño, para que el plano se pruebe con
     la variedad que va a tener de verdad y no con doce cuadrados iguales. */
  forma: i===1?'redonda' : i===6?'larga' : 'cuadrada',
  tam:   i===2?'chica'   : i===3?'grande': 'normal' }));

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
await page.setViewportSize({width:1280, height:900});

async function montar({puedeLama = true, conAreas = true} = {}){
  await page.addInitScript(({MESAS, CUENTAS, ITEMS, CARTA, AREAS, puedeLama, conAreas}) => {
    window.__rpc = [];
    /* Se anota TODA escritura a la base: la prueba comprueba qué se le pidió
       guardar, no solo qué se dibujó. */
    window.__esc = [];
    const SES = {user:{id:'u1', email:'jhon@cafe.cl', user_metadata:{nombre:'Jhon'}}};
    const T = {
      productos:[{id:1, sede:'plaza', producto:'Medialuna manjar', rubro:'Vitrina', stock_actual:20, activo:'SÍ'}],
      mesas:MESAS, cuentas:CUENTAS, cuenta_items:ITEMS, comandas:[],
      lama_areas: conAreas ? AREAS : [],
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
        insert(v){ window.__esc.push({tabla:n, op:'insert', datos:v});
          const rows=(Array.isArray(v)?v:[v]).map(r=>({id:++seq, ...r}));
          const e={select:()=>e, single:()=>Promise.resolve({data:rows[0],error:null}),
                   then:f=>Promise.resolve({data:rows,error:null}).then(f)}; return e; },
        update(v){ const reg={tabla:n, op:'update', datos:v};
          window.__esc.push(reg);
          const e={eq:(c,x)=>{reg[c]=x;return e;},in:()=>e,select:()=>e,
                   then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        upsert(){const e={select:()=>e,then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
        delete(){ const reg={tabla:n, op:'delete'};
          window.__esc.push(reg);
          const e={eq:(c,x)=>{reg[c]=x;return e;},in:()=>e,
                   then:f=>Promise.resolve({data:[],error:null}).then(f)};return e;},
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
  }, {MESAS, CUENTAS, ITEMS, CARTA, AREAS, puedeLama, conAreas});
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
const esc  = () => page.evaluate(() => window.__esc);
const txt  = sel => page.textContent(sel).catch(()=>null);
/* El aviso de la app es su propia ventana (`preguntar`), no un toast del
   navegador: hay que leerla de sus dos rótulos y CERRARLA, o la prueba
   siguiente arranca con la pantalla tapada. */
const aviso = async () => ((await txt('#ask-titulo')) || '') + ' ' + ((await txt('#ask-detalle')) || '');
const cerrarAviso = async () => { const b = await page.$('#ask-ok'); if(b) await b.click();
                                  await page.waitForTimeout(250); };
const hay  = sel => page.isVisible(sel).catch(()=>false);
const editar = async () => { await page.click('[data-lamaacc="plano-editar"]');
                             await page.waitForTimeout(250); };

console.log('\nCON EL .SQL CORRIDO · el plano se agrupa:');
await montar({conAreas:true});
await caso('la franja muestra la página, aunque haya una sola', async () =>
  await hay('[data-lamapagina]') || 'no se ve ninguna página');
await caso('las dos secciones se dibujan', async () =>
  (await page.locator('.lama-sec').count()) === 2 ||
  'hay ' + (await page.locator('.lama-sec').count()));
await caso('cada mesa quedó en su sección', async () => {
  const izq = await page.locator('[data-lamasec="11"] .lama-mesa').count();
  const der = await page.locator('[data-lamasec="12"] .lama-mesa').count();
  return (izq === 5 && der === 7) || `izquierda ${izq}, derecha ${der}`;
});
await caso('la sección lleva su nombre a la vista', async () =>
  (await txt('[data-lamasec="11"] .lama-sec-cab')).includes('Ala izquierda') || 'no dice el nombre');
await caso('y su color, que sale de la base y no del código', async () =>
  (await page.getAttribute('[data-lamasec="12"]', 'class')).includes('c-b') || 'no tomó el color');
await caso('la mesa ocupada sigue marcándose roja', async () =>
  (await page.getAttribute('[data-lamamesa="101"]','class')).includes('ocupada') || 'perdió el estado');
await caso('tocar una mesa la elige, como siempre', async () => {
  await page.click('[data-lamamesa="103"]'); await page.waitForTimeout(400);
  return (await page.getAttribute('[data-lamamesa="103"]','class')).includes('sel') || 'no se eligió';
});

console.log('\nLA FORMA Y EL TAMAÑO SALEN DE LA BASE, no del código:');
await caso('la redonda se dibuja redonda', async () =>
  (await page.getAttribute('[data-lamamesa="101"]','class')).includes('f-redonda') || 'no tomó la forma');
await caso('la larga se dibuja larga', async () =>
  (await page.getAttribute('[data-lamamesa="106"]','class')).includes('f-larga') || 'no tomó la forma');
await caso('la chica y la grande llevan su marca', async () =>
  ((await page.getAttribute('[data-lamamesa="102"]','class')).includes('t-chica') &&
   (await page.getAttribute('[data-lamamesa="103"]','class')).includes('t-grande')) || 'falta alguna');
await caso('una mesa normal NO lleva marca de más', async () => {
  const c = await page.getAttribute('[data-lamamesa="100"]','class');
  return (!c.includes('t-') && !c.includes('f-')) || 'le sobra: ' + c;
});
await caso('y en el computador la grande de verdad ocupa más', async () => {
  const g = await page.locator('[data-lamamesa="103"]').boundingBox();
  const n = await page.locator('[data-lamamesa="100"]').boundingBox();
  return (g.width > n.width * 1.5 && g.height > n.height * 1.5)
    || `grande ${Math.round(g.width)}x${Math.round(g.height)}, normal ${Math.round(n.width)}x${Math.round(n.height)}`;
});
await caso('y la chica, menos', async () => {
  const c = await page.locator('[data-lamamesa="102"]').boundingBox();
  const n = await page.locator('[data-lamamesa="100"]').boundingBox();
  return c.width < n.width || `chica ${Math.round(c.width)}, normal ${Math.round(n.width)}`;
});

console.log('\nEN EL TELÉFONO el tamaño NO se aplica, y es a propósito:');
await page.setViewportSize({width:390, height:844}); await page.waitForTimeout(350);
await caso('la grande mide lo mismo que una normal en el riel', async () => {
  const g = await page.locator('[data-lamamesa="103"]').boundingBox();
  const n = await page.locator('[data-lamamesa="100"]').boundingBox();
  /* Una mesa que se estira en una columna de 66 px empujaría a todas las
     demás fuera de la vista. Ahí mandan el número y el color. */
  return Math.abs(g.width - n.width) < 2 || `grande ${Math.round(g.width)}, normal ${Math.round(n.width)}`;
});
await page.setViewportSize({width:1280, height:900}); await page.waitForTimeout(350);

console.log('\nSIN EL .SQL · todo sigue como antes (lo que evita publicar una pantalla rota):');
await montar({conAreas:false});
await caso('no aparece ninguna sección', async () =>
  (await page.locator('.lama-sec').count()) === 0 || 'dibujó secciones sin tabla');
await caso('las 12 mesas se ven igual', async () =>
  (await page.locator('.lama-mesa').count()) === 12 ||
  'hay ' + (await page.locator('.lama-mesa').count()));
await caso('y no hay lápiz que prometa algo que no se puede', async () =>
  !(await hay('[data-lamaacc="plano-editar"]')) || 'ofrece editar sin dónde guardar');

console.log('\nEL MODO EDICIÓN · entrar y salir:');
await montar({conAreas:true});
await caso('el lápiz está a la vista', async () =>
  await hay('[data-lamaacc="plano-editar"]') || 'no aparece');
await editar();
await caso('la cinta dice que estás editando', async () =>
  ((await txt('#lama-banda')) || '').includes('Editando') || 'no avisa en qué modo estás');
await caso('y ofrece la salida al lado', async () =>
  await hay('[data-lamaacc="plano-listo"]') || 'un modo sin salida es una trampa');
await caso('aparece el + para agregar una mesa a cada sección', async () =>
  (await page.locator('[data-lamanuevamesa]').count()) === 2 ||
  'hay ' + (await page.locator('[data-lamanuevamesa]').count()));
await caso('y los botones de agregar sección y página', async () =>
  (await hay('[data-lamaacc="plano-nueva-seccion"]') &&
   await hay('[data-lamaacc="plano-nueva-pagina"]')) || 'falta alguno');

console.log('\nLA FICHA DE UNA MESA:');
await page.click('[data-lamamesa="103"]'); await page.waitForTimeout(300);
await caso('tocar una mesa abre su ficha, no la atiende', async () =>
  await hay('#lama-pf') || 'no abrió la ficha');
await caso('trae el número puesto', async () =>
  (await page.inputValue('#pf-num')) === '4' || 'dice ' + (await page.inputValue('#pf-num')));
await caso('deja elegir entre las dos secciones', async () =>
  (await page.locator('[data-lamapf="area_id"]').count()) === 2 || 'no ofrece las secciones');
await caso('y las tres formas y los tres tamaños', async () =>
  ((await page.locator('[data-lamapf="forma"]').count()) === 3 &&
   (await page.locator('[data-lamapf="tam"]').count()) === 3) || 'faltan opciones');

console.log('\nGUARDAR · lo que se le pide a la base:');
await page.click('[data-lamapf="forma"][data-v="redonda"]');
await page.waitForTimeout(150);
await page.fill('#pf-num', '30');
await page.click('[data-lamapf="area_id"][data-v="12"]');
await page.waitForTimeout(150);
await caso('elegir una píldora NO borra lo tipeado', async () =>
  (await page.inputValue('#pf-num')) === '30' ||
  'el número quedó en ' + (await page.inputValue('#pf-num')));
await page.click('[data-lamaacc="plano-guardar"]');
await page.waitForTimeout(500);
await caso('se guarda la mesa con su número, sección y forma', async () => {
  const u = (await esc()).filter(x => x.tabla === 'mesas' && x.op === 'update').pop();
  if(!u) return 'no se pidió ninguna actualización';
  return (u.datos.numero === 30 && u.datos.area_id === 12 && u.datos.forma === 'redonda')
    || JSON.stringify(u.datos);
});
await caso('y se cierra la ficha', async () => !(await hay('#lama-pf')) || 'quedó abierta');

console.log('\nEL NÚMERO REPETIDO SE ATAJA ANTES DE LA BASE:');
await montar({conAreas:true}); await editar();
await page.click('[data-lamamesa="103"]'); await page.waitForTimeout(300);
await page.fill('#pf-num', '7');            // ya existe la mesa 7
await page.click('[data-lamaacc="plano-guardar"]');
await page.waitForTimeout(400);
await caso('avisa que ese número ya existe', async () =>
  (await aviso()).includes('Ya existe la mesa 7') || 'dijo: ' + (await aviso()));
await caso('y NO le pide nada a la base', async () =>
  (await esc()).filter(x => x.tabla === 'mesas' && x.op === 'update').length === 0
  || 'igual mandó el cambio');

console.log('\n🔴 EL CANDADO QUE IMPORTA · una mesa con cuenta abierta:');
await cerrarAviso();
await page.click('[data-lamaacc="plano-cancelar"]'); await page.waitForTimeout(250);
await page.evaluate(()=>{ window.__esc = []; });
await page.click('[data-lamamesa="101"]');   // la 2, que tiene cuenta viva
await page.waitForTimeout(300);
await page.click('[data-lamaacc="plano-borrar"]');
await page.waitForTimeout(400);
const dijo = await aviso();
/* ⚠️ ACÁ HAY QUE ACEPTAR LO QUE APAREZCA, y no es un detalle de la prueba.
   Si el candado NO estuviera, lo que se abre es la confirmación "¿Quitar la
   mesa?" — y quedarse sin contestarla haría que no se escriba nada igual.
   La prueba pasaría en verde por la razón equivocada. Se contesta que SÍ: con
   el candado puesto no hay nada que confirmar, y sin él la mesa se borra y la
   prueba se pone roja, que es lo que tiene que pasar. */
await cerrarAviso();
await page.waitForTimeout(300);
await caso('no se puede quitar, y dice por qué', async () =>
  dijo.includes('cuenta abierta') || 'el aviso dice: ' + dijo.slice(0,70));
await caso('y la base no recibió NADA', async () =>
  (await esc()).filter(x => x.tabla === 'mesas').length === 0 || 'se mandó igual');

console.log('\nUNA SECCIÓN CON MESAS TAMPOCO SE BORRA:');
await montar({conAreas:true}); await editar();
await page.click('[data-lamaseced="11"]'); await page.waitForTimeout(300);
await caso('el título de la sección abre su ficha', async () =>
  await hay('#lama-pf') || 'no abrió');
await caso('trae el nombre puesto', async () =>
  (await page.inputValue('#pf-nom')) === 'Ala izquierda' || (await page.inputValue('#pf-nom')));
await page.click('[data-lamaacc="plano-borrar"]');
await page.waitForTimeout(400);
await caso('avisa cuántas mesas tiene adentro', async () =>
  (await aviso()).includes('5 mesas') || 'dijo: ' + (await aviso()));
await caso('y no se borró nada', async () =>
  (await esc()).filter(x => x.tabla === 'lama_areas' && x.op === 'delete').length === 0
  || 'la borró igual');
await cerrarAviso();

console.log('\nCREAR UNA SECCIÓN NUEVA:');
await montar({conAreas:true}); await editar();
await page.click('[data-lamaacc="plano-nueva-seccion"]'); await page.waitForTimeout(250);
await page.fill('#pf-nom', 'Barra');
await page.click('[data-lamapf="color"][data-v="c"]');
await page.waitForTimeout(150);
await caso('el color elegido no borra el nombre tipeado', async () =>
  (await page.inputValue('#pf-nom')) === 'Barra' || 'quedó en ' + (await page.inputValue('#pf-nom')));
await page.click('[data-lamaacc="plano-guardar"]');
await page.waitForTimeout(500);
await caso('nace colgando de la página abierta, no suelta', async () => {
  const i = (await esc()).filter(x => x.tabla === 'lama_areas' && x.op === 'insert').pop();
  if(!i) return 'no se creó nada';
  return (i.datos.nombre === 'Barra' && i.datos.padre_id === 10 &&
          i.datos.color === 'c' && i.datos.sede === 'plaza') || JSON.stringify(i.datos);
});

console.log('\nUNA SECCIÓN SIN NOMBRE NO SE GUARDA:');
await montar({conAreas:true}); await editar();
await page.click('[data-lamaacc="plano-nueva-seccion"]'); await page.waitForTimeout(250);
await page.click('[data-lamaacc="plano-guardar"]'); await page.waitForTimeout(400);
await caso('avisa que le falta el nombre', async () =>
  (await aviso()).includes('nombre') || 'dijo: ' + (await aviso()));
await caso('y no escribió nada', async () =>
  (await esc()).filter(x => x.tabla === 'lama_areas').length === 0 || 'guardó una sin nombre');
await cerrarAviso();

console.log('\n🔴 REORDENAR CON FLECHAS, NO ARRASTRANDO:');
await montar({conAreas:true}); await editar();
await caso('la primera sección no tiene flecha para subir', async () =>
  !(await page.isVisible('[data-lamasecsube="11"]')) || 'ofrece subir la que ya está primera');
await caso('pero sí tiene para bajar', async () =>
  await page.isVisible('[data-lamasecbaja="11"]') || 'no puede bajar');
await caso('la última no tiene flecha para bajar', async () =>
  !(await page.isVisible('[data-lamasecbaja="12"]')) || 'ofrece bajar la que ya está última');
await caso('y sí para subir', async () =>
  await page.isVisible('[data-lamasecsube="12"]') || 'no puede subir');
await caso('"Ala izquierda" empieza arriba', async () => {
  const t = await page.evaluate(() =>
    [...document.querySelectorAll('.lama-sec .t')].map(x => x.textContent));
  return t[0] === 'Ala izquierda' || 'orden inicial: ' + t.join(', ');
});
await page.click('[data-lamasecbaja="11"]'); await page.waitForTimeout(500);
await caso('bajarla la manda al final, en pantalla', async () => {
  const t = await page.evaluate(() =>
    [...document.querySelectorAll('.lama-sec .t')].map(x => x.textContent));
  return t[0] === 'Ala derecha' || 'sigue en: ' + t.join(', ');
});
await caso('y se lo pide a la base — las dos filas con su orden nuevo', async () => {
  const u = (await esc()).filter(x => x.tabla === 'lama_areas' && x.op === 'update');
  return u.length === 2 || 'mandó ' + u.length + ' actualizaciones';
});
await caso('las mesas se quedan en su sección — reordenar no las mueve', async () => {
  /* Sin `:not(.nueva)`: en modo edición cada sección lleva el + fantasma, que
     también es un `.lama-mesa` y se contaría de más. */
  const izq = await page.locator('.lama-sec:has-text("Ala izquierda") .lama-mesa:not(.nueva)').count();
  return izq === 5 || 'la sección quedó con ' + izq + ' mesas';
});

console.log('\nSALIR DEL MODO EDICIÓN:');
await montar({conAreas:true}); await editar();
await page.click('[data-lamaacc="plano-listo"]'); await page.waitForTimeout(300);
await caso('desaparece la cinta', async () =>
  !((await txt('#lama-banda')) || '').includes('Editando') || 'sigue puesta');
await caso('desaparecen los + fantasma', async () =>
  (await page.locator('[data-lamanuevamesa]').count()) === 0 || 'quedaron colgados');
await caso('y tocar una mesa vuelve a ATENDERLA, no a editarla', async () => {
  await page.click('[data-lamamesa="103"]'); await page.waitForTimeout(400);
  return !(await hay('#lama-pf')) || 'abrió la ficha de edición estando apagado';
});

console.log('\nY NINGÚN ERROR DE JAVASCRIPT EN TODA LA SESIÓN:');
await caso('la consola quedó limpia', async () =>
  errores.length === 0 || errores[0]);

console.log(`\n${ok} bien · ${mal} mal\n`);
await browser.close();
process.exit(mal ? 1 : 0);
