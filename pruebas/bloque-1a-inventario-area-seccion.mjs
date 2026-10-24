import fs from 'node:fs';

const html=fs.readFileSync(new URL('../index.html',import.meta.url),'utf8');
const migration=fs.readFileSync(new URL('../supabase/migrations/20261011143000_bloque_1a_inventario_area_seccion.sql',import.meta.url),'utf8');
let fallos=0;
const check=(nombre,ok)=>{console.log(`${ok?'✓':'✗'} ${nombre}`);if(!ok)fallos++;};

check('la pantalla de área conserva buscador y grupos históricos',
  html.includes("const tipoDe = p =>")&&html.includes("id=\"tipos\"")&&html.includes('renderAreaLista'));
check('los productos configurados con saldo cero son visibles',
  html.includes("r.configurado||Number(r.cantidad)!==0")&&html.includes('Configurado · sin existencias'));
check('las secciones físicas se agrupan por AM/PM solo visual',
  !html.includes('AM · organización visual')&&!html.includes('PM · organización visual'));
check('la ficha de área no habilita escritura de saldo',
  html.includes("const stockCortado=SEDE==='central'||SEDE==='plaza'")&&html.includes('producto_area_configuracion_guardar'));
const tablaSecciones=migration.split('create table public.area_secciones(')[1]?.split('comment on table public.area_secciones')[0]||'';
const lector=migration.split('create function stock_internal.leer_existencias_areas_plaza()')[1]?.split('create function public.stock_leer_areas()')[0]||'';
check('el esquema de configuración no contiene cantidades',
  !!tablaSecciones&&!/\bcantidad\b/.test(tablaSecciones));
check('las cantidades se leen del ledger y no de stock_actual',
  lector.includes('from stock_internal.existencias e')&&!lector.includes('stock_actual'));
check('las tablas de configuración quedan sin DML directo',
  migration.includes('revoke all on table public.area_secciones from public,anon,authenticated,service_role')&&
  migration.includes('revoke all on table public.producto_area_asignacion from public,anon,authenticated,service_role'));
check('el bloque no invoca transferencias ni escritores POS',
  !html.includes("sb.rpc('stock_transferir'")&&
  !migration.includes('fudo_')&&!migration.includes('lama_'));

if(fallos){console.error(`Fallaron ${fallos} verificaciones de Bloque 1A.`);process.exit(1);}
