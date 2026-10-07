# B1 — Administración segura de sedes y nodos

Fecha: 2026-10-06
Estado: **COMPLETADO**
Repositorio: `leoalejoleo1537/llamita-plus`
Supabase: `llamita-plus` (`iuryhsjucblmebdogewa`)
Alcance: únicamente el registro visible de sedes y el archivo lógico de Local 2. No se consultó ni modificó Café del Desierto / Llamita Stock.

## Decisiones aplicadas

- `plaza` es Local 1 y permanece activa.
- `angamos` es Local 2 y queda archivada, sin borrar ni reescribir su historial.
- `central` es la Bodega activa y conserva su comportamiento logístico.
- `bodega` es una clave histórica independiente, archivada y no reutilizable.
- Local 1 comparte el proyecto y modelo de datos; no es una frontera de aislamiento técnico.
- B2 (áreas y stock por área) queda pendiente. No se crean áreas ni se migran saldos.

## Hallazgos de esquema y seguridad

Antes de la migración no existía una tabla o configuración persistente adecuada para registrar sedes. `ajustes` es configuración booleana global. `app_permisos` tiene nueve filas y no tiene columna `sede`; sus políticas de lectura y actualización no constituyen un control confiable para autorizar administración desde el navegador. Por eso se creó un catálogo legible por los clientes, sin permisos de mutación desde `anon` o `authenticated`, y no se añadió un editor de sedes en Ajustes.

`public.sede_registro` contiene código interno estable, nombre visible, tipo, estado y timestamps. Una restricción impide cambiar el código mediante `UPDATE`; restricciones adicionales protegen `central` como nodo logístico activo y `bodega` como clave histórica archivada. Un trigger interno no es ejecutable directamente por `PUBLIC`, `anon` ni `authenticated`. El catálogo no contiene información sensible y tiene RLS activado con política de lectura.

El cambio de nombre o estado queda preparado en el modelo, pero su administración requiere un cambio controlado con credenciales de base de datos autorizadas. No se inventó un rol de administrador: las políticas actuales de `app_permisos` no permiten identificarlo de forma segura.

## Conteos previos a la migración

Las lecturas se ejecutaron sobre el proyecto confirmado. Los conteos operativos por sede fueron consultas de solo lectura y se guardaron antes de cualquier escritura. El total de productos es el número de filas de `productos`; `stock_actual` es una suma de proyección y no un conteo físico. El saldo de lotes se reporta por separado y no debe sumarse al stock de productos.

| Clave | Productos | Activos | Stock no cero | Suma `stock_actual` | Movimientos | Repartos | Líneas reparto | Lotes | Suma lotes | Historial manual | Historial automático |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `plaza` | 329 | 264 | 255 | 4,566.20 | 25 | 148 | 1,350 | 9 | 36 | 5,692 | 12,250 |
| `angamos` | 351 | 245 | 228 | 2,764.20 | 3 | 168 | 533 | 19 | 134 | 4,717 | 13,062 |
| `central` | 349 | 262 | 149 | 4,750.50 | 403 | 40 | 143 | 2 | 96 | 4,861 | 13,103 |
| `bodega` | 408 | 351 | 302 | 3,357.10 | 0 | 5 | 14 | 12 | 38 | 6,669 | 15,504 |
| **Total** | **1,437** | **1,122** | **934** | **15,438.00** | **431** | **361** | **2,040** | **42** | — | — |

Permisos: nueve registros globales en `app_permisos`; no hay una dimensión por sede que permita un conteo por `plaza`, `angamos`, `central` o `bodega`. No se modificó ninguna fila de permisos.

## Implementación

- Migración: `sql/2026-10-b1-registro-sedes.sql`, aplicada como `b1_sede_registro` únicamente en Llamita Plus.
- Reversión: `sql/2026-10-b1-registro-sedes.rollback.sql`. Verifica que el catálogo conserve exactamente las cuatro filas semilla y sus valores antes de eliminarlo; se detiene si fue ampliado o administrado.
- Aplicación: Local 2 inicia oculta; el catálogo controla etiquetas y sedes activas. Si falla la lectura, la aplicación vuelve a Local 1 y Bodega como lista segura. `pickSede` rechaza sedes archivadas o desconocidas antes de asignar `SEDE`; la navegación vuelve al selector si la sede deja de estar activa.
- Destinos nuevos: los flujos de envío ofrecen Local 1. Un intento directo desde Bodega a Local 2 muestra aviso y no crea un nuevo envío. No se actualizaron filas ni funciones de repartos.
- Bodega: `central` sigue habilitada; se conservan las vistas de recepción, conteo y envíos. Envíos a Local 1 siguen disponibles.
- `central` usa su propia clave en nombres de exportación; la clave histórica `bodega` permanece separada.

## Conteos después de la migración

Los conteos se repitieron después de aplicar la migración. Todos coinciden exactamente con la referencia previa. No se actualizó ningún producto, movimiento, reparto, línea, lote, vencimiento ni permiso. La comparación también confirmó que los historiales de las cuatro claves permanecen con los mismos conteos.

| Métrica | Antes | Después |
|---|---:|---:|
| Productos | 1,437 | 1,437 |
| Suma `stock_actual` | 15,438.00 | 15,438.00 |
| Movimientos | 431 | 431 |
| Repartos / líneas | 361 / 2,040 | 361 / 2,040 |
| Lotes | 42 | 42 |
| Permisos globales | 9 | 9 |
| Productos / stock `angamos` | 351 / 2,764.20 | 351 / 2,764.20 |
| Productos / stock `central` | 349 / 4,750.50 | 349 / 4,750.50 |
| Productos / stock `bodega` | 408 / 3,357.10 | 408 / 3,357.10 |

## Pruebas y límites

- `npm test`: pasó (código de salida 0). Los casos que requieren navegador se omitieron porque no hay navegador instalado.
- `node pruebas/sedes-seguras.mjs`: pasó; comprueba claves y estado seguro, Local 1/Bodega activas, Local 2 oculta, rechazo de `pickSede('angamos')`, navegación y destino de reparto.
- Sintaxis JavaScript embebido: válida.
- `git diff --check`: pasó.
- Verificación en Supabase: el registro devuelve exactamente cuatro filas con los estados esperados; RLS está activo, `anon` y `authenticated` pueden leer, no pueden insertar/actualizar/borrar, y no pueden ejecutar el trigger directamente.
- Consulta de migraciones confirma `b1_sede_registro` aplicado.
- Security advisors: no apareció un hallazgo nuevo por `sede_registro`; las seis tablas RLS sin política ya existían antes y siguen siendo las tablas Lama internas, `limpiezas` y un respaldo histórico; las advertencias de vistas/funciones heredadas permanecen.
- Performance advisors: alertas preexistentes sobre llaves foráneas, índices y múltiples políticas permisivas; ninguna apunta a `sede_registro`.
- El selector y `pickSede` se probaron en código; no se pudo hacer una prueba visual con navegador en este entorno.
- No se ha probado aislamiento de datos a nivel API. El esquema y las políticas operativas heredadas permiten accesos amplios; ocultar una sede en la interfaz no equivale a proteger sus datos.
- Riesgo: el flujo legado puede seguir permitiendo mutaciones directas a filas de Local 2 por API/RPC, aunque la app ya no ofrece rutas operativas. Endurecer RLS y permisos por sede requiere un bloque posterior.
- La clonación completa de sedes queda para una subfase posterior. No se copian productos, stock, lotes, vencimientos, movimientos, repartos, permisos ni historial.

## Publicación

Publicado en `master` con el commit `36d71a3` (`feat: add safe site registry and archive Local 2`). Push verificado; la rama `master` remota apunta al mismo SHA. B2 permanece PENDIENTE y no se activa automáticamente.
