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
  html.includes("sb.rpc('panel_producto_area_configurar'")&&html.includes('function guardarProductoEnArea()'));
check('la búsqueda consulta el catálogo maestro y tolera variaciones del lado servidor',
  html.includes("sb.rpc('bodega_productos_area_buscar'")&&html.includes('normNombre(q).length<2'));
const flujoSimple=html.slice(html.indexOf('/* Presentación simplificada del alta'),html.indexOf('async function elegirRepresentacionBodega'));
check('el flujo visible oculta IDs, factores y opciones irrelevantes',
  flujoSimple.includes('Stock disponible en Bodega:')&&!flujoSimple.includes('ID de Bodega:')&&!flujoSimple.includes('factor ')&&!flujoSimple.includes('Local 1 #'));
check('una única representación enlazada se reutiliza automáticamente',
  html.includes("else if(reps.length===1){\n    BODEGA_AREA_REP_ID=String(reps[0].producto_plaza_id)"));
check('si falta representación ofrece creación con saldo cero y sin mover stock',
  flujoSimple.includes('representación vinculada en Local 1 con saldo cero')&&flujoSimple.includes('Agregarlo al área no mueve existencias.'));
check('el detalle mantiene sección y límites por área con confirmación humana para candidatos',
  flujoSimple.includes('Confirmar que corresponde al mismo producto')&&flujoSimple.includes('area-producto-seccion')&&flujoSimple.includes('area-producto-min')&&flujoSimple.includes('area-producto-max'));
check('candidatos ya enlazados a otro maestro no se exponen',
  html.slice(html.indexOf('function candidatasLocalesRelevantes'),html.indexOf('function renderDetalleProductoBodegaLegacy')).includes('if(r.vinculada_a_bodega_id!=null) return false'));
check('el flujo no invoca transferencias, Fudo, lotes ni movimientos',
  !html.slice(html.indexOf('function guardarProductoEnArea()'),html.indexOf('function gestionarAreas()')).match(/stock_transferir|functions\.invoke|sb\.from\(['"](?:producto_lotes|stock_internal)/));
check('el selector de área se alimenta solo del catálogo operativo',
  html.includes("AREAS_CATALOGO.filter(a=>a.estado==='activa')")&&html.includes('Sin asignar</option>'));
check('se mantiene el selector de áreas de catálogo para el formulario general',
  html.includes("AREAS_CATALOGO.filter(a=>a.estado==='activa')"));

if(failures.length){console.error(`Fallaron ${failures.length} verificaciones B3.2a.3.`);process.exit(1);}
