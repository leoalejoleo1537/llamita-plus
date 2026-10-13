import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const html=readFileSync(join(raiz,'index.html'),'utf8');
const failures=[];
const check=(name,ok)=>{console.log(`${ok?'✓':'✗'} ${name}`);if(!ok)failures.push(name);};

check('Inventario ofrece Gestionar áreas solo con puede_ajustes',
  html.includes("PERMISOS.puede_ajustes?'<button type=\"button\" class=\"area-manage\" data-area-manage>Gestionar áreas</button>'"));
check('el acceso secundario abre la sección protegida existente de Ajustes',
  html.includes("ajActual='areas'; pickTab('ajustes')"));
check('cada área ofrece agregar el producto maestro de Bodega, no crear un producto local aislado',
  html.includes('data-area-assign=')&&html.includes('Agregar producto de Bodega')&&!html.includes('Crear producto nuevo'));
check('la incorporación escribe vínculo y configuración mediante la RPC protegida',
  html.includes("sb.rpc('bodega_producto_area_agregar'")&&html.includes('function guardarProductoEnArea()'));
check('la búsqueda consulta el catálogo maestro y tolera variaciones del lado servidor',
  html.includes("sb.rpc('bodega_productos_area_buscar'")&&html.includes('Producto maestro · Bodega #'));
check('el detalle presenta saldo de Bodega, representaciones y ubicaciones ledger locales',
  html.includes('Stock disponible en Bodega:')&&html.includes('Representación en Local 1')&&html.includes('Sin saldo físico en Local 1'));
check('las representaciones locales requieren selección explícita y admiten sección y límites',
  html.includes('El sistema no selecciona por nombre')&&html.includes('area-producto-seccion')&&html.includes('area-producto-min')&&html.includes('area-producto-max'));
check('una ficha local exacta duplicada no se crea aislada',
  html.includes('Ya existe una ficha con ese nombre en Local 1')&&html.includes('Agregar producto de Bodega'));
check('el flujo no invoca transferencias, Fudo, lotes ni movimientos',
  !html.slice(html.indexOf('function guardarProductoEnArea()'),html.indexOf('function gestionarAreas()')).match(/stock_transferir|functions\.invoke|sb\.from\(['"](?:producto_lotes|stock_internal)/));
check('el selector de área se alimenta solo del catálogo operativo',
  html.includes("AREAS_CATALOGO.filter(a=>a.estado==='activa')")&&html.includes('Sin asignar</option>'));
check('se mantiene el selector de áreas de catálogo para el formulario general',
  html.includes("AREAS_CATALOGO.filter(a=>a.estado==='activa')"));

if(failures.length){console.error(`Fallaron ${failures.length} verificaciones B3.2a.3.`);process.exit(1);}
