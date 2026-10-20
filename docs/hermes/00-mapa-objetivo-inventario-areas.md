# Mapa de objetivo — Inventario por áreas

> Estado actualizado: 20 de octubre de 2026. B1 y B2 completados; B3 continúa pendiente. Las Fases 1, 2 y 3 del contrato operativo de stock están completadas; Fase 4 aún no está activa.
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
├── D. Consumo por ventas                                          [PENDIENTE]
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

## Siguiente nodo del contrato: Fase 4 — disponibilidad y reserva de stock en Lama

PENDIENTE de activación específica. Debe mostrar disponibilidad vendible y resolver reservas, concurrencia, anulación e idempotencia sin comprometer el cierre comercial. B3 continúa siendo una tarea separada pendiente de activación.

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
