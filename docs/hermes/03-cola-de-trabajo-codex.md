# Cola de trabajo de Codex

Estado actual: **sin tareas activas**.

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

No hay ninguna tarea autorizada en este momento.