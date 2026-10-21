# Mapa de objetivo — Inventario por áreas

## Frente vigente — Panel de productos

P0 publicado en `34b4b48`: [informe 37](37-p0-panel-productos-catalogo-recetas-fudo-reinicio.md). **P1, P2 y P3 implementados**: el Panel administra el maestro central, unifica las altas humanas y separa `Insumos` de `Productos de venta`. Nombre/unidad/costo se editan una vez; el catálogo comercial y sus recetas manuales son neutrales, versionados y no mueven stock. Migraciones `20261021020517_p1_panel_productos`, `20261021112507_p2_unificar_altas_productos`, `20261021181318_p3_catalogo_comercial_recetas_manuales` y `20261021181440_p3_indices_fk_catalogo_comercial`.

Siguiente nodo **P4 — Mesas consume recetas y componentes desde una o varias áreas**, pendiente y no activado. Secuencia aprobada: **P1 → P2 → P3 → P4 → P7A → laboratorio → P5 → P6 → P7B**. Fudo no bloquea el laboratorio. No se activan P4, reinicio ni adaptación POS automáticamente. El árbol histórico siguiente conserva evidencia de trabajo completado y no sustituye esta prioridad.

### Resultado P3 — catálogo comercial neutral y recetas manuales

- El Panel muestra `Insumos` y `Productos de venta`; una identidad comercial no nace de un insumo ni de `fudo_productos`.
- Un producto de venta puede guardarse en borrador sin receta. Para quedar `listo` necesita al menos un ingrediente, cantidad positiva y una configuración producto–área activa como origen explícito para cada línea.
- Guardar genera una versión nueva de receta y conserva el orden manual. Crear un insumo desde el editor vuelve con ese insumo seleccionado, pero no crea receta, reserva, movimiento ni enlace POS.
- Las 396 recetas y 514 líneas heredadas permanecen idénticas. Las tablas neutrales nacen vacías; P4 será quien adapte Mesas al nuevo contrato sin doble descuento.

### Resultado P2 — entradas de creación unificadas

- Bodega abre el Panel con contexto Bodega; un área abre el mismo Panel con el destino preseleccionado.
- Recetas abre el Panel en modo ingrediente y regresa al editor/taller con la representación correcta seleccionada; la receta continúa siendo una decisión manual.
- Buscar y seleccionar un maestro existente precede al alta. Una representación enlazada se reutiliza en varias áreas; no se crea una copia por área.
- `authenticated` y `anon` ya no tienen INSERT directo en `productos`. Las RPC heredadas de alta perdieron ejecución de aplicación; `panel_producto_guardar` permanece como único escritor humano.
- La pantalla histórica de mantenimiento manual de `producto_enlace` se conserva por una dependencia distinta. Su sustitución por RPC protegida queda documentada como riesgo, sin reabrir otra alta.
- Las pruebas SQL terminaron con `ROLLBACK`; productos, stock, ledger, lotes, repartos, recetas, Fudo y Lama conservaron los conteos de línea base.

> Estado actualizado: 20 de octubre de 2026. B1 y B2 completados; B3 continúa pendiente. Las Fases 1, 2, 3 y 4 del contrato operativo de stock están completadas; Fase 5 permanece pendiente y no activa.
>
> Este documento es el tablero de orientación del proyecto. No reemplaza la bitácora: resume qué ya existe, cuál es el siguiente frente y qué queda después.

## Objetivo visible de la demo

Antes de continuar con automatizaciones complejas, Llamita Plus debe permitir que una persona entre a **Cafetería, Cocina fría, Cocina caliente o Barra**, y trabaje con la experiencia histórica de inventario:

- buscar productos;
- filtrar mediante las píldoras de tipo existentes;
- abrir secciones desplegables;
- ver las filas de productos;
- abrir la ficha/modal de cada producto;
- configurar manualmente productos, sección y mínimos/máximos por área;
- ver `Configurado · sin existencias` cuando el catálogo exista pero aún no se haya recibido mercadería.

Las cantidades seguirán siendo del ledger. No se reactivará la edición histórica de `productos.stock_actual`.

## Árbol de trabajo

```text
INVENTARIO POR ÁREAS
│
├── A. Cimientos técnicos                                         [HECHO]
│   ├── Ledger por ubicación: Bodega / Sin asignar / áreas         [x]
│   ├── Transferencias físicas seguras e idempotentes              [x]
│   ├── Áreas dinámicas y vínculo con ubicaciones                  [x]
│   ├── Configuración producto → área → sección → mínimos/máximos  [x]
│   └── Base de permisos S1/S2                                    [x]
│
├── B. Catálogo operativo sin existencias                          [EN CURSO]
│   ├── B1. Maestro Bodega → representación Local 1 enlazada      [x]
│   ├── B2. Recuperar interfaz histórica dentro de cada área      [x]
│   └── B3. Alta/configuración manual de productos demo           [→ SIGUIENTE; PENDIENTE DE ACTIVACIÓN]
│
├── C. Operación física                                            [EN CURSO]
│   ├── C1. Conteo y ajuste manual auditado                         [x]
│   ├── C2. Reparto por destino y recepción por área               [x]
│   └── C3. Urgencias manuales para reposición desde Bodega       [x]
│
├── D. Consumo por ventas                                          [EN CURSO]
│   ├── D0. Lama directo: fuente, reserva y consumo ledger        [x]
│   ├── D1. Lama: receta + área de producción                     [ ]
│   ├── D2. Alertas de receta/área ambigua                         [ ]
│   └── D3. Fudo como adaptador compatible                         [ ]
│
└── E. Experiencia y despliegue                                    [POSTERIOR]
    ├── E1. Flujo guiado y tolerante a errores                     [ ]
    ├── E2. Móvil y POS táctil                                     [ ]
    └── E3. Pulido visual y marca                                  [ ]
```

## Regla de avance

- Solo se implementa **una hoja activa** del árbol a la vez.
- Cada hoja debe terminar con un resultado comprobable en pantalla, pruebas y una entrada en la bitácora.
- Una hoja técnica no se declara terminada si impide el objetivo visible que habilita.
- La bitácora debe señalar el siguiente nodo exacto, no una lista abierta de posibilidades.

## Resultado completado: B1 — Maestro de Bodega hacia un área

**Decisión aprobada:** Bodega es el catálogo maestro. Las áreas no crean copias independientes del mismo producto.

Al añadir un producto desde un área:

1. la persona busca y elige un producto maestro existente de Bodega;
2. si ya existe su representación explícitamente enlazada en Local 1, se reutiliza;
3. si no existe, se crea una representación de Local 1 con saldo cero y enlace explícito al maestro;
4. se configura el producto en una o más áreas, con sección y mínimos/máximos;
5. no se crean lotes, movimientos ni existencias;
6. Bodega solo pierde stock cuando el área **recibe** un reparto futuro.

No habrá coincidencias automáticas ambiguas por nombre. Si no existe el producto maestro, primero se crea en Bodega.

### Resultado verificado de B1

Publicado en `master` en el commit `e7f0f40892ab2d190426ed4a07b4853890a3171c`. Las migraciones `20261013002913` y `20261013003415` están instaladas en Llamita Plus; las RPC de búsqueda y agregado fueron verificadas en el proyecto remoto. Codex reportó pruebas transaccionales, `npm test` y `git diff --check` satisfactorios. La prueba visual autenticada aún corresponde al usuario.

## Resultado completado: B2 — Interfaz histórica dentro de un área

La prioridad fue recuperar y conectar la interfaz histórica existente, no diseñar otra interfaz:

```text
Tarjeta de área → pantalla operativa del área
                → buscador + píldoras de tipo
                → secciones desplegables
                → filas de producto
                → modal/ficha existente adaptada al ledger
```

La pantalla muestra tanto productos configurados sin saldo como saldos físicos aún sin configuración. El saldo visible procede del ledger; la ficha permite corregir el conteo por la RPC auditada de C1, pero no reabre la edición directa de `productos.stock_actual` ni habilita lotes legacy, mermas, reparto o Fudo. El gesto legacy de swipe sigue desactivado en las áreas.

La pantalla de área dispone de cuatro filtros de lista en la misma vista: Críticos (bajo mínimo o sin saldo), Sobre-stock (sobre máximo), Sin límites (mínimo o máximo faltante) y Vencimientos (vencidos y próximos a vencer separados). Se adaptan a 4/2/1 columnas según ancho. El flujo de agregado desde Bodega permite seleccionar o crear una sección física desde un panel lateral; las secciones no contienen cantidades.

### Criterio de salida de B2

Al entrar a Cafetería, una persona puede navegar el patrón histórico completo y abrir una ficha de producto desde una sección, aunque el saldo sea cero. B2 no reimplementó el motor de vinculación B1 ni reactivó ediciones legacy de stock. El alta desde Bodega oculta IDs y detalles internos, reutiliza automáticamente la única representación enlazada y confirma explícitamente las alternativas reales; nunca muestra una ficha enlazada a otro maestro.

## B3 — Onboarding demo (pendiente de activación; tarea separada)

La persona responsable de cada área configura manualmente su catálogo real:

- agrega productos desde Bodega;
- crea en Bodega el maestro faltante cuando corresponda;
- elige área, sección y mínimos/máximos;
- no necesita clasificar todo el catálogo histórico por adelantado.

La clasificación automática mediante Excel/IA queda **postergada**. No es necesaria para la demo.

## Completado: C1 — conteo y ajuste manual auditado

La Fase 1 del contrato 36 quedó completada el 20 de octubre de 2026. Desde la ficha se puede ingresar el saldo contado para Bodega central o para la ubicación de Local 1 abierta. Los productos con lotes muestran líneas por lote y vencimiento, además del bucket independiente **Sin lote / vencimiento no informado**. El servidor calcula los deltas, bloquea producto/ubicación, guarda la auditoría y actualiza el ledger; el trigger mantiene `productos.stock_actual` como proyección. La migración `20261020000825_fase1_ajustes_manual_ledger` está instalada. Los conteos SQL y demás evidencia están en la entrada más reciente de Bitácora.

## Completado: C2 — reparto y recepción por área

La Fase 2 quedó completada el 20 de octubre de 2026. Bodega puede preparar un documento para cualquier área activa sin mover stock. El área destino ve su propia bandeja y confirma todas las cantidades recibidas: exactas, parciales, cero o excedentes. Al confirmar se usa el ledger una sola vez; Bodega entrega hasta su saldo disponible y cualquier excedente físico se registra como ajuste auditado. El documento queda cerrado y no deja diferencias pendientes.

La migración `20261020003917_fase2_repartos_recepcion_areas` está instalada. Las pruebas transaccionales terminaron con `ROLLBACK` y no dejaron repartos sintéticos.

## Completado: C3 — urgencias manuales por área

La Fase 3 quedó completada el 20 de octubre de 2026. La urgencia pertenece a una combinación producto–área, se marca y resuelve manualmente desde su ficha, incluye nota/actor/fecha y no cambia cantidades. Bodega ve las urgencias agrupadas por área y puede agregarlas al reparto conservando el destino correcto y el enlace explícito del producto. La migración instalada es `20261020102356_fase3_urgencias_producto_area`.

## Completado: D0 — disponibilidad y reserva de stock directo en Lama

La Fase 4 quedó completada el 20 de octubre de 2026. Cada producto vendido directamente necesita una fuente explícita producto–área; el disponible es el saldo físico del ledger menos reservas activas. Confirmar comanda reserva atómicamente, cerrar consume una sola vez y anular libera o compensa. Una falla física inesperada no bloquea el cierre comercial: deja alerta auditable. Mesas es visible en teléfono para propietario raíz y cuentas con `puede_lama`; el permiso sigue siendo obligatorio.

## Siguiente nodo del contrato: Fase 5 — recetas y combos multiárea

PENDIENTE de activación específica. Debe resolver componentes, cantidades y ubicaciones autorizadas por receta sin inferir destinos ni descontar dos veces. B3 continúa siendo una tarea separada pendiente de activación.

## Invariantes: no romper

- No tocar Café del Desierto / Llamita Stock.
- No volver a escribir directamente `productos.stock_actual` en Local 1 o Bodega.
- No alterar Fudo remoto, sus tablas o sus Edge Functions durante B1–B3.
- No alterar Lama, caja, pagos, recetas, lotes ni `stock_transferir` fuera de una fase que los nombre explícitamente.
- No crear sedes nuevas para simular áreas.
- No hacer rediseño de tarjetas, marca o móvil durante B1–B3.

## Lectura mínima para Codex

Antes de una hoja, leer solamente:

1. este mapa;
2. la última entrada relevante de `docs/hermes/04-bitacora-codex.md`;
3. el informe/preflight de la hoja activa;
4. las funciones y archivos que vaya a modificar.

No releer toda la historia cerrada salvo que la hoja dependa directamente de ella.
