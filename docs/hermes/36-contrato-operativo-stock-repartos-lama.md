# Contrato operativo — Ajustes, repartos y ventas por áreas

**Fecha:** 19 de octubre de 2026  
**Estado:** especificación aprobada; Fases 1 y 2 completadas el 20 de octubre de 2026. Fase 3 continúa pendiente.
**Repositorio:** `leoalejoleo1537/llamita-plus`  
**Propósito:** convertir las decisiones conversadas en reglas que Codex pueda aplicar sin reinterpretar la operación de Brunetti.

> Este documento no activa por sí mismo una migración ni autoriza a implementar todos los bloques juntos. Codex debe inspeccionar el estado vigente y trabajar una fase por vez. Las reglas de negocio aquí escritas prevalecen sobre notas anteriores que todavía describan inventario de solo lectura, recepción sin diferencias o recetas desconectadas de Lama.

## 1. Resultado que se busca

Una persona responsable de un área debe poder:

1. Ver y corregir el inventario físico real de su área.
2. Recibir allí los repartos que Bodega preparó específicamente para esa área.
3. Marcar productos urgentes para que Bodega priorice pedidos o reposición.
4. Vender/comandar desde Lama con disponibilidad visible y sin vender cantidades que el sistema sabe que no existen.
5. Usar recetas y combos para descontar sus componentes desde las áreas donde realmente están.

Bodega debe poder abastecer cualquier área operativa activa, presente o futura, sin listas de destinos rígidas.

El modelo debe tolerar el desorden de prueba y las fallas humanas sin fabricar silenciosamente saldos, dejar existencias negativas ni obligar al usuario a resolver cada diferencia antes de continuar.

## 2. Qué existe según el mapa y la bitácora vigentes

La documentación vigente de Hermes deja estas bases construidas:

- `stock_internal.existencias` es la lectura autoritativa del saldo por ubicación.
- `stock_internal.movimientos` conserva los cambios del ledger.
- Hay ubicaciones para Bodega, Sin asignar y áreas operativas.
- `public.stock_transferir` y el motor interno realizan transferencias idempotentes entre Bodega y áreas activas.
- Las áreas son dinámicas; una futura área no debe necesitar una lista de códigos en el cliente.
- Existe configuración producto–área–sección–mínimos/máximos.
- La representación local puede vincularse explícitamente al producto maestro de Bodega.
- La interfaz de área recuperó buscador, píldoras, secciones desplegables, filas, filtros y ficha/modal.
- Lama ya cuenta con cimientos para capturar eventos y snapshots de receta en modo controlado, pero esto no significa que la venta actual ya esté limitada por stock real.
- Las notas del proyecto describen varios caminos legacy de escritura que fueron bloqueados para Bodega/Local 1. No debe reactivarse una escritura directa a `productos.stock_actual`.

Estas son bases y antecedentes, no prueba de que los tres circuitos operativos solicitados ya funcionen de extremo a extremo. Codex debe verificar las funciones instaladas antes de cada fase y reportar qué está efectivamente activo.

## 3. Vocabulario que no se debe mezclar

| Concepto | Significado |
|---|---|
| Producto maestro | Identidad común del producto, creada/administrada desde Bodega. |
| Área | Lugar de operación: Cafetería, Barra, Cocina fría, Cocina caliente, Heladería u otra área activa. |
| Sección | Lugar físico dentro del área: Refrigerador, Congelador, Vitrina, Mueble, etc. |
| Existencia | Cantidad física que el ledger atribuye al producto en una ubicación. |
| Ajuste | Corrección del saldo físico contado frente al saldo que llevaba el sistema. |
| Reparto | Documento que registra qué se preparó para un área, qué salió documentalmente y qué recibió el área. |
| Urgente | Marca manual de prioridad; no es sinónimo de crítico ni mueve stock. |
| Receta/Combo | Componentes y cantidades que se consumen al vender un producto preparado o agrupado. |

Área no es sección. Una bandeja de recepción tampoco es otra área ni otra sede.

## 4. Reglas aprobadas por Alejo

### 4.1 Fuente única y libertad operativa para corregir cantidades

La persona debe poder editar manualmente la existencia contada de cualquier producto en Bodega o en un área, usando el control de inventario existente como experiencia de usuario. No es una excepción temporal: será una regla general del proyecto para corregir errores de registro, movimientos de emergencia y diferencias entre el sistema y el conteo físico.

Ejemplo: Cocina fría recibió físicamente 10 kg de carne, pero nadie registró el envío. Al hacer inventario, su responsable debe poder cambiar el saldo mostrado de 0 a 10 y continuar trabajando.

**Significado técnico obligatorio:**

- La edición que ve el usuario equivale a indicar el nuevo saldo contado: por ejemplo, “había 0; ahora conté 10”.
- La operación calcula la diferencia y la representa como un movimiento auditable del ledger.
- No se permite editar directamente `productos.stock_actual`; ese campo no puede convertirse en una segunda fuente.
- La corrección debe ser breve y práctica: motivo predefinido/rápido, con opción de observación cuando sea útil. No convertir el conteo en un formulario burocrático.
- La autorización debe seguir la capacidad operativa que ya habilita edición de inventario (`puede_editar`) durante la fase de prueba. No inventar ahora una jerarquía especial para Don Juan o jefes de turno.
- El ajuste debe afectar solo el producto y ubicación elegidos, guardar actor y fecha, y ser idempotente ante reintentos.
- Ninguna ruta de la aplicación puede dejar saldo negativo. La regla se aplica en backend/base de datos, no solo con validación visual.
- Ajustes, recepción, ventas, mermas, reversas y demás escritores deben converger al ledger. No reabrir escritores legacy que modifican el agregado directamente.

Esta libertad es necesaria para operar con datos imperfectos. No significa aceptar mutaciones invisibles o permitir saldos negativos.

### 4.2 Reparto: destino definido y recepción dentro del área

Bodega prepara cada reparto con un único destino explícito: un área activa de Local 1. El selector debe ser dinámico y admitir cualquier área futura; no debe incluir como destinos de esta ruta nombres de clientes o locales de un sistema de franquicias.

Cada área tiene su propia entrada o bandeja **“Recepciones de reparto”**, filtrada por destino. No hay una bandeja global ambigua en la que Cocina fría pueda aceptar por error un reparto dirigido a Cocina caliente. Los usuarios pueden consultar otras áreas, pero la recepción se realiza desde la bandeja del área destino y debe mostrar claramente el nombre de esa área.

Secuencia conceptual:

1. Bodega crea y prepara un reparto dirigido a un área.
2. El reparto aparece en la bandeja de recepción de esa área.
3. La persona destinataria verifica lo que llegó y registra cantidades físicas recibidas, por línea.
4. Confirma la recepción.
5. El sistema aplica inmediatamente los movimientos correspondientes, cierra la recepción y deja el resultado visible. No obliga a crear una tarea pendiente para investigar una diferencia.

Preparar/despachar no cambia las existencias físicas. La recepción confirmada aplica la cantidad realmente recibida.

#### Recepción parcial

Ejemplo: se prepararon/enviaron 10 cajas de leche y el área recibió 9.

- Área recibe +9.
- Bodega descuenta 9, no 10.
- La línea/reparto se cierra inmediatamente como recepción con diferencia de -1.
- No queda una recepción pendiente de resolver.
- La unidad no transferida permanece en el saldo de Bodega del ledger hasta que un conteo o ajuste físico posterior indique otra cosa. No se debe borrar ni descontar una unidad que el área no recibió sin evidencia de inventario.

#### Recepción superior al preparado o al saldo de Bodega

Ejemplo: el reparto dice 10; el área declara que recibió 11; el ledger de Bodega dice que solo hay 10.

- El área debe poder registrar la recepción física de 11.
- El traslado desde Bodega descuenta solo el saldo disponible: en el ejemplo, Bodega baja de 10 a 0.
- El área recibe las 11 unidades.
- La unidad excedente se registra como un ajuste positivo auditable en el área, vinculado a la recepción y marcado como diferencia/existencia no registrada en Bodega.
- La recepción queda cerrada inmediatamente, con diferencia visible, no pendiente.
- Está prohibido que Bodega quede en -1.

Ese caso aumenta en una unidad el total registrado del sistema, porque se está corrigiendo un saldo de Bodega que no reflejaba lo físicamente existente. La aplicación debe dejar explícita esta causa; no simular una transferencia balanceada que no ocurrió.

Si el área recibe más que lo preparado pero Bodega sí tiene el saldo, el sistema traslada la cantidad recibida completa. La diferencia queda registrada en el documento.

#### Rechazo o no recepción

El usuario puede indicar que un producto no llegó o fue rechazado:

- cantidad recibida 0;
- no se transfiere stock;
- la línea queda cerrada como no recibida/rechazada;
- no debe quedar un estado operativo eternamente pendiente.

Cada línea debe conservar preparado, declarado como recibido, trasladado desde Bodega, ajuste positivo si lo hubo y diferencia. Los reintentos no duplican ninguno de esos efectos.

### 4.3 Urgencia para Bodega

Desde la ficha de producto abierta dentro de su área, la persona puede marcar/desmarcar el producto como **Urgente**.

- Es una señal manual y por área.
- Los urgentes aparecen arriba o en una lista visible para que Bodega sepa qué debe pedir o priorizar.
- No modifica cantidad, mínimo, máximo, criticidad automática ni receta.
- No crea automáticamente un reparto, pedido a proveedor ni movimiento de stock.
- La urgencia se quita manualmente al resolverla; no debe desaparecer solo porque cambió el saldo, salvo que Alejo lo decida después.

### 4.4 Mesas/Lama debe conocer el stock antes de vender

Al buscar o seleccionar un producto en Lama desde teléfono o escritorio, la persona debe ver la disponibilidad del producto en el/las áreas desde donde se servirá. El sistema no debe aceptar una comanda que sabe que no puede cumplirse:

- Producto directo cuantificable sin saldo suficiente: mostrar disponibilidad y bloquear la cantidad imposible.
- Producto preparado o combo: calcular disponibilidad por sus componentes y cantidades de receta.
- La validación debe ocurrir en backend en el mismo camino que confirma la comanda; la UI no es autoridad.
- Debe manejar concurrencia: dos mesas no pueden reservar/vender la misma última unidad por una carrera entre consultas.
- Una anulación libera una reserva o compensa el consumo según el estado de esa línea.
- El stock no puede quedar negativo, incluso ante doble clic, timeout o cierres concurrentes.

Alejo aceptó que Lama verifique disponibilidad durante la venta y que el usuario pueda ver cantidades desde el teléfono. La propuesta funcional es **reservar al confirmar la comanda, descontar definitivamente al cerrar la mesa y liberar la reserva al anular antes del cierre**. Codex debe verificar cómo encaja con el cierre comercial actual y mostrar cualquier efecto de reservas en el disponible mostrado. Un fallo técnico del motor de stock no debe impedir cerrar comercialmente la mesa; debe producir alerta visible y un evento recuperable, nunca una salida negativa o silenciosa.

### 4.5 Recetas aplican también a Lama

El área de Recetas sirve para el producto vendible y para los adaptadores POS; no debe tratarse como una herramienta exclusiva de Fudo.

Ejemplo: “Yamita Kids” puede consistir en un selladito, un brownie, un zumo y un juguete. Al vender una unidad, se consumen las cantidades configuradas de cada componente. Si se venden dos, se duplica cada cantidad de la receta.

- Una receta debe poder incluir componentes de áreas diferentes.
- El objetivo preferido del ejemplo es que los componentes estén disponibles juntos en Barra/Cafetería cuando así opere el local.
- Si un componente no se encuentra allí y se desea permitir abastecerlo desde más áreas, la receta debe poder autorizar explícitamente varias áreas de origen para ese componente.
- Al registrar el consumo, guardar la asignación real por ubicación: qué cantidad salió de cada área.
- No descontar el mismo ingrediente dos veces ni seleccionar un área arbitrariamente cuando hay ambigüedad.
- Antes de consumir, la disponibilidad del combo se calcula sobre las ubicaciones de origen habilitadas para cada componente.
- Receta ausente, componente sin configuración, unidad incompatible o stock insuficiente debe generar mensaje/estado visible. No inventar consumo ni usar un área predeterminada silenciosa.
- No exigir que todo producto vendido tenga receta: productos cuantificables pueden venderse directamente desde su área; la receta se usa cuando el producto vendible es preparado o compuesto.
- Los snapshots/versionado de receta ya existentes deben seguir protegiendo el significado histórico de una venta.

**Nota de decisión:** el ejemplo aprueba componentes desde más de un área y permite que un componente obtenga unidades de más de una ubicación cuando se configure así. Codex debe confirmar en el preflight el contrato exacto de asignación por ingrediente y proponer una regla determinista de consumo, sin restringirlo silenciosamente a “solo el área donde se abrió la mesa”.

## 5. Modelo mental final

| Acción humana | Efecto esperado |
|---|---|
| Contar 10 kg donde la app decía 0 | Ajuste ledger +10 en esa ubicación; se actualiza inmediatamente. |
| Recibir 9 de las 10 enviadas | Traslado de 9; diferencia -1 cerrada; no se mueve la décima unidad. |
| Recibir 11 cuando Bodega registra 10 | Traslado de 10 + ajuste positivo de 1 en destino; Bodega queda 0; recepción cerrada con diferencia. |
| Marcar Carne de res urgente | Prioridad visual visible para Bodega; ninguna cantidad cambia. |
| Vender alfajor con 0 disponible | Lama muestra 0 y bloquea agregar/confirmar una cantidad inviable. |
| Vender combo de 4 componentes | Comprueba/reserva cada componente desde las ubicaciones habilitadas en la receta y registra la asignación exacta por ubicación. |
| Anular producto antes de cerrar mesa | Libera su reserva. |
| Error de inventario al cerrar comercialmente | La mesa/caja puede cerrar; el fallo queda visible y recuperable; jamás se inventa saldo negativo. |

## 6. Reglas técnicas transversales

1. Fuente de cantidad: `stock_internal.existencias`.
2. Todas las mutaciones físicas se expresan en el ledger como movimientos con producto, ubicación, cantidad, tipo/causa, actor, fecha y referencia idempotente.
3. `productos.stock_actual` es proyección de compatibilidad; nunca recibe escritura de negocio directa.
4. Una transferencia normal debe ser atómica y no negativa.
5. Un ajuste es compensatorio/auditable, no una edición destructiva del historial.
6. El excedente recibido no respaldado por saldo de Bodega es un ajuste positivo separado, explícito y vinculado al reparto.
7. La comprobación de stock de ventas debe ser transaccional frente a carreras; una consulta visual anterior no alcanza.
8. Idempotencia para doble clic/reintentos de ajustes, recepción, reservas, consumo, anulación y reversa.
9. Un evento sin receta/área/origen válido nunca descuenta “a ojo”. Debe ser visible para resolver.
10. Toda cantidad debe respetar unidad/fracción y evitar conversiones implícitas incorrectas.
11. Conservar enlace explícito del producto Local 1 al maestro de Bodega; no volver a emparejar por nombre durante la transferencia.
12. No alterar Fudo remoto ni romper la integración Fudo existente. Las mutaciones generadas por una integración POS futura deben usar el mismo contrato de inventario, pero adaptarla es una fase separada.
13. El backend/base de datos, no solo el navegador, debe impedir saldos negativos.
14. Mantener los cierres de mesa, pagos y caja operativos incluso si el inventario falla; reportar el evento de inventario fallido.

## 7. Orden de trabajo propuesto

No ejecutar todos los bloques en un solo prompt ni mezclar frontend, modelo y ventas en la misma migración.

### Fase 0 — Preflight acotado y matriz de escritores (solo lectura)

Mapear, usando el estado instalado actual:

- RPC/métodos de ajuste o edición manual que existan;
- transferencia/reparto, recepción y sus escritores;
- todas las rutas que cambian existencias;
- cómo se calcula el stock libre/reservado;
- cómo Lama crea, confirma, anula y cierra una comanda;
- captura y snapshot de recetas;
- qué adaptador/función se usa para Fudo y cómo evitar regresiones;
- dónde se forman los dropdowns/listas y fichas en UI.

Entregable: matriz “acción → función → tabla/movimiento → efecto → idempotencia → prueba”, diferencias con este contrato, recomendación de migraciones/fases, y riesgos. Solo lectura. Sin cambios de código/esquema/datos ni llamadas remotas de negocio.

### Fase 1 — Edición manual universal mediante ajustes al ledger

Crear el camino que permita ingresar el saldo físico contado directamente en el campo de stock y traducirlo a delta. Aplicarlo a Bodega y a todas las áreas, sin habilitar escritura directa al agregado. Incluir motivo rápido, actor, auditoría, no negatividad e idempotencia.

No activar reparto ni venta hasta probar la base de ajustes en transacciones revertidas y con casos de cada ubicación.

#### Decisiones de implementación aprobadas el 20 de octubre de 2026

- Por ahora todas las cantidades aceptan decimales, incluso si `productos.unidad` está vacía. Ninguna ubicación ni lote puede quedar con saldo negativo.
- En productos sin lotes, el conteo final se registra en la clave lógica `sin_lote`.
- En productos con lotes se muestran y cuentan por separado los lotes conocidos, conservando vencimientos verificables. El stock físico no identificado se registra en un bucket del ledger con `lote_id = NULL`, visible como **Sin lote / vencimiento no informado**.
- El detalle del saldo siempre se calcula desde `stock_internal.movimientos`/`stock_internal.existencias`. `producto_lotes.cantidad` no se utiliza como cantidad operativa.
- Un encabezado de ajuste inmutable conserva la solicitud, actor, motivo, saldos contados, resultado y referencia, incluso cuando el conteo no cambia el saldo. Los deltas distintos de cero se guardan como movimientos `ajuste` inmutables.
- La misma referencia y el mismo contenido devuelven el resultado anterior; reutilizarla con contenido distinto se rechaza. El motor bloquea transaccionalmente producto y ubicación y vuelve a calcular cada diferencia bajo el bloqueo.

#### Resultado técnico de Fase 1

Completada y publicada en `origin/master`. Migración instalada: `20261020000825_fase1_ajustes_manual_ledger`. RPC protegidas: `stock_ajuste_desglose_leer` y `stock_ajuste_guardar`. La ficha de producto permite el conteo desde Bodega central y desde ubicaciones de Local 1 cuando la cuenta tiene `puede_editar`. El campo legacy de `productos.stock_actual` permanece bloqueado; su proyección sigue siendo mantenida por el trigger del ledger. El detalle de pruebas y el estado de la suite local están en la entrada de Bitácora del 20 de octubre.

Fase 2 — recepción por área, reservas, ventas, urgencias y recetas no quedan activadas por este resultado.

### Fase 2 — Recepción propia por área y liquidación inmediata de diferencias

Añadir el documento/estado de reparto con destino dinámico y bandeja de recepción dentro del área destino. La recepción por línea acepta cantidad real, incluyendo 0, parcial y excedente; aplica transferencia hasta el saldo disponible de Bodega y ajuste positivo por exceso; cierra inmediatamente con diferencia registrada. Evitar cualquier saldos negativos y estados pendientes permanentes.

#### Resultado técnico de Fase 2

Completada e instalada con la migración `20261020003917_fase2_repartos_recepcion_areas`. Bodega prepara documentos privados para áreas activas sin mover existencias. Cada área lista únicamente sus repartos y la recepción completa todas las líneas de forma atómica e idempotente. El saldo recibido se transfiere hasta lo disponible en Bodega y cualquier excedente físico se incorpora como ajuste auditado de Fase 1; una línea recibida en cero no mueve stock. Lotes conocidos conservan identidad/vencimiento y el saldo desconocido usa el bucket sin lote.

Las RPC `reparto_area_catalogo_buscar`, `reparto_area_crear`, `repartos_area_listar` y `reparto_area_recibir` están cerradas a `authenticated` con validación interna. Las tablas privadas no admiten DML del navegador. El reparto legacy no se reactivó y no se escriben directamente ni `productos.stock_actual` ni `stock_internal.existencias`. Fase 3 no queda activada por este resultado.

### Fase 3 — Urgencias y operación visible para Bodega

Añadir bandera manual por producto/área, presentación prioritaria en el área y resumen consultable desde Bodega. No generar pedidos o movimientos automáticos.

### Fase 4 — Lectura y validación de disponibilidad en Lama

Mostrar stock disponible en selección de producto y bloquear adición/confirmación que exceda lo disponible. Resolver reserva/idempotencia/concurrencia y anulación, preservando cierre comercial independiente.

### Fase 5 — Recetas multicomponente y consumo por ubicación

Asegurar editor de recetas usable por Lama y Fudo, snapshot histórico y selección explícita de áreas de origen por componente, incluyendo múltiples ubicaciones si el negocio lo permite. Calcular disponibilidad del producto compuesto y registrar los consumos de cada área sin doble descuento.

### Fase 6 — Prueba integral del ciclo

En datos sintéticos o transacciones revertidas primero; después, solo con autorización, prueba manual controlada:

- ajuste manual de área y Bodega;
- reparto con recepción total, parcial, excedente y rechazo;
- saldo de Bodega insuficiente;
- urgencia visible en Bodega;
- producto directo en Lama;
- combo con componentes en áreas iguales y distintas;
- agotamiento, concurrencia, anulación, timeout y cierre;
- conteos conciliados antes/después;
- Fudo y Bodega sin regresión.

## 8. Criterio de aceptación global

La solución se considera funcional cuando una persona puede recorrer el ciclo:

`contar/corregir → preparar reparto → recibir lo que realmente llegó → ver existencias/urgencias → comandar según disponibilidad → consumir receta al cerrar`

Y cuando las pruebas prueban simultáneamente:

- ninguna ubicación tiene saldo negativo;
- cada ajuste y diferencia tiene actor, fecha y causa;
- recepción no duplica cantidades ni deja pendiente la diferencia;
- una venta no consume una receta distinta de la vigente al momento correcto;
- las comandas de venta/cierre conservan su comportamiento financiero y comercial aunque falle un movimiento de inventario;
- Fudo permanece sin regresiones;
- no se cambian datos ni infraestructura de Café del Desierto/Llamita Stock.

## 9. Límites de alcance y protección del trabajo

- No modificar ni consultar Café del Desierto/Llamita Stock.
- No desplegar Fudo remoto, activar un origen POS o cambiar secretos en este contrato.
- No ejecutar migraciones, DML de operación o transferencias reales en la Fase 0.
- No hacer un rediseño visual global. Aplicar el lenguaje visual vigente en `docs/hermes/04-bitacora-codex.md` para nuevos controles: simple y claro, pocos textos, respetar paleta/materiales actuales, sin inventar una nueva identidad.
- Mantener el inventario que ya existe, no reemplazarlo por tarjetas administrativas.
- Leer solo este contrato, el mapa, la última entrada pertinente de bitácora, la sección visual vigente y los archivos/RPC implicados en la fase activa. No releer toda la historia cerrada.
- Publicar cada fase a `origin/master` solo cuando Alejo la active y sus criterios pasen. El hecho de que este documento exista no activa las fases 1–6.

## 10. Siguiente paso autorizado a Codex

La primera tarea sugerida es **Fase 0 — Preflight acotado y matriz de escritores**, con acceso solo de lectura y sin implementar nada. Su prompt está en el mensaje de Hermes que acompaña este documento. Codex debe devolver evidencia y una secuencia ejecutable para aprobación de Alejo antes de tocar código o datos.
