# Bitácora de Codex

## Guía visual del proyecto — Lápiz y papel

Esta es la referencia visual consolidada para diseñar y vestir pantallas existentes. La identidad prioriza uso rápido y legible en una app de inventario, ventas y gestión para pequeñas empresas; la apariencia nunca debe cambiar datos, permisos ni reglas de operación.

### Personalidad

- Simple, fluida y rápida; cercana, juvenil y moderna; editable y adaptable.
- Notion es una referencia de claridad y baja carga visual, no una plantilla que haya que copiar.
- Voz humana, directa y amable. Usar el mínimo texto que permita entender la acción; no añadir títulos o instrucciones redundantes.

### Paleta

| Uso | Color | Regla |
|---|---|---|
| Fondo claro principal | `#F6FFF8` | Base limpia y ligeramente verdosa; evitar el blanco frío como fondo de toda la página. |
| Superficie | `#FFFFFF` | Tarjetas, paneles y controles elevados. |
| Tinte suave | `#EAF4F4` | Selección, agrupación o apoyo visual discreto. |
| Verde niebla | `#CCE3DE` | Acento secundario en superficies o ilustración, sin competir con la acción. |
| Verde salvia | `#A4C3B2` | Detalle secundario, nunca color dominante de pantalla. |
| Tinta | `#171717` (o `#202421` en tokens compartidos) | Texto principal e iconos; contraste alto sobre superficies claras. |
| Acción y énfasis | `#F35B04` | Acción primaria y señal puntual. Usarlo con moderación; no pintar paneles enteros. |

En modo oscuro, conservar el mismo carácter con fondo `#101512`, panel lateral `#0C100E`, tarjetas `#1B221E`, selección `#232C27`, texto `#F6FFF8`, texto secundario `#AAB7AF` y el naranja de marca `#F35B04`. Los estados críticos/éxito conservan sus colores semánticos: no sustituirlos por el naranja.

### Formas, superficies y movimiento

- Tarjetas blancas de esquinas redondeadas y texto alineado a la izquierda. La jerarquía se construye con espacio, tipografía y superficie, no con marcos gruesos.
- No usar rebordes negros ni contornos gruesos para indicar selección. Preferir elevación pequeña, sombra difusa, tinte cálido muy suave o un halo naranja tenue, con transición breve y sin saltos de layout.
- Mantener separaciones generosas pero eficientes; reducir ruido y repetición. En teléfono priorizar controles táctiles cómodos sin desperdiciar ancho.
- Las líneas divisorias, cuando sean imprescindibles para separar campos o datos, deben ser finas y de bajo contraste; no decorar cada tarjeta con borde.
- Respetar `prefers-reduced-motion`; la respuesta visual debe ser sutil, no necesaria para entender el estado.
- Las cantidades editables se muestran en controles compactos casi cuadrados, con radio de 10–12 px; no usar píldoras, marcos negros ni esquinas filosas.
- El historial que crece con el tiempo debe vivir plegado o en una vista secundaria. Nunca debe empujar la operación diaria varios pliegues hacia abajo.
- La paleta clara u oscura se aplica antes de la primera pintura del navegador. No se acepta un destello de la interfaz anterior durante la carga.
- Una ventana operativa prioriza nombre, campos y acción. Los datos técnicos de auditoría pueden conservarse en la lógica, pero no deben convertirse en párrafos explicativos dentro del formulario.
- **Regla de explicación cero:** si una acción o dato necesita un párrafo para entenderse, primero corregir jerarquía, orden, etiqueta, forma, color o estado visual. El texto complementario se reserva para errores, confirmaciones y consecuencias que no puedan expresarse sin perder seguridad; nunca para compensar una interfaz confusa.

### Dibujo e iconografía

- Lenguaje “lápiz y papel”: trazo humano, sencillo, monocromo o de tinta, con irregularidad controlada. Dibujos cerca de cero: se usan solo si comunican algo mejor que un icono.
- Evitar ilustraciones genéricas, emoji, clip-art, decoración abundante y símbolos ambiguos. Mantener pocos trazos, grosor coherente y lectura reconocible a tamaño móvil.
- Los dibujos de áreas, el icono de Inicio/casa y el futuro logo pueden compartir esta familia; el logo/rostro final sigue pendiente de decisión.

### Navegación compacta en teléfono

- La barra inferior conserva los cuatro accesos cotidianos de cada sede. Las rutas restantes se abren con un deslizamiento desde el borde izquierdo; no se añade un botón visible a la cabecera.
- Durante el arrastre el cajón, el velo y el desenfoque siguen el dedo. Al abrir, el cajón se superpone al contenido sin cambiar su tamaño; al cerrar puede tocarse fuera, usar Escape o deslizar el panel hacia la izquierda.
- El cajón tiene hasta `86vw` (máximo `344px`) para que las etiquetas completas sean legibles, incluidos módulos que no caben en la barra inferior. Los permisos y restricciones por sede siguen siendo la autoridad: no se habilita Mesas, Bodega ni ninguna ruta mediante CSS.
- Respetar `prefers-reduced-motion`: las transiciones no son necesarias para comprender ni operar el menú.

## 2026-10-30 — Punto 1: selector de sede y modo oscuro

- El selector de sede toma sus superficies directamente del tema guardado antes de que JavaScript monte una sede. En oscuro usa fondo `#101512`, tarjeta y botones `#1B221E`, texto `#F6FFF8`, secundario `#AAB7AF` y énfasis `#F35B04`.
- No depende de clases de una vista interior: volver a elegir sede, recargar la aplicación o iniciar una sesión con el tema oscuro guardado conserva la misma apariencia sin un destello blanco.
- Se incorporó una prueba de navegador que guarda el tema oscuro, reinicia la sesión y comprueba colores reales del selector. También valida que no haya desborde en escritorio y teléfono.

## 2026-10-30 — Punto 3A: riel lateral compacto en escritorio

- En pantallas con puntero preciso, la navegación reserva siempre un riel de `72 px`. Al posar el puntero o navegar con teclado, el riel se abre hasta `208 px` **sobre** el contenido: el lienzo de trabajo conserva su ancho y posición.
- Los iconos usan la misma coordenada en ambos estados. Las etiquetas aparecen con opacidad y desplazamiento sutil; no hay reordenamiento, salto vertical ni títulos de grupo que empujen las acciones.
- El riel conserva rutas, permisos, sede y estado activo existentes. En dispositivos táctiles no cambia todavía: el gesto de arrastre desde el borde izquierdo se implementará como el siguiente punto independiente.
- La prueba visual cubre compacto, expansión por puntero, repliegue, ausencia de desborde y la consistencia del riel en Inventario, Mesas, Arqueo, Movimientos, Productos, Reparto, Recetas, Historial, Mermas y Ajustes.

## 2026-10-30 — Punto 3B: navegación por gesto en teléfono

- Se reemplazó el disparador visual del menú por el gesto desde los primeros `28 px` del borde izquierdo. El panel acompaña el arrastre en tiempo real; un gesto corto o vertical no interfiere con el scroll ni abre el menú.
- Al revelarse, el contenido —incluida la barra inferior— queda atenuado y difuminado. El panel no redimensiona ni desplaza la vista que queda detrás. Se cierra tocando fuera, con Escape o arrastrándolo hacia la izquierda.
- Se mantuvieron los mismos botones originales dentro del cajón, por lo que rutas, permisos, sede, estado activo y handlers siguen siendo únicos. La barra inferior permanece fija y sus cuatro rutas operativas no cambian.
- Cobertura automatizada: 390×844, 320×700, horizontal, claro/oscuro, apertura/cierre por gesto, toque exterior, Escape, todas las rutas de Local 1 y las rutas de Bodega, permisos de Mesas, barra inferior, ausencia de errores JavaScript y riel de escritorio. Sin escrituras comerciales.

## 2026-10-30 — Punto 5: Ajustes → Áreas de inventario

- Las áreas dejaron de dibujarse como filas administrativas comprimidas. Cada una es ahora una tarjeta de superficie suave: nombre editable, contexto de productos/unidades, orden numérico compacto y acciones al final de la lectura.
- Crear un área usa la misma composición y no promete stock: la única nota visible es “Se crea sin stock”. Las cifras son texto auxiliar, no cápsulas ni barras.
- Se conservaron IDs, atributos `data-*`, botones, RPC, permisos y validaciones existentes; el cambio es estrictamente de jerarquía, espaciado y contraste.
- Pruebas visuales verifican tarjetas, separación de campos/acciones y ausencia de desborde a 1440×900 y 390×844. Sin escrituras comerciales.

## 2026-10-30 — Punto 8: ficha de producto

- La ficha muestra una secuencia de trabajo directa: nombre/categoría cuando son editables, cantidad, límites, vencimiento y acciones disponibles. Área, sección y cantidad solo aparecen cuando aplican a esa ficha.
- Se retiraron de la vista los resúmenes de saldo físico, explicaciones del ledger, clasificación histórica, motivo visible de conteo y nota visible de urgencia. La auditoría conserva internamente el motivo seguro de conteo y las mismas validaciones.
- Las acciones rápidas se agrupan sólo si están disponibles; una única acción ocupa todo el ancho. Los botones y handlers de urgente, merma, Fudo, vencimientos, guardado, cancelación y eliminación se mantienen sin cambiar su contrato.
- Se adopta la Regla de explicación cero de esta guía para toda la aplicación.

## 2026-10-30 — Reparto: recepción

- La recepción diaria se organiza como una secuencia de tarjetas: encabezado del reparto con progreso, producto y cantidad solicitada, llegada, cifra recibida y descarte. Se eliminó la explicación técnica visible de Fudo; la integración conserva exactamente el mismo handler y ocurre después de recibir.
- Las cantidades usan controles compactos de esquinas suaves, la llegada y el descarte tienen estados semánticos verde/rojo, y los repartos resueltos reducen su presencia visual sin ocultar la posibilidad de deshacer.
- Armar pedido, pendientes, cerrados y la ventana de recepción por fechas usan las mismas superficies, espaciado, contraste y radio de la identidad Lápiz y papel, en claro y oscuro. La recepción hacia áreas también elimina la ruta física repetida en cada línea y muestra solo pedido, fecha útil cuando existe y controles de recepción.
- No se modificaron RPC, stock, Fudo, permisos, restricciones por sede ni el flujo de perecederos. Marcar X sigue poniendo cantidad cero hasta la confirmación; las fechas siguen siendo obligatorias para productos perecederos.

## 2026-10-30 — Reparto: búsqueda compacta

- Cada resultado de búsqueda muestra solo la decisión necesaria: producto, disponibilidad y acción para agregar. Se retiraron rubro, mínimos y máximos repetidos que ocupaban espacio sin ayudar a armar el reparto.
- La disponibilidad es un contador compacto de estado y el “+” una acción táctil clara. En teléfono las filas bajan a `48 px`, conservan el nombre truncado de forma segura y controles de `32 px`; no aparece texto auxiliar ni una segunda línea.
- La búsqueda conserva sus mismos candidatos, regla de congelador, carrito, cantidades, handlers y restricciones por sede. El ajuste es únicamente visual y no escribe datos.

## 2026-10-30 — Inventario por área: pestaña Repartos

- Cada área operativa tiene dos vistas separadas: **Inventario** y **Repartos**. El inventario ya no empieza con documentos de llegada ni el historial crece debajo de los productos.
- Repartos reúne las recepciones abiertas bajo “Por recibir” y mantiene los documentos cerrados en un bloque plegado “Cerrados”, limitado a los registros recientes que ya entrega el contrato. La navegación no crea una segunda fuente ni una nueva ruta comercial.
- Cambiar de pestaña no escribe, no modifica cantidades y no altera permisos, sede, stock, Fudo o el contrato de recepción. La bandeja se mantiene cargada sin hacerse visible fuera de su pestaña.

## 2026-10-23 — Corrección visual transversal: Ajustes, Productos y recepciones por área

### Plan ejecutado

1. Se fijó la identidad Lápiz y papel antes de la primera pintura para eliminar el destello de colores antiguos al abrir Local 1.
2. Se corrigieron contraste y composición de Ajustes, primero Áreas de inventario y luego Secciones y turnos, sin cambiar sus RPC ni permisos.
3. Se incorporó `productos` al encabezado visual compartido y se rehízo su hoja de estilos con los tokens oficiales para impedir que vuelva a la estética anterior al navegar.
4. Se simplificó la ficha de producto del área: desaparecen el resumen técnico, el texto de conteo, el motivo visible y la nota de urgencia. El motivo auditado continúa enviándose internamente con su valor seguro predeterminado.
5. Bodega → Enviar usa menos texto, resultados sin identificadores técnicos, cantidades rectangulares y una acción de quitar compacta.
6. Las recepciones del área se presentan como lista: nombre, cantidad preparada, confirmación de llegada, cantidad recibida y X para marcar cantidad cero. El historial cerrado queda plegado y muestra como máximo los ocho registros más recientes al abrirlo.
7. Se verificaron escritorio y 390×844, modo claro/oscuro, teclado, modales, navegación, ausencia de desbordes y conservación de RPC protegidas.

### Límites funcionales respetados

- La X no borra un ítem ni escribe de inmediato: cambia la cantidad recibida a cero y la confirmación final conserva `reparto_area_recibir`, su referencia idempotente y el motivo auditado.
- La fecha de vencimiento heredada del lote de Bodega se muestra en la lista. La RPC vigente solo recibe `item_id` y `cantidad_recibida`; por eso esta pasada no inventa un selector que no podría persistir una fecha nueva. Añadir o corregir vencimiento al recibir requiere una decisión de contrato y backend.
- No se cambió arquitectura, esquema, stock, Fudo, Lama, reglas comerciales, permisos ni restricciones por sede. No se habilitó ninguna merma pausada.

### Archivos y comprobaciones

- Aplicación: `index.html`, `identity-modules.css`, `panel-productos.css`.
- Pruebas ajustadas/ampliadas: `pruebas/identidad-modulos.mjs`, `pruebas/inventario-areas.mjs`, `pruebas/fase2-repartos-area.mjs`.
- Cobertura nueva: contraste de Ajustes, filas sin solapamiento, identidad persistente de Productos, recepción compacta, historial plegado, X sin escritura inmediata, modal simplificado, desktop y teléfono.
- Pasaron las pruebas dirigidas `identidad-modulos`, `inventario-areas`, `fase1-ajuste-stock`, `fase2-repartos-area`, `panel-productos`, `movil-navegacion` y `pantalla-sana`, además de `git diff --check`. La suite global todavía se detiene en dos fixtures históricos ajenos a esta pasada: `ajustes-navegacion` espera el permiso antiguo desde `app_permisos` en lugar de la RPC vigente, y `estetica-no-rompio-nada` intenta usar el buscador antes de entrar a un área desde la portada. Ninguno alcanza ni contradice los flujos modificados; no se maquillaron esos fixtures dentro de un cambio visual.
- Los dos directorios de prototipos locales no rastreados permanecieron intactos y fuera de la publicación.

## 2026-10-21 — P4: Mesas consume recetas manuales multiárea

Se implementó únicamente P4 en `leoalejoleo1537/llamita-plus`, Supabase `llamita-plus` / `iuryhsjucblmebdogewa`, destino `origin/master`. Fudo permaneció inactivo y P5 continúa pendiente.

### Resultado visible

- Mesas usa los **Productos de venta** neutrales de P3. La carta distingue productos listos, borradores y configuraciones no vendibles; muestra disponibilidad calculada y áreas de origen. Un producto sin receta lista, sin origen activo o sin saldo no puede agregarse.
- Añadir a una mesa no reserva ni consume. **Confirmar comanda** toma un snapshot de la receta vigente y reserva atómicamente todos los ingredientes, incluso si pertenecen a áreas distintas. Si uno falla no se crea una comanda ni quedan reservas parciales.
- **Cerrar mesa** consume el snapshot una sola vez desde el ledger y mantiene los lotes mediante FIFO. Anular antes del cierre libera; anular después del consumo registra movimientos compensatorios una sola vez.
- El circuito directo de Fase 4 queda rotulado como **Compatibilidad directa**. Cada línea usa exclusivamente el motor neutral o el directo; ambos descuentan sus reservas al calcular disponibilidad, evitando sobreventa y doble descuento.
- Una falla técnica al consumir no oculta el problema ni bloquea el cierre comercial: la reserva queda en error y se registra una alerta pendiente auditable.

### Backend y seguridad

- Migración instalada: `20261021193322_p4_lama_recetas_manuales` (archivo fuente `supabase/migrations/20261021210000_p4_lama_recetas_manuales.sql`).
- `cuenta_items.producto_venta_id` enlaza la línea comercial con su identidad neutral. Las nuevas tablas privadas `stock_internal.lama_receta_reservas` y `lama_receta_reserva_movimientos` conservan el snapshot por componente y sus movimientos definitivos/compensatorios.
- RPC nuevas: `lama_productos_venta_listar()` y `cuenta_producto_venta_agregar(...)`. Se adaptaron `cuenta_confirmar(...)` e `item_anular(...)`, y el cierre reutiliza `consumir_cuenta_lama(...)` para ambos motores. Sesión y `puede_lama` se validan mediante S1; las RPC son `SECURITY DEFINER`, `search_path=''`, solo `authenticated`. Las tablas tienen RLS forzada y no exponen DML a navegador, `anon` ni `service_role`.
- La concurrencia se serializa por producto+ubicación con bloqueos ordenados; las claves únicas por línea/componente y movimiento hacen idempotentes confirmación, cierre y anulación.

### Pruebas y conteos

1. `sql/2026-10-p4-pruebas-lama-recetas-manuales.sql`, ejecutado en `BEGIN … ROLLBACK`: receta de una línea, combo, dos áreas, reserva sin consumo, cierre único, liberación y compensación, falta de saldo, origen inactivo, idempotencia, atomicidad, falla física inesperada con cierre comercial y alerta, raíz, usuario Lama, usuario sin permiso y anónimo. No dejó datos sintéticos.
2. `pruebas/p4-lama-recetas-manuales.mjs` validó contratos, bloqueos, separación de motores y ausencia de Fudo/recetas heredadas. Chromium real validó catálogo, borradores, stock, escritorio y 390×844; la regresión visual P3 también pasó.
3. `npm test` completo y `git diff --check` pasan. Los advisors no atribuyen a P4 RLS abierta, ejecución anónima ni `search_path` inseguro. Permanecen avisos globales históricos fuera de alcance; los índices P4 aparecen aún sin uso porque el catálogo neutral y las reservas nacen vacíos.

Conteos persistentes pre/post idénticos: 1.438 productos; stock proyectado 15.456; saldo ledger 9.334,7; 410 movimientos ledger; 42 lotes; 0 transferencias; 1 reparto; 396 recetas/514 ingredientes heredados; 1.377 productos y 15.357 movimientos Fudo; 64 cuentas; 33 pagos; 2 movimientos de caja. P4 quedó con 0 productos neutrales listos, 0 reservas por receta y 0 enlaces a movimientos. `origen_pos` continúa en `ninguno`.

Los 321 productos activos del espejo antiguo de Mesas continúan en compatibilidad directa y **ninguno tiene fuente directa activa**; por tanto, no son vendibles por stock hasta configurarlos o reemplazarlos por Productos de venta con receta manual. No se accedió ni modificó Café del Desierto / Llamita Stock.

**Siguiente nodo según la secuencia aprobada: P7A — respaldo, restauración ensayada y reinicio limpio. P5 — adaptador Fudo hacia este mismo motor neutral— sigue pendiente y no activo.**

## 2026-10-21 — P3: catálogo comercial neutral y recetas manuales

Se implementó únicamente P3 en `leoalejoleo1537/llamita-plus`, Supabase `llamita-plus` / `iuryhsjucblmebdogewa`, destino `origin/master`. P4 permanece pendiente y no activo.

### Resultado visible

- `Menú → Panel de productos` tiene dos pestañas: **Insumos** conserva el motor P1/P2; **Productos de venta** administra una identidad comercial neutral, nombre, precio y estado borrador/listo.
- La receta se arma siempre a mano. Cada línea elige un insumo existente, una cantidad decimal positiva y una configuración producto–área activa como origen. Las líneas se pueden añadir, quitar y reordenar.
- Un producto puede guardarse como borrador sin receta. Para marcarlo listo el servidor exige al menos un componente y valida todos los orígenes. Cada guardado con ingredientes crea una versión nueva y conserva las anteriores.
- **Crear insumo** desde la receta abre la pestaña Insumos, exige al menos un área activa y vuelve al editor con el nuevo insumo y su origen seleccionados. No crea recetas, reservas ni publicaciones POS.

### Backend y seguridad

- Migraciones instaladas: `20261021181318_p3_catalogo_comercial_recetas_manuales` y `20261021181440_p3_indices_fk_catalogo_comercial`.
- Tablas privadas nuevas: `catalogo_internal.productos_venta`, `recetas_venta`, `receta_venta_componentes`, `producto_venta_pos_enlaces` —vacía y reservada para el enlace explícito futuro— y `producto_venta_operaciones`.
- RPC nuevas: `panel_ventas_listar`, `panel_ingredientes_listar` y `panel_venta_guardar`. Usan sesión, capacidades S1, `SECURITY DEFINER`, `search_path=''`, idempotencia y revisión optimista. Solo `authenticated` ejecuta; `anon` no lee ni escribe y el navegador no tiene DML sobre las tablas.
- La identidad no depende de `fudo_productos` ni usa `fudo_product_id`. No se modificaron `recetas`/`receta_items` heredados, reservas Lama, fuentes directas, ledger, stock, repartos, caja, pagos o Edge Functions.

### Pruebas y conteos

1. `sql/2026-10-p3-pruebas-catalogo-comercial-recetas.sql`, ejecutado completo en `BEGIN … ROLLBACK`: borrador sin receta, receta manual de una línea, tres ingredientes, decimal `0,5`, origen en otra área, orden, idempotencia, rechazo de cero/negativo/origen inactivo/receta vacía lista, raíz, usuario operativo, usuario sin permiso y anon.
2. Chromium: `pruebas/p3-catalogo-comercial.mjs` validó las dos pestañas, guardado de borrador, receta multiárea, retorno desde Crear insumo y ausencia de desborde en 390×844. Regresiones `panel-productos.mjs` y `p2-unificacion-altas.mjs` pasan.
3. `npm test`, sintaxis JavaScript y `git diff --check` pasan. Advisors no atribuyen una apertura de seguridad a P3; los avisos globales anteriores permanecen. Los índices de FK nuevos eliminan los avisos de FK sin índice del esquema P3; aparecen como no usados porque las tablas nacen vacías.

Conteos persistentes pre/post idénticos: 1.438 productos; stock proyectado 15.456; saldo ledger 9.334,7; 410 movimientos ledger; 42 lotes; 0 transferencias; 1 reparto; 396 recetas/514 ingredientes heredados; 1.377 productos y 15.357 movimientos Fudo; 0 reservas Lama; 64 cuentas; 2 movimientos de caja. El catálogo neutral quedó vacío: 0 productos de venta, 0 versiones, 0 componentes y 0 enlaces POS.

Rollback técnico: `sql/2026-10-p3-catalogo-comercial-recetas.rollback.sql`, aplicable antes de uso real y después de retirar las RPC. Archivos funcionales: `index.html`, `panel-productos.js`, `panel-productos-venta.js`, `panel-productos.css`, migraciones y pruebas P3. No se accedió ni modificó Café del Desierto / Llamita Stock.

**Siguiente nodo: P4 — Mesas consume recetas y componentes desde una o varias áreas, pendiente y no activado.**

## 2026-10-21 — P2: unificación de entradas de creación

Se implementó únicamente P2 en `leoalejoleo1537/llamita-plus`, Supabase `llamita-plus` / `iuryhsjucblmebdogewa`, destino `origin/master`. P3 permanece pendiente y no activo.

### Resultado visible

- **Bodega**, el botón general, Ajustes y **cualquier área de Local 1** abren el Panel de productos. Al entrar desde un área, esta queda preseleccionada y la persona ve primero la búsqueda del maestro central para reutilizarlo antes de crear otro.
- **Recetas → Crear ingrediente** abre el mismo Panel. Al guardar vuelve al editor con la representación Local 1 seleccionada; el taller vuelve con el insumo elegido. El Panel no crea `recetas` ni `receta_items`.
- El contexto de origen se muestra dentro del Panel y **Volver** restituye la pantalla anterior. No se rediseñaron el Panel, inventario ni navegación.
- El alta antigua de Enlaces queda oculta y redirigida. Se eliminó de ese flujo la invocación que publicaba en Fudo y creaba una receta automáticamente.

### Backend y cierre coordinado

- Migración instalada: `20261021112507_p2_unificar_altas_productos`.
- `panel_producto_guardar` admite `crear_representacion=true`: crea o reutiliza la representación enlazada de Local 1 con saldo cero. Si Recetas todavía no elige un área, la deja explícitamente **Sin asignar**, sin existencia física.
- `authenticated` y `anon` perdieron INSERT directo en `public.productos`; se retiraron las políticas INSERT abiertas. Las RPC `crear_producto_enlazado`, `producto_plaza_crear`, `producto_plaza_crear_configurado` y `bodega_producto_area_agregar` ya no son ejecutables por la aplicación. `panel_producto_guardar` conserva `SECURITY DEFINER`, `search_path=''`, sesión y capacidad S1, y ejecución exclusiva de `authenticated`.
- No se revocó todavía el DML histórico de mantenimiento sobre `producto_enlace`: la pantalla Enlaces aún crea/quita vínculos manuales fuera del alta de productos. Es una dependencia concreta distinta y debe migrarse a RPC protegida en un bloque posterior; cerrarla aquí habría roto una función visible.

### Pruebas y conteos

1. `sql/2026-10-p2-pruebas-unificacion-altas.sql`, ejecutado completo en `BEGIN … ROLLBACK`: raíz, usuario operativo con edición, usuario sin permiso y ACL anónima; alta desde área, representación para Recetas, mismo insumo en dos áreas, idempotencia, DML directo bloqueado y las cuatro RPC heredadas cerradas. Verificó ausencia de saldos, existencias, lotes, movimientos, repartos, recetas automáticas, Fudo y reservas Lama.
2. Chromium: `pruebas/p2-unificacion-altas.mjs` validó alta Bodega, búsqueda/reutilización, área preseleccionada y retorno real al editor de Recetas con el insumo seleccionado. `pruebas/panel-productos.mjs` confirmó la regresión P1. Ambas pasan.
3. `npm test` ordinario pasa; `git diff --check` y sintaxis JS pasan. La suite completa forzada con Chromium vuelve a detenerse primero en `ajustes-navegacion.mjs`: su mock histórico no entrega `permisos_mios()` con la forma vigente y no muestra Ajustes. Es la misma falla reproducida antes de P1; no se modificó una prueba ajena para ocultarla.
4. Advisors no muestran una apertura nueva en P2. Persisten hallazgos globales anteriores de vistas/functions legacy y políticas duplicadas; la RPC P2 permanece cerrada para anon y las cuatro RPC antiguas aparecen cerradas para anon/authenticated.

Los conteos persistentes pre/post fueron idénticos: 1.438 productos; stock proyectado 15.456; saldo ledger 9.334,7; 410 movimientos ledger; 42 lotes; 0 transferencias; 1 reparto de área; 396 recetas/514 ingredientes; 15.357 movimientos y 1.377 productos espejo Fudo; 0 reservas Lama; 2 movimientos de caja. Las pruebas SQL no dejaron productos ni operaciones sintéticas.

Archivos funcionales: `index.html`, `panel-productos.js`, `panel-productos.css`, migración P2, prueba SQL y pruebas de interfaz actualizadas. No se modificaron ledger, `stock_transferir`, Fudo/Edge Functions, Lama, Mesas, reservas, recetas, caja, repartos, precios o stock. No se accedió ni modificó Café del Desierto / Llamita Stock.

**Siguiente nodo: P3 — productos de venta y recetas manuales, pendiente y no activado.**

## 2026-10-21 — P1: núcleo del Panel de productos

P0 se publicó primero en `34b4b48`. Se implementa únicamente P1 en `leoalejoleo1537/llamita-plus`, destino `origin/master`, Supabase `llamita-plus` / `iuryhsjucblmebdogewa`. El commit de esta entrada se identifica con `git log --grep='Implementar P1'`. P2 y posteriores no se activan.

### Resultado visible y coherencia del maestro

- **Menú → Panel de productos**, desde Bodega o Local 1, con `puede_editar`; disponible también en demostración. Buscar maestros, crear insumo, editar nombre/unidad/costo y configurar una o varias áreas con sección física, mínimo/máximo y principal opcional. Los grupos se eligen del catálogo existente; no hay clasificación automática.
- `productos` de sede `central` conserva la identidad maestra. El Panel muestra esa identidad una sola vez. Una edición adopta el maestro como `panel_gestionado` y propaga nombre, unidad, costo y condición pendiente a **todas** sus representaciones enlazadas de plaza en la misma transacción. Un enlace posterior hereda esos atributos mediante trigger. No se escriben cantidades.
- Los atributos administrados quedan bloqueados fuera del motor, tanto en central como en sus representaciones. El modal legacy muestra el mensaje de ir al Panel si intenta modificarlos. No se obliga a una segunda edición. La unidad es una etiqueta: cambiarla no convierte existencias; enlaces con factor distinto de 1 se rechazan para revisión explícita.
- No se adopta ni renombra masivamente el catálogo histórico. Antes de su primera edición desde Panel, cada maestro conserva el comportamiento anterior. P2 unificará entradas y retirará escritores legacy coordinadamente. No se afirma que todo el DML histórico ya esté cerrado.
- Al configurar áreas se reutiliza `producto_enlace`: con una representación activa se reutiliza; con varias se exige escoger; sin ninguna se crea plaza enlazada, saldo cero. Un homónimo sin enlace o una representación archivada exige revisar identidad: nunca se adivina ni fusiona. Una representación se configura en varias áreas; no se crea una por área. Omitir un área conserva su configuración; este bloque no implementa retirarla.
- Costo inicial cero/pending; puede completarse manualmente por unidad. Nuevas fichas y configuraciones no generan stock, lotes, movimientos, recetas, ingredientes ni enlaces Fudo.

### Archivos y objetos

- `index.html`: entrada, formulario, guard de acceso y mensaje claro al intentar editar atributos protegidos por una ruta antigua.
- `panel-productos.js` / `.css`: lectura, formulario, reintento con referencia estable, validación y presentación acotada según guía Darío. Sin DML navegador ni llamadas Edge/Fudo.
- `supabase/migrations/20261021020517_p1_panel_productos.sql`: aplicada, versión instalada confirmada. Agrega `costo_compra`, `costo_pendiente`, `panel_gestionado`, `catalogo_revision` a productos; índice único de nombre normalizado central activo; esquema privado `catalogo_internal`, auditoría `operaciones` y permiso transitorio privado por transacción/backend. Los saltos de secuencia producidos por tests revertidos son esperables; no equivalen a filas persistentes.
- RPC `panel_productos_listar(text,bigint)` y `panel_producto_guardar(uuid,bigint,bigint,jsonb)`: S1 `editar`, sesión/Auth validada, SECURITY DEFINER con search_path vacío, solo authenticated; sin EXECUTE para anon/service_role/PUBLIC. Helpers privados sin ejecución de aplicación; RLS forzada y política cerrada. Reutiliza `stock_internal.guardar_configuracion_producto`, sin modificarlo.
- Triggers `catalogo_proteger_producto`, `catalogo_enlace_coherente` y auditoría inmutable. Referencia+actor+contenido idénticos recuperan resultado; referencia con otro contenido/actor se rechaza. Bloqueos por referencia/nombre/maestro y revisión optimista evitan sobrescrituras y altas duplicadas.
- `sql/2026-10-p1-pruebas-panel-productos.sql`, `pruebas/panel-productos.mjs` y rollback `sql/2026-10-p1-panel-productos.rollback.sql`.

### Pruebas y evidencia

1. SQL en BEGIN/ROLLBACK sobre la definición instalada: alta maestro y plaza con dos áreas, cero existencias/lotes, reintento, referencia inválida, duplicado, segunda representación histórica y herencia, edición operativa de nombre/unidad/costo coherente en las tres filas, auditoría, revisión obsoleta, rechazo de edición directa/desvinculación, inmutabilidad, fallo tardío que revierte todo, ambigüedad y elección explícita, configuración omitida conservada, usuario no autorizado, anónimo y ACL. También alta/lectura con `SET LOCAL ROLE authenticated`; identidades simuladas en SQL, no inicio de sesión real ni JWT compartido. Concurrencia validada mediante bloqueo + revisión obsoleta equivalente al segundo guardado, no prueba de carga de dos clientes simultáneos.
2. Navegador Chromium contra aplicación local y Supabase simulado: ruta real, alta multiárea, sección y límites fraccionarios, costo pendiente cero, edición, elección explícita de representación, respuesta perdida/reintento idéntico, rechazo UI sin permiso y acceso móvil. Capturas revisadas a 1366 y 390 px, sin desbordamiento horizontal. `pruebas/movil-navegacion.mjs` con Chromium pasa; no se rediseñó la navegación.
3. `npm test` ordinario pasa; este entorno requiere CHROME_PATH para que las pruebas de pantalla encuentren Chromium, por lo que ese comando salta las visuales. La ejecución ampliada `CHROME_PATH=/usr/bin/chromium PRUEBAS_HTTP_BASE=... npm test` falla en `ajustes-navegacion.mjs`: el mock devuelve `{data:[]}` a `permisos_mios`, no concede Ajustes y el clic expira. Reproducido sobre copia limpia de `34b4b48` con idéntico resultado antes de P1. No se altera la prueba legacy ni se presenta la suite ampliada como aprobada. Las dos pruebas visuales pertinentes se ejecutaron explícitamente y pasaron. `git diff --check` y sintaxis JS pasan.
4. Advisors: las dos RPC aparecen en [aviso de SECURITY DEFINER ejecutable por authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), comportamiento intencional con autorización S1 probada; el [índice del actor aún sin uso](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index) se conserva para la FK. No hay hallazgo nuevo de RLS abierta, EXECUTE anónimo o search_path inseguro en P1. Los hallazgos históricos no se modificaron.

### Conteos pre/post

Los conteos y hashes del contenido de 16 tablas coinciden (para productos se excluyen del hash solo las cuatro columnas nuevas). No quedaron filas de prueba, operaciones P1 ni permisos transitorios.

| Objeto | Antes | Después |
|---|---:|---:|
| productos / enlaces / configuraciones área | 1.438 / 513 / 6 | 1.438 / 513 / 6 |
| stock proyectado global | 15.456 | 15.456 |
| saldo ledger central+plaza | 9.334,7 | 9.334,7 |
| movimientos ledger / filas existencias | 410 / 409 | 410 / 409 |
| lotes / transferencias / repartos de área | 42 / 0 / 1 | 42 / 0 / 1 |
| movimientos Fudo / espejo Fudo | 15.357 / 1.377 | 15.357 / 1.377 |
| recetas / ingredientes | 396 / 514 | 396 / 514 |
| reservas Lama / cuentas / pagos / movimientos caja | 0 / 64 / 33 / 2 | 0 / 64 / 33 / 2 |

El total global incluye las sedes históricas angamos/bodega; central (4.750,5) + plaza (4.584,2) concilian con ledger 9.334,7. No se cambian saldos históricos.

### Límites, rollback y siguiente nodo

Rollback SQL provisto únicamente antes de uso real: se niega si hay auditoría o maestros adoptados; no borra evidencia. No se ejecutó el rollback en producción. Después de uso, retirar la interfaz conservando datos/protecciones y planificar migración compensatoria. Revertir solo frontend no debe reabrir la edición independiente.

Pendientes: P2 reemplazará entradas antiguas Bodega/área/taller; los homónimos históricos y enlaces de conversión requieren resolución humana. La búsqueda del Panel devuelve hasta 100 maestros activos por consulta; no importa desde Fudo. Productos de venta y recetas manuales corresponden a P3; la función antigua fudo-crear-producto no se usa y deberá perder su receta automática antes de cualquier reutilización en P6. No hay sesión Auth real de usuario en la prueba visual ni validación manual en iPhone físico.

**Siguiente nodo: P2 — unificación de entradas de creación, pendiente y no activado.** Se conserva P1 → P2 → P3 → P4 → P7A → laboratorio → P5 → P6 → P7B. No se tocaron Fudo remoto, Lama, recetas, caja, repartos ni stock_transferir; Bodega solo recibe los atributos/guardas del catálogo descritos, no cambios operativos. No se accedió ni modificó Café del Desierto / Llamita Stock.

## 2026-10-20 — P0: preflight Panel de productos y decisiones de Alejo

- Preflight completado mediante lecturas sobre `7b8309d`, sin DML ni llamadas Fudo. Informe único: [37](37-p0-panel-productos-catalogo-recetas-fudo-reinicio.md).
- Verificadas altas paralelas, maestro central/representaciones, recetas ligadas a Fudo, reserva directa F4 y dependencias de respaldo/purga. Las tres Edge Functions de catálogo no están desplegadas; la fuente local crear-producto genera receta automática y autoriza por correo: debe refactorizarse antes de cualquier reutilización.
- Decisiones: catálogo comercial neutral; recetas siempre manuales; respaldo/purga ensayada conservando plano de mesas y configuración. Secuencia P1 → P2 → P3 → P4 → P7A → laboratorio → P5 → P6 → P7B.
- P1 debe resolver edición única y coherencia de nombre/unidad/costo entre maestro y plaza. Se autoriza solo P1 después del commit documental; no se activa P2 ni Fudo.
- No se accedió a Café del Desierto / Llamita Stock. Publicación exclusivamente documental en origin/master, comprobada con git diff --check.

## 2026-10-20 — Contrato operativo, Fase 4: disponibilidad y reservas Lama

- Estado: **COMPLETADA**. Fase 5 — recetas y combos con ingredientes de una o varias áreas — queda **PENDIENTE**, no activa.
- Entorno: repositorio `leoalejoleo1537/llamita-plus`, publicación en `origin/master`; Supabase Llamita Plus ref `iuryhsjucblmebdogewa`. No se accedió a Café del Desierto / Llamita Stock.
- Migraciones instaladas: `20261020112543_fase4_lama_reservas_stock` y `20261020113016_fase4_indices_fk`. Se crearon `stock_internal.lama_fuentes_directas`, su auditoría inmutable, `lama_reservas`, `lama_reserva_movimientos` y `lama_alertas`; todas tienen RLS forzada, política cerrada y ningún DML para roles de aplicación. La segunda migración cubre las claves foráneas nuevas.
- Fuente y disponibilidad: un producto directo se vincula explícitamente con una configuración principal producto–área activa y su ubicación. No hay coincidencia por nombre ni fallback a Bodega. La lectura protegida calcula saldo físico menos reservas `reservada`/`error`. Al cierre de esta fase, los 321 productos activos del catálogo de Mesas requieren revisión: ninguno tenía fuente directa instalada; se configura solo el subconjunto realmente directo en **Ajustes → Mesas** y los preparados/combos esperan Fase 5.
- Ciclo Lama: agregar una línea no mueve stock. `cuenta_confirmar` bloquea y reserva toda la comanda atómicamente; insuficiencia o falta de fuente rechaza todas las líneas. El cierre consume por FIFO desde el ledger y vincula cada movimiento; `item_anular` y `comanda_anular` liberan la reserva o revierten un consumo mediante entrada compensatoria. Repetir confirmar, cerrar o anular no duplica efectos.
- Continuidad comercial: el cierre de mesa valida líneas nuevas no confirmadas. Si aparece una falla técnica después de esa validación, la cuenta permanece cerrada y se registra reserva `error` más alerta pendiente visible; no se inventa stock ni se permite saldo negativo. Existe 1 línea histórica confirmada y abierta anterior a Fase 4 sin reserva: si se cierra, quedará señalada por esta vía de alerta y no tendrá descuento silencioso.
- RPC protegidas: `lama_fuentes_candidatas_listar`, `lama_fuentes_directas_listar`, `lama_fuente_directa_guardar`, `lama_stock_alertas_listar`, `cuenta_confirmar`, `item_anular` y `comanda_anular`. Usan `SECURITY DEFINER`, `search_path=''`, validan `auth.uid()`/`puede_lama`; la gestión de fuentes exige además capacidad operativa de ajustes. `EXECUTE` se concede solo a `authenticated`.
- Interfaz: Mesas muestra disponibilidad y área fuente en cada producto directo, error claro cuando falta configuración y banner de cierres con inventario pendiente. Ajustes permite guardar/quitar la fuente explícita. En teléfono se retiró el bloqueo por modo demostración y Mesas vuelve a mostrarse para raíz o `puede_lama`; el guard directo impide abrirla sin permiso. No se rediseñó el POS.
- Prueba `sql/2026-10-fase4-pruebas-lama-reservas.sql`, íntegra en `BEGIN … ROLLBACK`: reserva suficiente, falta de saldo/fuente, disponibilidad compartida, multilinea atómica, cierre y FIFO, liberación/reversa, doble operación, falla técnica recuperable, permisos y no negatividad. Resultado: 0 fuentes, 0 reservas y 0 alertas sintéticas persistentes.
- Conteos antes/después idénticos: 1.438 productos; stock proyectado 15.456; 410 movimientos del ledger; 409 filas de existencias; 42 lotes; 0 transferencias; 1 reparto de área; 15.357 movimientos Fudo; 0 eventos del motor Lama histórico; 396 recetas; 2 movimientos de caja; 33 pagos; 64 cuentas; 0 saldos negativos.
- Regresión: `npm test` completo y la prueba estática `pruebas/fase4-lama-reservas.mjs` pasan. Además, `pruebas/movil-navegacion.mjs` pasó con Chromium del sistema en 390×844 y escritorio: Mesas visible/navegable con permiso aun en demostración, oculta y bloqueada por ruta directa sin permiso, Bodega sin Mesas y consola sin errores. `git diff --check` pasa.
- Advisors: los objetos nuevos conservan `search_path` seguro, grants acotados e índices de claves foráneas. El advisor informa RPC `SECURITY DEFINER` accesibles a `authenticated`, exposición intencional y protegida por validación interna; los demás avisos son heredados y quedaron fuera del alcance.
- Rollback: `sql/2026-10-fase4-lama-reservas-stock.rollback.sql` aborta al encontrar fuentes, reservas o alertas reales; antes del uso retira únicamente el motor Fase 4 y restaura las funciones Lama reemplazadas. Después de uso corresponde reconciliación auditada, no borrar historial.
- No se modificaron Fudo ni sus Edge Functions, recetas, Bodega, repartos, `stock_transferir`, precios, pagos, caja o arqueos. No se consultó ni modificó Café del Desierto / Llamita Stock.

## 2026-10-20 — Contrato operativo, Fase 3: urgencias manuales por área

- Estado: **COMPLETADA**. Fase 4 — disponibilidad y reserva de stock en Lama — queda **PENDIENTE**, no activa.
- Preflight de stock: la variación de 15.438 a 15.453 se explicó completamente por el ajuste manual real de Fase 1 con referencia `e6e6dc47…f646`, producto **Café grano 250 gr**, ubicación Cafetería, actor operativo autenticado `6c3f…d642`, motivo **Conteo/corrección manual**, saldo 0 → 15. No fue una prueba revertida. Después de Fase 2 hubo una recepción real separada que añadió 3 unidades al mismo producto; por ello la línea base previa y posterior de esta fase es 15.456.
- Migración instalada: `20261020102356_fase3_urgencias_producto_area`. `producto_area_asignacion` incorpora prioridad manual, nota, actor y fecha. La configuración no contiene cantidades y la urgencia no se deriva automáticamente del saldo ni de mínimos/máximos.
- RPC protegidas: `producto_area_urgencia_guardar` y `producto_area_urgencias_listar`. Ambas son `SECURITY DEFINER`, `search_path=''`, validan internamente autorización S1 y solo conceden `EXECUTE` a `authenticated`; `PUBLIC`, `anon` y `service_role` permanecen sin ejecución.
- Interfaz de área: la ficha permite **Marcar urgente** / **Quitar urgente**, con nota opcional. La marca pertenece a la combinación producto–área; los urgentes aparecen primero y con distintivo visible. Marcar o quitar no mueve stock.
- Interfaz de Bodega: **Urgentes por área** agrupa destinos activos y muestra producto, saldo real del área, mínimo/máximo, nota y fecha. **Agregar** fija el destino correcto y usa el enlace explícito Bodega → Local 1; si hay varios lotes exige selección humana. El carrito impide mezclar destinos.
- Prueba SQL `sql/2026-10-fase3-pruebas-urgencias-area.sql`, íntegra en `BEGIN … ROLLBACK`: marcar/quitar, mismo producto en una y dos áreas, idempotencia, filtro por destino, propietario, administrador operativo con `puede_editar`, usuario común y anónimo. El fixture de segunda área fue transaccional y no dejó configuraciones ni urgencias persistentes.
- Regresión: `npm test` completo, `pruebas/fase3-urgencias-area.mjs`, `pruebas/pantalla-sana.mjs` y `git diff --check` pasan. Los casos Playwright se omiten automáticamente porque Chromium no está instalado.
- Conteos antes/después idénticos: 1.438 productos; stock proyectado 15.456; ledger neto 9.334,70 y 410 movimientos; 409 filas de existencias; 42 lotes; 0 transferencias; 1 reparto de área y 1 línea reales; 15.357 movimientos Fudo; 0 eventos Lama; 396 recetas; 2 movimientos de caja; 64 cuentas; 0 saldos negativos. Urgencias persistentes al cierre: 0.
- Advisors ejecutados: las RPC nuevas no aparecen como anónimas ni con `search_path` mutable. Permanecen hallazgos globales anteriores; el índice parcial nuevo figura sin uso por no existir aún urgencias reales.
- Rollback: `sql/2026-10-fase3-urgencias-area.rollback.sql` aborta si existe alguna urgencia activa; antes de uso elimina únicamente las dos RPC, el índice y las cuatro columnas añadidas.
- No se modificaron Fudo, Lama, caja, ventas/POS, recetas, lotes, repartos, `stock_transferir`, Bodega legacy ni cantidades. No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-20 — Contrato operativo, Fase 2: reparto Bodega → área

- Estado: **COMPLETADA**. Fase 3 — urgencias manuales para priorizar reposición desde Bodega — queda **PENDIENTE**, no activa.
- Entorno confirmado: repositorio `leoalejoleo1537/llamita-plus`, destino `origin/master`; Supabase Llamita Plus ref `iuryhsjucblmebdogewa`. No se accedió a Café del Desierto / Llamita Stock.
- Migración instalada: `20261020003917_fase2_repartos_recepcion_areas`. Se añadieron los documentos privados e inmutables `stock_internal.repartos_area` y `stock_internal.repartos_area_items`, con RLS forzada, política de rechazo y sin grants directos para roles de aplicación. El reparto legacy permanece bloqueado e intacto.
- Preparación: Bodega elige cualquier área activa de Local 1 desde el catálogo dinámico, busca una representación enlazada explícitamente y registra cantidades/lotes. `reparto_area_crear` crea solo el documento; no modifica stock, lotes, movimientos ni transferencias.
- Recepción: la bandeja se muestra dentro de cada área y `repartos_area_listar` filtra por su `area_id`. `reparto_area_recibir` exige todas las líneas, acepta decimales y cero, bloquea documento/producto/ubicación y cierra atómicamente. Una misma referencia y contenido retorna el resultado previo; contenido distinto se rechaza.
- Resultado físico: recepción exacta o parcial mueve únicamente lo recibido. Si el recibido supera lo preparado, el total físico recibido se acepta. El motor transfiere desde Bodega hasta su saldo disponible y registra el resto mediante `stock_ajuste_guardar`, vinculado a la línea; Bodega nunca queda negativa. Lotes conocidos conservan lote/vencimiento; lo desconocido permanece separado como **Sin lote / vencimiento no informado**.
- RPC instaladas: `reparto_area_catalogo_buscar`, `reparto_area_crear`, `repartos_area_listar`, `reparto_area_recibir`. Las cuatro son `SECURITY DEFINER`, `search_path=''`, `EXECUTE` solo para `authenticated`, con validación interna mediante autorización S1. `anon` y `service_role` no pueden ejecutarlas.
- Interfaz mínima: en Bodega, **Nuevo reparto**, selector dinámico de área, búsqueda, lote, cantidad y lista antes de enviar; dentro del área, **Repartos por recibir**, cantidades preparada/recibida y **Confirmar recepción**. No se rediseñaron Inventario, navegación ni móvil.
- Prueba `sql/2026-10-fase2-pruebas-repartos-area.sql`, íntegra en `BEGIN … ROLLBACK`: preparar sin alterar existencias; aislamiento entre áreas; exacta, parcial, cero y excedente; lote conocido y bucket sin lote; referencia repetida; reutilización inválida; saldo insuficiente absorbido como ajuste; fallo forzado entre líneas con rollback total; usuario autorizado/no autorizado; anónimo; no negatividad y conteos fuera de alcance. Resultado final: cero repartos/ítems sintéticos persistentes.
- Verificación local: `pruebas/fase2-repartos-area.mjs`, `pruebas/pantalla-sana.mjs`, `npm test` completo y `git diff --check` pasan. Las pruebas Playwright se omiten automáticamente porque Chromium no está instalado.
- Conteos observados después del rollback: 1.438 productos; proyección agregada 15.453; 409 movimientos ledger; 0 transferencias; 42 lotes; 396 recetas; 15.357 movimientos Fudo; 0 eventos Lama; 2 movimientos de caja; 64 cuentas; 0 saldos negativos. Hay un ajuste persistente de Fase 1 previo a esta ejecución; Fase 2 no creó datos de negocio persistentes.
- Advisors ejecutados. Las RPC nuevas no aparecen como ejecutables por anónimo ni con `search_path` mutable. Persisten avisos globales anteriores; rendimiento señala claves foráneas de las tablas nuevas sin índices dedicados, aceptable para volumen inicial y pendiente de medir antes de optimizar.
- Rollback técnico: `sql/2026-10-fase2-repartos-area.rollback.sql` solo procede antes del primer reparto real. Con actividad real, aborta para no borrar auditoría y exige una compensación auditada.
- No se modificaron Fudo, Lama, caja, recetas, ventas/POS, lotes legacy, Bodega legacy ni `public.repartos`/`public.reparto_items`. El núcleo `stock_internal.transferir_aplicar` se reutilizó sin cambiar su contrato.

## 2026-10-20 — Contrato operativo, Fase 1: conteo y ajuste auditado

- Estado: **COMPLETADA**. Fase 2 — recepción por área — permanece **PENDIENTE**, no activa.
- Repositorio y destino verificados: `leoalejoleo1537/llamita-plus`, publicación directa en `origin/master`. Supabase verificado como Llamita Plus, ref `iuryhsjucblmebdogewa`. No se accedió a Café del Desierto / Llamita Stock.
- Decisiones aplicadas: toda unidad admite decimales; ningún saldo de ubicación o lote puede ser negativo. Productos sin lote usan un bucket `lote_id=NULL`; productos lotificados presentan los lotes/vencimientos verificables y el bucket independiente **Sin lote / vencimiento no informado**. El ledger, no `producto_lotes.cantidad`, determina todos los saldos.
- Migración instalada: `20261020000825_fase1_ajustes_manual_ledger`. Añade `stock_internal.ajustes_manuales`, un registro inmutable de solicitud/idempotencia/resultado, y `stock_internal.movimientos.ajuste_manual_id`. El encabezado no almacena saldo operativo. Los deltas distintos de cero son movimientos `ajuste`; conteos sin diferencia conservan auditoría sin inventar movimientos de cantidad cero.
- RPC: `stock_ajuste_desglose_leer` valida sesión autenticada y ubicación; `stock_ajuste_guardar` valida `auth.uid()` y `puede_editar`, serializa referencia y producto/ubicación, calcula el delta del saldo final y rechaza referencias reutilizadas con contenido distinto. Las RPC son `SECURITY DEFINER`, `search_path=''`, con ejecución solo a `authenticated`; las tablas privadas mantienen RLS/grants cerrados.
- Interfaz: la ficha/modal de inventario muestra saldo actual, **Stock contado**, motivo inicial **Conteo/corrección manual** y botón Guardar conteo. Funciona en Bodega central y en la ubicación de Local 1 abierta (incluye áreas y Sin asignar) para cuentas con `puede_editar`. En productos con lotes se cuenta cada línea por separado; el lote desconocido aparece con el nombre aprobado. Reintentos usan la misma referencia; la actualización de la vista viene del ledger. `productos.stock_actual` sigue bloqueado como entrada y solo recibe su proyección mediante el trigger existente.
- Prueba transaccional `sql/2026-10-fase1-pruebas-ajuste-manual.sql`: pasó positivo y negativo decimal sin lote, saldo negativo rechazado, lote conocido, alta separada sin lote en producto lotificado, referencia repetida idéntica y distinta, conteo sin delta, proyección coherente, propietario raíz, administrador operativo real con `puede_editar`, usuario sin permiso, no negatividad, lock de producto/ubicación y límites de transferencias, lotes existentes, Fudo, Lama, recetas y caja. Terminó en `ROLLBACK`; consulta posterior confirma 0 ajustes y 0 movimientos de ajuste persistentes.
- Privilegios comprobados en el proyecto: ambas RPC muestran `SECURITY DEFINER`, `search_path` vacío, ejecución `authenticated=true`, `anon=false`, `service_role=false`. Tabla interna con política `false/false`; sin SELECT/DML concedido a roles de aplicación. `stock_transferir` conserva su firma y no se modificó.
- Conteos observados después de las pruebas: 1.438 productos; proyección agregada 15.438; 408 movimientos ledger / 9.316,70 netos; 42 lotes; 0 transferencias; 396 recetas; 15.357 movimientos locales de Fudo; 0 eventos Lama; 2 movimientos de caja. Las diferencias entre proyección y ledger de `central/plaza` son 0. El encabezado de B2.3 registraba 1.437 productos; el conteo actual fue 1.438 y esta fase no hizo DML de productos.
- Verificación local: la prueba nueva `pruebas/fase1-ajuste-stock.mjs`, `pruebas/pantalla-sana.mjs` y `git diff --check` pasan. `npm test` se ejecutó y terminó con error en `pruebas/ajustes-navegacion.mjs`: su regex espera el cuerpo antiguo de `pickTab` (sin la condición de navegación de área que ya existe en `origin/master`); esta fase no modifica esa función. Las pruebas visuales Playwright se omitieron porque el entorno actual no tiene Chromium.
- Rollback técnico: `sql/2026-10-fase1-ajustes-manuales.rollback.sql` aborta si encuentra cualquier encabezado o movimiento de ajuste. Tras uso real no se borran movimientos: la corrección se registra como un nuevo ajuste auditado.
- Archivos de implementación: `index.html`, migración y prueba SQL/rollback bajo `supabase/migrations/` y `sql/`, más `pruebas/fase1-ajuste-stock.mjs`. Se actualizaron contrato 36, cola y mapa. No se alteraron Fudo, Lama, caja, recetas, lotes existentes, repartos ni `stock_transferir`; Fudo remoto no fue consultado ni modificado.
- Fase 2 queda pendiente y requiere activación explícita de Alejo.

### Cierre mínimo de pruebas de Fase 1

- La falla atribuida inicialmente a `pruebas/ajustes-navegacion.mjs` provenía realmente de `pruebas/sedes-seguras.mjs`. Su aserción exigía que el guard de sede activa apareciera inmediatamente después de `if(!SEDE)return;` dentro de `pickTab`.
- Desde el commit `ebd08f1`, anterior a Fase 1, existe entre ambas líneas una navegación legítima: al tocar Inventario mientras está abierta un área, se vuelve a Todas las áreas. El guard de sede seguía presente y se ejecutaba antes de cambiar vistas; no había regresión funcional.
- Se ajustó únicamente la prueba para inspeccionar el tramo inicial de `pickTab` y comprobar la presencia del guard sin depender de que dos instrucciones no relacionadas sean adyacentes. Fase 2 continúa pendiente y no fue activada.
- Resultado: `npm test` completo y `git diff --check` pasan. Las pruebas que requieren navegador continúan informando su omisión cuando Chromium no está instalado, sin convertirla en un fallo de la suite.

## 2026-10-19 — Movimientos de caja y correcciones de legibilidad

- Movimientos de caja conserva la misma RPC `arqueo_movimiento`, el turno abierto y sus permisos, pero ahora presenta una acción permanente **Nuevo movimiento** y un historial ordenado. La creación abre una ventana centrada en escritorio y una hoja inferior en teléfono, con tipo, monto, detalle, Cancelar y Guardar. Si no hay caja abierta, la pantalla ofrece ir a Arqueo y no promete una operación imposible.
- La ventana mantiene el borrador mientras se alterna entre ingreso y egreso, mueve el foco al monto, cierra con Cancelar o Escape y devuelve el foco a la acción original. Solo una confirmación válida usa la escritura existente; no se añadieron tablas, RPC ni reglas contables.
- En la búsqueda de Reparto se retiró el texto auxiliar sobre la entrada por congelador. La regla operativa no cambió: el buscador sigue ofreciendo directamente el producto correcto.
- Se corrigió una causa compartida de bajo contraste en Bodega/Enviar y Enlaces: tres controles usaban `--sec-bg` —un color de fondo— como tinta. Ahora usan `--sec-tx`, legible en claro y oscuro. La revisión de CSS no dejó otros textos usando tokens `*-bg`, salvo un estado seleccionado que lleva texto blanco explícito.
- Verificación Chromium con datos sintéticos: escritorio 1440×900 y teléfono 390×844; creación visible, ventana, selector ingreso/egreso, foco, Cancelar, Escape, hoja inferior, ausencia de desborde, contraste de Bodega y consola sin errores. No se ejecutaron escrituras comerciales ni se cambiaron datos.

## 2026-10-19 — Navegación lateral unificada y menú móvil completo

- Se igualó el riel fijo al de Inventario: 208 px en escritorio amplio y el mismo comportamiento adaptable en pantallas medianas. Módulos e Inventario comparten fondo, superficie, texto, estado activo y acento.
- En teléfono, el cajón se limita a la mitad del ancho disponible, aumenta la legibilidad de las etiquetas y permite abrir Mesas, Arqueo, Movimientos, Inventario, Reparto, Recetas y Mermas desde sus pestañas originales. Recibir/Enviar continúan disponibles en Bodega.
- Se retiraron del lateral el selector/botón de Apariencia, el bloque de presencia “En línea” y los nombres de usuario. Se conserva el botón de cierre de sesión. La barra inferior y la navegación existente se mantienen.
- La visibilidad sigue respetando exactamente los permisos de cuenta y las rutas de cada sede: por ejemplo, Mesas, Arqueo y Movimientos siguen sujetos a `puede_lama`; Recetas no aparece en Bodega. No se amplió acceso ni se cambiaron reglas comerciales.
- Verificación Chromium: `pruebas/movil-navegacion.mjs` prueba apertura desde teléfono de cada ruta permitida, ancho máximo del cajón, permisos, Bodega, navegación inferior y riel de 208 px. `pruebas/identidad-modulos.mjs` compara el ancho en Inventario y todos los módulos y comprueba ventanas, oscuro y ausencia de desbordes en 390×844 y 1440×900.
- Publicado en `origin/master` como `a5cd01ce49eda188136849c3414fafa2e84bf9e2`; Vercel confirmó producción `READY` con ese SHA y alias `llamita-plus.vercel.app`.

## 2026-10-19 — Mesas v2: plano a ancho completo y ficha inferior en teléfono

- Se aplicó la propuesta aprobada al área real de Mesas. En escritorio se conservan el plano y la cuenta en paralelo; en teléfono el plano usa tres columnas y la mesa elegida abre una ficha inferior. El plano queda atenuado detrás, la ficha se ajusta por encima de la navegación fija y el botón flotante se oculta mientras la ficha está abierta.
- La selección mantiene páginas/salones, secciones, formas y estados existentes. El detalle conserva las acciones y el contenido que ya dibujan `lamaPintarPanel`, la carta, la precuenta y el cobro; no se añaden acciones comerciales. Cerrar con el botón, tocar fuera o usar Escape devuelve al plano. El foco pasa al cierre al abrir la ficha y regresa a la mesa al cerrarla.
- Se mantuvo la paleta Lápiz y papel, el naranja `#F35B04`, el modo oscuro, las superficies suaves y el movimiento sutil de las tarjetas. No se alteraron permisos, datos, esquema, ventas, caja, Fudo, Lama–Stock ni las reglas de stock.
- Verificación: Chromium con datos sintéticos en 1440×900 y 390×844; tres columnas, ficha sobre navegación, ausencia de solapamiento del botón flotante, Escape, navegación, ventanas existentes, modo oscuro, consola sin errores y sin desborde horizontal. Pasó `pruebas/identidad-modulos.mjs`. `pruebas/lama-mesas.mjs` sigue bloqueada antes de su flujo por el fixture histórico de permisos que no habilita la pestaña Mesas; esta limitación ya estaba registrada en la auditoría del 19 de octubre.
- Publicado en `origin/master` como `5e8c05f93d5e8a41522e701e4fd71eabd79fe91d`. Vercel confirmó producción `READY` con ese mismo SHA y alias `llamita-plus.vercel.app`.

## 2026-10-19 — Mesas: fondo y navegación alineados con Inventario

- Se corrigió la diferencia visual entre Mesas e Inventario: fondo `#F6FFF8`, panel lateral blanco, texto de navegación oscuro y selección suave `#EAF4F4`; el acento vuelve al naranja de marca `#F35B04`. El modo oscuro ahora usa las mismas superficies de la identidad del selector de áreas (`#101512`, `#0C100E`, `#1B221E`, `#232C27`).
- No se alteraron tarjetas, formas, movimientos, estructura, rutas ni comportamiento de Mesas. Solo se unificaron los tokens de página y navegación; flujos comerciales y permisos permanecen intactos.
- Verificación Chromium, datos sintéticos: colores de página, riel y texto comprobados en claro/oscuro; suite `pruebas/identidad-modulos.mjs` completa, sin errores JavaScript ni desbordes en escritorio y teléfono. Capturas: selección de mesa en ambas resoluciones.
- Publicado en `origin/master` como `7f57c0420969f13d5a8caa125e2361219504bfbe`; Vercel confirmó producción `READY` con ese SHA y alias `llamita-plus.vercel.app`.

## 2026-10-19 — Identidad visual v1 en módulos operativos

- Estado: **IMPLEMENTADO Y VERIFICADO LOCALMENTE** en el commit `fc30a89`. Alcance: Mesas, Reparto, Arqueo, Movimientos de caja, Recetas, Historial, Bodega, Ajustes y Mermas. La publicación se realiza después de esta entrada y debe comprobarse contra el SHA servido por Vercel.
- Se incorporó una capa compartida `identity-modules.css` con la paleta Lápiz y papel (`#F6FFF8`, blanco, tinta y acento `#F35B04`), tarjetas suaves sin rebordes gruesos, espaciado y jerarquía comunes, riel oscuro, modo oscuro persistente y adaptación móvil. No se copiaron pantallas de prototipo: se vistieron los controles, filas y handlers reales.
- Cada módulo tiene un solo título útil y un control claro/oscuro. Bodega agrupa Stock, Recibir, Enviar y Enlaces en una subnavegación que pulsa las pestañas existentes y conserva su visibilidad por sede. En teléfono se mantienen la cabecera y la navegación inferior requeridas para orientarse y volver.
- Las ventanas existentes se presentan como hojas inferiores en teléfono. Escape, toque fuera y navegación por Tab invocan siempre los botones de cancelación originales; el foco entra al diálogo y vuelve al control que lo abrió. No se añadió ninguna vía de confirmación o guardado.
- Mesas conserva salones, mesa seleccionada, caja y acciones existentes. El aviso de caja se movió fuera del riel estrecho del plano para que sea legible en teléfono. Mermas continúa en demostración/solo lectura; no se habilitó ninguna operación pausada en Bodega o Local 1.
- Frontera técnica: no se modificaron arquitectura, esquema, migraciones, permisos, stock, ledger, Fudo, Lama–Stock ni reglas comerciales. No hay RPC, DML ni llamadas remotas nuevas. Las pruebas visuales usan una sesión y tablas sintéticas en memoria y no escriben datos operativos.

### Auditoría visual de esta entrega

| Prioridad | Pantalla y tamaño | Pasos | Esperado / observado antes | Resultado |
| --- | --- | --- | --- | --- |
| P1 | Mesas · 390×844 | Abrir Mesas con caja cerrada | Aviso y botón legibles; el aviso quedaba comprimido en el riel de 66 px | Resuelto: aviso a ancho completo |
| P1 | Mesas · 390×844 | Seleccionar mesa y observar la acción flotante | La acción no debe tapar la navegación; se superponía con la barra inferior | Resuelto: queda por encima de la barra y safe area |
| P2 | Mesas · 1440×900, oscuro | Activar oscuro y abrir una mesa | Toda la tarjeta debía cambiar; variables locales heredadas dejaban el interior claro | Resuelto: materiales oscuros coherentes |
| P2 | Modales · 390×844 | Abrir Recetas/confirmación, usar Tab y Escape | Hoja móvil cerrable y foco recuperable; faltaba un tratamiento uniforme | Resuelto con cierre original, trampa de foco y retorno |
| P3 | Arqueo · escritorio/teléfono | Entrar a Arqueo | Un solo título; aparecía un segundo encabezado redundante | Resuelto: se conserva únicamente el título principal |

- Resultado abierto de la capa nueva: **0 defectos reproducibles** en la matriz automatizada y en la inspección de capturas. Se verificaron 1440×900 y 390×844, claro/oscuro, ausencia de desborde, navegación, permisos de Mesas, cuatro vistas de Bodega, formulario/cancelación de Arqueo, modal de Recetas, confirmación, clic exterior, Escape, Tab y consola JavaScript.
- Pruebas que pasan: `pruebas/identidad-modulos.mjs`, `pruebas/pantalla-sana.mjs`, `pruebas/movil-navegacion.mjs`, `pruebas/inventario-areas.mjs`, `pruebas/b2-interfaz-area-historica.mjs`, `pruebas/b3-2a-2-interfaz-areas.mjs`, `pruebas/b3-2a-3-flujo-browser.mjs`, `pruebas/mermas.mjs` y `git diff --check`.

### Incidencias anteriores, separadas de esta implementación

- P3 · infraestructura de pruebas: `estetica-no-rompio-nada.mjs`, `pc-riel.mjs`, `ajustes-navegacion.mjs`, `telefono-y-bodega.mjs` y `lama-ancho.mjs` usan un fixture anterior a la RPC `permisos_mios`. Al ejecutarlos sobre el commit base limpio `b6aa251`, la app cae en Mesas o deja la ruta esperada oculta; por eso el clic/selector posterior falla. Esperado: el fixture debe devolver el contrato de permisos actual. Observado: la pantalla objetivo nunca se habilita. No reproduce un fallo de producción ni fue introducido por `fc30a89`.
- P3 · infraestructura de pruebas: `recetas-en-pantalla.mjs` obtiene 23 comprobaciones correctas y 2 fallidas sobre el mismo `b6aa251` porque su cliente simulado no define `sb.rpc`. Esperado: cargar Recetas con el cliente vigente. Observado: el mock interrumpe la preparación de la vista. No se cambió el flujo real de Recetas.
- Bloqueo concreto para Hermes/Codex: modernizar esos fixtures compartidos antes de volver a usar `npm test` como puerta única de publicación. La matriz pertinente y actual sí pasa; la deuda no bloquea esta entrega visual y no debe corregirse alterando permisos o lógica de aplicación.

## 2026-10-19 — Limpieza de apariencia y navegación dentro del área

- Se quitó del interior de cada área el texto auxiliar redundante, el resumen “con saldo / unidades físicas” y el botón “Todas las áreas”. El nombre del área queda arriba a la izquierda y se oculta la barra superior de sede y sección para recuperar espacio.
- Para regresar al selector, se vuelve a tocar Inventario en el panel de navegación. En teléfono, el acceso al menú se conserva junto al título del área.
- “Agregar producto de Bodega” ahora es un botón circular flotante abajo a la derecha. Conserva el permiso `puede_editar` y abre el flujo existente; la acción “Actualizar” sigue disponible en Atajos del panel.
- Criterio de diseño: mostrar solo la información necesaria para orientarse y actuar; retirar textos que repiten la ubicación o el estado visible; priorizar el contenido útil y reservar una acción principal evidente.
- Verificación con Chromium en escritorio y teléfono: título, ausencia de barra/textos redundantes, menú móvil, posición y etiqueta accesible del botón flotante, navegación de vuelta al selector, filtros, lectura por ubicación y flujo de Bodega. Las pruebas `pruebas/inventario-areas.mjs`, `pruebas/b2-interfaz-area-historica.mjs` y `pruebas/b3-2a-3-flujo-browser.mjs` pasan. El navegador de prueba usa datos ficticios; no se escribieron datos operativos.

## 2026-10-19 — Identidad visual compartida en las áreas operativas

- Se aplicó al interior de todas las áreas físicas el lenguaje visual aprobado para el selector: fondo claro, tarjetas suaves sin bordes gruesos, acento naranja `#F35B04`, trazos propios tipo lápiz y alternativa oscura persistente. La pantalla compartida cubre Cocina fría, Cocina caliente, Barra, Cafetería, Heladería y áreas futuras; `Sin asignar` y `Todas las áreas` conservan sus vistas especiales.
- La jerarquía queda en una sola columna de trabajo: regreso y acción de Bodega, nombre y dibujo del área, búsqueda, grupos, cuatro filtros de estado y secciones con productos. En teléfono, los filtros se muestran en dos columnas y no hay desborde horizontal.
- Es un cambio de presentación y textos de ayuda. Se conservan las mismas filas, cantidades del ledger, filtros, permisos y RPC. Secciones y límites siguen sin mover stock. No se modificaron tablas, migraciones, Fudo ni Lama–Stock.
- Verificación local con Chromium y productos ficticios en memoria: navegación, filtrado por área, modo oscuro, escritorio y teléfono, flujo de agregar desde Bodega y ausencia de escrituras directas. Pasaron `pruebas/inventario-areas.mjs`, `pruebas/b2-interfaz-area-historica.mjs` y `pruebas/b3-2a-3-flujo-browser.mjs`. La suite general se detuvo en `pruebas/ajustes-navegacion.mjs`, que intenta pulsar una opción oculta del menú de Ajustes; queda como incidencia separada por verificar.

## 2026-10-13 — Corrección visual de B2 verificada con Chromium

- La revisión de las capturas reales del usuario mostró que el resultado publicado no correspondía al diseño: una regla general de escritorio aplicaba dos columnas a `#list`, incluyendo encabezados y acordeones del área. Eso comprimía las tarjetas y mandaba las secciones a la segunda columna.
- Se corrigió el layout únicamente para el espacio de inventario por área: la lista ahora fluye en una columna y llena el ancho disponible. Se agregó un título visible del área debajo del botón de regreso; las tarjetas y el inventario quedan debajo en el mismo flujo.
- Al entrar al área se abre la primera sección física, para que el contenido del inventario aparezca de inmediato. Las demás siguen siendo desplegables.
- Se revisó la versión local con Chromium 151 y Playwright en escritorio (1567 px), tamaño intermedio (768 px) y teléfono (390 px), usando productos ficticios en memoria y sin sesión contra Supabase. Después se comprobó el HTML servido por producción y se abrió con el mismo fixture: cuatro tarjetas a lo ancho, lista vertical y encabezado visible. Se observaron 4, 2 y 1 columnas según el ancho, y no hubo errores de JavaScript. No se leyeron ni escribieron datos reales para la prueba visual.
- La nota anterior de que Chromium no estaba instalado fue incorrecta: `/usr/bin/chromium` y Playwright sí están disponibles. El script general de `npm test` omite ciertas pruebas visuales, pero se pudo hacer una revisión directa con el navegador del entorno.
- Despliegue: commit `008cbe5` quedó en `origin/master`; Vercel reportó el despliegue de producción `READY` y alias actualizado. El HTML público contiene el encabezado y la regla corregida.
- Pruebas: `npm test` y `git diff --check` pasan. No se realizaron escrituras ni consultas a Supabase; ningún dato cambió.
- No se tocó Fudo, Lama, caja, recetas, lotes ni stock. No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-13 — B2: refinamiento de filtros y alta desde Bodega

- Se refinó la pantalla de trabajo dentro de cada área sin alterar la navegación general ni los datos del inventario. Las cuatro tarjetas son filtros en la misma lista: **Críticos** (bajo mínimo o saldo cero), **Sobre-stock** (sobre máximo), **Sin límites** (falta mínimo o máximo) y **Vencimientos** (con grupos separados para vencidos y próximos a vencer, ventana de 7 días).
- Las tarjetas usan el ancho útil en cuatro columnas de escritorio, dos en tamaño intermedio y una en teléfono. El buscador, las píldoras históricas y la lista también ocupan el ancho del área de contenido; no se abren modales al pulsar los filtros.
- El botón para agregar desde Bodega conserva el flujo de producto maestro. El formulario permite elegir una sección física existente; desde el panel lateral puede seleccionarse o, con permiso de Ajustes, crear una sección. El panel entra visualmente desde un costado. Las secciones siguen siendo clasificación operativa sin saldo propio.
- Si no existe el producto en Bodega, **Crear nuevo producto** lleva a la creación del maestro solo en Bodega, oculta el enlace Fudo y retorna al área para confirmar la configuración. Si ya hay más de un maestro exacto, ninguno se elige automáticamente. Esta ruta no crea receta, stock, lote, movimiento ni transferencia.
- Archivos de aplicación: `index.html`; prueba: `pruebas/b2-interfaz-area-historica.mjs`. Documentación de estado: cola y mapa de Inventario por Áreas. No se agregaron migraciones ni cambios de esquema, RLS o permisos; ningún dato operativo se modificó.
- Verificación: `npm test` pasó; las pruebas estáticas validan las cuatro tarjetas, el diseño 4/2/1, la separación sección/categoría y uso de RPC protegidas. `git diff --check` pasó. No se pudo hacer revisión visual automatizada: Chromium no está instalado.
- El ledger permanece como única fuente de cantidades; `stock_internal.existencias` no se modificó ni se invocó `stock_transferir`. Fudo, Lama, caja, ventas, Bodega operativa, recetas y lotes no se modificaron. No se accedió a Café del Desierto / Llamita Stock.
- B3 permanece pendiente; no se activó carga inicial, ajuste, reparto, despacho ni recepción.

## 2026-10-13 — B2: interfaz histórica dentro de cada área y alta Bodega simplificada

- Repositorio confirmado: `leoalejoleo1537/llamita-plus`; `origin` apunta a ese repositorio. Publicación solicitada únicamente a `origin/master`. No se accedió, consultó ni modificó Café del Desierto / Llamita Stock.
- Inventario por áreas: se recuperó la jerarquía de uso histórico: píldoras derivadas del campo existente `tipo` → secciones físicas desplegables → filas de producto → ficha/modal. AM/PM continúa siendo orden visual. No se introdujeron categorías nuevas ni se migraron rubros/secciones históricas.
- Las filas usan `stock_leer_areas` y sus cantidades del ledger. Los productos configurados sin saldo siguen visibles como “Configurado · sin existencias”; los saldos sin configuración quedan claramente marcados. El buscador y las píldoras limitan la lista al área elegida.
- La ficha abierta desde un área muestra área, tipo, sección física, saldo del ledger, límites configurados y vencimientos cuando existen. Stock, mermas, lotes, Fudo y nombre/ficha maestra quedan fuera de edición en ese contexto. Guardar configuración solo llama `producto_area_configuracion_guardar`; si la fila es solo saldo físico o Sin asignar queda en solo lectura.
- Se bloquearon los gestos legacy de swipe al navegar dentro de las áreas, para que no abran reparto ni merma. No se modificó la lógica comercial de esas funciones.
- Alta desde Bodega simplificada: resultados y detalle no muestran IDs, factores ni IDs de fichas locales. Se muestra nombre, unidad, stock de Bodega, destino y configuración mínima del área. Si hay una sola representación ya enlazada se reutiliza automáticamente; varias representaciones enlazadas requieren selección; candidatos locales sin vínculo solo se presentan cuando son pertinentes y requieren confirmación. No se muestran ni reutilizan fichas ligadas a otro maestro. Si se crea una representación local, nace con saldo cero y la confirmación dice que las unidades llegarán al recibir reparto.
- El agregado continúa usando `bodega_producto_area_agregar`; no crea stock, lotes, movimientos, transferencias, recetas ni enlaces Fudo. No hubo migraciones ni escrituras de base de datos.
- Pruebas: `npm test` completado con exit 0; incluye la prueba estática nueva `pruebas/b2-interfaz-area-historica.mjs`, prueba vigente del flujo B1 y `pruebas/pantalla-sana.mjs`. `git diff --check` pasó. La limitación de revisión visual consignada en esta entrada fue corregida en la entrada superior.
- Archivos cambiados: `index.html`, `pruebas/b2-interfaz-area-historica.mjs`, `pruebas/b3-2a-3-asignacion-existente.mjs`, este registro, cola y mapa objetivo. No cambió esquema, RLS, permisos ni datos; Fudo, Lama, Bodega operativa, recetas, caja y stock permanecen intactos.
- Siguiente nodo: **B3 — alta/configuración manual de productos demo**, pendiente de activación explícita. Carga inicial/ajustes, reparto/recepción y transferencias visuales no quedan habilitados por B2.

## 2026-10-13 — Revalidación de B1 publicado

- B1 ya estaba implementado en `e7f0f40` y documentado como COMPLETADO; se comprobó que `origin/master` contiene también el mapa y la cola que dejan B2 como siguiente nodo pendiente. No se inició B2.
- Proyecto Supabase confirmado por historial: `llamita-plus` (`iuryhsjucblmebdogewa`); las migraciones `20261013002913` y `20261013003415` siguen instaladas.
- Se volvió a ejecutar la suite `supabase/tests/bodega_producto_area_rpc.sql` en una sentencia transaccional con rollback forzado al final. Pasaron búsqueda, enlace/creación, reutilización, idempotencia, configuración en varias áreas, ausencia de stock/movimientos/lotes y grants. Una identidad `authenticated` sin `puede_editar` fue rechazada por la RPC antes de validar o escribir producto.
- Conteos observados después de la prueba: productos 1.438; stock proyectado 15.438,00; existencias ledger 408 filas / 9.316,70 unidades; lotes 42; movimientos legacy 431; movimientos ledger 408; transferencias 0; recetas 396; movimientos Fudo locales 15.357; configuración Lama–Stock 0. No quedaron productos sintéticos persistentes. La suite compara dentro de su subtransacción los conteos de lotes, movimientos y ledger antes/después.
- `npm test` y `git diff --check` pasaron. Sigue pendiente una comprobación visual autenticada del usuario. No se cambió código ni esquema; no se accedió a Café del Desierto / Llamita Stock.

## 2026-10-13 — Vínculo Bodega → Local 1 desde un área

- Estado: **IMPLEMENTADO Y DESPLEGADO EN SUPABASE; PRUEBAS TRANSACCIONALES COMPLETADAS**.
- Repositorio: `leoalejoleo1537/llamita-plus`; rama local `work`; publicación prevista únicamente en `origin/master`. Proyecto confirmado: `llamita-plus`, ref `iuryhsjucblmebdogewa`. No se accedió a Café del Desierto / Llamita Stock.
- Base de diseño: entrada de preflight inmediatamente anterior (commit `dc7e048`); no existe informe aparte, el diagnóstico está en esta bitácora.
- RPC nuevas: `bodega_productos_area_buscar(text, uuid)` busca el catálogo maestro activo de Bodega, stock leído del ledger Bodega central, enlaces y representaciones posibles de Local 1. `bodega_producto_area_agregar(bigint, bigint, boolean, uuid, uuid, numeric, numeric, boolean, boolean)` valida `auth.uid()`/rol JWT y `authz_internal.exigir_capacidad_b3_2a('editar')`, confirma el maestro y la representación elegidos, y en una transacción enlaza o crea la representación de plaza y guarda su configuración producto–área–sección.
- La RPC de escritura exige `p_confirmar=true`; el destino debe ser área activa de `plaza` con ubicación ledger activa vinculada. Bloquea el maestro para serializar reintentos. Si una identidad Bodega ya está configurada en esa área, devuelve `ya_configurado` y no agrega una segunda representación/configuración, aun cuando haya varios enlaces locales. El reintento tras timeout reutiliza la representación creada por la propia RPC.
- Representación nueva: copia la ficha descriptiva necesaria del maestro y crea `productos.stock_actual=0`; luego guarda el enlace explícito en `producto_enlace` (`sede='plaza'`, factor 1, actor y fecha). No crea enlace Fudo ni receta. La configuración existente conserva sección, mínimos/máximos, actor y fechas en `producto_area_asignacion`. El actor/maestro/representación/área/fecha quedan auditables al unir ambas tablas. Para una ficha local suelta, la interfaz exige selección y confirmación expresa; nunca la enlaza solo por nombre.
- Interfaz: desde tarjetas o pantalla de un área activa aparece “Agregar producto de Bodega”; desaparece “Crear producto nuevo” dentro del área. La búsqueda exige elegir maestro y, si aplica, representación local; muestra ID maestro, unidad, stock Bodega, representación/ID, factor, ubicación y saldo local. Permite elegir sección y mínimos/máximos. Si no hay maestro en Bodega, indica crearlo allí y volver. Sin asignar no ofrece esta acción. La pantalla heredada de alta de producto en Ajustes no fue modificada fuera del manejo de duplicado para evitar abrir este flujo con un ID de plaza equivocado.
- Cero escrituras a `stock_internal.existencias`, `stock_internal.movimientos`, lotes, `productos.stock_actual` salvo la inserción explícita de una nueva fila con valor cero; no se invocó `stock_transferir`. No se alteró RLS/ACL de tablas existentes ni se habilitaron permisos nuevos de DML directo. El flujo web usa solo estas RPC. **Nota de seguridad preexistente:** `producto_enlace` mantiene sus grants/RLS anteriores (incluyen DML directo para roles API); no se cambiaron para no alterar los flujos heredados de enlaces. Ese endurecimiento global es ajeno a esta tarea y queda como riesgo separado.
- Migraciones aplicadas en Supabase Llamita Plus: `20261013002913_bodega_producto_area_rpc` y `20261013003415_bodega_producto_area_idempotency`. La segunda vuelve a publicar las RPC con guardas finales de idempotencia global producto-maestro/área. Sin tablas ni políticas nuevas; rollback de código: `DROP FUNCTION public.bodega_producto_area_agregar(bigint,bigint,boolean,uuid,uuid,numeric,numeric,boolean,boolean)` y `DROP FUNCTION public.bodega_productos_area_buscar(text,uuid)`. Si ya hubo uso real, no borrar enlaces/configuraciones: conservarlos o revertirlos mediante acción compensatoria autorizada.
- Pruebas SQL con datos sintéticos dentro de `BEGIN ... ROLLBACK`: maestro sin representación, enlace existente, varias representaciones, representación local candidata con nombre distinto, búsqueda con mayúsculas/tildes/plural, selección explícita, misma representación en dos áreas, configuración ya existente del mismo maestro-área incluso con otra representación, reintento de creación, nombre normalizado duplicado, stock cero, grants de RPC y rechazo de rol anon. Resultado: pasó y no dejó filas sintéticas.
- Conteos pre/post iguales: productos `1438` (plaza `330`, central `349`), existencias ledger `408` filas / `9316.70` unidades, lotes `42`, movimientos ledger `408`, enlaces plaza `250`, configuraciones plaza `3`, recetas `396`. No se crearon transferencias ni datos persistentes.
- Verificación de grants instalada: ambas RPC `SECURITY DEFINER`, `search_path=''`, ejecutables por `authenticated`, no por `anon` ni `service_role`; `producto_area_asignacion` conserva RLS y sin INSERT/UPDATE directo para `authenticated`. Los grants/RLS de `producto_enlace` son idénticos a los previos.
- `npm ci` (sin cambios al lockfile), `npm test` y `git diff --check`: pasan. Las pruebas visuales de navegador se omiten porque no hay Chromium en el entorno. Advisors de seguridad/rendimiento: sin hallazgos nuevos para las RPC; se mantienen avisos preexistentes no relacionados.
- Archivos: `index.html`, tres pruebas MJS actualizadas, migraciones SQL de las RPC e idempotencia, `supabase/tests/bodega_producto_area_rpc.sql`, esta bitácora. No se tocaron funciones Edge ni datos remotos Fudo, Lama, caja, recetas o stock.
- Riesgos pendientes: el administrador deberá ejecutar una prueba visual autenticada en un navegador; la tabla `producto_enlace` conserva la exposición DML histórica señalada arriba. El trabajo termina aquí; no se activan ajustes físicos, transferencia/recepción ni descuentos Lama.

## 2026-10-13 — Preflight: agregar producto maestro de Bodega a un área

- Estado: **PREFLIGHT COMPLETADO; IMPLEMENTACIÓN DETENIDA POR PIEZA FALTANTE**.
- Entorno: repositorio `leoalejoleo1537/llamita-plus`, rama `work`, fast-forward limpio a `origin/master` antes de revisar; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`). No se accedió a Café del Desierto / Llamita Stock.
- Las RPC `producto_area_configuracion_guardar` y `producto_area_preferencia_guardar` validan autorización `puede_editar` por servidor. Para áreas se debe usar la primera: permite reactivar/crear la configuración producto–área–sección y guardar mínimo/máximo. La tabla solo admite productos de `plaza`; no contiene cantidades.
- `stock_leer_areas` y `producto_area_preferencia_leer` obtienen la ubicación y saldo del ledger. El actual flujo “Agregar producto existente” busca solo filas locales de `DATA` (`plaza`), no el catálogo maestro de Bodega. Guardar una configuración no escribe movimientos, lotes ni existencias.
- `producto_enlace` es el puente requerido entre IDs de Bodega y Local 1. Hay 513 filas, 276 IDs maestros distintos y 513 IDs locales distintos: un producto de Bodega puede tener varios destinos locales. Por ello no se puede escoger un destino usando solo nombre ni tomar el primer enlace; cada par debe mostrarse y confirmarse explícitamente.
- El catálogo `productos` no tiene columnas de marca o formato; sí contiene nombre, rubro, tipo y unidad. La búsqueda puede normalizar tildes y comparar tokens/singular-plural en los campos existentes, pero marca/formato solo podrán mostrarse si forman parte del nombre o si se aprueba un modelo/catálogo que los suministre.
- Pieza faltante: cuando el producto maestro no tiene enlace a `plaza`, no existe un flujo backend protegido dedicado que cree una representación local enlazada y la asigne al área. `producto_area_asignacion` y `stock_leer_areas` requieren el producto local de `plaza`. La RPC legacy `crear_producto_enlazado` crea filas por destino y enlaces, admite también `angamos`, no aplica la autorización S1 de B3.2a y no garantiza que el usuario haya confirmado el par correcto; no se debe conectar al nuevo flujo como solución directa.
- Diseño recomendado para la siguiente subfase: RPC de búsqueda de maestros con resultados de enlaces explícitos y ubicación/saldo; RPC protegida y acotada para crear el maestro en `central` cuando no haya candidato y crear su contraparte enlazada de `plaza` únicamente tras confirmación; usar `producto_area_configuracion_guardar` para sección/mínimo/máximo. Todo en un flujo idempotente y sin stock ni lotes. Antes de implementarlo debe confirmarse que una fila local enlazada es la representación técnica permitida del producto maestro único.
- No se modificó código, SQL, esquema, datos, permisos, interfaz ni despliegues. No se ejecutaron pruebas de escritura. La bitácora es el único archivo de documentación actualizado en esta ejecución.


## 2026-10-12 — Decisión aprobada: producto maestro único y configuración por área

- Estado: **DECISIÓN APROBADA; IMPLEMENTACIÓN PENDIENTE**.
- Objetivo inmediato: simplificar el motor de demostración y permitir que cada área construya su propio inventario sin clasificaciones automáticas arbitrarias.
- Regla principal: un producto físico/conceptual tiene un único producto maestro y una identidad lógica común. Cuando el esquema heredado tenga filas o IDs distintos entre Bodega y Local 1, se usará un enlace explícito y auditable; nunca se fusionarán filas a ciegas. Cafetería, Barra, Cocina fría y Cocina caliente no crearán copias independientes de una misma leche, manzana u otro insumo.
- Bodega es el catálogo maestro y el origen operativo. La creación de productos nuevos se realiza en Bodega. Desde un área solo se puede buscar y configurar un producto que ya existe en Bodega.
- “Crear producto en el área” debe convertirse en “Agregar producto existente a esta área”. La operación crea o activa una configuración producto–área–sección; no crea un nuevo producto maestro ni existencia inicial.
- Si el producto no existe en Bodega, el flujo debe guiar al usuario a crear primero el producto maestro en Bodega y luego regresar a la configuración del área.
- La misma identidad puede configurarse en varias áreas. Cada configuración puede tener sección física, mínimo, máximo, estado y área principal; las cantidades viven únicamente en stock_internal.existencias.
- El sistema puede sugerir coincidencias por nombre, pero nunca debe enlazar automáticamente una coincidencia ambigua. Debe mostrar candidatos con nombre, marca, formato y unidad cuando existan, exigir confirmación humana y bloquear el guardado si hay ambigüedad no resuelta.
- Ejemplo obligatorio: si el usuario escribe “menta”, no debe crear automáticamente otro producto si existen “hojas de menta”, “menta hoja” u otros candidatos. Debe mostrar la lista de candidatos y una acción clara de “Usar este producto”. Solo si no existe un candidato adecuado se habilita “Crear producto maestro en Bodega”.
- No debe existir una falla silenciosa. Coincidencia dudosa, producto sin enlace, receta sin área, área de producción ausente o ingrediente sin ubicación válida deben generar alerta visible y estado pendiente de resolución.
- Bodega pierde stock únicamente cuando el área confirma la recepción real del reparto. Preparar y despachar son estados documentales/reservas; recibir ejecuta una transferencia idempotente del mismo producto y lote cuando corresponda.
- Fudo continúa vinculado al producto maestro y su adaptador no debe modificarse por esta decisión. La configuración de áreas no crea IDs Fudo nuevos.
- Lama conserva el flujo de cierre de mesa ya implementado. Para descontar una receta: identificar producto vendido → leer receta capturada → resolver área de producción → descontar ingredientes desde esa área. Si falta área o existe ambigüedad, el evento queda pendiente con alerta y no se aplica un descuento inventado.
- Regla de resolución para Lama: primero área de producción del producto vendido; después área definida en la receta; después configuración explícita del ingrediente únicamente si es inequívoca. No se usará un área predeterminada silenciosa.
- Requisito de frontend prioritario: el flujo debe ser comprensible para personas con poca experiencia digital. La interfaz debe explicar “producto maestro”, “producto ya existente”, “agregar a esta área” y “no se mueve stock” con lenguaje cotidiano. Debe mostrar candidatos claramente, advertir duplicados antes de guardar, confirmar qué producto se enlazó y ofrecer recuperar/corregir una selección sin perder información.
- El frontend debe privilegiar prevención de errores sobre velocidad de escritura: búsqueda tolerante a tildes, singular/plural y variaciones razonables; resultados con contexto; estados visibles; confirmación antes de crear un producto nuevo; y alertas persistentes para pendientes.
- Fuera de alcance de esta decisión: clasificar automáticamente todo el Excel, inventar familias o secciones, duplicar productos por área, modificar Fudo remoto, cambiar recetas históricas o habilitar descuentos silenciosos.
- Regla de trabajo para Codex: leer esta entrada, el último informe de Bloque 1A y únicamente los archivos/RPC que vaya a modificar. No releer toda la historia Hermes ni repetir auditorías cerradas.
- Próxima fase propuesta: preflight acotado del motor “Agregar producto existente a un área”, seguido de implementación por una sola subfase. Debe incluir búsqueda/candidatos, confirmación humana, creación de producto maestro exclusivamente en Bodega cuando no exista y pruebas de duplicados/ambigüedad.


## 2026-10-11 — Bloque 1A: inventario funcional por área y secciones internas

- Estado: **COMPLETADA**. Se implementó Producto → Área → Sección → mínimo/máximo sin introducir cantidades fuera del ledger.
- Migraciones aplicadas en Supabase Llamita Plus: `20261011181753 bloque_1a_inventario_area_seccion` y `20261011181901 bloque_1a_indice_seccion_area`.
- Datos: nueva tabla cerrada `area_secciones`; `producto_area_asignacion` admite varias áreas por producto y guarda sección, límites y principal. No se migraron `public.secciones`, `productos.rubro` ni categorías ambiguas; no se crearon secciones ni configuraciones nuevas. La única fila asignada previa quedó marcada principal para conservar compatibilidad.
- Lectura: `stock_leer_areas` devuelve configuraciones con saldo cero y saldos físicos no configurados. Lee `stock_internal.existencias`, nunca `productos.stock_actual`.
- Interfaz: las tarjetas abren inventarios funcionales con buscador, filtros por `productos.tipo`, métricas, secciones desplegables, organización AM/PM visual y modal histórico adaptado. La ficha separa grupo histórico, sección física, saldo ledger y límites por área. Ajustes administra secciones mediante RPC; no hay DML directo.
- Prueba `BEGIN … ROLLBACK`: sección, duplicado, dos áreas para un producto, principal único, límites, producto nuevo con saldo cero, raíz/administrador/común/anon, archivo lógico, firma de `stock_transferir` y ausencia de efectos contables. Pasó y no dejó filas sintéticas.
- Conteos pre/post: 1.438 productos; stock 15.438,00; 42 lotes; 431 movimientos legacy; 408 movimientos ledger/9.316,70; 361 repartos; 396 recetas; 15.357 movimientos Fudo; 0 eventos Lama; 5 áreas; 3 configuraciones; 0 secciones nuevas persistentes.
- `npm test`, sintaxis JavaScript inline y `git diff --check` pasaron. Chromium no está instalado, por lo que la verificación visual real de escritorio/móvil queda como riesgo manual documentado.
- Advisors: la tabla nueva aparece como RLS sin política de forma intencional porque no tiene grants; RPC solo para `authenticated` con autorización servidor. El índice compuesto requerido por el advisor se añadió en la segunda migración. Los demás avisos son heredados y quedan fuera de 1A.
- No se implementaron carga inicial, ajuste de stock, reparto, despacho, recepción, transferencia, Fudo, Lama, lotes, caja, recetas ni Bodega legacy. No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-11 — Decisiones operativas Brunetti para Inventario por Áreas

- Estado: **DECISIONES APROBADAS POR ALEJO** para la implementación posterior al preflight de Bloque 1A.
- Turnos: Brunetti realiza inventario PM. Por ahora AM/PM es solo organización visual de secciones y recordatorio del conteo; no condiciona saldos, transferencias, mínimos, máximos ni reglas del ledger.
- Momento contable del reparto: Bodega central pierde existencias únicamente cuando el responsable del área confirma la recepción real. Preparar y despachar son estados documentales/reservas. Al confirmar recepción, se ejecuta una única transferencia idempotente Bodega → área con la cantidad efectivamente recibida.
- Visibilidad: no existe censura entre áreas durante esta fase. Cualquier encargado puede ver Bodega y todas las áreas. Las restricciones de lectura o de ajustes se definirán después de conversar con Don Juan.
- Píldoras: reciclar el comportamiento y los grupos existentes de la interfaz histórica. No inventar grupos nuevos. Si un valor histórico es ambiguo o no corresponde, conservarlo para revisión posterior antes de cambiarlo.
- Ajustes de cantidad: durante la prueba, todos los usuarios operativos pueden crear ajustes auditados. Esto no autoriza escritura directa sobre `productos.stock_actual`; la interfaz debe usar la futura RPC protegida de ajuste. La política final de quién ajusta stock queda pendiente de validación con Don Juan.
- Requisito de UX confirmado: al abrir un área se entra a una pantalla de trabajo de inventario, no a Ajustes. Debe reutilizar buscador, píldoras históricas, agrupaciones desplegables, fichas de producto, críticos, vencimientos y modal de producto; las secciones físicas pertenecen al área y los filtros de grupo se reciclan desde el comportamiento histórico.
- Próxima ejecución: implementar Bloque 1A según preflight, incorporando estas decisiones. No activar aún carga inicial, ajustes, reparto/recepción, Fudo, Lama, Bodega legacy, lotes ni `stock_transferir`.

## 2026-10-11 — Decisión de reconstrucción: Bodega → Área → Sección → Producto

- Estado: **PLAN APROBADO; IMPLEMENTACIÓN AÚN NO ACTIVADA**.
- Decisión de Alejo: las áreas internas de Local 1 —Cafetería, Barra, Cocina fría, Cocina caliente y futuras áreas— conservan saldo físico propio. No se crearán sedes ficticias para representarlas.
- Flujo objetivo mínimo antes del 31 de octubre: Don Juan consulta necesidades por área desde Bodega central, prepara y despacha un reparto; el responsable del área registra la recepción real; solo la recepción confirmada mueve existencias mediante el ledger. El área puede realizar conteos y ajustes auditados.
- Identidad: un producto conserva una identidad lógica común. Una misma leche puede tener existencias en Bodega, Cafetería y Barra; cambia su ubicación, no el producto.
- Modelo objetivo:
  1. Bodega central → Local 1 → Área → Sección interna → Producto.
  2. Producto + área + sección configura mínimo, máximo, estado y área principal; no contiene cantidades.
  3. El ledger conserva las cantidades físicas por ubicación y lote.
  4. Un reparto conserva estados Borrador → Preparado → Despachado → Recibido → Cerrado. En esta primera versión, preparar y despachar son documentales/reservas; la recepción confirmada ejecuta una sola transferencia idempotente.
  5. Cambiar una cantidad desde la interfaz crea un ajuste auditado con diferencia, motivo, actor y referencia; nunca escribe directamente `productos.stock_actual`.
- Recuperación: la interfaz histórica de secciones, mínimos, máximos, editor de cantidades y repartos no fue eliminada. Quedó congelada por B2.3 y oculta para `plaza` por B3.1. Debe reutilizarse visualmente, conectándola a las RPC y al ledger nuevos; no debe reactivar escritores legacy.
- Secciones: `public.secciones` y `productos.rubro` contienen datos históricos mezclados. No se migrarán automáticamente. Primero se construirá catálogo de secciones internas ligado a cada `area_id`, con vista previa y asignación explícita. Categorías como Limpieza, Sándwiches o Tortas no se tratarán como ubicaciones físicas.
- Alcance de reconstrucción, en orden:
  1. Configuración producto–área–sección con mínimo/máximo por área y visibilidad de productos configurados aun con saldo cero.
  2. Carga inicial y ajustes auditados sobre el ledger.
  3. Reparto Bodega → área con preparación, despacho documental, recepción, diferencias e idempotencia.
  4. Recuperación de la interfaz histórica sobre el modelo protegido y preparación de datos de demostración.
- Fuera de alcance hasta completar este circuito: nuevas sedes para áreas, remodelación móvil adicional, cambios a Fudo, Lama, caja, POS, recetas o Café del Desierto / Llamita Stock.
- Regla de trabajo: ejecutar una sola subfase por vez. En cada preflight, leer únicamente esta entrada, el último informe de la subfase relacionada y las definiciones/código que vayan a cambiar; no releer toda la historia Hermes salvo que aparezca una dependencia concreta.
- Próxima tarea: preflight de solo lectura del Bloque 1 para diseñar una única relación producto–área–sección que admita un producto en múltiples áreas sin crear dos fuentes de stock.

## 2026-10-09 — B2.4.1: áreas activas dinámicas en transferencias

- Estado: **COMPLETADA**. Se ejecutó únicamente B2.4.1; C1–C4 siguen pendientes.
- Migración aplicada en Llamita Plus: `20261009192100 b2_4_1_dynamic_active_areas`.
- Cambio: las dos listas fijas del núcleo fueron sustituidas por validación de `area_id`, `plaza`, estado activo y coincidencia `areas_operativas.codigo = ubicaciones.codigo`. No cambió ninguna otra parte de la función.
- Suite `BEGIN … ROLLBACK`: Cocina fría, Cafetería, Heladería y área futura aceptadas; área archivada, UUID inexistente, ubicación sin vínculo, destino en sede incorrecta y saldo insuficiente rechazados; reintento idéntico conservó una transferencia y dos movimientos.
- Los dos primeros intentos del fixture abortaron antes de transferir por reglas reales del esquema —columna normalizada generada y ubicación archivada obligatoriamente inactiva—. Se corrigió el fixture y la repetición integral pasó; ningún intento dejó filas.
- Rollback técnico ensayado dentro de transacción revertida. Se bloquea si existen transferencias persistentes vinculadas a áreas dinámicas.
- Verificación final: 1.437 productos; stock 15.438,00; 42 lotes; 431 movimientos legacy; 408 movimientos ledger; ledger 9.316,70; 0 transferencias; 0 áreas/ubicaciones sintéticas.
- `npm test` y `git diff --check` pasaron. Advisors revisados: solo hallazgos heredados; B2.4.1 no añadió exposición, grants ni `search_path` inseguro.
- No se modificaron Fudo, Lama, Bodega operativa, productos, recetas, caja, mermas ni Café del Desierto / Llamita Stock.

## 2026-10-09 — C0: auditoría del circuito interno de inventario por áreas

- Repositorio y destino confirmados: `leoalejoleo1537/llamita-plus`, HEAD sincronizado con `origin/master`; Supabase confirmado como `llamita-plus` (`iuryhsjucblmebdogewa`).
- Se pausó M2–M4. Se inspeccionaron el cliente, migraciones, contratos instalados, tablas, restricciones, ACL y definiciones reales de `stock_transferir`, `stock_leer_areas` y RPC B3.2a.
- Lectura actual: `stock_leer_areas` deriva cantidades de `stock_internal.existencias`; Sin asignar contiene 4.566,20 unidades en 258 filas con saldo y Bodega central 4.750,50 en 150. Las cinco áreas activas de `plaza` tienen saldo cero.
- La asignación usa `producto_area_preferencia_guardar`; modifica metadata y no llama `stock_transferir`. La interfaz no tiene todavía una operación de transferencia física.
- `productos.rubro` + `public.secciones` explican Limpieza, Vitrina, Sándwiches, Congelador y muebles; `productos.tipo` contiene categorías. No son áreas contables.
- Bloqueo: existe el área activa dinámica `heladeria`, con ubicación de ledger, pero `stock_internal.transferir_aplicar` permite únicamente cuatro códigos fundacionales. Esto contradice la exigencia de áreas configurables sin modificar `stock_transferir`.
- Resultado: C0 completada; C1–C3 detenidas antes de modificar base o código y marcadas REQUIERE DECISIÓN. C4 permanece separada y pendiente.
- Consultas ejecutadas: únicamente SELECT sobre catálogos PostgreSQL y tablas de Llamita Plus. No hubo SQL de escritura, migraciones, datos sintéticos, llamadas Fudo/Lama ni cambios de stock.
- Conteos: 1.437 productos; 329 en `plaza`; 42 lotes; 408 movimientos ledger; 0 transferencias; 250 enlaces Bodega→plaza; 361 repartos y 2.040 ítems; 0 preferencias persistentes.
- No se accedió a Café del Desierto / Llamita Stock. Informe: `docs/hermes/33-c0-auditoria-circuito-inventario-areas.md`.

## 2026-10-09 — B3.2a.3: áreas encontrables y producto existente

- Estado: **COMPLETADA**. B3.2b permanece pendiente y no se activa.
- Causa: crear área estaba implementado solo dentro de `Ajustes → Áreas de inventario`; no había acceso desde Inventario y en móvil la subsección era difícil de descubrir. La RPC no estaba fallando.
- Interfaz: Inventario ofrece **Gestionar áreas** solo con `puede_ajustes`. Cada área separa **Agregar producto existente** de **Crear producto nuevo**. Un nombre duplicado abre la ficha coincidente y ofrece reutilizarla, sin crear copia.
- Datos: la asignación usa `producto_area_preferencia_guardar`; muestra preferencia y saldo físico por separado y avisa que no mueve existencias. Los destinos salen solo de áreas activas más Sin asignar; rubros/categorías como Limpieza, Vitrina o Sándwiches conservan su campo descriptivo, pero no son ubicaciones.
- No hubo migraciones. La prueba SQL real terminó con `ROLLBACK`; conteos pre/post: 1.437 productos, stock 15.438,00, 42 lotes, 431 movimientos legacy, 408 ledger, 0 transferencias, 396 recetas, 513 enlaces, 15.357 movimientos Fudo y 0 eventos Lama.
- Pasaron `npm test`, pruebas estáticas, navegador Chromium 390/1280, regresión M1, RPC/permisos/conteos y `git diff --check`. Fudo remoto, Lama real, Bodega, stock, lotes, movimientos y recetas no fueron alterados.
- Informe: `docs/hermes/32-b3-2a-3-depuracion-areas-productos.md`. No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-09 — M1: navegación móvil

- Estado: **COMPLETADA** tras autorización de Alejo para comenzar la remodelación. M2–M4, B3.2a.3 y B3.2b siguen pendientes.
- `index.html` y `themes.css`: bajo 720 px el riel deja de reservar 88 px y se vuelve menú temporal; barra inferior contextual reutiliza pestañas/handlers originales, permisos y modo demostración. Cabecera compacta, safe area, teclado/Escape y zoom móvil. Escritorio no se modifica.
- Prueba nueva: `pruebas/movil-navegacion.mjs` con datos simulados y Chromium 390/1280 px; pasó navegación, permisos, demostración, Bodega, foco, cierre y consola sin errores. `npm test` y `git diff --check` pasaron. Las pruebas antiguas de navegador tienen fixtures desactualizados; se documentan en el informe.
- Captura sintética: el aviso de caja en Mesas continúa estrecho; corresponde a M2, no a M1. Se necesita validación en teléfono real.
- Sin Supabase, SQL, datos, stock, permisos, Fudo, Lama comercial o cambios en Café del Desierto / Llamita Stock. Informe: `docs/hermes/31-m1-navegacion-movil.md`.

## 2026-10-08 — Hermes: propuesta de remodelación móvil y prototipo v1

- Estado: **DISEÑO PARA REVISIÓN; IMPLEMENTACIÓN NO ACTIVADA**. B3.2a.2 sigue completada. B3.2a.3 y B3.2b permanecen pendientes; este documento no altera la cola.
- Origen: Alejo probó el inventario por áreas en teléfono y confirmó que Heladería aparece. Las capturas de Mesas e Inventario muestran una barra lateral permanente que ocupa ancho útil, caja comprimida, lista de mesas de una sola columna y recorrido vertical excesivo. Prioridad de producto: recuperar la navegabilidad móvil antes de seguir agregando operaciones.
- Propuesta: en móvil, reemplazar la barra lateral fija por cabecera compacta, barra inferior Mesas/Inventario/Reparto/Mermas/Más y menú temporal completo. Mesas a cuadrícula adaptable; Inventario con áreas dinámicas, búsqueda y contenido a pantalla completa. Preservar paleta azul marino/azul/blanco, accesibilidad, permisos, modo demostración y diseño de escritorio.
- Especificación: `docs/hermes/30-propuesta-remodelacion-movil.md`. Contiene evidencia, mapa de navegación, comportamiento de Mesas/Inventario, módulos secundarios, reglas responsive, fases M0–M4, límites y criterios de aceptación. Prototipo navegable: `docs/hermes/prototipos/llamita-movil-v1.html` (sin conexión, cifras ilustrativas). JavaScript del prototipo validado sintácticamente.
- Decisión de diseño pendiente: confirmar orden final de accesos inferiores y patrón de detalle de mesa tras auditar la interfaz real. Codex debe inspeccionar DOM/CSS/JS y preparar un **modo plan de solo lectura**; no ejecutar M1 ni cambios de aplicación sin autorización nueva de Alejo.
- Frontera técnica: no se modificaron `index.html`, Supabase, SQL, permisos, Fudo, Lama, Bodega, stock, recetas ni caja. El prototipo no es una migración ni fuente de datos. No se consultó ni tocó Café del Desierto / Llamita Stock.
- Publicación: solo documentación y HTML de referencia en `master`. El estado de esta entrada no equivale a activar una tarea en la cola.

## 2026-10-06 — Inicialización del entorno

- Estado: entorno documental creado.
- Repositorio: `leoalejoleo1537/llamita-plus`.
- Rama objetivo: `master`.
- Cambios de aplicación: ninguno.
- Cambios de base de datos: ninguno.
- Tareas activas: ninguna.
- Próximo hito: preparar el plan de arquitectura por áreas operativas y someterlo a revisión antes de activarlo.
- Esta entrada describe el estado inicial del documento; la activación y el resultado posterior de B1 quedan anotados abajo.

Las futuras entradas deben incluir fase, commit, archivos tocados, pruebas, resultado y riesgos pendientes.

## 2026-10-08 — B3.2a.1: fundamentos de áreas y preferencias

- Estado: **COMPLETADA**. B3.2a.2, B3.2a.3 y B3.2b quedan pendientes y no se activan.
- Entorno: repositorio oficial `leoalejoleo1537/llamita-plus`, rama local `work` sincronizada; Supabase `llamita-plus` ref `iuryhsjucblmebdogewa`, activo, PostgreSQL 17.6.1.166.
- Migración remota: `20261008175901 b3_2a_1_fundamentos_areas_preferencias`; fuente `supabase/migrations/20261008175539_b3_2a_1_fundamentos_areas_preferencias.sql`.
- Modelo: actores de creación/modificación/archivo, nombre normalizado único, preferencia única producto/sede, rechazo de área archivada y relación 1:1 área/ubicación. `Sin asignar` permanece como `area_id=NULL`.
- RPC: listado; crear/editar/archivar área; guardar preferencia; crear producto `plaza` con stock cero. Área requiere `puede_ajustes`; producto/preferencia `puede_editar`; sesión y capacidad se validan en servidor mediante S1.
- Seguridad: solo `authenticated` ejecuta las RPC; `PUBLIC`, `anon` y `service_role` no. Las tablas continúan sin grants directos. El administrador operativo puede operar áreas/productos, pero no gestionar usuarios.
- Pruebas `BEGIN ... ROLLBACK`: área+ubicación, duplicados, sedes, reserva `sin_asignar`, archivo sin/con preferencias y con saldo, área archivada, productos con/sin área, producto enlazado Fudo, propietario/operador/común/anon, DML directo y continuidad de `stock_transferir`. Pasaron.
- `npm test` pasó; Chromium no está instalado. Advisors revisados: sin ejecución anónima, `search_path` mutable ni grants nuevos de B3.2a.1. Avisos de RLS sin política/RPC definer autenticadas son intencionales y están documentados. Índices nuevos aún sin uso porque no hay asignaciones persistentes.
- Conteos pre/post: productos 1.437; stock 15.438,00; áreas 4; asignaciones 0; ubicaciones 6; ledger 408/9.316,70; transferencias 0; lotes 42; movimientos 431; recetas/ítems 396/514; enlaces 513; Fudo 15.357; Lama–Stock 0; cuentas/pagos 59/30. Sin cambios.
- Rollback: `sql/2026-10-b3-2a-1-fundamentos-areas-preferencias.rollback.sql`; aborta tras actividad persistente. Pruebas: `sql/2026-10-b3-2a-1-pruebas-transaccionales.sql`.
- Informe: `docs/hermes/28-b3-2a-1-fundamentos-areas-preferencias.md`.
- No se modificaron UI, Fudo, Lama, Bodega, caja, recetas, lotes, mermas, stock ni datos comerciales. No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-08 — S2: verificación de seguridad y regresión

- Estado: **COMPLETADA**. No se halló escalamiento; las sesiones reales y la auditoría persistente pasaron.
- Data API anónima rechazó SELECT, INSERT, UPDATE, cambio de `auth_uid`, DELETE y las RPC administrativas. TRUNCATE está revocado para los tres roles API.
- Pruebas `BEGIN ... ROLLBACK`: raíz, administrador operativo, usuario común, auditoría inmutable, RLS propia, DML denegado, `stock_transferir`, áreas, Bodega y lectura Fudo pasaron.
- Las RPC S1 conservan `SECURITY DEFINER`, `search_path=''`, nombres calificados, comprobación de `auth.uid()` y ACL correcta. No hay políticas abiertas nuevas en `app_permisos`.
- `npm test` pasó; Chromium no está instalado. Advisors conservan los hallazgos globales heredados de S0, fuera de S2.
- Prueba manual: raíz con login, lectura global, otorgamiento/revocación y auditoría correctos; cuenta operativa con login y operación normal, sin administración global, escritura directa ni autoelevación. No se compartieron secretos.
- La contradicción inicial quedó resuelta: las pruebas SQL anteriores hicieron `ROLLBACK` y no hubo entonces una llamada Auth persistente a la RPC.
- Causa comprobada: UPDATE de permisos e INSERT de auditoría son atómicos; todos los ensayos SQL previos finalizaron con ROLLBACK. Los logs no contienen ninguna llamada autenticada exitosa a `permisos_actualizar`, solo el probe anónimo 401. El conteo se hizo como `postgres`, por lo que RLS no ocultó filas.
- Prueba persistente final: el propietario raíz usó la interfaz con una sesión Auth real para cambiar únicamente `fudo_bloqueos` de `[]` a `["boton"]` y restaurarlo a `[]`. Los logs registran dos llamadas HTTP 200 y `authz_internal.permisos_auditoria` conserva las filas inmutables 7 y 8.
- La cuenta operativa terminó exactamente con editar/Fudo/Ajustes habilitados, Lama apagado y cero bloqueos Fudo.
- Conteos post prueba: 1.437 productos, stock 15.438, 431 movimientos, 42 lotes, 59 cuentas, 30 pagos, caja 2, Lama–Stock 0, Fudo 15.357, auditorías 2 y transferencias 0.
- No hubo migraciones, cambios de código o esquema, llamadas a Fudo remoto ni acceso a Café del Desierto. Las dos filas de auditoría son la única evidencia persistente intencional. Informe 26 y plan 27.

## 2026-10-07 — S1: identidad raíz y gobierno seguro de permisos

- Estado: **COMPLETADA**. Alejo confirmó el UUID raíz exacto; Supabase verificó que existe, está confirmado y no es anónimo.
- Migraciones aplicadas solo en `llamita-plus` (`iuryhsjucblmebdogewa`): identidad/gobierno de permisos e índices FK de auditoría.
- `authz_internal` contiene singleton raíz, auditoría inmutable y foto privada pre-S1. `app_permisos` queda vinculada por `auth_uid`; dos cuentas vinculadas y siete filas históricas inertes.
- Segunda cuenta: editar/Fudo/Ajustes habilitados, Lama apagado y cero bloqueos Fudo; conserva administración operativa, sin gobierno de permisos.
- Seguridad: anon sin lectura; authenticated solo su fila por RLS; service role conserva SELECT; los tres carecen de DML. RPC raíz con `SECURITY DEFINER`, `search_path=''`, `auth.uid()` y ACL explícita.
- Interfaz: carga propia por RPC; panel de personas y permisos individuales Fudo exclusivo del propietario raíz. No se crean usuarios Auth desde la app.
- Compatibilidad: `stock_transferir` conserva firmas y motor; consulta capacidad efectiva por UUID. La Edge que lee permisos conserva SELECT. Sin despliegue ni invocación Fudo.
- Pruebas transaccionales por cinco roles, degradación raíz, auditoría, Data API, transferencia y Edge-read pasaron. `npm test` pasó; navegador omitido por falta de Chromium.
- Conteos operativos pre/post idénticos: productos 1.437, stock 15.438,00, movimientos 431, lotes 42, cuentas 59, pagos 30, caja 2, Lama–Stock 0 y Fudo movimientos 15.357.
- Informe: `docs/hermes/25-s1-identidad-raiz-gobierno-permisos.md`. Fases posteriores de seguridad quedan pendientes y no activadas.

## 2026-10-07 — S0: auditoría integral de seguridad y permisos

- Estado: **REQUIERE DECISIÓN**. El mapa técnico está completo para diseñar S1, pero no existe una identidad verificable de propietario raíz.
- Entorno: repositorio `leoalejoleo1537/llamita-plus`, rama `work`, sincronizado con `origin/master`; Supabase `llamita-plus` ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166.
- Identidad anonimizada: 2 usuarios Auth confirmados, 0 anónimos; 9 filas de `app_permisos`, 2 coincidentes por correo y 7 sin usuario Auth actual. Ambas cuentas reales tienen capacidades administrativas. No hay UID/FK/propietario ni rol seguro en app metadata.
- Hallazgos: lectura anónima y autoedición de `app_permisos`; 36 tablas `public` con políticas abiertas `ALL`; 40 funciones `SECURITY DEFINER` ejecutables por anon, 36 con escritura y ninguna de esas 40 con chequeo de sesión; Lama, caja, Ajustes, recetas y logística dependen principalmente de controles del cliente.
- Controles que sí existen: `stock_internal` cerrado; áreas/asignaciones cerradas; puente Lama–Stock sin acceso de navegador; triggers de corte protegen stock/lotes/escritores legacy para `central/plaza`; POS en `ninguno`, Fudo prueba/cron apagado y Lama real apagado.
- Edge: se leyeron metadatos y fuentes de las seis funciones desplegadas sin invocarlas. Todas tienen JWT y guard de origen POS; varias no exigen capacidad de usuario confiable y usan service role únicamente en servidor.
- Advisors: 40 funciones definer anónimas, 3 vistas definer, 10 funciones con search path mutable, 8 tablas RLS sin política y protección de contraseñas filtradas desactivada.
- Trabajo ejecutado: consultas SELECT/catálogos, advisors, lectura de código y documentación. Sin migraciones, DML, RPC operativos, Edge invocadas, cambios de código funcional, RLS, grants, usuarios, datos o configuración.
- Informe: `docs/hermes/24-auditoria-integral-seguridad-permisos.md`. S1 no activa; B3.2a continúa requiere decisión y B3.2b pendiente.
- Decisión: Alejo debe designar privadamente cuál cuenta Auth es el `propietario_raiz` y aprobar el procedimiento de recuperación.
- No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-07 — B3.2a: bloqueo de autorización documentado

- Estado: **REQUIERE DECISIÓN**. Alejo activó B3.2a; la ejecución se detuvo antes de modificar código o base de datos al comprobar que `app_permisos.puede_ajustes` no es una fuente confiable con las políticas instaladas.
- Repositorio: `leoalejoleo1537/llamita-plus`, rama `work`, remoto `origin` oficial. Supabase verificado: `llamita-plus`, ref `iuryhsjucblmebdogewa`, estado `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166.
- Evidencia de solo lectura: políticas de `public.app_permisos`: `INSERT authenticated WITH CHECK true`; `UPDATE authenticated USING true WITH CHECK true`; y `UPDATE anon,authenticated USING true WITH CHECK true`. Grants directos amplios para anon y authenticated incluyen INSERT, UPDATE, DELETE y TRUNCATE. La tabla contiene 9 filas, 6 con `puede_ajustes=true`; estos valores no prueban quién está autorizado mientras las políticas permitan que el cliente los cambie.
- Resultado: no se agregaron secciones de Ajustes, edición de área, asignación preferida ni creación por área. No se aplicó SQL/migración, no se cambió permiso alguno ni se insertaron datos sintéticos. Sin cambios en productos, stock, lotes, movimientos, transferencias, recetas o datos comerciales.
- Decisión solicitada: definir/autorizar un endurecimiento de la administración de `app_permisos` que tenga bootstrap confiable y permita proteger sus escrituras mediante backend, o designar otra fuente de autorización confiable. La propuesta y sus límites están en `docs/hermes/23-b3-2a-bloqueo-autorizacion.md`.
- B3.2b permanece **PENDIENTE**, no activa. No se accedió a Café del Desierto / Llamita Stock.
- Verificación documental: `git diff --check` pasó. No se ejecutaron pruebas de aplicación/DB porque no hubo implementación ni cambios de esquema.
- Publicación de documentación del bloqueo: autorizada a `master` por la solicitud original; commit pendiente.

## 2026-10-06 - Canal de comunicación Hermes/Codex y activación de A1

- Estado: **A1 ACTIVA**, auditoría documental y técnica de solo lectura.
- Se creó `docs/hermes/06-canal-hermes-codex.md` como canal compartido de contexto, decisiones, preguntas y respuesta arquitectónica.
- Se actualizó `03-cola-de-trabajo-codex.md` para que Codex lea el canal antes de trabajar y responda allí el resultado.
- Se actualizó `docs/hermes/README.md` para incluir el canal.
- Cambios de aplicación: ninguno.
- Cambios de esquema y datos: ninguno.
- Publicación de esta actualización documental: autorizada a `master`.
- Siguiente paso: ejecutar la auditoría A1 y completar el canal con hechos comprobados sobre Fudo, Lama, Ajustes y los escritores de stock.

## 2026-10-06 — B1: verificación, detenida por decisiones pendientes

- Estado: **REQUIERE DECISIÓN**. Solo se hizo inspección de lectura; no se ejecutó migración ni se insertaron o actualizaron datos.
- Commit base inspeccionado: `c5cc8d6` (`origin/master`). Rama local `work`, igual a `origin/master`; árbol limpio después del fast-forward solicitado.
- Alcance: se verificaron los documentos Hermes, código de inventario y esquema activo del proyecto Supabase `llamita-plus` (`iuryhsjucblmebdogewa`). No se consultó ni modificó Café del Desierto / Llamita Stock.
- Archivos de esta actualización: `docs/hermes/03-cola-de-trabajo-codex.md`, `docs/hermes/04-bitacora-codex.md`, `docs/hermes/05-decisiones-pendientes.md`.
- Migraciones ejecutadas: ninguna. Datos creados o modificados: ninguno. Pruebas de aplicación: no ejecutadas; no hubo cambios de código ni modelo que probar. Se ejecutaron consultas `SELECT` y lecturas de metadatos únicamente en el proyecto verificado.
- Resultado: no se encontró una sede o rama de demostración aislada. El interruptor global `modo_demostracion` está activo, pero la documentación y el código muestran que solo filtra pantallas; no separa los datos. Las sedes `plaza`, `angamos`, `central` y la clave antigua `bodega` tienen productos y registros existentes. No se usarán para sembrar áreas sin una decisión explícita.
- Riesgo arquitectónico: `productos.stock_actual` es el stock vigente, editable desde la app y usado por RPC de ventas, entradas, mermas, repartos, restauraciones y por el trigger que suma `producto_lotes`. Una tabla de stock por área no puede convertirse en fuente paralela. Se requiere definir un corte que adapte todos esos caminos o posponer las cantidades por área hasta un corte coordinado.
- Siguiente paso: resolver las dos decisiones nuevas registradas en `05-decisiones-pendientes.md`. B2 permanece sin activar. No se hizo push de código ni de migración; se publicará solo la actualización documental del estado bloqueado para evitar que otra ventana repita B1.

## 2026-10-06 - A1: auditoría Fudo y Llamita Lama completada

- Estado: **COMPLETADA** en modo plan y solo lectura.
- Repositorio: `leoalejoleo1537/llamita-plus`, rama `work`, sincronizada con `origin/master` mediante fast-forward. Proyecto Supabase verificado: `llamita-plus` (`iuryhsjucblmebdogewa`), `ACTIVE_HEALTHY`.
- Archivos de auditoría: `docs/hermes/06-canal-hermes-codex.md`; se actualizó también esta bitácora y el estado de A1 en `03-cola-de-trabajo-codex.md`.
- Hallazgos: Fudo tiene catálogo espejo, recetas, `fudo_procesar_item`, modo prueba/real, idempotencia por ítem y empujes manuales protegidos por Ajustes. Lama tiene mesas, comandas, cobros parciales, anulaciones, impresión y arqueos, pero no llama al motor de inventario ni escribe `productos.stock_actual`.
- Contrato recomendado: evento común con `event_id`, `source`, `source_sale_id`, `source_line_id`, sede, fecha, estado, referencia de producto/proveedor, cantidad, fulfillment y versión de receta; deduplicación y compensación de anulaciones en un único motor.
- Consultas: inspección `rg`/`sed`/`find`/`wc`, metadatos Supabase de solo lectura (`get_project`, `list_tables`, `list_edge_functions`, `list_migrations`, `list_branches`) y `git diff --check`. No se ejecutó SQL, RPC, migración, Edge Function ni prueba de aplicación.
- Frontera de datos: no se consultó ni modificó Café del Desierto / Llamita Stock; no se insertó, actualizó ni borró ningún dato.
- Riesgos pendientes: decisión del momento de descuento de Lama, anulaciones y consumos internos; múltiples escritores de stock; falta de identificador universal y adaptador Toteat.
- Siguiente paso: resolver las decisiones del contrato común. Mantener B1 y cualquier puente Lama→inventario sin activar.

## 2026-10-06 - A2: regla de descuento de Lama aclarada

- Decisión de Alejo: una mesa de Lama descuenta inventario al **cerrarse**. Deben descontarse todas sus líneas confirmadas, con independencia de que el pago sea efectivo, tarjeta, parcial, cortesía o ya se haya registrado antes.
- Aclaración: pago, propina, medio de pago y cierre de caja no son disparadores separados de inventario. El evento de consumo es el cierre de mesa.
- Consecuencia para A2: el contrato debe modelar cierre idempotente y una compensación explícita si una línea cerrada se anula posteriormente. No se modificó código, esquema ni datos.

## 2026-10-06 - A2: contrato común de venta, receta e inventario

- Estado: **COMPLETADA como diseño documental**; la implementación queda pendiente de decisiones explícitas.
- Repositorio: `leoalejoleo1537/llamita-plus`, rama `work`, sincronizada por fast-forward con `origin/master` antes de comenzar. No se consultó ni modificó Café del Desierto / Llamita Stock.
- Archivo nuevo: `docs/hermes/07-contrato-comun-inventario.md`.
- Canal actualizado: `docs/hermes/06-canal-hermes-codex.md` con la respuesta arquitectónica A2.
- Diseño: producto canónico Llamita, enlaces Fudo/Toteat, precio independiente con snapshot, receta versionada, `SaleEvent`, ledger inmutable, idempotencia por proveedor y compensaciones sin borrado.
- Regla Lama: el cierre de mesa emite un consumo único de todas las líneas confirmadas; pagos parciales, propinas, medios y arqueo no son disparadores adicionales. Las anulaciones previas no consumen; las posteriores generan compensación.
- Transición: fases de inventario de escritores, identidad/proyección, ledger con área opcional, corte coordinado de todos los escritores, activación por sede y retiro de compatibilidad. No se crea una segunda fuente editable.
- Pruebas definidas: reintentos, timeouts, anulaciones, pagos parciales, recetas/precios históricos, FIFO, Fudo/Toteat y conciliación producto-área. No se ejecutan pruebas de aplicación en una fase documental.
- Verificaciones: `git fetch origin master`, `git merge --ff-only origin/master`, lectura de cola/bitácora/canal/decisiones y `git diff --check`. No se ejecutó SQL, RPC, migración, Edge Function ni mutación de datos.
- Cambios de código, esquema y datos: **ninguno**.
- Siguiente paso: obtener las decisiones de Alejo listadas en el contrato antes de activar cualquier implementación o B1.

## 2026-10-06 — A3.1: cimientos del puente Lama → Stock aplicados

- Estado: **COMPLETADA**. Se ejecutó únicamente A3.1; A3.2 permanece pendiente y no fue activada.
- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, rama `work`, remoto `origin` correcto y fast-forward a `origin/master` antes de trabajar.
- Proyecto confirmado: Supabase `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`.
- Migración aplicada: `a3_1_cimientos_lama_stock`; archivo `sql/2026-10-a3-1-cimientos-lama-stock.sql`.
- Tablas nuevas: `lama_stock_config`, `lama_stock_eventos`, `lama_stock_aplicaciones`. Incluyen estados `pendiente`, `prueba`, `aplicado`, `sin_receta`, `error`, `revertido`, snapshots, trazabilidad, reversa e idempotencia.
- Seguridad: RLS activo; sin políticas ni privilegios de tabla para `anon`/`authenticated`; no hay funciones ni triggers nuevos. La configuración quedó sin filas y el modo efectivo permanece apagado.
- Pruebas: firmas reales de `cuenta_cobrar` y `cuenta_cerrar` verificadas y no modificadas; colisiones `lama_stock_*` ausentes antes de aplicar; índices/constraints/RLS/grants comprobados después; prueba de duplicado de evento y aplicación rechazada dentro de transacción revertida.
- Integridad: pre/post cuentas 59, líneas 88, recetas 396, ítems de receta 514, productos 1.437 y stock total 15.438. Nuevas tablas: 0 filas. No cambiaron ventas, recetas, productos, lotes ni cantidades de stock.
- Documentación Supabase consultada: guía vigente de Row Level Security y changelog público; se verificó PostgreSQL 17.6 y disponibilidad de `gen_random_uuid()` antes de aplicar.
- Rollback preparado: `sql/2026-10-a3-1-cimientos-lama-stock.rollback.sql`; protegido para abortar si las tablas contienen filas. No ejecutado.
- Frontera de datos: no se accedió a Café del Desierto / Llamita Stock.

## 2026-10-06 — A3.2: captura protegida del cierre Lama completada

- Estado: **COMPLETADA**; A3.3 no fue activada.
- Preflight: repositorio `leoalejoleo1537/llamita-plus`, rama `work`, fast-forward a `origin/master`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- Definiciones instaladas obtenidas con `pg_get_functiondef`: `cuenta_cobrar(bigint,text,text,text,numeric,jsonb,jsonb)` y `cuenta_cerrar(bigint,text)`. Las firmas se conservaron y su comportamiento comercial se mantuvo; solo se añadió una llamada protegida posterior al cierre.
- Migraciones aplicadas: `a3_2_captura_cierre_lama` y `a3_2_restrict_captura_execute`.
- Implementación: `lama_stock_capturas`, `lama_stock_capturar_cuenta(bigint)` y llamadas desde ambos cierres. En apagado no hay eventos; en prueba se congelan cantidad, precio y snapshot de receta; líneas anuladas se excluyen; sin receta queda `sin_receta`; mesa vacía deja captura con cero eventos; reintentos no duplican.
- Seguridad: helper `SECURITY DEFINER`, `search_path` controlado y EXECUTE revocado explícitamente para `public`, `anon`, `authenticated` y `service_role`.
- Pruebas revertidas: apagado; receta existente; sin receta; línea anulada; mesa vacía; doble cierre/reintento; `cuenta_cobrar` con pago parcial, propina y descuento; error forzado mediante trigger temporal. Todas pasaron y terminaron con `ROLLBACK`.
- Error forzado: la captura quedó en estado `error` con diagnóstico y la cuenta quedó `cerrada`; pagos/caja no se revirtieron.
- Integridad pre/post: cuentas 59, líneas 88, recetas 396, ítems de receta 514, productos 1.437 y stock total 15.438; tablas A3.2 quedaron en cero filas tras pruebas revertidas. No cambió ninguna cantidad de stock ni se creó aplicación.
- Archivos: migración, hardening, rollback y documentación Hermes. No se modificaron UI, Fudo, recetas, productos ni lotes.

## 2026-10-06 - Activación de A3.1

- Decisión de negocio: una mesa y su importe cierran y alimentan caja aunque inventario falle; el evento de stock queda pendiente, sin receta o con error y se reprocesa después.
- Plan nuevo: `docs/hermes/08-plan-implementacion-puente-lama-stock.md`, dividido en A3.1–A3.4.
- Estado: solo **A3.1 ACTIVA**. Autoriza cimientos aditivos, RLS, constraints, idempotencia y pruebas; no autoriza conectar cierres ni modificar stock.
- A3.2–A3.4 y B1 continúan pendientes. No hubo cambios de aplicación, SQL ejecutado ni datos en esta activación documental.

## 2026-10-06 - Revisión de A3.1 y activación de A3.2

- Revisión de Hermes: las tablas A3.1 son aditivas; RLS está activo sin políticas abiertas; `anon` y `authenticated` no tienen privilegios directos; los modos nacen apagados y la idempotencia está respaldada por índices únicos.
- A3.2 queda **ACTIVA** para capturar cierres en modo apagado/prueba, sin escribir stock.
- Requisito añadido: persistir el estado de captura por cuenta y aislar cualquier excepción del puente para que venta, pago y cierre de caja permanezcan válidos.
- A3.3, A3.4 y B1 continúan pendientes. Esta activación solo cambia documentación.

## 2026-10-06 - Revisión de A3.2 y activación de A3.3

- Revisión de Hermes: la captura está aislada de caja, respeta modo apagado/prueba, conserva firmas y no escribe stock.
- Corrección requerida: futuros eventos usarán `cuentas.cerrada_at` como `ocurrido_at`; la hora de agregado de la línea será metadata.
- A3.3 queda **ACTIVA** para construir y probar el motor neutral. El camino real solo puede probarse dentro de transacciones revertidas; ninguna sede queda activada.
- Requisitos críticos: atomicidad por línea, snapshot inmutable, idempotencia y ausencia de doble escritura entre lotes y `stock_actual`.
- A3.4 y B1 permanecen pendientes. Esta activación solo modifica documentación.


## 2026-10-06 — A3.3: motor neutral y aplicación transaccional completada

- Estado: **COMPLETADA**; A3.4 no fue activada.
- Preflight: fast-forward a `origin/master`; repositorio `leoalejoleo1537/llamita-plus`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- Firmas verificadas con `pg_get_functiondef`: `cuenta_cobrar(bigint,text,text,text,numeric,jsonb,jsonb)`, `cuenta_cerrar(bigint,text)`, `descontar_lotes(bigint,numeric)`, `descontar_con_reposicion(text,bigint,numeric)` y `sync_stock_desde_lotes()`. FIFO real: `trg_sync_stock_lotes` recalcula `productos.stock_actual` desde `producto_lotes`.
- Migraciones aplicadas: `a3_3_motor_neutral_lama_stock` y `a3_3_fulfillment_rules`.
- Corrección de captura: `ocurrido_at = cuentas.cerrada_at`; `cuenta_items.agregado_at` se conserva en `metadata`; mesa Lama usa `fulfillment = serve`.
- Motor: `lama_stock_aplicar_evento(uuid)`, solo snapshot de receta; aplicaciones por ingrediente con delta negativo, lote FIFO elegido, estado, clave idempotente y error. `siempre/servir/llevar` se traduce según `serve/takeaway`.
- Pruebas revertidas: modo prueba sin stock; real por `cuenta_cerrar`; sin lotes; FIFO; doble ejecución/reintento; timeout equivalente; error intermedio; insuficiencia según funciones instaladas; sin receta; receta modificada después de capturar; receta simple/múltiple.
- Atomicidad: el error forzado en el segundo ingrediente dejó cero aplicaciones aplicadas y conservó marcadores `error`; la cuenta/caja no se alteró.
- Seguridad: helper sin `EXECUTE` para `public`, `anon`, `authenticated` ni `service_role`; tablas A3 con RLS y sin grants directos al navegador. Advisors revisados: los avisos encontrados son preexistentes o el aviso esperado de RLS sin políticas en tablas internas.
- Integridad final: `lama_stock_config`, eventos, aplicaciones y capturas: 0; productos: 1.437; suma `stock_actual`: 15.438. Ningún stock persistente cambió y no se accedió a Café del Desierto/Llamita Stock.
- Rollback: `sql/2026-10-a3-3-motor-neutral-lama-stock.rollback.sql`.


## 2026-10-06 — A3.4a: observabilidad y reproceso seguro completada

- Estado: **COMPLETADA**; A3.4b permanece pendiente y no fue activada.
- Preflight: repositorio `leoalejoleo1537/llamita-plus`, rama `work` sincronizada con `origin/master`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`) activo. Se revisaron cola, bitácora, contrato A2 y plan vigente.
- Migración aplicada: `a3_4a_observabilidad_reproceso`.
- Observabilidad: vista interna `lama_stock_eventos_observabilidad` para consultar `pendiente`, `aplicado`, `error` y `sin_receta`, incluyendo diagnóstico y conteo de aplicaciones. `security_invoker` y sin SELECT para roles públicos.
- Reproceso: `lama_stock_reintentar_evento(uuid)` solo permite eventos `error` con `modo_efectivo = prueba`; usa el `event_id` y las claves A3.3. Eventos `sin_receta` y eventos `real` son rechazados.
- Seguridad: helper sin EXECUTE para `public`, `anon`, `authenticated` ni `service_role`; no se creó una RPC pública ni permisos de mutación.
- Pruebas revertidas: estados consultables, reproceso exitoso, doble reproceso idempotente, `sin_receta`, rechazo de modo real, permisos y suma de stock sin cambios.
- Integridad final: `lama_stock_config`, eventos y aplicaciones: 0; productos: 1.437; suma `stock_actual`: 15.438. No se modificaron cierres, ventas, Fudo, áreas ni Café del Desierto/Llamita Stock.
- Rollback: `sql/2026-10-a3-4a-observabilidad-reproceso.rollback.sql`.

## 2026-10-06 — A3.4b: prueba sintética E2E Lama–Stock completada

- Estado: **COMPLETADA**; A3.4c queda pendiente y no fue activada.
- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, proyecto Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- No se modificó código de aplicación ni se aplicó una migración. La prueba se ejecutó exclusivamente dentro de `BEGIN ... ROLLBACK` usando productos, receta, cuenta, líneas, mesa, trigger y función temporales.
- Flujo verificado: `cuenta_agregar`, `cuenta_confirmar`, `cuenta_cerrar`, captura protegida, snapshot de receta, procesamiento `prueba`, aplicaciones por ingrediente, idempotencia, reintento y error intermedio.
- La receta temporal de dos ingredientes produjo dos aplicaciones esperadas con delta total `-6` para una línea de cantidad `2`. Cambiar la receta viva después de capturar no cambió el snapshot.
- Se forzó un error en el segundo ingrediente. La cuenta quedó `cerrada` y conservó total comercial `250`; el evento quedó `error` y no dejó aplicaciones parcialmente aplicadas. El reintento pasó a `prueba`; un segundo reintento no duplicó aplicaciones. Un fallo del motor de stock no impidió cerrar la mesa ni registrar sus datos comerciales.
- Conteos antes y después: cuentas `59`, líneas `88`, recetas `396`, ítems de receta `514`, productos `1437`, suma `productos.stock_actual` `15438.00`, comandas persistentes `50`; `lama_stock_config`, eventos, aplicaciones y capturas `0` en ambos cortes.
- Todos los artefactos sintéticos se revirtieron. No se activó modo real, no cambió stock persistente y no se accedió a Café del Desierto/Llamita Stock.
- Evidencia: `docs/hermes/11-pruebas-a3-4b.md`.

## 2026-10-06 — A3.4c: prueba controlada Lama en modo prueba completada

- Estado: **COMPLETADA**; A3.4d queda pendiente y no fue activada.
- Proyecto verificado: Supabase `llamita-plus` (`iuryhsjucblmebdogewa`). Repositorio: `leoalejoleo1537/llamita-plus`.
- Se ejecutó una única transacción `BEGIN ... ROLLBACK` con sede, mesa, cuenta, productos y receta sintéticos. Se reprodujo el camino que usa Lama mediante `cuenta_agregar`, `cuenta_confirmar` y `cuenta_cerrar`.
- IDs observados dentro de la transacción: cuenta `990301`; evento `646d4cb3-5124-4410-ab40-4dbd89a68b6c`; aplicaciones `2a419ca9-56bf-49b8-8bea-71645f3f10dd` y `a9bea2ef-19c9-4f25-82c8-07f4b49fa33d`.
- El evento quedó en modo/estado `prueba`; hubo dos aplicaciones por ingrediente. Dos ejecuciones posteriores de `lama_stock_aplicar_evento` devolvieron las mismas dos aplicaciones y no generaron duplicados.
- La cuenta quedó `cerrada`, el stock sintético permaneció en `10` por producto y el modo real nunca se habilitó.
- Conteos pre/post: cuentas 59, líneas 88, productos 1437, recetas 396, ítems de receta 514, comandas 50, suma de stock 15438; configuración, eventos, aplicaciones y capturas 0 tras el rollback.
- Los IDs son efímeros y fueron revertidos. No se usaron ventas reales, no se tocó Fudo, no se implementaron áreas y no se accedió a Café del Desierto/Llamita Stock.
- Procedimiento manual: `docs/hermes/12-prueba-manual-a3-4c.md`.


## 2026-10-07 — Bloque 0: auditoría de áreas, sedes y Bodega

- Estado: **COMPLETADO — solo lectura y documentación**. B1 queda pendiente y no activa.
- Repositorio: `leoalejoleo1537/llamita-plus`, remoto correcto, rama local `work`. Proyecto confirmado por metadatos: Supabase `llamita-plus` (`iuryhsjucblmebdogewa`, PostgreSQL 17.6).
- Archivo nuevo: `docs/hermes/13-auditoria-areas-sedes-bodega.md`. Se actualizaron `01-plan-areas-operativas.md`, `03-cola-de-trabajo-codex.md`, `05-decisiones-pendientes.md` y este canal/bitácora.
- Hechos clave: 1,437 productos en cuatro claves de sede (`plaza`, `angamos`, `central`, `bodega`) y stock agregado 15,438.00; Bodega activa es `central`; `bodega` queda como conjunto histórico. No hay tabla de inventario por área. Las áreas de `lama_areas` pertenecen al plano de mesas. Lotes no tienen ubicación y su suma coincide con el agregado actual por producto.
- Se documentaron rutas de escritura, trigger de lotes, Fudo/Lama, recepción/repartos, mermas, mínimos/máximos, RLS/permisos, opción arquitectónica, conciliación, archivo de Local 2, Bodega y clonación futura.
- Consultas/verificaciones: `git status`, `git remote -v`, `git branch --show-current`, lecturas `rg`/`sed`, metadatos Supabase, listado de tablas, `SELECT`, `information_schema` y `pg_catalog`; no se llamó RPC ni función de escritura.
- Verificaciones: `git diff --check` satisfactorio. No se ejecutaron pruebas de aplicación: no hubo cambios de código.
- Cambios de aplicación, esquema y datos: **ninguno**. Sin SQL de escritura, migración o inserción/actualización/borrado. No se accedió a Café del Desierto / Llamita Stock.
- Riesgos/decisiones pendientes: fuente única y corte coordinado de escritores; seguridad por sede/área; ubicación temporal sin asignar; transferencia Bodega→área atómica con lote; compatibilidad de proyección.
- Publicación autorizada: exclusivamente documentación de Bloque 0 a `master`, después de revisión de diff y `git diff --check`.

## 2026-10-06 — B1: administración segura de sedes y nodos

- Estado: **COMPLETADA**. Se ejecutó solo B1; B2 (áreas y stock por área) permanece pendiente y no activa.
- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, remoto oficial `origin`; la rama local es `work`, el destino solicitado es `master`.
- Proyecto Supabase confirmado antes de escribir: `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`. No se accedió a Café del Desierto / Llamita Stock.
- Migración aplicada: `b1_sede_registro` (`sql/2026-10-b1-registro-sedes.sql`). Se creó `public.sede_registro`, con clave estable, nombre visible, tipo y estado. RLS activado; clientes `anon` y `authenticated` solo tienen SELECT. INSERT/UPDATE/DELETE directos y EXECUTE del trigger interno se comprobaron revocados.
- Resultado: `plaza` Local 1 activa; `angamos` Local 2 archivada; `central` Bodega activa/logística; `bodega` histórica separada y archivada. La app oculta y rechaza Local 2; Bodega conserva sus rutas y destinos nuevos a Local 1. No se creó CRUD en Ajustes porque los permisos globales existentes no son una autorización segura para ese cambio.
- Conteos antes/después idénticos: productos 1,437; stock agregado 15,438.00; movimientos 431; repartos 361; líneas 2,040; lotes 42; permisos globales 9. `angamos`: 351 productos, 2,764.20 stock, 3 movimientos, 168 repartos, 533 líneas, 19 lotes (suma de lotes 134), historial 4,717, historial automático 13,062. `central`: 349 productos, 4,750.50 stock. Clave histórica `bodega`: 408 productos, 3,357.10 stock. No cambió ningún dato operativo.
- Pruebas: `npm test` pasó; `node pruebas/sedes-seguras.mjs` pasó; sintaxis JavaScript embebido válida; `git diff --check` pasó. Casos visuales de navegador se omitieron porque no hay navegador instalado.
- Advisors: no hay nuevo aviso para `sede_registro`; siguen seis tablas preexistentes RLS sin política, tres vistas SECURITY DEFINER, diez funciones con search_path mutable y avisos sobre funciones SECURITY DEFINER heredadas. Alertas de rendimiento existentes no apuntan a la tabla nueva.
- Riesgo pendiente: las guardas impiden entrar accidentalmente por la interfaz, pero no aíslan ni bloquean escrituras API/RPC directas sobre filas históricas de `angamos`; las políticas operativas heredadas siguen siendo permisivas. `app_permisos` no tiene permisos por sede.
- Archivos: `index.html`, `pruebas/sedes-seguras.mjs`, `sql/2026-10-b1-registro-sedes.sql`, `sql/2026-10-b1-registro-sedes.rollback.sql`, `docs/hermes/01-plan-areas-operativas.md`, `docs/hermes/03-cola-de-trabajo-codex.md`, `docs/hermes/06-canal-hermes-codex.md` y `docs/hermes/14-b1-registro-sedes-resultados.md`.
- Publicación: commit `36d71a3` enviado a `master` con `git push origin HEAD:master`; push verificado contra `origin/master`.

## 2026-10-07 — B2.1: cimientos del modelo de áreas operativas

- Estado: **COMPLETADA**. B2.2 permanece pendiente y no se activó.
- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, remoto `origin`; rama `work` al día con `origin/master`. Supabase confirmado por metadatos: `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`.
- Migraciones aplicadas: `b2_1_cimientos_areas_operativas`, `b2_1_indices_fk_producto_area` (cobertura de FK nuevas) y `b2_1_comentario_relacion_area` (descripción alineada con la unicidad por producto/sede).
- Tablas: `areas_operativas` con sede/código estable/nombre/estado/orden/fechas; `producto_area_asignacion` con sede/producto/área/estado/origen/regla/fechas, sin columna de cantidad. RLS activo, sin políticas ni permisos de tabla abiertos. No se otorgó acceso directo a `anon`, `authenticated` ni `service_role`.
- Áreas creadas solo en `plaza`: Cocina fría, Cocina caliente, Barra y Cafetería. Asignaciones persistidas: 0.
- Conciliación SELECT-only: 329 productos únicos de `plaza`; Barra 18/108,00; Cafetería 42/536,50; Cocina caliente 19/204,00; Cocina fría 17/17,50; Sin asignar 233/3.700,20. Cada producto aparece una vez y el total hipotético 4.566,20 reconcilia con stock actual de `plaza`. No se guardaron estas asignaciones.
- Conteos pre/post idénticos: productos 1.437; stock total 15.438,00; productos plaza 329; stock plaza 4.566,20; movimientos 431; repartos 361; líneas 2.040; lotes 42; recetas 396; ítems de receta 514; permisos 9; `lama_areas` 5. Las tablas nuevas no contienen saldos.
- Pruebas: `sql/2026-10-b2-1-pruebas-estructura.sql`, ejecutado transaccionalmente y revertido; validó áreas/sede, restricciones, trigger, unicidad, RLS, ausencia de grants/políticas y columnas de saldo. Advisor: sin FK desindexadas nuevas después de la corrección; quedan avisos intencionales de RLS sin políticas e índices aún no usados en una tabla vacía. `git diff --check` y revisión del diff al cierre.
- Archivos SQL: migración y rollback `sql/2026-10-b2-1-cimientos-areas-operativas[.rollback].sql`; conciliación `sql/2026-10-b2-1-simulacion-clasificacion.sql`; prueba `sql/2026-10-b2-1-pruebas-estructura.sql`. Resultado completo: `docs/hermes/15-b2-1-cimientos-areas.md`.
- Sin cambios en productos, stock, movimientos, repartos, lotes, recetas, permisos, `lama_areas`, `central`, `angamos` o `bodega`. No se accedió a Café del Desierto / Llamita Stock.
- Riesgo: clasificación por heurísticas descriptivas requiere revisión humana; la relación actual no modela distribución cuantitativa y no debe sumarse como stock. B2.2 debe decidir el destino de un producto repartido entre áreas, el corte de escritores y el control por sede.
- Rollback preparado, no ejecutado; aborta si hay asignaciones o catálogo distinto al estado inicial.

## 2026-10-07 — B2.2: auditoría de fuente única; requiere decisión

- Estado: **REQUIERE DECISIÓN**. B2.3 (interfaz y formularios) permanece pendiente y no se activó.
- Repositorio verificado: `leoalejoleo1537/llamita-plus`, remoto origin correcto, rama `work`, sincronizada con `origin/master` en `60e83c68a4fa24dff461576c6ccd30b00323ba7c`. Supabase verificado por metadatos: `llamita-plus`, ref `iuryhsjucblmebdogewa`, activo, PostgreSQL 17.6.
- Auditoría solo lectura: UI edita directamente `productos.stock_actual`, crea productos con saldo y reemplaza `producto_lotes`; el trigger `trg_sync_stock_lotes` recalcula el total. El catálogo instalado muestra escritores/delegados para mermas/reversa, entradas/reversa, repartos/reversa, Fudo, Lama, fusiones/reversa, restauraciones/reversa, franquicia y productos enlazados. Lectores, mínimos y máximos siguen usando saldo por producto.
- Modelo B2.1: las cuatro áreas existen solo para `plaza`; `producto_area_asignacion` tiene 0 filas, no almacena cantidad, su constraint solo permite estado asignado/sin asignar y hoy limita la relación a una fila por producto/sede. El lote carece de ubicación.
- Conteos inicio/cierre iguales: productos 1.437; stock total 15.438,00; plaza 329/4.566,20; movimientos 431/25; lotes 42/9; repartos 361/148 destino plaza; recetas 396/195. Asignaciones por área 0. Productos de plaza con lotes: 6, lotes suman 36,00 y no difieren de `stock_actual`.
- Decisión: no poblar saldos por área mientras continúen los escritores y la interfaz sobre `stock_actual`; eso crearía doble fuente editable. Recomendar ledger por ubicación como autoridad de `plaza` con agregado global de compatibilidad solo de lectura tras corte coordinado. Hace falta resolver adaptación de escritores/permisos, lotes por área y confirmación de la simulación como ubicación física.
- No hubo migración ni rollback SQL, RPC de escritura, cambios de código, SQL mutacional o cambios de datos. No se tocó `central`, `angamos`, `bodega` histórica ni áreas operativas. No se accedió a Café del Desierto / Llamita Stock.
- Informe: `docs/hermes/16-b2-2-auditoria-fuente-unica-stock.md`. `git diff --check` debe pasar antes de publicar documentación. B2.3 sigue pendiente.

## 2026-10-07 — Decisión aprobada: libro de existencias por ubicación

- Alejo aprobó la arquitectura del inventario por ubicación documentada en `docs/hermes/17-decision-libro-existencias-ubicacion.md`.
- B2.2 queda **REQUIERE DECISIÓN RESUELTA** como fase de decisión; no queda implementada la fuente de stock. No se activó B2.3.
- Fuente futura única: libro por producto, sede, ubicación y lote cuando aplique. `productos.stock_actual` será una proyección de compatibilidad no editable.
- La migración inicial futura llevará todo `central` a Bodega central; todo `plaza` y sus lotes a Sin asignar; no migrará `angamos` ni la clave histórica `bodega`. No habrá clasificación histórica automática.
- Operación aprobada: nuevos productos físicos entran primero a Bodega; el reparto elige área y mueve stock atómicamente conservando producto, cantidad, usuario, fecha y lote; la merma global indica área; búsqueda, críticos y reportes calculan por área. Recetas y Lama–Stock real permanecen desactivados hasta que el modelo esté funcionando.
- Alcance de esta ejecución: actualizar documentación Hermes únicamente. Sin SQL, tablas, migraciones, código, operaciones ni cambios de datos. Café del Desierto / Llamita Stock no fue tocado.
- B2.3 (interfaz/formularios sobre el modelo implementado) queda **PENDIENTE**, no activado. El plan y el documento 17 describen sus precondiciones y criterios.

## 2026-10-07 — B2.3: corte del libro por ubicación detenido

- Estado: **REQUIERE DECISIÓN**; B2.4 queda **PENDIENTE**, no activada.
- Entorno: repositorio `leoalejoleo1537/llamita-plus`, remoto origin esperado, rama `work`, HEAD igual a `origin/master` al inicio (`aaa428fe05d81191dcf58976e515518a688e6fe2`). Supabase `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.
- B2.3 se detuvo antes de cualquier cambio de base de datos/código: `productos.stock_actual` y `producto_lotes` conservan escritores de la interfaz, DML directo vía Data API con políticas/grants permisivos, un trigger de lotes que reescribe el agregado, RPC de inventario y rutas heredadas de Fudo y Lama. No se puede declarar que el saldo antiguo esté cortado ni bloquearlo con seguridad sin diseñar el alcance por sede y preservar operaciones relacionadas.
- Conteos SELECT de inicio/cierre: productos 1.437, stock global 15.438,00; `central` 349 / 4.750,50; `plaza` 329 / 4.566,20. Lotes: `central` 2 / 96,00, un producto con lotes y cero diferencias; `plaza` 9 / 36,00, seis productos con lotes y cero diferencias. Los lotes no se suman otra vez al stock.
- Otros conteos: movimientos 431 (403 central, 25 plaza), repartos 361, recetas 396, líneas de receta 514, permisos 9, asignaciones preparatorias producto-área 0, `lama_areas` 5. Sin escrituras no hay pre/post de migración; conteos inicio/cierre iguales. `angamos` y clave histórica `bodega` no se migraron.
- `productos.stock_actual` continúa como fuente editable vigente, no como proyección. No se crearon libro, ubicaciones con saldo ni distribución hacia áreas. No cambió lotes, producto, movimientos, repartos, recetas, permisos, Fudo ni Lama.
- Evidencia y matriz de bloqueos: `docs/hermes/18-b2-3-bloqueo-corte-libro-ubicaciones.md`. El documento 17 y plan 01 aclaran que la interfaz de áreas queda para UX posterior; B2.3 es el corte del libro.
- Consultas SELECT-only y catálogo de políticas, grants, funciones y trigger; no se probaron escrituras ni migraciones por ser inseguro y no existir implementación. `git diff --check` se ejecuta antes de publicar documentación.
- Sin cambios en Café del Desierto / Llamita Stock. B2.4 queda pendiente y no se activa automáticamente.

## 2026-10-07 — B2.3: corte coordinado y libro por ubicación completados

- Estado: **COMPLETADA** para `central` y `plaza`; B2.4 permanece **PENDIENTE**, no activa. El bloqueo del primer intento documentado arriba y en el informe 18 quedó resuelto por autorización explícita posterior de Alejo.
- Entorno: repositorio `leoalejoleo1537/llamita-plus`, remoto oficial; rama de trabajo `work`. Proyecto Supabase Llamita Plus `iuryhsjucblmebdogewa`, confirmado antes de aplicar cambios.
- Migraciones instaladas: `20261007152558 b2_3_libro_existencias_corte`; `20261007152805 b2_3_indices_permisos_libro`.
- Modelo: esquema privado `stock_internal`; catálogo `ubicaciones`; libro inmutable `movimientos`; `aperturas`; `transferencias`; `permiso_proyeccion`; vista `existencias`. RLS y políticas restrictivas de denegación; sin permisos directos a roles de aplicación.
- Apertura: 150 productos de `central` a Bodega central = 4.750,50; 258 de `plaza` a Sin asignar = 4.566,20. Libro: 408 aperturas/9.316,70. No hubo clasificación histórica y las cuatro ubicaciones físicas de `plaza` quedaron con saldo cero.
- Conteos pre/post: productos 1.437; stock total 15.438,00; `central` 349/4.750,50; `plaza` 329/4.566,20; `angamos` 351/2.764,20; `bodega` histórica 408/3.357,10; lotes 42/304,00; movimientos legacy 431; repartos/líneas 361/2.040; recetas/líneas 396/514; permisos 9; `lama_stock_config` 0. Todos iguales. Conciliación por producto/sede sin diferencias.
- Escritores: saldo directo, altas con saldo, lotes, trigger histórico de lotes y rutas legacy de movimientos, entradas, mermas, repartos/deshacer, restauraciones y fusiones bloqueados para `central`/`plaza`. `productos.stock_actual` queda como proyección protegida y se refresca solo con permiso interno transaccional. Otras sedes mantienen compatibilidad.
- Fudo: guardas añadidas a cinco fuentes Edge, que **no fueron desplegadas**; triggers bloquean modo real y aplicación en base. Ningún cambio remoto de Fudo. Plaza sigue en modo prueba y cron apagado. Lama real sigue apagado; configuración vacía.
- Pruebas: SQL sintético `BEGIN ... ROLLBACK` validó conciliación, lote sin doble suma, permisos, writers bloqueados, configuraciones reales bloqueadas, transferencia Bodega -12/Cafetería +12 con producto lógico/lote/referencia comunes, total conservado e idempotencia. Post-rollback no quedaron aplicaciones ni transferencias sintéticas. `npm test` exit 0; análisis esbuild de cinco fuentes Edge exit 0; `git diff --check` pasó. Pruebas visuales omitidas por ausencia de navegador.
- Seguridad/rendimiento: advisor ya no marca `stock_internal` como RLS sin política; se agregaron índices de FK faltantes. Permanecen avisos previos de vistas/tablas ajenas y avisos de índices nuevos aún no usados.
- Rollback técnico `sql/2026-10-b2-3-libro-existencias.rollback.sql`: aborta si hay operaciones posteriores; luego solo compensación auditada, sin borrar movimientos.
- Resultado detallado: `docs/hermes/19-b2-3-corte-libro-ubicaciones.md`. No se tocó Café del Desierto / Llamita Stock; no se cambió ningún stock persistente previo ni datos comerciales. B2.4 no se activó.

## 2026-10-07 — B2.3.1: blindaje de origen POS por sede

- Estado: **COMPLETADA**. B2.4 continúa **PENDIENTE**, no activa. Entorno confirmado: repositorio oficial `leoalejoleo1537/llamita-plus`, proyecto Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- Configuración previa verificada: `fudo_sync` solo tenía modo/cursor, `lama_stock_config` modo Lama y `ajustes` flags booleanos. Se creó `stock_internal.origen_pos`, una fila por sede con origen restringido. `plaza`, `central`, `angamos` y `bodega` quedaron `ninguno`.
- Migración aplicada `20261007162948 b2_3_1_pos_origin_guard`; fuente local `supabase/migrations/20261007162700_b2_3_1_pos_origin_guard.sql`.
- Backend: `public.stock_pos_origen_permitido` solo ejecutable por `service_role`; tabla interna sin grants; `fudo_procesar_item` cerrado a roles de navegador y protegido por origen; triggers bloquean DML de Fudo y real de Lama cuando el proveedor no coincide. La definición instalada del motor Lama exige origen Lama antes de aplicación real, además del bloqueo de modo actual.
- Edge desplegadas `ACTIVE`, v1, `verify_jwt=true`, marker `2026-10-07-b2.3.1`: ciclo, sync ventas, empujar stock, deshacer, sumar y probar escritura. Se recuperaron las seis fuentes desplegadas y se confirmó guard + marker. Invocación sin JWT devuelve 401.
- Pruebas transaccionales: estado `ninguno/prueba`, segundo POS duplicado, central/archivadas/histórica, RPC/Fudo DML, Lama real, ACL/RLS y helper bajo `SET LOCAL ROLE service_role`. Sin escrituras persistentes.
- Estado post: orígenes ninguno (4 filas); `plaza fudo_sync` prueba/cron false; Lama config 0; productos 1.437/stock 15.438; movimientos 431; fudo_movimientos 15.357. Fudo remoto no fue consultado ni modificado.
- `npm test`, esbuild, `git diff --check` y advisors ejecutados. Sin nuevos findings asociados a la configuración; avisos previos ajenos persisten. `docs/hermes/20-b2-3-1-blindaje-origen-pos.md` describe despliegues, permisos, pruebas y riesgos.
- No hay selector de Ajustes. Futuro endpoint debe verificar `app_permisos.puede_ajustes`; no se otorgó escritura a navegador/`service_role`. No se activó Fudo/Lama real, Toteat ni B2.4. No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-07 — B2.4: motor seguro de transferencias entre ubicaciones

- Estado: **COMPLETADA**. B3 —interfaz de áreas— queda **PENDIENTE**, no activada. Se ejecutó solo en `leoalejoleo1537/llamita-plus`, Supabase `llamita-plus` ref `iuryhsjucblmebdogewa`. No se accedió a Café del Desierto / Llamita Stock.
- Migraciones verificadas en el historial remoto: `20261007165310 b2_4_transferencias_ubicaciones_seguras`, `20261007165656 b2_4_index_lote_continuidad_transferencia`, `20261007165826 b2_4_secure_transfer_entrypoint`.
- Motor: `stock_internal.transferencias` + pares de `stock_internal.movimientos` inmutables y balanceados. `public.stock_transferir` es `SECURITY INVOKER`; exige JWT autenticado, UID/email coincidentes y `app_permisos.puede_editar`. El helper privado repite validación y el núcleo queda reservado al propietario. No hay DML directo de tablas para `anon`, `authenticated` ni `service_role`.
- Rutas admitidas: Bodega central→área activa plaza con `producto_enlace` real factor 1; Sin asignar→área; área→área con mismo producto. No se comparan nombres ni se crean enlaces. Una referencia UUID serializa la llamada; payload repetido idéntico retorna resultado existente y payload diferente falla. Un constraint trigger diferido valida el par completo.
- Lotes: se conserva el ID canónico de `producto_lotes` y vencimiento en `stock_internal.lote_continuidad`, asociado al producto destino; no se crea lote de origen ficticio. Detalle legado sin lote solo puede reclasificarse si el saldo agregado alcanza para cubrirlo, mediante movimientos balanceados en la misma transacción.
- Pruebas ejecutadas desde `sql/2026-10-b2-4-pruebas-transferencias.sql`, todas dentro de `BEGIN ... ROLLBACK`: Bodega→Cafetería, Sin asignar→Barra, área→área, lote y sin lote, saldo insuficiente, producto sin enlace, repetición idempotente, fallo forzado entre movimientos, permiso insuficiente, llamada de usuario authenticated, ACL/RLS, par diferido y suma/no-negatividad. Sin Fudo remoto ni Lama real.
- Conteos post rollback: productos 1.437; `stock_actual` global 15.438,00; lotes 42; neto del libro 9.316,70; transferencias persistentes 0; continuidad nueva 0; clasificaciones persistentes 0; movimientos de transferencia persistentes 0; `fudo_movimientos` 15.357; movimientos legacy 431; configuraciones Lama real 0. Total global conservado y `stock_actual` coincide con la proyección del libro.
- Aclaración de proyección: `productos.stock_actual` no se modifica directamente por el motor. El trigger contable actualiza su proyección; en transferencias entre productos maestros distintos, los agregados individuales origen/destino cambian en sentidos opuestos, pero la suma global se conserva.
- Reversa: rollback técnico `sql/2026-10-b2-4-transferencias-ubicaciones.rollback.sql` aborta si ya hay actividad B2.4. Tras actividad persistida solo procede reversa compensatoria auditada; el campo `reversa_de` prepara el vínculo, pero aún no existe endpoint de reversa.
- Riesgos: writers cotidianos legacy permanecen bloqueados por B2.3; aún no hay UI de transferencia ni acceso para usuarios sin `puede_editar`; lotes históricos con discrepancia respecto del saldo agregado quedan bloqueados para revisión. Los índices recién creados pueden aparecer como no usados en advisors hasta que haya volumen de transferencias.
- Resultado detallado: `docs/hermes/21-b2-4-motor-transferencias-ubicaciones.md`. Se ejecutó `git diff --check`; B3 no se activa automáticamente.
## 2026-10-07 — B3.1: interfaz de lectura y navegación por áreas

- Estado: **COMPLETADA**. B3.2 queda **PENDIENTE**, no activa.
- Entorno confirmado: `leoalejoleo1537/llamita-plus`, remoto oficial, rama `work`; Supabase Llamita Plus `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166.
- Se añadieron a `plaza` portada con seis tarjetas, lista filtrada de la ubicación y vista global con cantidades separadas por producto/ubicación. Sin asignar se describe como stock inicial pendiente de distribución. Áreas físicas muestran saldo cero y “sin mínimos configurados”; no se inventan críticos. Bodega sigue con su renderer anterior.
- Lectura: `public.stock_leer_areas()` (SECURITY INVOKER; `EXECUTE` solo authenticated) y helper `stock_internal.leer_existencias_areas_plaza()` (SECURITY DEFINER, search_path vacío, sesión obligatoria). Las cifras salen de `stock_internal.existencias`; ninguna función lee `productos.stock_actual`. El helper mantiene productos inactivos si aún tienen saldo positivo.
- Migraciones aplicadas exclusivamente en Llamita Plus: `20261007174518 b3_1_lectura_inventario_areas`, `20261007174626 b3_1_include_inactive_stock_products`.
- Resultado autenticado y conciliado: Barra, Cafetería, Cocina caliente y Cocina fría 0/0,00; Sin asignar 255 productos con saldo / 4.566,20; total RPC = libro de plaza. Conteos SELECT: productos 1.437 (plaza 329), central 4.750,50, movimientos del libro 408, transferencias 0, lotes 42 y líneas de receta 514. Sin DML ni cambios en conteos/datos comerciales.
- Seguridad: anon no ejecuta funciones; authenticated ejecuta RPC/helper; service_role no ejecuta; ningún rol de aplicación probado tiene INSERT de movimientos y authenticated no actualiza ubicaciones. Consulta sin sesión rechazada. Advisors Supabase muestran hallazgos globales preexistentes, separados del RPC nuevo; quedan documentados para revisión fuera de este bloque.
- Verificación: SQL autenticado dentro de `BEGIN ... ROLLBACK`, conciliación, privilegios, `node pruebas/pantalla-sana.mjs`, `node --check pruebas/inventario-areas.mjs`, `npm test`, `git diff --check`. Chromium no está instalado: los checks visuales automatizados se omiten; el informe 22 contiene pasos manuales desktop/móvil y revisión de consola.
- Rollback: `sql/2026-10-b3-1-lectura-areas.rollback.sql` elimina solo ambas funciones de lectura. Sin filas/saldos nuevos que revertir.
- Informe: `docs/hermes/22-b3-1-lectura-areas.md`. B3.2 sigue sin activar. No se accedió a Café del Desierto / Llamita Stock.
- Publicación de aplicación y migraciones: commit `2a9c8c2` enviado a `origin/master`.
## 2026-10-08 — B3.2a.2 completada: interfaz dinámica de áreas

- Repositorio y destino verificados: `leoalejoleo1537/llamita-plus`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- La lectura del ledger dejó de filtrar cuatro códigos: usa todas las áreas activas vinculadas de `plaza` y conserva `sin_asignar` como ubicación lógica.
- Se añadió `producto_area_preferencia_leer(bigint,text)` con sesión obligatoria, `search_path=''`, objetos calificados y `EXECUTE` solo para `authenticated`.
- La interfaz de Inventario genera tarjetas desde las RPC, incorpora áreas nuevas con saldo cero, conserva Todas/Sin asignar y no cambia Bodega.
- Ajustes administra crear/editar/archivar mediante las cuatro RPC de B3.2a.1. La UI no hace DML directo sobre áreas/asignaciones.
- Las altas normales y del taller de recetas en `plaza` usan `producto_plaza_crear`; Bodega/Enlaces y Edge Functions Fudo quedaron intactos. La edición de preferencia usa su RPC y muestra aparte ubicación/saldo físico.
- Migraciones remotas: `20261008210149 b3_2a_2_lectura_dinamica_areas` y corrección de delegación invoker `20261008210212 b3_2a_2_restaurar_execute_lector`. La primera prueba detectó el grant faltante; falló antes de persistir y se revirtió. La corrección solo restituyó el `EXECUTE` requerido por `stock_leer_areas`.
- Prueba SQL transaccional final correcta: Heladería dinámica, renombre, producto con/sin preferencia, archivo y roles; `ROLLBACK` dejó cero sintéticos.
- Conteos pre/post idénticos: 1.437 productos; stock global 15.438,00; ledger 9.316,70; 42 lotes; 431 movimientos legacy; 408 ledger; 0 transferencias; 396 recetas; 15.357 movimientos Fudo; 0 eventos Lama.
- `npm test`, sintaxis JS, advisors, ACL/RPC y `git diff --check` pasaron. No había Chromium; procedimiento manual desktop/móvil documentado en el informe 29.
- No se accedió a Café del Desierto / Llamita Stock. B3.2a.3 y B3.2b siguen pendientes.
# 2026-10-23 — Corrección circuito Mocachino E2E

- Implementados acceso móvil real a Mesas, guard global de rueda numérica, costo editable, secciones en contexto, ficha atómica organización+conteo, sección auditable en repartos y candidatos pendientes en recetas.
- Migraciones instaladas exclusivamente en Llamita Plus: `20261023152940`, `20261023204230`, `20261023204300`, `20261023204333`.
- SQL con `ROLLBACK` (incluida repetición E2E de P4: receta multiárea, reserva, consumo y reversa), `npm test`, Chromium real móvil/escritorio y `git diff --check` aprobados. Conteos pre/post idénticos: productos 1.438; ledger 9.337,7; lotes 42; movimientos ledger 424; repartos área 5; recetas 396; Fudo movimientos 15.357. Cero sintéticos del circuito.
- AM/PM fue retirado de UI, RPC y columnas de `area_secciones`/`secciones`; sus valores previos tienen respaldo interno versionado. Informe: `docs/hermes/38-circuito-mocachino-e2e.md`.
- No se accedió a Café del Desierto / Llamita Stock ni se tocó Fudo remoto, caja, pagos o recetas heredadas.

# 2026-10-27 — Reparación de acceso a Inventario por áreas

- Se reprodujo el error real de la portada de Inventario con una sesión operativa de Llamita Plus. La causa no era la conexión del teléfono ni del navegador: `stock_internal.leer_existencias_areas_plaza()` intentaba aplicar un `ORDER BY` con expresiones al nivel de un `UNION ALL`, lo que PostgreSQL rechazaba con `0A000 invalid UNION/INTERSECT/EXCEPT ORDER BY clause`.
- Se instaló la migración `20261027231127_reparar_lectura_inventario_areas`. La unión quedó encapsulada en la CTE `filas` y el orden se aplica sobre columnas explícitas de esa relación. No cambió el contrato de `public.stock_leer_areas()`, sus cantidades ni las fuentes del ledger.
- Verificación autenticada posterior: 266 filas leídas, cuatro áreas activas y total de 4.613,2 unidades; el total coincide exactamente con `stock_internal.existencias` para las ubicaciones activas de Local 1. Una sesión anónima continúa rechazada.
- Se añadió `supabase/tests/inventario_areas_lectura.sql`, ejecutado dentro de `BEGIN … ROLLBACK`, para comprobar lectura, conciliación con el ledger y rechazo anónimo. No hubo escrituras de negocio ni cambios de stock, productos, lotes, movimientos o repartos.
- La ejecución completa de `npm test` sigue exponiendo pruebas de navegador históricas desactualizadas (`ajustes-navegacion.mjs` aún simula el contrato anterior de permisos y AM/PM; `inventario-areas.mjs` aún busca el botón separado de conteo eliminado por la ficha unificada). No se confundieron esos fallos del arnés con el bloqueo SQL de producción; quedan para saneamiento separado.
- No se accedió a Café del Desierto / Llamita Stock y no se tocaron Fudo, Lama, caja, recetas ni el motor de transferencias.

## Corrección del mismo cierre

- La primera verificación configuró claims autenticados, pero no ejecutó con `SET ROLE authenticated`; por eso no detectó que la migración había revocado el `EXECUTE` interno requerido por la RPC pública `SECURITY INVOKER`. En el navegador el error persistía como `42501 permission denied for function leer_existencias_areas_plaza`.
- Se añadió `20261027234000_restaurar_execute_lector_areas`, que devuelve únicamente `EXECUTE` sobre el lector interno a `authenticated`, tal como exigía el contrato delegado previo. `anon` y `service_role` continúan sin ese permiso y no se concedió DML.
- La prueba de regresión ahora usa explícitamente `SET LOCAL ROLE authenticated`, además de los claims JWT, para reproducir la ejecución real de PostgREST y evitar otro falso positivo de privilegios.
