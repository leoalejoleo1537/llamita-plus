/* EL PUENTE DE IMPRESIÓN · lo que se puede comprobar sin un Windows.
   node pruebas/puente-de-impresion.mjs

   ⚠️ EMPIEZO POR LO QUE ESTA PRUEBA **NO** HACE, porque decirlo es la mitad de
   su valor: **no ejecuta el puente**. Acá no hay Windows ni PowerShell, así que
   no se puede saber si el papel sale. Eso sólo se sabe en el local.

   Lo que sí comprueba es todo lo que, si se rompe, se rompe **en silencio** —
   y por eso vale la pena mirarlo desde acá:

     · que el archivo lleve BOM (sin él, PowerShell 5.1 lee las tildes como
       basura y el papel de prueba sale ilegible)
     · que la secuencia ESC/POS esté completa y EN ORDEN — el avance del papel
       ANTES del corte, o la cuchilla parte la última línea
     · que no haya quedado ni una mención a Zadig o WinUSB, que es la salida
       fácil que dejaría a Fudo sin imprimir
     · que el puente NUNCA borre filas de la cola
     · que no pida instalar nada

   Es una lectura del texto, no una ejecución. Vale menos que correrlo, y vale
   mucho más que no mirar nada. */
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const rutaPs = join(raiz, 'puente', 'Llamita-Impresora.ps1');
const crudo = readFileSync(rutaPs);
const ps = crudo.toString('utf8');

let ok=0, mal=0;
const caso = (n, fn) => {
  try { const r = fn(); if(r===true){ok++;console.log('  ✓ '+n);}
        else {mal++;console.log('  ✗ '+n+'  → '+r);} }
  catch(e){ mal++; console.log('  ✗ '+n+'  → '+e.message); }
};

console.log('\nLOS ARCHIVOS QUE SE LE ENTREGAN AL CLIENTE:');
caso('el programa está', () => existsSync(rutaPs) || 'falta el .ps1');
caso('y el doble clic que lo abre', () =>
  existsSync(join(raiz,'puente','Llamita Impresora.bat')) || 'falta el .bat');
caso('y el que sirve para cambiar la impresora', () =>
  existsSync(join(raiz,'puente','Configurar impresora.bat')) || 'falta el de configurar');
caso('NO se le pide instalar nada', () => {
  /* Node, npm o un "instalar.bat" son exactamente lo que se sacó: Windows ya
     trae PowerShell y .NET. Si alguien los vuelve a meter, esto avisa. */
  const sobra = ['nodejs.org','npm install','node_modules','instalar.bat']
    .filter(x => ps.includes(x));
  return sobra.length === 0 || 'volvió a pedir: ' + sobra.join(', ');
});

console.log('\n🔴 EL BOM · sin él las tildes salen como basura:');
caso('el .ps1 está guardado en UTF-8 con BOM', () =>
  (crudo[0]===0xEF && crudo[1]===0xBB && crudo[2]===0xBF)
  || 'no tiene BOM — PowerShell 5.1 lo va a leer como ANSI');
caso('y está dicho en el archivo, para que nadie lo saque sin querer', () =>
  ps.includes('BOM') || 'no queda explicado');

console.log('\nLA SECUENCIA ESC/POS:');
const pos = t => ps.indexOf(t);
caso('despierta la impresora (ESC @)', () => ps.includes('0x1B, 0x40') || 'falta el init');
caso('alinea a la izquierda', () => ps.includes('0x1B, 0x61, 0x00') || 'falta la alineación');
caso('avanza el papel', () => ps.includes('0x0A, 0x0A, 0x0A, 0x0A') || 'falta el avance');
caso('corta', () => ps.includes('0x1D, 0x56, 0x00') || 'falta el corte');
caso('🔴 y el AVANCE va ANTES del corte, no después', () => {
  /* Si se invierte, la cuchilla corta encima de la última línea y el ticket
     sale sin su pie.

     ⚠️ ESTE CASO NACIÓ MIRANDO EL LUGAR EQUIVOCADO. Buscaba `$AVANCE` y
     `$CORTE` en toda la función, y los encontraba en las líneas donde se
     DECLARAN —que están en ese orden siempre—, no en la línea que arma el
     papel. Al invertir el orden a propósito, seguía en verde. Ahora mira la
     línea del `return`, que es la única donde el orden significa algo. */
  const ret = (ps.match(/return \$ESC_INIT.*/) || [''])[0];
  if(!ret) return 'no encuentro la línea que arma el papel';
  const a = ret.indexOf('$AVANCE'), c = ret.indexOf('$CORTE');
  return (a > 0 && c > 0 && a < c) || 'el corte va antes del avance: ' + ret.trim();
});
caso('la traducción de acentos la hace .NET y no una tabla a mano', () =>
  ps.includes('GetEncoding') || 'volvió a una tabla escrita a mano');

console.log('\n🔴 LO QUE NO SE HACE, PASE LO QUE PASE:');
caso('ni una mención a Zadig o WinUSB', () => {
  /* Cambiarle el driver a la impresora dejaría que el navegador la tome — y
     con eso Fudo deja de imprimir. Es romper el servicio del café para ganar
     una comodidad nuestra. */
  const m = ['zadig','winusb','libusb'].filter(x => ps.toLowerCase().includes(x));
  return m.length === 0 || 'aparece: ' + m.join(', ');
});
caso('el puente NUNCA borra filas de la cola', () =>
  !/'DELETE'|Method\s+DELETE/i.test(ps) || 'hay un borrado');
caso('le PIDE a Windows con un trabajo RAW, no le quita el aparato', () =>
  ps.includes('"RAW"') || 'no usa el modo RAW del spooler');

console.log('\nLO QUE PASA CUANDO ALGO FALLA:');
caso('un papel que no sale queda marcado como error', () =>
  ps.includes("estado = 'error'") || 'un fallo se perdería sin dejar rastro');
caso('y deja escrito POR QUÉ', () => ps.includes('error = $motivo') || 'no guarda el motivo');
caso('si se cae la red, sigue intentando', () =>
  ps.includes('sigo intentando') || 'se rinde');
caso('y no repite el aviso cada tres segundos', () =>
  ps.includes('$avisoDeRed') || 'va a llenar la pantalla de ruido');

console.log('\nLA PRIMERA VEZ:');
caso('la impresora se elige de una LISTA, no se escribe a mano', () =>
  ps.includes('Elegir-De-Lista') && ps.includes('Listar-Impresoras')
  || 'hay que tipear el nombre exacto, que es donde se equivoca todo el mundo');
caso('y si no hay ninguna instalada, lo dice', () =>
  ps.includes('No encontre ninguna impresora') || 'se queda callado');
caso('las sedes se traen de Llamita, así sirve para otro café', () =>
  ps.includes('mesas?select=sede') || 'están escritas a mano');
caso('el arranque automático se PREGUNTA, no se impone', () =>
  ps.includes('Queres que arranque solo') || 'se mete solo en el arranque');

console.log(`\n${ok} bien · ${mal} mal`);
console.log('(que el papel salga se comprueba en el local, no acá)\n');
process.exit(mal ? 1 : 0);
