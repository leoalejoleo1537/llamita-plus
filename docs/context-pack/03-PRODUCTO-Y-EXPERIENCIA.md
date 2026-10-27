# Producto y experiencia

## Objetivo de experiencia

Llamita Plus debe convertir una operaci�n gastron�mica compleja en una secuencia que una persona pueda entender sin dominar teor�a de inventario. La interfaz no debe exponer el cableado interno salvo cuando sea indispensable para tomar una decisi�n.

## Actores y trabajos principales

| Actor | Necesidad |
|---|---|
| Due�o/administrador | Ver el negocio, configurar productos y detectar problemas |
| Encargado de Bodega | Mantener abastecimiento, preparar repartos y atender urgencias |
| Jefe de �rea | Ver qu� tiene, recibir, contar, corregir y marcar urgencias |
| Garz�n/cajero | Comandar y cerrar mesas con una interacci�n r�pida |
| Responsable de recetas | Definir exactamente qu� consume cada producto de venta |

No debe asumirse censura entre �reas salvo que se apruebe un modelo de permisos m�s granular.

## Arquitectura conceptual visible

```text
Panel de productos
  �� Insumos maestros
  �    �� Bodega
  �    �� �reas  Secciones  Existencias
  �� Productos de venta
       �� Receta manual  Insumos + cantidad + �rea origen

Bodega  Reparto  Recepci�n del �rea  Stock del �rea
Mesas  Comanda  Reserva  Cierre  Consumo del stock
```

## Flujo de inventario por �rea

Al entrar a Cocina fr�a, Cocina caliente, Barra, Cafeter�a u otra �rea din�mica, el usuario debe encontrar una experiencia operativa, no una pantalla de ajustes:

1. Identidad clara del �rea.
2. Resumen de estados relevantes.
3. Buscador y filtros familiares.
4. Agrupaciones visibles por secci�n f�sica.
5. Productos configurados aunque su saldo sea cero.
6. Ficha del producto con saldo, m�nimo, m�ximo, vencimientos, secci�n y acciones.

Las categor�as comerciales y las secciones f�sicas son conceptos distintos. "Leches" puede ser un grupo descriptivo; "Refrigerador" es una ubicaci�n interna del �rea.

## Estados operativos del �rea

La direcci�n aprobada agrupa el resumen en cuatro familias, evitando duplicidades:

- Cr�ticos o sin stock.
- Sobre-stock.
- Sin datos de m�nimo/m�ximo.
- Vencimientos: pr�ximos y vencidos, diferenciados dentro de la misma familia.

Al tocar un estado deben mostrarse los productos correspondientes en la pantalla, no obligar a navegar por una cadena de modales.

## Crear y configurar un insumo

El punto de mando es el Panel de productos. All� se crea el maestro y, en la misma operaci�n, se seleccionan las �reas donde se utilizar�. Las entradas desde Bodega, un �rea o Recetas deben redirigir al mismo motor, con contexto preseleccionado y retorno al flujo original.

Resultado de crear:

- Identidad maestra �nica.
- Representaciones internas enlazadas cuando sean necesarias.
- Configuraci�n en una o varias �reas.
- Saldo inicial cero.
- Ninguna receta o publicaci�n POS autom�tica.

## Secciones f�sicas

Las secciones deben poder administrarse en el momento en que resulten necesarias. Si al configurar Leche de almendras el usuario necesita "Refrigerador", debe poder crear esa secci�n sin abandonar mentalmente la tarea. Tambi�n puede existir una administraci�n completa en Ajustes, pero no debe ser el �nico camino.

## Conteo y ajuste manual

El usuario ingresa el stock que encontr� f�sicamente y un motivo. El servidor calcula la diferencia y la registra en el ledger. Para productos lotificados, el conteo se separa por lote/vencimiento y por saldo sin lote informado.

La libertad para corregir stock es una regla operativa aprobada, no una excepci�n temporal. Debe acompa�arse de auditor�a, no de una prohibici�n.

## Reparto y recepci�n

- Bodega selecciona un �rea destino din�mica.
- Preparar o enviar no mueve stock.
- Solo el �rea destino ve y recibe su documento.
- Al recibir, se declara lo que realmente lleg� por l�nea.
- En ese momento se descuenta de Bodega y se suma al �rea.
- Si se recibe m�s de lo disponible, Bodega queda en cero y el excedente entra como ajuste auditado; nunca queda negativa.
- La recepci�n cierra el documento inmediatamente, incluso si fue parcial o cero.

## Urgencias

Una urgencia pertenece a producto + �rea y puede incluir una nota. Sirve para priorizar visualmente al jefe de �rea y a Bodega. No mueve stock ni sustituye m�nimos/m�ximos.

## Productos de venta y recetas

Un producto comercial se crea manualmente con nombre y precio. Puede quedar como borrador. Para marcarlo listo debe existir al menos un ingrediente v�lido.

Cada ingrediente define:

- Insumo maestro.
- Cantidad, incluso decimal.
- �rea de origen expl�cita.
- Orden visual.

Ejemplo:

```text
Bebida Coca-Cola cubana
  - Coca-Cola: 1 unidad desde Cafeter�a
  - Lim�n: 0,5 unidad desde Barra
  - Menta: 1 g desde Barra
```

El sistema no debe crear esta receta por intuici�n.

## Mesas

- La carta operativa usa productos de venta neutrales.
- Confirmar la comanda reserva todos los ingredientes at�micamente.
- Cerrar la mesa consume exactamente la reserva una sola vez.
- Anular antes del cierre libera la reserva.
- Anular despu�s del consumo compensa de forma auditada.
- Un borrador, receta inv�lida o falta de stock debe bloquearse con un mensaje comprensible.
- Una falla t�cnica posterior no debe impedir el cierre comercial; debe generar una alerta auditable.

## Direcci�n aprobada: Panel estilo tabla

El Panel de productos debe evolucionar hacia una tabla tipo Excel porque es un patr�n conocido por el p�blico. Propuesta funcional:

| Columna | Prop�sito |
|---|---|
| Nombre | Identidad visible del insumo |
| Unidad | Unidad de conteo |
| Costo | Costo de compra; puede quedar pendiente/cero |
| Bodega | Existencia o estado de Bodega |
| �reas | �reas configuradas, resumidas |
| M�n./M�x. | Estado de par�metros |
| Estado | Activo, pendiente, archivado |
| Acciones | Abrir ficha, editar, configurar |

La tabla es una direcci�n aprobada, no debe describirse como terminada sin evidencia de implementaci�n.

## Principios de usabilidad

- Un objetivo principal por pantalla.
- Texto m�nimo suficiente; la explicaci�n avanzada va bajo demanda.
- Nombres cercanos a la operaci�n real.
- Mostrar consecuencia antes de confirmar.
- Retornar al contexto original tras una creaci�n.
- Evitar parpadeos, pantallas en blanco y recargas completas innecesarias.
- Validar m�vil real, teclado, Escape, clic exterior y ausencia de scroll horizontal.
- Dise�ar para errores humanos recuperables y hacer visibles los errores no recuperables.


