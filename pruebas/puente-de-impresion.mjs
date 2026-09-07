/* EL PUENTE DE IMPRESIÓN · la mitad que SÍ se puede probar sin ir al local.
   node pruebas/puente-de-impresion.mjs

   ⚠️ LO QUE ESTA PRUEBA NO PRUEBA, y decirlo es la mitad del valor: **no
   comprueba que el papel salga**. Eso depende del spooler de Windows y de la
   impresora, y sólo se sabe en el local. Es exactamente §0.5 — una prueba
   contra un mundo que uno construye valida la LÓGICA, no el ENCAJE.

   Lo que sí prueba, y es lo que se puede romper desde acá: que los bytes que
   se le mandan a la impresora sean los correctos. Un acento mal traducido no
   se ve en el código; se ve cuando sale "Medialuna de jam?n" en la comanda. */
import { bytes, aPapel, ESC } from '../puente/imprimir.mjs';

let ok=0, mal=0;
const caso = (n, fn) => {
  try { const r = fn(); if(r===true){ok++;console.log('  ✓ '+n);}
        else {mal++;console.log('  ✗ '+n+'  → '+r);} }
  catch(e){ mal++; console.log('  ✗ '+n+'  → '+e.message); }
};

console.log('\nLOS ACENTOS · lo que rompe una comanda de verdad:');
caso('la ñ no viaja en UTF-8', () =>
  aPapel('ñ') === '\xa4' || 'salió ' + JSON.stringify(aPapel('ñ')));
caso('las cinco vocales con tilde se traducen', () =>
  aPapel('áéíóú') === '\xa0\x82\xa1\xa2\xa3' || JSON.stringify(aPapel('áéíóú')));
caso('"Medialuna de jamón" queda legible', () =>
  aPapel('Medialuna de jamón') === 'Medialuna de jam\xa2n' || aPapel('Medialuna de jamón'));
caso('la flecha del comentario se vuelve algo imprimible', () =>
  aPapel('→ sin azúcar') === '-> sin az\xa3car' || aPapel('→ sin azúcar'));
caso('la línea divisoria no se vuelve basura', () =>
  aPapel('─────') === '-----' || aPapel('─────'));
/* Sin este caso, un carácter raro futuro saldría como un byte cualquiera y
   la impresora podría interpretarlo como un COMANDO. Ahí no sale un símbolo
   feo: sale cualquier cosa, o se corta el papel a mitad. */
caso('un carácter desconocido cae en "?" y no en un byte suelto', () =>
  aPapel('日') === '?' || JSON.stringify(aPapel('日')));
caso('lo que ya es ASCII no se toca', () =>
  aPapel('MESA 12  x2  $3.400') === 'MESA 12  x2  $3.400' || 'lo cambió');

console.log('\nEL PAPEL COMPLETO:');
const b = bytes('MESA 4\nCafé');
caso('empieza despertando la impresora', () =>
  b.slice(0,2).toString('latin1') === ESC.init || 'no arranca con el init');
caso('termina cortando el papel', () =>
  b.slice(-3).toString('latin1') === ESC.corte || 'no corta');
caso('deja avanzar el papel ANTES de cortar', () => {
  /* Sin ese avance, la cuchilla corta encima de la última línea y el ticket
     sale sin su pie. Son cuatro saltos de línea y se ven acá. */
  const t = b.toString('latin1');
  return t.indexOf(ESC.feed) > 0 && t.indexOf(ESC.feed) < t.lastIndexOf(ESC.corte)
    || 'el avance no está antes del corte';
});
caso('el texto va adentro, ya traducido', () =>
  b.toString('latin1').includes('Caf\x82') || 'el acento no se tradujo en el papel');
caso('y NO va el acento en UTF-8', () =>
  !b.toString('latin1').includes('Café') || 'viajó crudo');
caso('es un Buffer de bytes, no un texto', () =>
  Buffer.isBuffer(b) || 'no es Buffer');

console.log('\nLA ALINEACIÓN:');
caso('el papel se imprime alineado a la izquierda', () =>
  b.toString('latin1').includes(ESC.izq) || 'no fija la alineación');

console.log(`\n${ok} bien · ${mal} mal`);
console.log('(el encaje con la impresora se comprueba en el local, no acá)\n');
process.exit(mal ? 1 : 0);
