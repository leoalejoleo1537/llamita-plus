# Cola de trabajo de Codex

Estado actual: **A3.2 activa — captura protegida del cierre Lama en modo apagado/prueba**. A3.3–A3.4 y B1 de áreas permanecen pendientes.

Este archivo se utiliza como una cola explícita. Codex debe leerlo antes de cada ejecución programada.

## Reglas de lectura

- Si no existe una tarea marcada como `ACTIVA`, no modificar código ni base de datos.
- Ejecutar únicamente la tarea marcada como `ACTIVA`.
- Respetar el alcance, archivos permitidos y criterios de salida de esa tarea.
- Al finalizar, actualizar `04-bitacora-codex.md` y cambiar la tarea a `COMPLETADA`, `BLOQUEADA` o `REQUIERE DECISIÓN`.
- No activar por cuenta propia la tarea siguiente.
- No ejecutar SQL ni migraciones salvo que la tarea lo autorice explícitamente.
- Leer `docs/hermes/06-canal-hermes-codex.md` antes de comenzar y responder allí el resultado arquitectónico.

## Plantilla de tarea

### Tarea [ID] — [nombre]

- Estado: `PENDIENTE` | `ACTIVA` | `COMPLETADA` | `BLOQUEADA` | `REQUIERE DECISIÓN`
- Autorización: [quién y cuándo la aprobó]
- Objetivo:
- Contexto y documentos que leer:
- Alcance permitido:
- Fuera de alcance:
- Archivos o migraciones esperadas:
- Criterios de aceptación:
- Pruebas requeridas:
- Publicación: [sin push | push a master autorizado]
- Riesgos conocidos:

### Tarea B1 — Verificación, modelo y preparación de datos

- Estado: REQUIERE DECISIÓN
- Autorización: Alejo aprobó el plan de áreas operativas y autorizó iniciar el Bloque 1.
- Objetivo: verificar la arquitectura real de inventario por áreas y preparar una base aditiva, segura y conciliada para Llamita Plus.
- Contexto: trabajar únicamente en Llamita Plus. Café del Desierto / Llamita Stock queda fuera de alcance.
- Documentos obligatorios: CLAUDE.md, README.md, docs/hermes/00-reglas-operativas.md, docs/hermes/01-plan-areas-operativas.md y la documentación relevante de docs/.
- Alcance permitido: inspección de código y esquema; mapa de dependencias; definición de fuente única de stock; migración aditiva solo si es segura; áreas de prueba en contexto seguro; clasificación simulada; conciliaciones; pruebas; actualización de bitácora.
- Fuera de alcance: Bloques 2 y 3; rediseño de UI; automatización de descuentos desde recetas/Fudo; cualquier cambio en Café del Desierto.
- Clasificación de prueba: gaseosas a Barra de bar; café, té, leche común y tortas a Cafetería; panes, pizzas y sándwiches a Cocina caliente; helados, productos “ice”, leche condensada, manjar e ingredientes dulces a Cocina fría; ambiguos a Sin asignar.
- Criterios de aceptación: arquitectura documentada; no existen dos fuentes editables de stock; no se duplican cantidades; productos y asignaciones son corregibles; datos y permisos verificados; pruebas ejecutadas; bitácora actualizada.
- Publicación: push a master autorizado si la fase termina y las pruebas son satisfactorias. Si hay una decisión crítica abierta, detenerse y registrar BLOQUEADO o REQUIERE DECISIÓN.
- Riesgos conocidos: stock histórico sin área, lotes sin ubicación, clasificación ambigua, falta de un contexto de datos aislado y corte de fuente única pendiente.
- Resultado de preflight (2026-10-06): repositorio sincronizado por fast-forward hasta `c5cc8d6`; `work` coincide con `origin/master` y el árbol está limpio. Se confirmó por lectura que Supabase `iuryhsjucblmebdogewa` es `llamita-plus`.
- Bloqueos: no existe un contexto aislado de datos de demostración; `modo_demostracion` solo cambia la presentación y las sedes existentes tienen datos. También falta acordar un corte de stock único que incluya todos los escritores actuales antes de habilitar existencias independientes por área.
- Cambios en código, esquema y datos: ninguno. No activar B2.

### Tarea A1 - Auditoría de integración Fudo y Llamita Lama

- Estado: COMPLETADA
- Autorización: Alejo aprobó iniciar la primera parte del plan el 2026-10-06.
- Objetivo: auditar la integración Fudo ya existente, el módulo Llamita Lama y sus conexiones reales con recetas, ventas, caja e inventario antes de diseñar stock por áreas.
- Documentos obligatorios: `CLAUDE.md`, `README.md`, `docs/LAMA.md`, `docs/fudo-api-cuanto-sirve.md`, `docs/atlas-fudo.md`, `docs/hermes/00-reglas-operativas.md` y `docs/hermes/06-canal-hermes-codex.md`.
- Alcance permitido: lectura del repositorio; lectura del esquema autorizado de Llamita Plus; mapa de componentes, funciones, tablas, permisos, sincronizaciones y puntos de lectura/escritura; propuesta de contrato común.
- Fuera de alcance: cambios de código; SQL o migraciones; inserciones/actualizaciones/borrados; cambios de UI; activación de áreas; cambios en modo demostración; cualquier acceso a Café del Desierto.
- Criterios de aceptación: respuesta en `06-canal-hermes-codex.md`; bitácora actualizada; hechos e inferencias separados; Fudo existente distinguido de Lama futuro; función de pagos/caja separada de evento de inventario; riesgos y decisiones pendientes explícitos.
- Pruebas requeridas: solo consultas y verificaciones de lectura; `git diff --check`; no se requieren pruebas de aplicación porque no se modifica código.
- Publicación: push a `master` autorizado para esta actualización documental, sin cambios de aplicación, esquema ni datos.
- Riesgos conocidos: documentación histórica que podría no coincidir con el esquema vigente; funciones Fudo visibles solo bajo permisos; múltiples escritores de `productos.stock_actual`; ausencia de stock por área.
- Resultado (2026-10-06): auditoría documentada en `docs/hermes/06-canal-hermes-codex.md`. Se confirmó Fudo operativo con recetas, espejo, modo prueba/real e idempotencia por ítem; Lama tiene mesas, comandas, cobros, anulaciones y arqueos, pero todavía no descuenta inventario. Quedan decisiones sobre el momento de descuento, anulaciones, versionado de recetas y contrato común.
- Cambios en código, esquema y datos: ninguno. No activar B1 ni el puente Lama→inventario hasta resolver las decisiones pendientes.

### Tarea A2 - Contrato común: venta, receta e inventario

- Estado: COMPLETADA
- Autorización: Alejo aprobó iniciar A2 el 2026-10-06, después de revisar la auditoría A1.
- Objetivo: producir una especificación implementable para que Fudo existente, Llamita Lama y un futuro Toteat puedan entregar eventos al mismo motor de inventario, sin mezclar pagos/caja con consumo físico.
- Documentos obligatorios: `CLAUDE.md`, `docs/LAMA.md`, `docs/fudo-api-cuanto-sirve.md`, `docs/hermes/00-reglas-operativas.md`, `docs/hermes/05-decisiones-pendientes.md` y `docs/hermes/06-canal-hermes-codex.md`.
- Decisiones ya tomadas: el **cierre de mesa** de Lama es el único disparador de descuento de inventario de sus líneas; el método de pago, propina, cobro parcial o caja no cambian esa regla. La venta local debe tener identidad propia de Llamita; la receta histórica debe poder reconstruirse; por operación solo habrá un origen POS activo por sede (Fudo, Lama o Toteat), sin perjuicio de la deduplicación de reintentos dentro de cada origen; los precios deben tener su propio modelo y la línea vendida debe conservar el precio aplicado.
- Pregunta principal pendiente: definir el tratamiento exacto de confirmaciones/comandas previas al cierre, anulaciones antes y después del cierre, consumo interno y reversas.
- Alcance permitido: inspección de lectura adicional estrictamente necesaria; matriz de decisiones; modelo de eventos y estados; diseño de identidad de productos; diseño de receta versionada o instantánea; estrategia de deduplicación; plan de migración de `stock_actual` a stock por área; especificación de precios/instantánea de precio; actualización documental.
- Fuera de alcance: código de aplicación, SQL/migraciones, inserciones/actualizaciones/borrados, activación de conectores, cambio de modo demostración, creación de áreas, cambios en Café del Desierto.
- Entregables: `docs/hermes/07-contrato-comun-inventario.md` nuevo; respuesta/resumen en `06-canal-hermes-codex.md`; bitácora actualizada; propuesta de fases de implementación y criterios de prueba.
- Criterios de aceptación: separar hechos de decisiones; no plantear doble fuente de stock; definir comportamiento de reversa sin borrado histórico; explicar compatibilidad con Fudo existente y Toteat futuro; dejar las decisiones que sigan abiertas listas para que Alejo elija.
- Pruebas requeridas: verificaciones de lectura y `git diff --check`; no se requieren pruebas de aplicación.
- Publicación: push a `master` autorizado solo para documentación de A2. Sin cambios de aplicación, esquema ni datos.
- Resultado (2026-10-06): contrato documentado en `docs/hermes/07-contrato-comun-inventario.md`; canal y bitácora actualizados. Se fija cierre de mesa de Lama como disparador único, idempotencia por origen, receta/precio históricos y transición a ledger producto-área sin doble saldo.
- Pendientes: identidad canónica, permisos de reversa, consumos internos, snapshot de receta, errores parciales, unidades/redondeo y ventana de corte por sede. No activar B1 ni implementar el puente hasta aprobación.

### Tarea A3.1 - Cimientos del puente Lama → Stock

- Estado: COMPLETADA
- Autorización: Alejo aprobó iniciar los bloques A3 el 2026-10-06 y confirmó que la mesa/caja deben cerrar aunque falle inventario.
- Objetivo: crear únicamente la base aditiva, segura e idempotente para eventos y aplicaciones de inventario, sin conectarla todavía al cierre de mesas ni escribir stock.
- Documento obligatorio: `docs/hermes/08-plan-implementacion-puente-lama-stock.md` completo, además de las reglas, contrato A2 y documentación Lama/Fudo relevante.
- Alcance permitido: inspección final; documentación vigente de Supabase; migración versionada; tablas, constraints, índices, estados, RLS/permisos, pruebas de estructura e idempotencia; aplicación de la migración solo en Supabase Llamita Plus verificado si es segura.
- Fuera de alcance: cambios en UI; `cuenta_cobrar`, `cuenta_cerrar`, `item_anular`; escritura de stock; modificación de recetas/datos/ventas; funciones o secretos Fudo; áreas; Café del Desierto.
- Criterios de aceptación: esquema aditivo y reversible; modo efectivo apagado; sin mutación de ventas/stock; RLS y grants revisados; idempotencia probada; rollback documentado; pruebas y limitaciones registradas.
- Publicación: commit y push a `master` autorizados si las verificaciones pasan. No activar A3.2.
- Regla de detención: cualquier duda de identidad de repositorio/proyecto, firma existente, seguridad, colisión de nombres o migración no reversible cambia el estado a `REQUIERE DECISIÓN` sin ejecutar cambios.
- Resultado (2026-10-06): migración `a3_1_cimientos_lama_stock` aplicada únicamente en Supabase `llamita-plus`. Se crearon los cimientos aditivos con RLS, permisos directos revocados, modo efectivo apagado y claves únicas de idempotencia. Pruebas estructurales y transaccionales correctas; ventas, recetas, productos y stock sin cambios.
- Archivos: `sql/2026-10-a3-1-cimientos-lama-stock.sql` y rollback `sql/2026-10-a3-1-cimientos-lama-stock.rollback.sql`. No activar A3.2.

### Tarea A3.2 - Captura protegida del cierre Lama

- Estado: ACTIVA
- Autorización: Alejo aprobó continuar los bloques A3 después de completar A3.1; Hermes revisó la migración aplicada y no encontró un bloqueo para captura en modo apagado/prueba.
- Objetivo: hacer que los cierres de Lama creen eventos idempotentes y snapshots de sus líneas cuando el modo sea `prueba`, sin modificar stock y sin permitir que un fallo de inventario impida cerrar la mesa o registrar caja.
- Documentos obligatorios: `docs/hermes/08-plan-implementacion-puente-lama-stock.md`, contrato A2, reglas operativas, documentación Lama y resultado A3.1.
- Alcance permitido: migración aditiva; función interna de captura; integración conservando exactamente las firmas actuales de `cuenta_cobrar` y `cuenta_cerrar`; estado persistente de captura por cuenta; modo `apagado/prueba`; pruebas transaccionales y de aplicación; documentación.
- Regla transaccional: la venta, pagos y cierre de cuenta son autoritativos. La captura de inventario debe ejecutarse en un bloque protegido; receta faltante produce `sin_receta`, y una excepción técnica deja un marcador persistente `pendiente/error` sin revertir el cierre comercial.
- Modo apagado: ausencia de fila en `lama_stock_config` conserva exactamente el comportamiento actual y no crea eventos.
- Modo prueba: crea un evento por línea confirmada y no anulada, congela cantidad, precio y receta, pero no crea descuentos reales ni cambia productos/lotes.
- Idempotencia: cierre repetido, doble clic o timeout no duplican eventos. Cubrir ambos caminos reales: `cuenta_cobrar` y `cuenta_cerrar`; mesa vacía no genera eventos.
- Fuera de alcance: escritura de `productos.stock_actual`; aplicaciones reales; modo `real`; reversas; panel; Fudo/Edge Functions; áreas; Café del Desierto.
- Criterios de aceptación: pruebas de modo apagado, prueba, sin receta, receta existente, línea anulada, mesa vacía, cierre repetido y excepción de captura; conteos y suma de stock pre/post sin cambios; rollback documentado; RLS/grants revisados.
- Publicación: migración y código asociado pueden aplicarse exclusivamente a Llamita Plus y publicarse a `master` si todas las pruebas pasan. No activar A3.3.
- Regla de detención: si no puede garantizarse que una falla de captura deje cerrar y conservar caja, no modificar las funciones de cierre y marcar `REQUIERE DECISIÓN`.
