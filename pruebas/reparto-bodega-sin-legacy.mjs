import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
import assert from 'node:assert/strict';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const html=readFileSync(join(raiz,'index.html'),'utf8');
const bloque=html.slice(html.indexOf('<div class="wrap" id="view-repcentral"'),html.indexOf('<!-- Resuelve una ruta incompleta'));
const inicioTab=html.indexOf('function pickTab(tab)');
const tab=html.slice(inicioTab,html.indexOf('/* ---------------- recetas',inicioTab));

assert.match(bloque,/<section class="f2-box" id="f2-preparar">/);
assert.match(bloque,/<select id="f2-area">/);
assert.match(bloque,/<div id="repc-salida" hidden>/);
assert.doesNotMatch(tab,/loadEnlaces\(\)\.then\(\(\)=>repcModo\('salida'\)\)/);
assert.match(tab,/if\(esEnvios\) f2CargarAreas\(\);/);
console.log('✓ Bodega muestra solo el reparto por áreas activas y no inicializa destinos legacy.');
