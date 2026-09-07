/* EL PUENTE DE IMPRESIÓN de Llamita Lama.
   ---------------------------------------------------------------------------
   Corre en el computador del local. Hace dos cosas y ninguna más:

     1. se suscribe a la cola `lama_impresiones` de Supabase
     2. le pide a WINDOWS que imprima, con el driver que ya está puesto

   No abre ningún puerto, no pelea con Windows por el aparato, y no sabe nada
   de inventario ni de ventas: si falla, falla solo. Esa es la regla de §2.3.

   ⚠️ ESTE ARCHIVO NO SE PROBÓ CONTRA LA IMPRESORA DE VERDAD. La lógica sí
   está probada (`pruebas/puente-de-impresion.mjs`), pero el encaje con el
   spooler de Windows sólo se comprueba en el local — y esa distinción es
   exactamente la lección de §0.5: una prueba contra un mundo que uno mismo
   construye valida la lógica, no el encaje.                               */
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const cfg  = JSON.parse(readFileSync(join(aqui, 'config.json'), 'utf8'));

const hora = () => new Date().toLocaleTimeString('es-CL');
const log  = (...a) => console.log('[' + hora() + ']', ...a);

import { imprimir } from './imprimir.mjs';

/* ---------- la cola ---------- */
const sb = createClient(cfg.supabase_url, cfg.supabase_key);

/* Uno por vez, y en orden. Dos papeles saliendo a la vez en una térmica es un
   papel ilegible; y el orden importa porque una anulación después de su
   comanda cuenta una historia, al revés no cuenta nada. */
let trabajando = false;
async function vaciarCola(){
  if(trabajando) return;
  trabajando = true;
  try {
    for(;;){
      const {data, error} = await sb.from('lama_impresiones')
        .select('*').eq('sede', cfg.sede).eq('estado','pendiente')
        .order('creada_at').limit(1);
      if(error){ log('no pude leer la cola:', error.message); break; }
      const fila = (data || [])[0];
      if(!fila) break;
      try {
        imprimir(cfg, fila.contenido);
        await sb.from('lama_impresiones')
          .update({estado:'impresa', impresa_at:new Date().toISOString()})
          .eq('id', fila.id);
        log('impreso ·', fila.tipo, '#' + fila.id);
      } catch (e) {
        const motivo = String(e.stderr || e.message || e).split('\n')[0].slice(0, 300);
        /* Queda escrito POR QUÉ falló, y en la fila que falló. Un papel que
           no sale y no deja rastro es la falla silenciosa de §0.5: nadie va a
           buscar lo que parece estar bien. */
        await sb.from('lama_impresiones')
          .update({estado:'error', error:motivo}).eq('id', fila.id);
        log('✗ no salió ·', fila.tipo, '#' + fila.id, '·', motivo);
      }
    }
  } finally { trabajando = false; }
}

log('Llamita · puente de impresión');
log('sede:', cfg.sede, '· impresora:', cfg.impresora);

sb.channel('cola-impresion')
  .on('postgres_changes',
      {event:'INSERT', schema:'public', table:'lama_impresiones'},
      () => vaciarCola())
  .subscribe(estado => {
    log('conexión:', estado);
    /* Al conectar se vacía lo que haya quedado: si el computador estuvo
       apagado, esos papeles siguen esperando y tienen que salir igual. */
    if(estado === 'SUBSCRIBED') vaciarCola();
  });

/* La red se cae, el aviso se pierde, y nadie se entera hasta que falta un
   papel. Cada 60 segundos se mira la cola igual — es barato y es la red que
   hace que un aviso perdido no cueste una comanda. */
setInterval(vaciarCola, 60000);
