import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const html=readFileSync(join(raiz,'index.html'),'utf8');
const fallas=[];
const check=(nombre,ok)=>{console.log(`${ok?'✓':'✗'} ${nombre}`);if(!ok)fallas.push(nombre);};

const area=html.slice(html.indexOf('function renderAreaTipoPills()'),html.indexOf('/* Normaliza texto para buscar'));
const ficha=html.slice(html.indexOf('async function openModal(id)'),html.indexOf('/* ---------------- urgente'));
const guardado=html.slice(html.indexOf("$('m-guardar').addEventListener('click'"),html.indexOf('/* Reemplaza los lotes'));

check('Las píldoras reutilizan los tipos existentes y los productos presentes en área/ledger',
  area.includes('AREA_ROWS.filter')&&area.includes('r.tipo')&&area.includes('data-area-tipo'));
check('Las secciones de área usan los acordeones históricos y AM/PM es solo agrupación visual',
  area.includes('class="sec')&&area.includes('class="sec-btn"')&&area.includes('AM · organización visual')&&area.includes('PM · organización visual')&&area.includes('data-secname="${esc(clave)}"'));
check('Productos configurados con saldo cero aparecen identificados sin confundirse con existencias',
  area.includes('Configurado · sin existencias')&&area.includes('r.configurado||Number(r.cantidad)!==0'));
check('Saldo de fila viene del ledger y queda no editable',
  area.includes('stock_actual:cantidad')&&area.includes('disabled title="Saldo de solo lectura: ledger por ubicación"')&&html.includes("sb.rpc('stock_leer_areas'"));
check('La fila histórica abre el modal con el registro exacto de área',
  html.includes('data-area-code="${esc(r.area_codigo)}"')&&html.includes('AREA_ROWS.find(r=>String(r.producto_id)===String(info.dataset.open)&&r.area_codigo===info.dataset.areaCode)'));
check('La ficha de área muestra ubicación, sección, límites, saldo y vencimientos sin controles de stock',
  ficha.includes('m-area-ficha-resumen')&&ficha.includes('Saldo físico')&&ficha.includes('Sección física')&&ficha.includes('Vencimientos')&&ficha.includes("m-stock-field').style.display=fichaArea?'none'"));
check('Guardar desde área solo usa la RPC de configuración, nunca saveFields ni productos.stock_actual',
  guardado.indexOf("sb.rpc('producto_area_configuracion_guardar'")<guardado.indexOf('const nombre=')&&guardado.slice(0,guardado.indexOf('const nombre=')).includes("SEDE==='plaza'&&MODAL_AREA_ROW"));
check('La vista no reintroduce editor de stock, mermas, lotes ni Fudo en la ficha de área',
  ficha.includes("$('m-mermar').style.display = fichaArea?'none':'flex'")&&ficha.includes("$('m-venc-field').style.display = conVenc&&!fichaArea ? 'block' : 'none'")&&ficha.includes("$('m-fudo').style.display=fichaArea?'none'"));
check('El gesto legacy de reparto/merma no se activa sobre filas de Local 1',
  html.includes("if(SEDE==='plaza'&&areaActual!==null) return;   // las áreas son de lectura"));

if(fallas.length){console.error(`Fallaron ${fallas.length} verificaciones B2.`);process.exit(1);}
