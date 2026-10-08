import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const html=readFileSync(join(raiz,'index.html'),'utf8');
const migration=readFileSync(join(raiz,'supabase/migrations/20261008193000_b3_2a_2_lectura_dinamica_areas.sql'),'utf8');
const failures=[];
const check=(name,ok)=>{console.log(`${ok?'✓':'✗'} ${name}`);if(!ok)failures.push(name);};

check('la interfaz ya no contiene una lista fija AREA_ORDEN_UI',!html.includes('AREA_ORDEN_UI'));
check('la navegación combina catálogo dinámico y lectura del ledger',html.includes("sb.rpc('areas_operativas_listar'")&&html.includes("sb.rpc('stock_leer_areas'"));
check('Ajustes usa solo RPC protegidas para áreas',['area_operativa_crear','area_operativa_editar','area_operativa_archivar'].every(x=>html.includes(`sb.rpc('${x}'`)));
check('las altas normales de plaza usan producto_plaza_crear',html.includes("sb.rpc('producto_plaza_crear'"));
check('la preferencia usa lectura y escritura protegidas',html.includes("sb.rpc('producto_area_preferencia_leer'")&&html.includes("sb.rpc('producto_area_preferencia_guardar'"));
check('la interfaz distingue preferencia y saldo físico',html.includes('Cambiar esta preferencia no mueve unidades.')&&html.includes('Ubicación física actual'));
check('el lector SQL acepta cualquier área activa vinculada',migration.includes("u.area_id is not null and a.id is not null")&&!migration.includes("u.codigo in ('cocina_fria'"));
check('la RPC de preferencia exige sesión/capacidad y queda solo para authenticated',migration.includes("exigir_capacidad_b3_2a('lectura')")&&migration.includes('grant execute on function public.producto_area_preferencia_leer(bigint,text)\n  to authenticated'));
check('el bloque no escribe existencias ni movimientos',!migration.match(/insert\s+into\s+stock_internal\.(existencias|movimientos)/i)&&!migration.match(/update\s+stock_internal\.(existencias|movimientos)/i));
check('los flujos enlazados de Bodega siguen presentes',html.includes("sb.rpc('crear_producto_enlazado'")&&html.includes("if(SEDE==='central'){ pickTab('enlaces')"));

if(failures.length){console.error(`Fallaron ${failures.length} verificaciones.`);process.exit(1);}
