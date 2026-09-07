/* Un papel de prueba, sin tocar la base. Si esto sale, el puente sirve.
   Se prueba SOLO la mitad difícil —hablarle a la impresora— porque es la
   única que puede fallar en el local. */
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const aqui = dirname(fileURLToPath(import.meta.url));
const cfg = JSON.parse(readFileSync(join(aqui,'config.json'),'utf8'));
import { imprimirPrueba } from './imprimir.mjs';
console.log('Mandando un papel de prueba a:', cfg.impresora);
try { imprimirPrueba(cfg); console.log('\n✓ Se mandó. Si salió el papel, está listo.'); }
catch(e){ console.log('\n✗ No salió:', String(e.stderr || e.message || e).split('\n')[0]); }
