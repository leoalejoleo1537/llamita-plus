# Cola de trabajo de Codex

Estado actual: **A1 activa — auditoría de Fudo y Lama, solo lectura**. La antigua B1 de áreas queda pausada hasta conocer el contrato real entre ventas e inventario.

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

- Estado: ACTIVA
- Autorización: Alejo aprobó iniciar la primera parte del plan el 2026-10-06.
- Objetivo: auditar la integración Fudo ya existente, el módulo Llamita Lama y sus conexiones reales con recetas, ventas, caja e inventario antes de diseñar stock por áreas.
- Documentos obligatorios: `CLAUDE.md`, `README.md`, `docs/LAMA.md`, `docs/fudo-api-cuanto-sirve.md`, `docs/atlas-fudo.md`, `docs/hermes/00-reglas-operativas.md` y `docs/hermes/06-canal-hermes-codex.md`.
- Alcance permitido: lectura del repositorio; lectura del esquema autorizado de Llamita Plus; mapa de componentes, funciones, tablas, permisos, sincronizaciones y puntos de lectura/escritura; propuesta de contrato común.
- Fuera de alcance: cambios de código; SQL o migraciones; inserciones/actualizaciones/borrados; cambios de UI; activación de áreas; cambios en modo demostración; cualquier acceso a Café del Desierto.
- Criterios de aceptación: respuesta en `06-canal-hermes-codex.md`; bitácora actualizada; hechos e inferencias separados; Fudo existente distinguido de Lama futuro; función de pagos/caja separada de evento de inventario; riesgos y decisiones pendientes explícitos.
- Pruebas requeridas: solo consultas y verificaciones de lectura; `git diff --check`; no se requieren pruebas de aplicación porque no se modifica código.
- Publicación: push a `master` autorizado para esta actualización documental, sin cambios de aplicación, esquema ni datos.
- Riesgos conocidos: documentación histórica que podría no coincidir con el esquema vigente; funciones Fudo visibles solo bajo permisos; múltiples escritores de `productos.stock_actual`; ausencia de stock por área.
