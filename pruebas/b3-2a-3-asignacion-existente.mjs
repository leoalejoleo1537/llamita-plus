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
check('cada área permite agregar una ficha existente y crear una nueva por separado',
  html.includes('data-area-assign=')&&html.includes('Agregar producto existente')&&html.includes('Crear producto nuevo'));
check('la asignación escribe únicamente mediante la RPC protegida',
  html.includes("sb.rpc('producto_area_preferencia_guardar'")&&html.includes('function guardarProductoEnArea()'));
check('el buscador cubre nombre, ID, sección y categoría',
  html.includes('[p.producto,p.id,p.rubro,p.tipo]')&&html.includes('Nombre, ID, sección o categoría'));
check('el detalle distingue preferencia de ubicación y saldo físico',
  html.includes('Área preferida actual:')&&html.includes('Ubicación física actual:')&&html.includes('Las existencias no se moverán.'));
check('un duplicado abre Usar existente y no crea una copia',
  html.includes("abrirAsignarProducto(destino,dup.id,true)")&&html.includes("duplicado?'Este producto ya existe'"));
check('el selector de área se alimenta solo del catálogo operativo',
  html.includes("AREAS_CATALOGO.filter(a=>a.estado==='activa')")&&html.includes('Sin asignar</option>'));
check('las clasificaciones heredadas se explican por separado',
  html.includes('Limpieza, Vitrina y Sándwiches son secciones o categorías de producto'));
check('el flujo no invoca transferencias, Fudo, lotes ni movimientos',
  !html.slice(html.indexOf('function guardarProductoEnArea()'),html.indexOf('function gestionarAreas()')).match(/stock_transferir|functions\.invoke|producto_lotes|movimientos/));

if(failures.length){console.error(`Fallaron ${failures.length} verificaciones B3.2a.3.`);process.exit(1);}
