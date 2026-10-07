# Plan de implementación: inventario por áreas operativas en Llamita Plus

**Estado:** Bloque 0 completado como auditoría de solo lectura (2026-10-07). B1 permanece pendiente y no activa hasta resolver la fuente única de stock, el corte coordinado de escritores y los controles de acceso. Los Bloques 2 y 3 siguen inactivos.

**Repositorio objetivo:** `leoalejoleo1537/llamita-plus`, rama `master`.

**Límite permanente:** Café del Desierto / Llamita Stock queda completamente fuera de alcance. Toda simulación, migración, dato de prueba y cambio de aplicación descrito aquí corresponde exclusivamente a Llamita Plus.

## 1. Objetivo

Convertir el inventario de Llamita Plus en una vista por áreas operativas configurables dentro de cada sede. Cada área debe funcionar como un espacio de inventario propio: sus productos asignados, existencias, mínimos, movimientos y mermas deben poder consultarse dentro de esa área. La persona también debe poder consultar todas las áreas desde una vista general.

La primera configuración de prueba usará cuatro áreas: **Cocina fría, Cocina caliente, Barra de bar y Cafetería**. Se clasificarán productos existentes de Llamita Plus con reglas hipotéticas para probar la experiencia. La clasificación no representa una decisión operativa definitiva de Brunetti.

La arquitectura debe permitir que un mismo producto maestro exista en varias áreas con cantidades distintas. Por ejemplo, la búsqueda general de “leche” puede mostrar 5 unidades en Cocina, 12 en Cafetería, 1 en Barra y 3 en Cocina fría; dentro de Cafetería, el buscador debe mostrar solo el inventario de Cafetería.

## 2. Decisiones acordadas

1. Las áreas se configuran por sede. No se deducen de `tipo`, `rubro`, nombre de producto ni turno.
2. Las tarjetas de áreas son entradas a páginas completas. Al seleccionar Cocina fría, la persona entra a esa área y la pantalla de inventario queda acotada a ella.
3. El buscador dentro de un área busca solo en esa área. La vista global sigue disponible y agrupa el mismo producto por área con sus existencias.
4. Los productos mantienen una identidad maestra. No se crean copias como “Leche Cafetería” y “Leche Cocina” para representar existencias distintas.
5. No se automatiza ahora el descuento de stock desde Fudo ni desde recetas.
6. Se construirá la posibilidad de asociar una receta a un área de elaboración. Esa relación será metadato; no aplicará recetas a productos existentes ni ejecutará descuentos.
7. Las recetas existentes se conservan tal como están. Alejo creará productos y recetas nuevos para probar la asignación por área.
8. La recepción de reparto no asumirá que todo producto va a un área operativa. El destino se hará explícito y deberá admitir la bodega/sede existente o un área, según el flujo real que Codex confirme en el código.
9. La clasificación de prueba se guardará separada de `rubro` y `tipo`; esos campos no se reescriben para simular áreas.
10. No se aplican como reglas universales el flujo “Congelador → Vitrina” ni los turnos AM/PM. Son comportamientos heredados de Café del Desierto.

## 3. Reglas para la simulación inicial

La simulación usa el nombre y los campos descriptivos existentes para proponer una asignación. Debe mostrar qué regla asignó cada producto y dejar corregirla manualmente. Si un producto es ambiguo, queda **Sin asignar** para revisión. No se fuerza una clasificación solo para llenar todas las áreas.

| Regla prioritaria | Destino | Ejemplos / alcance |
|---|---|---|
| Bebidas calientes y productos de barra de café simple | Cafetería | Café, té, leches de uso de cafetería y bebidas de café. Una bebida fría de café puede requerir revisión si el nombre no permite distinguirla. |
| Tortas | Cafetería | Todas las tortas, incluyendo trozos, mientras el nombre permita identificarlas. |
| Preparaciones saladas | Cocina caliente | Panes, pizzas y sándwiches. |
| Helados y productos identificados como “ice” | Cocina fría | Aplicar solo cuando el nombre realmente identifique helado/producto frío; coincidencias ambiguas se revisan. |
| Ingredientes dulces | Cocina fría | Leche condensada, manjar/dulce de leche y otros ingredientes dulces identificables. |
| Bebidas gaseosas | Barra de bar | Coca-Cola, Sprite y otras bebidas gaseosas claramente identificables. |
| Otros productos | Sin asignar | Revisión manual; no inferir destino por una categoría incompleta. |

**Prioridad cuando hay conflicto:** aplicar la regla más específica. Por ejemplo, torta va a Cafetería aunque sea un producto frío; leche condensada/manjar va a Cocina fría, mientras la leche común destinada al flujo de cafetería va a Cafetería; café y té van a Cafetería, mientras una gaseosa va a Barra de bar. Si el nombre no resuelve el conflicto, dejar Sin asignar.

La clasificación inicial debe ser reproducible y auditable: guardar origen de asignación (por ejemplo, regla de simulación o asignación manual), permitir editarla y poder contar productos por área y pendientes. No modificar el nombre, stock, sede, `tipo` ni `rubro` como efecto secundario de asignar un área.

## 4. Arquitectura propuesta

La implementación debe modelar tres conceptos distintos:

- **Producto maestro:** qué producto es, con su identidad existente.
- **Área operativa:** dónde se controla dentro de una sede.
- **Existencia por producto y área:** cuánto hay de ese producto en esa área, con sus parámetros de control propios.

El diseño probable requiere una entidad para áreas por sede y otra relación producto-área con stock, unidad/parámetros necesarios y restricciones de unicidad. Los nombres y columnas definitivos se deciden después de revisar el esquema activo. No asumir que las tablas propuestas existen.

### Fuente única de stock

Antes de programar, Codex debe trazar todos los usos de `productos.stock_actual` y determinar cómo evitar dos fuentes simultáneas de verdad. No dejar `stock_actual` y el nuevo stock por área editables de forma independiente.

La migración debe ser aditiva, verificable y con una ruta de compatibilidad definida. Debe especificar cómo representa el stock histórico que todavía no tiene área: por ejemplo, conservarlo como inventario general/Sin asignar o migrarlo mediante una regla explícita aprobada. La simulación de clasificación no puede duplicar cantidades al presentar totales. Antes de cualquier migración de datos, Codex debe producir un resumen de origen, destino y conciliación por sede/producto.

Codex debe confirmar si área equivale a ubicación de stock, si lotes y vencimientos requieren área, cómo se identifica una existencia por sede, y qué pantallas o procesos escriben stock. No implementar una capa de áreas solo en la interfaz mientras las operaciones sigan descontando un stock ambiguo.

### Movimientos, lotes y reparto

- Una operación manual dentro de un área debe indicar el área y afectar solo la existencia de ese producto en esa área.
- Las mermas deben quedar ligadas al área donde ocurrieron para que los indicadores posteriores puedan discriminarla.
- Los registros históricos sin área mantienen su condición histórica; no asignarlos retroactivamente según las reglas de nombre sin autorización.
- Codex debe inspeccionar si los lotes/vencimientos pertenecen al producto o a la ubicación. Si una misma partida puede distribuirse entre áreas, la relación de lote debe permitir esa trazabilidad o documentar la limitación antes de implementarla.
- Para repartos, mantener el flujo actual de sede y permitir elegir destino por ítem cuando corresponda: bodega/sede o área. No trasladar automáticamente todos los ingresos a Cocina fría ni a otra área.
- Un traslado entre áreas, si el sistema ya lo soporta o se añade en esta fase, debe generar salida de un área y entrada en otra como una operación conciliada, conservando usuario, fecha y producto.

### Recetas

- Añadir en creación/edición de receta el campo “Área de elaboración” o equivalente, permitiendo elegir una de las áreas de la sede.
- Si la receta es nueva, su área puede guardarse y editarse para probar el flujo.
- No vincular automáticamente la receta a productos actuales, a Fudo, a ventas, a mermas ni al descuento de ingredientes.
- No alterar ni migrar recetas existentes. Una pantalla nueva puede mostrar “Sin área asignada” en las recetas históricas, pero no las asigna en lote.
- No usar esta primera versión para decidir cómo se descuenta café en grano u otros ingredientes no cuantificables. Esos conteos permanecen manuales.

## 5. Experiencia esperada

### Portada de Inventario

- Mostrar tarjetas navegables de Cocina fría, Cocina caliente, Barra de bar y Cafetería para la sede de prueba.
- Cada tarjeta presenta al menos cantidad de productos asignados y cantidad de productos críticos, calculados desde datos reales del modelo. La definición de “crítico” debe reutilizar la regla actual de mínimos si existe y Codex debe verificarla.
- Incluir entrada a “Todas las áreas” y a la lista de productos Sin asignar.
- Incluir una opción clara para administrar/agregar áreas por sede. Antes de crear Ajustes nuevos, inspeccionar si ya hay una sección de configuración adecuada.

### Página de un área

- Entrar a una página completa, con nombre del área y sede visibles.
- Mostrar únicamente productos con existencia/asignación a esa área.
- Buscador, rubros/secciones, filtros, conteos y acciones deben permanecer dentro del área seleccionada.
- Permitir asignar un producto maestro existente al área y definir su stock y parámetros de control para esa área.
- Permitir crear un producto nuevo y asignarlo a una o más áreas si el modelo actual admite producto compartido. Cada área mantiene su cantidad independiente.
- Preservar rutas de retorno y navegación, sin enlaces huérfanos.

### Vista global

- Mantener búsqueda global.
- Agrupar resultados por producto maestro y mostrar cada área con su cantidad, incluyendo cero o “sin asignar” según el comportamiento acordado.
- Al pulsar una línea de área, abrir el producto dentro de esa área.
- No sumar cantidades que pertenezcan a otra sede; respetar sede activa y permisos existentes.

## 6. Fases de trabajo para Codex

### Bloque 0 — Auditoría de áreas, sedes y Bodega

**Estado: COMPLETADO (solo lectura y documentación).** El informe `docs/hermes/13-auditoria-areas-sedes-bodega.md` registra esquema instalado, sedes, stock, lotes, escritores, reparto, mermas, Fudo, Lama, permisos, arquitectura recomendada y conciliación. No se cambió código, esquema ni datos.

Decisiones de negocio registradas: Local 1 (`plaza`) será el ensayo operativo, Local 2 (`angamos`) se archivará más adelante conservando historia, Bodega (`central`) es nodo logístico, las áreas serán configurables por sede, mermas siguen globales con área cuando corresponda, las clasificaciones son editables, la distribución identifica destino por línea y una sede futura solo copia configuración aprobada. Local 1 no es aislamiento técnico: comparte proyecto y políticas de datos permisivas.

**Salida:** mantener B1 pendiente. Antes de habilitar stock de área se deben decidir autoridad única, corte de escritores, tratamiento de saldo sin asignar y controles de acceso. La selección de Local 1 no autoriza migrar ni clasificar stock.


La cola tendrá una sola fase activa. Las tres ventanas sugeridas son **12:00, 14:00 y 17:00 hora de Santiago**, cada una para un bloque independiente. Si el bloque previo no terminó o dejó una decisión pendiente, el siguiente no empieza y registra el bloqueo. Codex no activa por su cuenta la fase siguiente.

### Bloque 1 — Verificación, modelo y preparación de datos

**Objetivo:** comprobar la arquitectura real y dejar lista la base segura para las áreas.

1. Leer `CLAUDE.md`, las reglas de `docs/hermes/` y documentación relevante.
2. Trazar el inventario actual: producto, stock por sede, secciones/rubros, movimientos, mermas, lotes, reparto, permisos, búsqueda y rutas.
3. Verificar contra el esquema activo de Llamita Plus las tablas y columnas necesarias. No conectarse ni escribir en Café del Desierto.
4. Entregar un mapa de dependencias y decidir la fuente única del stock por área, la migración de stock histórico, el tratamiento de Sin asignar y la relación de lotes/repartos.
5. Si el mapa confirma el diseño sin decisiones pendientes, implementar la migración aditiva y la gestión básica de áreas por sede. Si una cuestión de datos no se puede resolver de manera segura, detenerse antes de aplicar migración y documentar la decisión requerida.
6. Crear las cuatro áreas solo en el contexto de prueba acordado de Llamita Plus. No crear áreas en todas las sedes sin confirmación de los datos y del alcance.
7. Preparar una vista previa de clasificación con las reglas de la sección 3; asignar coincidencias claras y dejar ambiguas en Sin asignar. Guardar procedencia de la regla.
8. Conciliar conteos y cantidades antes/después por sede y producto. No duplicar stock ni alterar movimientos históricos.

**Criterios de salida:** arquitectura documentada; migración aplicada o SQL listo según autorización y capacidad; datos conciliados; CRUD/configuración de áreas funcional; clasificación visible y corregible; pruebas del modelo y permisos; resumen antes de pasar al Bloque 2.

### Bloque 2 — Portada, páginas de área, productos y búsquedas

**Objetivo:** hacer que la navegación refleje áreas sin perder inventario global.

1. Construir la portada de Inventario con tarjetas por área, conteos y críticos.
2. Construir la página completa de cada área y conservar navegación de ida y vuelta.
3. Acotar búsqueda, conteos, rubros/filtros y listados al área abierta.
4. Implementar “Todas las áreas” con agrupación por producto y cantidades por área.
5. Agregar la asignación de un producto existente a una o más áreas y el alta de productos con asignación inicial a área. No duplicar la identidad maestra.
6. Mantener Sin asignar visible y corregible. La lista general no puede desaparecer ni quedar inaccesible desde un enlace antiguo.
7. Validar sede activa, roles y acceso directo a rutas de áreas.

**Criterios de salida:** búsquedas aisladas y globales correctas; un producto puede tener cantidades independientes en varias áreas; no se filtra información de otra sede; tarjetas reflejan datos; pruebas de navegación, permisos y datos vacíos.

### Bloque 3 — Operaciones, mermas, repartos, recetas y cierre

**Objetivo:** conectar las operaciones de inventario con el área correcta y dejar la receta lista como metadato.

1. Actualizar conteo manual, ajuste y registro de merma para exigir/usar el área cuando se opera desde una página de área.
2. Conservar movimientos históricos sin área y mostrarlos como históricos/globales sin atribuirlos falsamente a una zona.
3. Adaptar mínimos/críticos y reportes básicos para calcularlos por área, sin contar dos veces el mismo producto.
4. Revisar recepción de reparto y permitir el destino correcto por ítem según las capacidades actuales: bodega/sede o área operativa. No cambiar el destino predeterminado hasta verificar el flujo existente.
5. Implementar transferencias entre áreas solo si el análisis confirma que el modelo actual permite registrar ambos lados de forma atómica y auditable; si requiere otra fase, documentarlo y no simular el movimiento.
6. Añadir el campo de área de elaboración a creación/edición de recetas nuevas. Mantener recetas existentes intactas y sin asignación masiva.
7. Confirmar que no hay llamadas de descuento de receta, Fudo/POS ni stock automático relacionadas con esa metadata.
8. Ejecutar pruebas de integración, regresión de inventario general, conciliación por sede/área, datos sin asignar, errores de red y modos de demostración.
9. Actualizar `CLAUDE.md` en un capítulo específico de Llamita Plus y la documentación del plan/bitácora con comportamiento final y límites.

**Criterios de salida:** mermas y conteos asociados a la zona correcta; recetas con metadato editable y sin efectos automáticos; reparto no ambiguo; regresiones clave aprobadas; documentación y bitácora actualizadas; despliegue de Llamita Plus revisado.

## 7. Pruebas de aceptación globales

1. La sede de prueba muestra cuatro áreas configurables; otra sede no recibe esas áreas por accidente.
2. Una misma leche puede tener existencias independientes en Cocina fría, Cafetería y otras áreas.
3. Dentro de Cafetería, buscar “leche” no muestra las existencias de las otras áreas.
4. En “Todas las áreas”, “leche” muestra una sola identidad de producto con cantidades separadas por área y sede.
5. Coca-Cola y Sprite se proponen para Barra de bar; café, té, leche común y tortas para Cafetería; panes, pizzas y sándwiches para Cocina caliente; leche condensada/manjar e ingredientes dulces identificables para Cocina fría.
6. Los nombres ambiguos permanecen Sin asignar y se pueden corregir manualmente.
7. La asignación no altera `rubro`, `tipo`, nombres, sedes, ventas o movimientos anteriores.
8. Una merma registrada dentro de Cocina fría reduce únicamente el inventario de ese producto allí y queda identificada con su área.
9. Una receta nueva puede asociarse a Cafetería y guardarse. Una receta antigua no cambia, y guardar la nueva no descuenta stock ni invoca Fudo.
10. La recepción de un reparto exige un destino inequívoco y conserva compatibilidad con el flujo de bodega/sedes vigente.
11. Un producto Sin asignar y un área vacía tienen una presentación utilizable, sin tablas rotas ni conteos falsos.
12. No hay cambio ni consulta sobre el proyecto de Café del Desierto / Llamita Stock.

## 8. Riesgos y controles

| Riesgo | Control previsto |
|---|---|
| Dos fuentes de stock (`stock_actual` y stock por área) | Definir una sola autoridad, conciliación antes/después y pruebas de no duplicación. |
| Cambiar stock histórico al asignar áreas | Migración auditada; no atribuir movimientos antiguos por heurística. |
| Búsqueda o total que mezcla áreas/sedes | Filtros explícitos de sede y contexto de área; pruebas con productos repetidos. |
| Clasificación incorrecta por palabras ambiguas | Precedencia documentada, origen visible, lista Sin asignar y corrección manual. |
| Lotes sin ubicación | Inspección en Bloque 1; modelar destino o dejar explícito el límite antes de recibir cambios de stock. |
| Recetas disparan descuentos no deseados | Campo solo metadato; pruebas que confirmen ausencia de llamadas a Fudo/POS o mutaciones de stock. |
| Repartos no distinguen bodega y áreas | Destino obligatorio por ítem cuando corresponda; mantener compatibilidad con sede actual. |
| Cambio de áreas rompe la vista de Café del Desierto | No tocar ese repo/base; no reutilizar lógica organizacional como regla universal. |

## 9. Publicación y registro

- Cada bloque autorizado termina con resumen, archivos, migraciones, pruebas, riesgos y commit.
- El destino normal de publicación es `master` de Llamita Plus, de acuerdo con la autorización de trabajo ya dada por Alejo.
- Un fallo de pruebas o una decisión de datos abierta detiene el bloque; no se presenta como completo.
- Codex registra el resultado en `docs/hermes/04-bitacora-codex.md` y deja la cola en un estado que impida repetir o saltar fases.
- El usuario revisa el resultado visible en Llamita Plus antes de activar el bloque siguiente.

## 10. Pendientes antes de B1

1. Definir la fuente única de stock y la secuencia de corte que adapte todos los escritores antes de crear saldos editables por área.
2. Definir controles de acceso por sede/área; Local 1 es el ensayo elegido, pero no una frontera de aislamiento en el esquema actual.
3. Aprobar cómo se representa el stock que no ha sido contado o transferido físicamente: debe permanecer sin asignar, sin duplicar.
4. Diseñar destino por línea, origen y atomicidad para reparto Bodega→área, incluyendo unidad/factor y lote/vencimiento.
5. Especificar cómo se reconcilian identidad de producto, stock mínimo/máximo y lotes por ubicación.
6. Confirmar qué partes de Fudo/Lama permanecen como escritoras durante cada etapa; no activarlas sobre saldos nuevos sin adaptación.
7. Definir archivo operativo de Local 2 preservando IDs, cantidades e historial; no borrar ni transferir stock por heurística.

Los hechos actuales y la recomendación están en `docs/hermes/13-auditoria-areas-sedes-bodega.md`. Estas preguntas no autorizan cambios de aplicación, SQL, migración ni datos.

Estas verificaciones no son permiso para abrir alcance hacia Café del Desierto, ejecutar operaciones destructivas o automatizar el descuento de recetas.
