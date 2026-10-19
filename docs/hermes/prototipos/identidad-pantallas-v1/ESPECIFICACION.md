# Propuestas visuales v1 · módulos pendientes

Estado: prototipos HTML para revisar e implementar por etapas. Datos ficticios. Referencia de identidad: fondo `#F6FFF8`, superficies blancas, tinta oscura, acento `#F35B04`, sombras suaves, radios redondos y dibujo lineal solo donde aclara la función. Sin contornos de selección gruesos, sin cabecera redundante «Local 1 · módulo», con la acción principal evidente. En teléfono, la navegación inferior permanece visible y los cuadros emergentes pasan a hoja inferior. El modo oscuro conserva la jerarquía.

Abrir [el índice](index.html) para recorrer las ocho pantallas. [Mermas](../mermas-identidad-v1.html) ya tiene una propuesta separada. Las páginas `.html` comparten `pantallas.css` y `pantallas.js`. No son código de aplicación ni alteran datos.

## Mesas · `mesas.html`

1. Objetivo: ubicar una mesa, ver su cuenta y actuar sin perder el plano.
2. Flujo: elegir salón → tocar mesa → si está libre, abrirla; si está ocupada, revisar cuenta → agregar productos o cobrar → volver al plano.
3. Pantallas: plano + cuenta contextual; hojas «Abrir mesa», «Agregar a Mesa 4», cantidad de producto y «Cobrar Mesa 4».
4. Textos: «Salón», «Terraza», «Libre», «Cuenta abierta», «Agregar productos», «Cobrar», «Ver precuenta», «Cerrar mesa», «Abrir mesa».
5. Errores: mesa cambiada por otra persona, producto no disponible, importe inválido, fallo al cobrar.
6. Alertas: «Esta mesa cambió. Revisa la cuenta antes de seguir»; «No se pudo cobrar. La cuenta sigue abierta».
7. Después: actualizar plano y cuenta con el estado real; mantener el foco en la mesa elegida.
8. Hermes: conservar los estados de mesa, confirmación de comanda, cobro parcial, anulaciones, caja y descuento de inventario al cierre. El prototipo no define nuevos disparadores.

## Reparto · `reparto.html`

1. Objetivo: armar un pedido y reconocer qué repartos esperan recepción.
2. Flujo: «Armar pedido» → buscar y elegir productos → revisar cantidades → enviar. Para recibir: abrir reparto → comparar con lo físico → confirmar lo recibido.
3. Pantallas: lista por confirmar/cerrados; hojas de pedido, cantidad y recepción.
4. Textos: «Armar pedido», «Por confirmar», «Revisar», «Enviar reparto», «Confirmar recepción», «Repartos cerrados».
5. Errores: cantidad mayor a la disponible, producto sin enlace, recepción parcial, doble toque y pérdida de conexión.
6. Alertas: «Este producto no se puede enviar todavía»; «Confirma solo lo que llegó físicamente»; «No se confirmó: intenta de nuevo».
7. Después: el pedido aparece como pendiente; el stock cambia solo al confirmar recepción, según la ruta vigente.
8. Hermes: validar rutas de Bodega a área, estados e idempotencia antes de conectar los botones. Franquicias conservan su flujo propio.

## Arqueo · `arqueo.html`

1. Objetivo: ver el turno vigente y cerrar la caja con un conteo entendible.
2. Flujo: abrir arqueo con monto inicial si no existe → ver saldo/ventas → contar cada medio → leer diferencia y mesas abiertas → finalizar.
3. Pantallas: turno e historial; hoja «Finalizar arqueo» y detalle de uno cerrado.
4. Textos: «Caja principal», «Saldo actual», «Total de ventas», «Contar y finalizar», «Efectivo contado», «Tarjeta según comprobante», «Finalizar arqueo».
5. Errores: medio sin contar, hora futura, conexión fallida o segundo turno abierto.
6. Alertas: «Falta contar algún medio»; «Hay mesas abiertas»; «No se pudo finalizar. Revisa tu señal».
7. Después: mostrar el arqueo cerrado con sus importes congelados y habilitar un nuevo turno según reglas vigentes.
8. Hermes: respetar arqueo ciego y no mostrar cifras del sistema cuando esté activado; conservar autorización, medios, cálculos y cierre irreversibles.

## Movimientos de caja · `movimientos.html`

1. Objetivo: anotar ingresos y egresos manuales del turno.
2. Flujo: tocar «Registrar movimiento» → elegir ingreso/egreso → indicar monto y motivo → revisar → registrar → ver la fila nueva.
3. Pantallas: resumen/lista, hoja de registro y detalle.
4. Textos: «Ingresos», «Egresos», «Monto», «Motivo», «Registrar movimiento».
5. Errores: sin arqueo abierto, monto vacío/cero, motivo vacío, conexión fallida.
6. Alertas: «Abre un arqueo para registrar movimientos»; «Escribe un monto mayor que cero»; «El movimiento no se guardó».
7. Después: agregar la fila al historial y actualizar el saldo del turno.
8. Hermes: usar la operación de movimiento existente y la misma fuente que Arqueo; no crear otra caja ni saldo paralelo.

## Recetas · `recetas.html`

1. Objetivo: encontrar un combo y revisar qué insumos tiene asociados.
2. Flujo: buscar combo → abrir ficha → revisar/ajustar insumos, cantidad y momento de aplicación → guardar.
3. Pantallas: lista; hojas «Editar receta» y «Crear combo».
4. Textos: «Buscar receta o producto», «Crear combo», «Insumos», «Agregar insumo», «Guardar receta».
5. Errores: producto vendido no encontrado, insumo duplicado o sin ubicación, cantidad inválida.
6. Alertas: «Elige un producto vendido»; «Revisa los insumos repetidos»; «Falta definir el área de este insumo».
7. Después: volver a la ficha con resumen de insumos y estado actualizado.
8. Hermes: mantener el modelo de receta e integración Fudo/Lama vigente; las áreas de producción y descuentos pendientes requieren validación arquitectónica.

## Historial · `historial.html`

1. Objetivo: guardar y consultar la fotografía del inventario de un día.
2. Flujo: ver días recientes → abrir día y consultar productos/Excel; para hoy, guardar y confirmar reemplazo si ya existe.
3. Pantallas: días; detalle; hoja «Guardar inventario de hoy» y confirmación de reemplazo.
4. Textos: «Guardar inventario de hoy», «Ver», «Descargar Excel», «Volver al historial», «Reemplazar».
5. Errores: lectura incompleta, falla de red, guardado previo de hoy.
6. Alertas: «Ya guardaste el inventario de hoy. ¿Lo reemplazamos?»; «No se pudo guardar. Revisa tu señal».
7. Después: mostrar el día en primer lugar y conservar la consulta del detalle.
8. Hermes: no alterar el formato de instantáneas ni su fuente de datos; revisar en el futuro la interpretación de cantidades por ubicación.

## Bodega · `bodega.html`

1. Objetivo: consultar stock maestro y entrar sin confusión a recibir, enviar y enlaces.
2. Flujo: seleccionar «Stock», «Recibir», «Enviar» o «Enlaces» → buscar producto/destino → revisar → ejecutar la operación vigente.
3. Pantallas: cuatro vistas compactas; hojas de producto, alta, entrada y envío.
4. Textos: «Buscar producto en Bodega», «Agregar producto», «Registrar entrada», «Armar envío», «Crear envío», «Enlaces».
5. Errores: duplicado, producto sin enlace, cantidad insuficiente, destino equivocado, falla de red.
6. Alertas: «Revisa si el producto ya existe»; «Este destino necesita un enlace»; «No se creó el envío».
7. Después: mostrar el registro/estado actualizado; una preparación para un local no cambia el stock hasta la recepción.
8. Hermes: Bodega es catálogo maestro; respetar `stock_internal` y la ruta de recepción. Los envíos a franquicias no se equiparan a los de locales.

## Ajustes · `ajustes.html`

1. Objetivo: encontrar las opciones sin exponer en la portada un panel repleto de controles.
2. Flujo: elegir sección → editar una configuración permitida → revisar efecto → guardar o cancelar.
3. Pantallas: índice de secciones y panel contextual; muestra de Apariencia con cambio claro/oscuro.
4. Textos: «Productos e inventario», «Mesas», «Integraciones», «Personas y permisos», «Apariencia», «Modo oscuro».
5. Errores: acceso insuficiente, cambio concurrente, configuración inválida.
6. Alertas: «No tienes permiso para cambiar esto»; «Otro usuario actualizó esta opción. Revísala antes de guardar».
7. Después: volver a la sección correspondiente y mostrar el valor vigente.
8. Hermes: no alterar permisos, interruptores, Fudo ni reglas de configuración; solo jerarquía visual y navegación.

## Regla de implementación

Aplicar primero la presentación sobre los datos y eventos reales de `index.html`. Los prototipos usan ejemplos y no autorizan escrituras nuevas, migraciones ni cambios comerciales. Si un módulo no está activo para la sede o el permiso actual, no se fuerza su aparición. Las ventanas deben poder cerrarse con «Cancelar», clic fuera y Escape; en móvil los botones de confirmación deben permanecer visibles. Comprobar teclado, contraste, modo oscuro y ancho 375–390 px.
