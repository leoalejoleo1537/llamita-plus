# C0 — Auditoría del circuito interno de inventario por áreas

Fecha: 2026-10-09
Estado: **COMPLETADA; C1–C3 REQUIEREN DECISIÓN**

Entorno exclusivo: `leoalejoleo1537/llamita-plus`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`). El frente móvil M2–M4 quedó pausado.

## Conclusión

La arquitectura separa correctamente tres conceptos:

1. `producto_area_asignacion`: preferencia organizativa, sin cantidad.
2. `stock_internal.ubicaciones` y `stock_internal.existencias`: ubicación y saldo físicos.
3. `productos.rubro`, `public.secciones` y `productos.tipo`: clasificaciones legadas del catálogo y del conteo.

La interfaz actual no permite mover cantidades porque B3.1/B3.2a fueron diseñados expresamente como lectura y preferencia. No existe ninguna llamada cliente a `stock_transferir`.

No es seguro continuar C1–C3 todavía. Las áreas son dinámicas y ya existe Heladería, pero el núcleo de `stock_transferir` solo admite los códigos `cocina_fria`, `cocina_caliente`, `barra` y `cafeteria`. La interfaz genérica solicitada fallaría para Heladería o cualquier área futura.

## Circuito comprobado

### Lectura

- `public.stock_leer_areas()` es `SECURITY INVOKER`, solo ejecutable por `authenticated`.
- Delega en el helper privado y calcula desde `stock_internal.existencias`.
- Sin asignar de `plaza`: 4.566,20 unidades y 258 filas con saldo.
- Bodega central: 4.750,50 unidades y 150 filas con saldo.
- Cocina fría, Cocina caliente, Barra, Cafetería y Heladería: saldo cero.
- Bodega no se suma dentro de Local 1.

### Preferencia

- `producto_area_preferencia_guardar` exige sesión y capacidad `puede_editar` mediante autorización S1.
- Solo acepta productos y áreas activas de `plaza`.
- Cambia `producto_area_asignacion`; no toca existencias, lotes ni movimientos.
- Actualmente hay cero preferencias persistentes.

### Transferencia

- `public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)` conserva la firma B2.4.
- Es `SECURITY INVOKER`, valida `auth.uid()`, JWT autenticado y `permisos_mios().puede_editar`.
- Produce un encabezado idempotente y dos movimientos balanceados mediante el núcleo privado.
- Bodega→Local 1 exige `producto_enlace` explícito con factor 1.
- El lote canónico y su vencimiento se conservan mediante `lote_continuidad`.
- El navegador no tiene DML directo sobre el ledger.

## Por qué aparecen Limpieza, Vitrina o Sándwiches

No provienen de `areas_operativas`.

- `productos.rubro` agrupa físicamente el inventario legado para conteos: Congelador, Vitrina de tortas, Limpieza, muebles, Sándwiches, etc.
- `public.secciones` guarda nombre, turno y orden de esas agrupaciones por sede.
- `productos.tipo` clasifica el producto: Envases, Cafetería, Insumos, Bollería, Bebidas, Limpieza, Sándwiches, Tortas, etc.
- Los formularios `m-seccion` y `n-rubro` todavía editan/eligen `rubro`.
- B3.2a.3 ya restringe el selector de área a áreas activas y Sin asignar, por lo que esas etiquetas no aparecen como destino contable.

Crear ahora una segunda tabla de secciones internas sería técnicamente posible, pero antes debe definirse cómo convivirá con `rubro` y `public.secciones`: reemplazo gradual, alias o metadata adicional. Sin esa decisión se crearían dos campos visibles llamados “sección” con significados superpuestos.

## Contradicción bloqueante

`areas_operativas` permite nuevas áreas y crea atómicamente una ubicación vinculada. Heladería existe como área activa y ubicación válida. Sin embargo, `stock_internal.transferir_aplicar` contiene listas fijas para origen/destino. Por ello:

- Heladería puede mostrarse.
- Puede guardarse como preferencia.
- No puede recibir una transferencia física.
- Una nueva sección interna asociada a Heladería tampoco resolvería el bloqueo.

Opciones para decisión:

1. **Recomendada:** una subfase B2.4.1 que sustituya únicamente la lista fija por validación de `ubicacion.area_id` enlazada a un área activa de `plaza`, conservando sedes, enlaces, lotes, idempotencia, permisos y atomicidad.
2. Limitar formalmente las existencias físicas a las cuatro áreas fundacionales y tratar las áreas nuevas solo como preferencias. Esto contradice la expectativa actual de áreas configurables.

## Formularios y flujos localizados

- Creación/edición normal: modal de producto en `index.html`, con `rubro`, `tipo` y área preferida.
- Alta segura de `plaza`: `producto_plaza_crear`, stock cero.
- Asignación existente: `producto_area_preferencia_guardar`.
- Inventario por áreas: `stock_leer_areas` y `areas_operativas_listar`.
- Bodega/recepción/reparto: flujos heredados separados y bloqueados por el corte B2.3 donde corresponde.
- No existe aún formulario de transferencia por ubicación.

## Conteos observados

| Control | Valor |
|---|---:|
| Productos | 1.437 |
| Productos `plaza` | 329 |
| Áreas activas `plaza` | 5 |
| Preferencias | 0 |
| Movimientos ledger | 408 |
| Transferencias | 0 |
| Lotes | 42 |
| Enlaces `central`→`plaza` | 250 |
| Repartos / ítems | 361 / 2.040 |

## Cambios y pruebas

Se ejecutaron exclusivamente consultas `SELECT` sobre catálogos PostgreSQL y Llamita Plus para inspeccionar columnas, constraints, ACL, funciones y conteos. No hubo SQL de escritura, migraciones, pruebas con DML, datos sintéticos ni llamadas remotas.

Los conteos no cambiaron. No se modificaron aplicación, esquema, permisos, productos, stock, lotes, movimientos, transferencias, repartos, recetas, Fudo, Lama, caja o Bodega operativa. No se accedió a Café del Desierto / Llamita Stock.

## Continuación

C1, C2 y C3 quedan detenidas hasta resolver B2.4.1 y el destino semántico de las secciones legadas. C4 permanece en una ejecución separada; no se preparó ni movió información de demostración.
