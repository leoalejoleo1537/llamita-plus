# Cola de trabajo de Codex

Estado actual: **B1 requiere decisión**. No hay tarea ejecutable hasta resolver los bloqueos registrados en esta cola y en `05-decisiones-pendientes.md`.

Este archivo se utiliza como una cola explícita. Codex debe leerlo antes de cada ejecución programada.

## Reglas de lectura

- Si no existe una tarea marcada como `ACTIVA`, no modificar código ni base de datos.
- Ejecutar únicamente la tarea marcada como `ACTIVA`.
- Respetar el alcance, archivos permitidos y criterios de salida de esa tarea.
- Al finalizar, actualizar `04-bitacora-codex.md` y cambiar la tarea a `COMPLETADA`, `BLOQUEADA` o `REQUIERE DECISIÓN`.
- No activar por cuenta propia la tarea siguiente.
- No ejecutar SQL ni migraciones salvo que la tarea lo autorice explícitamente.

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
