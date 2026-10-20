# P0 — Panel de productos, catálogo, recetas, Fudo y reinicio

Fecha: 2026-10-20. Preflight completado sobre `7b8309dd537b1ad7a32cb19a9a1cf56508020cdb`. Repositorio `leoalejoleo1537/llamita-plus`; Supabase verificado `llamita-plus`, ref `iuryhsjucblmebdogewa`. Solo lecturas/SELECT/metadatos. No se contactó Fudo ni Café del Desierto / Llamita Stock.

## Decisiones de Alejo y secuencia vigente

Orden: **P1 → P2 → P3 → P4 → P7A → laboratorio → P5 → P6 → P7B**. P1 es la única hoja autorizada después de publicar este informe. Fudo no bloquea Mesas, recetas ni laboratorio.

- P1 conserva `productos.central` como maestro operativo Brunetti. El Panel ofrece una sola edición de nombre, unidad y costo. Las representaciones de plaza deben reflejar esos atributos y bloquear su edición independiente; el mecanismo exacto y sus pruebas se documentan al cerrar P1.
- Todo producto de venta y toda receta se crean manualmente. Una venta directa lleva receta manual de una línea, por ejemplo Coca-Cola × 1 desde Barra. Altas de insumos, importación o publicación Fudo jamás crean recetas/ingredientes.
- Catálogo comercial neutral nuevo, separado del espejo Fudo. No se infiere qué insumo se vende.
- Reinicio mediante respaldo validado y purga operativa, conservando distribución de mesas, salones, medios de pago y motivos. Esta decisión aprueba el diseño; no ejecuta ahora la purga.

## Matriz de altas verificada

| Pantalla | Función/RPC | Tablas | Identidad/enlace | Riesgo |
|---|---|---|---|---|
| Bodega → Enlaces | `crear_producto_enlazado` | productos, producto_enlace | Reutiliza por nombre normalizado/sede; Bodega opcional | Autoriza anon, permite fichas aisladas, no idempotencia por referencia |
| Área → Agregar de Bodega | `bodega_producto_area_agregar` | productos, producto_enlace, producto_area_asignacion | Maestro explícito; representación seleccionada o nueva enlazada | Protegida S1; confirma ambigüedad, no mueve stock |
| Modal general plaza | `producto_plaza_crear_configurado` | productos, producto_area_asignacion | Nueva fila plaza sin maestro | Segunda fuente de creación |
| Taller → Crear ingrediente | `producto_plaza_crear` o INSERT productos | productos y preferencia | Nombre de artículo Fudo; sin vínculo Bodega | Ficha aislada y duplicado posible |
| Editor/taller de recetas | DML navegador | recetas, receta_items | sede + fudo_product_id | Guardado por pasos no atómico |
| Mesas | lectura fudo_productos + fuentes directas F4 | cuenta_items, fuentes/reservas | ID Fudo como identidad comercial | Acoplamiento del POS local a Fudo |
| Publicar Fudo | fuente local fudo-crear-producto | remoto, espejo, recetas, receta_items | Producto inventario + remoto | Receta automática y efectos parciales |
| Importar Fudo | fuente local fudo-sync-productos | fudo_productos | ID remoto por sede | No desplegada; sin reconciliación de ausentes |

Rutas de edición: `saveFields` actualiza productos; ficha de área guarda sección/límites por RPC; enlaces legacy insertan/borran desde navegador. El Panel debe gobernar atributos maestros sin volver editable `stock_actual`.

## Identidad y objetos reales

`productos` contiene 1.438 filas: central 349, plaza 330, angamos 351 y clave histórica bodega 408. Central es el maestro por convención; plaza es una representación histórica para conservar referencias. `producto_enlace` tiene 513 filas y UNIQUE(sede,producto_sede_id): una representación tiene un maestro, pero un maestro puede tener varias representaciones históricas. Nunca fusionarlas por nombre.

El Panel mostrará el ID maestro. Representaciones/enlaces/configuraciones permanecen internos. Agregar un área reutiliza representación plaza y UNIQUE(sede,producto_id,area_id), sin insertar saldo. Hay 6 configuraciones y 1 sección física. Costos no existen todavía en productos. Nombre/unidad existen y hoy pueden divergir. Se detectaron 5 pares de nombre normalizado en central, ninguno con dos activos; no se deduplican automáticamente.

`recetas` tiene UNIQUE(sede,fudo_product_id), 396 filas; receta_items tiene 514 y UNIQUE(receta_id,producto_id). No tiene origen por área ni catálogo comercial neutral. F4 tiene una reserva por cuenta_item, no un desglose de ingredientes: se debe evolucionar para snapshots de receta, evitando consumo directo adicional.

## Matriz POS objetivo

| Modo | Catálogo / creador | Receta y enlace | Evento de inventario | Evitar doble descuento |
|---|---|---|---|---|
| Mesas/Llamita | productos de venta locales, alta humana | Receta manual e ingredientes/orígenes explícitos | Confirmar reserva; cerrar consume snapshot | Referencia de línea/comanda, un solo motor |
| Fudo | Espejo remoto; producto local creado por persona | Enlace humano remoto → venta → receta | Venta cerrada consume el mismo ledger | ID externo + origen POS exclusivo |
| Ningún POS | Catálogo comercial local opcional | Receta manual | Ningún evento POS consume | Origen ninguno |

## Fudo: local frente a desplegado

La lista instalada contiene seis funciones (ciclo, sync-ventas, empujar-stock, deshacer-stock, sumar-stock, probar-escritura). **crear-producto, activar-producto y sync-productos no están desplegadas**; no existe fuente instalada que atribuirles.

La fuente local crear-producto autoriza por correo en app_permisos, crea/reutiliza remoto, intenta espejo y genera receta con ingrediente ×1. Contradice S1 y la regla manual definitiva. Su futura refactorización exige quitar por completo ese comportamiento.

Si remoto crea y falla el enlace local, queda un producto remoto huérfano; el espejo falla silenciosamente y la respuesta de insertar ingrediente no se comprueba. Un reintento podría duplicar. Activar-producto cambia primero productos.activo y después remoto: también permite fallo parcial. La API local implementa PATCH active para desactivar; no se verificó una operación DELETE remota ni se promete reversibilidad de la creación. Publicar requerirá solicitud durable, reconciliación y confirmación; nunca repetir creación incierta a ciegas.

La fuente desplegada sync-ventas sí coincide con la local, versión 2026-10-07-b2.3.1. Llama a fudo_procesar_item, que todavía usa descontar_lotes/descontar_con_reposicion. No es todavía el adaptador de consumo por ubicaciones. `origen_pos` vale ninguno en todas las sedes; no se activó.

Hallazgo acotado: productos, producto_enlace, recetas y receta_items conservan escrituras legacy por políticas abiertas; crear_producto_enlazado conserva EXECUTE anon y search_path=public. Los RPC recientes S1 usan auth.uid(), search_path vacío y ACL cerradas. P2 deberá sustituir las rutas antes de cerrar sus permisos; no se amplía P0 a auditoría general.

## Reinicio: respaldo, dependencias y restauración

Conservar: Auth, app_permisos, authz_internal (incluida auditoría), sede_registro, areas_operativas, ubicaciones, origen_pos, motores y definiciones SQL/RLS/grants, configuración de aplicación, mesas/lama_areas, medios y motivos. La tabla lama_stock_config contiene configuración de modo y debe conservarse (hoy 0 filas); fudo_sync mezcla modo y cursor, requiere preservar configuración y reiniciar solo el cursor/estado operativo según el corte aprobado.

Respaldar y clasificar para purga: productos/enlaces/asignaciones, area_secciones y secciones históricas operativas, producto_lotes/lote_continuidad, ajustes_manuales/movimientos/transferencias, repartos_area/items y repartos/items legacy, movimientos/ajustes/historial_auto legacy y mermas contenidas en ellos, recetas/items y respaldo histórico de ingredientes, espejo/categorías/pospuestos/no_lleva_receta/movimientos/stock_push/pendientes Fudo, fuentes/auditoría/reservas/alertas Lama, capturas/eventos/aplicaciones históricos, cuentas/items/comandas/pagos/propinas, impresiones, caja/arqueos de prueba. Dependencias adicionales verificadas: envios_franquicia_items y meta_productos; no ignorarlas por no ser visibles en la navegación.

Línea base P0: ledger 410 movimientos y 409 saldos no cero; 42 lotes; 2 ajustes; 0 transferencias; 1 reparto de área y 1 línea; 1.377 filas espejo Fudo, 15.357 movimientos Fudo y 11.245 stock_push; 0 fuentes/reservas/alertas F4; 14 mesas, 64 cuentas, 95 ítems, 52 comandas; legacy 361 repartos y 2.040 líneas. Son lecturas puntuales, no una foto transaccional de respaldo.

Orden de dependencias a resolver, sin SQL destructivo en P0:

1. Ventana sin escritores; inventario de tareas/consumidores y origen POS; respaldo consistente de datos, esquema, secuencias y configuración con hashes.
2. Hijos: reserva_movimientos, reservas/alertas, pagos/propinas/ítems/comandas, fuentes/auditorías, aplicaciones/eventos/capturas, hijos de arqueos. Conservar plano de mesas.
3. Receta_items y enlaces comerciales antes de recetas/catálogo; continuidad de lotes antes de repartos_area_items y transferencias; líneas antes de documentos.
4. Movimientos antes de ajustes; liberar referencias a productos/lotes (incluidos envíos históricos y JSON/snapshots sin FK). Existencias es una vista: no se vacía con DML.
5. Configuraciones antes de secciones, enlaces y lotes; representaciones/maestros al final. Configuración permanente fuera de la lista de purga.
6. Restaurar en orden inverso con IDs originales; resolver secuencias, FKs, JSON, hashes, conciliación ledger/proyección, ACL y triggers. Ensayar en base aislada.

Los bloqueos de inmutabilidad y triggers de proyección impiden tratar esto como un DELETE genérico. P7A debe diseñar un procedimiento administrativo acotado y ensayado que restablezca exactamente protecciones. No se desactivan ahora. Antes del script requieren decisión: destino/retención del respaldo, ventana, corte de cursores externos, retención legal/operativa de datos y autorización de purga exacta. No reiniciar idempotencia Fudo para volver a importar ventas antiguas.

## Hojas implementables

| Hoja | Resultado/modelo y RPC | Pruebas / rollback | Depende de |
|---|---|---|---|
| P1 | Panel insumos, maestro central, coherencia nombre/unidad/costo, RPC atómica y lectura; configuraciones saldo cero | Edición única, múltiples representaciones/áreas, idempotencia, permisos, cero cambios físicos; retiro aditivo solo antes de uso | P0 publicado |
| P2 | Todas las altas abren Panel; retirada gradual de RPC/DML legacy | Bodega/área/ingrediente regresión; rollback de acceso manteniendo protecciones | P1 |
| P3 | productos_venta neutral, receta manual versionada con origen por ingrediente, enlace POS explícito | Directo ×1, combos, origen ambiguo; conservar compatibilidad histórica | P2 |
| P4 | Evolución F4 a reservas de ingredientes/snapshot, mismo consumo ledger | Atomicidad, concurrencia, doble cierre/anulación, fallo técnico; no rollback con reservas nuevas abiertas | P3 |
| P7A | Respaldo, restauración ensayada y reinicio limpio Brunetti | Hashes/FKs/saldos cero/protecciones, restauración completa; ejecución separadamente autorizada | P4 |
| Laboratorio | Configuración manual Brunetti y ensayo Mesas/recetas/repartos/ajustes | Escenarios humanos acordados; compensaciones auditadas, sin Fudo | P7A |
| P5 | Adaptador Fudo de lectura/enlace/consumo común, sin altas automáticas | API simulada, idempotencia/origen, eventos sin receta en alerta; deshabilitar adaptador conserva evidencia | Laboratorio |
| P6 | Publicación Fudo explícita; retirar receta automática y auth por correo | Fallos parciales, reconciliación, confirmación; compensación remota solo desactivar | P5 |
| P7B | Preparación final, respaldo/corte y habilitación acordada después del adaptador | Ensayo de restauración y no doble consumo; restauración validada sin repetir eventos externos | P6 |

No se ejecuta P1 automáticamente con P0. La instrucción posterior de Alejo autoriza únicamente P1 tras este commit documental. P2 y siguientes permanecen pendientes.
