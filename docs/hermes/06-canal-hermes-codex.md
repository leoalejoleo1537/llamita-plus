# Canal de comunicación Hermes ↔ Codex

Este documento es el canal documental compartido entre la mesa de trabajo de Hermes y el ingeniero Codex. Su propósito es conservar el **porqué**, el contexto del negocio y las decisiones arquitectónicas que no aparecen en el código.

## Cómo se usa

1. Codex lee este archivo antes de iniciar cualquier tarea de Llamita Plus.
2. Hermes deja aquí el contexto, las prioridades, las decisiones y las preguntas que deban orientar la inspección.
3. Codex responde en la sección `Respuesta de Codex`, con evidencia concreta del código, la documentación y, cuando corresponda, la base autorizada de Llamita Plus.
4. Si aparece una decisión que no está resuelta, Codex no la inventa: la registra también en `05-decisiones-pendientes.md` y cambia el estado de la cola.
5. La bitácora (`04-bitacora-codex.md`) conserva el resultado operativo; este canal conserva la conversación arquitectónica entre ambos agentes.

## Reglas del canal

- Este canal no autoriza por sí solo cambios de código, SQL o datos. La autorización vigente sigue estando en `03-cola-de-trabajo-codex.md`.
- Ningún supuesto reemplaza una comprobación en el repositorio, `CLAUDE.md`, `docs/` o el esquema real autorizado.
- Todo análisis debe distinguir entre: hecho comprobado, inferencia, decisión pendiente y recomendación.
- La frontera permanente se mantiene: no tocar Café del Desierto / Llamita Stock.
- Si dos documentos discrepan, Codex debe señalar la discrepancia y no elegir silenciosamente.

## Contexto de Hermes — mensaje vigente

Fecha: 2026-10-06  
Autor: Hermes, mesa de arquitectura  
Estado: **solicitud de auditoría, solo lectura**

### Objetivo del producto

Llamita Plus busca unir control de stock con un POS propio llamado Llamita Lama y conservar la posibilidad de recibir ventas desde POS externos. La arquitectura futura debe permitir cambiar de Fudo a Toteat sin reescribir el núcleo de inventario.

### Hechos que Codex debe tener presentes

1. **Fudo ya está integrado.** Café del Desierto opera con esa conexión. En Llamita Plus no se debe construir Fudo desde cero: hay que localizar, entender y documentar el adaptador existente.
2. La documentación del proyecto indica que Fudo ya cuenta con catálogo local, recetas, ventas cerradas, `fudo_procesar_item()` e idempotencia. Codex debe verificar que esto siga reflejando el código y la base actuales.
3. **Llamita Lama aún no descuenta stock.** Sus ventas, comandas y cobros existen como módulo, pero deben conectarse al motor de recetas de manera segura.
4. Llamita es quien gestiona pagos, cobros y cierre de caja cuando se usa el POS propio. Fudo y Toteat gestionan pagos y cierres dentro de sus propios sistemas; Llamita solo debe recibir el evento de venta necesario para inventario.
5. El área existente de **Recetas** y la creación/enlace de productos deben reciclarse. Ejemplo: una venta de Llamita Kids puede consumir jamón, queso, juguete, dos naranjas y una mini dona.
6. Café del Desierto / Llamita Stock no puede ser consultado ni modificado durante esta tarea.

### Decisiones de producto ya tomadas

- Las áreas operativas iniciales serán Cocina fría, Cocina caliente, Barra de bar y Cafetería.
- Las tarjetas de áreas serán páginas completas; al entrar, el buscador queda limitado a esa área. La búsqueda global debe seguir existiendo y mostrar el mismo producto separado por área.
- Las áreas no se deducen permanentemente de `tipo` o `rubro`; deben ser una capa explícita por sede.
- La simulación de clasificación se ejecutará, si se autoriza, solo con datos sintéticos de Llamita Plus: gaseosas a Barra; café, té, leche común, tortas y bebidas calientes a Cafetería; panes, pizzas y sándwiches a Cocina caliente; helados, productos “ice”, leche condensada, manjar e ingredientes dulces a Cocina fría; ambiguos a Sin asignar.
- No se deben modificar automáticamente las recetas históricas. Primero se construye y prueba la capacidad de asociar una receta a un área.
- No se debe crear una segunda fuente editable de stock mientras `productos.stock_actual` y sus escritores no hayan sido migrados de forma coordinada.

## Tarea solicitada a Codex: Parte 1 — auditoría de lo existente

Antes de implementar las áreas, auditar en modo plan y solo lectura:

1. La arquitectura Fudo existente: catálogo, recetas, enlaces, ventas, sincronizaciones, permisos, modos de prueba/real, anulaciones y puntos que escriben o leen stock.
2. La arquitectura de Lama: venta, comanda, cobro, cierre, anulación y puntos donde hoy podría conectarse el inventario.
3. La interfaz de Ajustes relacionada con Fudo: qué existe en código, qué se muestra, qué está oculto por permisos/modo demostración y qué falta realmente.
4. Todos los escritores actuales de `productos.stock_actual`, lotes, movimientos, repartos, mermas, restauraciones y reportes.
5. La compatibilidad real entre el motor Fudo existente y el futuro evento de inventario de Lama/Toteat.

### Límites de esta tarea

- No modificar código de aplicación.
- No ejecutar SQL ni migraciones.
- No insertar, actualizar ni borrar datos.
- No activar todavía las áreas ni cambiar el modo demostración.
- Sí se permite consultar en lectura el esquema autorizado de Llamita Plus si el entorno está conectado.

### Entregable requerido

Codex debe dejar en la respuesta y en la bitácora:

- mapa de componentes y flujo actual;
- tabla de fuentes y escritores de stock;
- tabla de funciones visibles/ocultas de Fudo en Ajustes;
- hechos comprobados, inferencias y decisiones pendientes separados;
- propuesta de contrato común para eventos de inventario;
- archivos que tocaría en una fase posterior y archivos que no deben tocarse;
- pruebas de lectura ejecutadas y limitaciones;
- recomendación sobre si la siguiente fase puede comenzar o sigue bloqueada.

## Respuesta de Codex

Pendiente de la primera ejecución de auditoría.

Formato mínimo de respuesta:

```text
Fecha:
Estado: COMPLETADA | BLOQUEADA | REQUIERE DECISIÓN
Hechos comprobados:
Inferencias:
Discrepancias encontradas:
Mapa Fudo:
Mapa Lama:
Puntos de stock:
Ajustes/Fudo visibles y ocultos:
Contrato común propuesto:
Decisiones pendientes:
Archivos revisados:
Pruebas de lectura:
Cambios de código/SQL/datos: ninguno en esta fase
Siguiente paso recomendado:
```

