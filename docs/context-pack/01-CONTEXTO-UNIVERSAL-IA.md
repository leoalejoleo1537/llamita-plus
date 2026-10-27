# Contexto universal de Llamita Plus

## Definici�n en una frase

Llamita Plus es un sistema operativo para negocios gastron�micos que conecta inventario, Bodega, �reas de trabajo, recetas, ventas por mesas y control de caja.

## Qu� problema resuelve

En una cafeter�a o restaurante la realidad f�sica suele quedar fragmentada entre planillas, memoria del personal, sistemas de venta y conteos manuales. Eso provoca productos duplicados, repartos sin registro, diferencias de stock, recetas desconectadas de la venta y decisiones tard�as.

Llamita Plus busca convertir esa operaci�n dispersa en un circuito visible:

1. Un insumo se crea una sola vez como producto maestro.
2. Se habilita en Bodega y en las �reas que lo utilizan.
3. Bodega prepara repartos y cada �rea recibe lo que efectivamente lleg�.
4. Los equipos cuentan y corrigen el stock real con trazabilidad.
5. Los productos de venta tienen recetas manuales expl�citas.
6. Las ventas reservan y consumen los ingredientes desde sus �reas de origen.

## P�blico principal

- Due�os y administradores de cafeter�as, restaurantes y negocios gastron�micos.
- Encargados de Bodega que necesitan saber qu� existe, qu� falta y qu� debe repartirse.
- Jefes de �rea que cuentan, reciben, corrigen y priorizan productos.
- Garzones y cajeros que venden desde Mesas sin conocer la complejidad del inventario.
- Personas con alfabetizaci�n digital desigual y experiencia previa principalmente en Excel, WhatsApp o sistemas POS tradicionales.

## Realidad humana que el producto debe soportar

La organizaci�n puede ser imperfecta: un reparto puede no registrarse, una cantidad puede llegar distinta, alguien puede olvidar una operaci�n o contar tarde. El sistema no debe fingir que esos eventos no ocurren. Debe permitir corregir la realidad f�sica, pero registrar qui�n cambi� qu�, cu�ndo y por qu�.

La experiencia debe ser guiada, evidente y dif�cil de malinterpretar. La complejidad t�cnica debe quedar detr�s de acciones humanas como "cont� 10", "recib� 9" o "este producto es urgente".

## Modelo mental del producto

### Insumo

Materia prima o art�culo controlable: leche, carne, menta, botella de Coca-Cola, juguete. Tiene una identidad maestra y puede estar disponible en varias �reas sin convertirse en productos distintos.

### Configuraci�n por �rea

Indica en qu� �rea y secci�n f�sica se usa un insumo, junto con m�nimos y m�ximos. No contiene la cantidad real.

### Existencia

Cantidad f�sica en una ubicaci�n. La fuente de verdad es el ledger de inventario, no un campo editable aislado.

### Producto de venta

Art�culo comercial ofrecido al cliente: Mocachino, Mojito, bebida Coca-Cola o un combo infantil. Es distinto del insumo.

### Receta

Relaci�n manual y expl�cita entre un producto de venta y uno o varios insumos, cada uno con cantidad y �rea de origen. Nunca debe inferirse autom�ticamente que algo vendible tiene una receta determinada.

## Principios aprobados

- Una identidad maestra por insumo; las �reas reutilizan esa identidad.
- Crear un producto no genera stock, lote, receta ni publicaci�n en Fudo.
- El stock puede corregirse manualmente mediante un ajuste auditado.
- Nunca debe haber saldos negativos.
- Bodega pierde stock cuando el �rea confirma lo efectivamente recibido.
- Una recepci�n parcial se cierra con la cantidad recibida; no deja una deuda operativa oculta.
- Una receta se crea manualmente, incluso si el producto parece "obvio".
- Si falta una definici�n de origen o existe ambig�edad, se bloquea o genera una alerta; no se adivina silenciosamente.
- Los permisos y la auditor�a protegen la operaci�n, pero la interfaz debe seguir siendo pr�ctica.
- Fudo y el POS propio deben ser adaptadores del mismo modelo, no fuentes paralelas de inventario.

## Capacidades implementadas a la fecha de este paquete

- Inventario por �reas y secciones f�sicas.
- Panel de productos para crear y configurar insumos.
- Conteos y ajustes manuales auditados, con desglose por lote cuando corresponde.
- Repartos Bodega  �rea, con recepci�n exacta, parcial, cero o superior al preparado.
- Urgencias por producto y �rea.
- Cat�logo neutral de productos de venta.
- Recetas manuales multiingrediente y multi�rea.
- Mesas que reserva ingredientes al confirmar una comanda y los consume al cerrar.
- Liberaci�n o compensaci�n auditada al anular.
- Autorizaci�n basada en una identidad ra�z y capacidades operativas.

## Estado del producto

Es un producto en evoluci�n y piloto, no un SaaS masivo terminado. El n�cleo Bodega  �rea  receta  venta  stock ya fue construido y probado en escenarios controlados. Quedan trabajo de depuraci�n visual, validaci�n humana extensa, adaptaci�n de Fudo al motor neutral, respaldo/reinicio ensayado y maduraci�n comercial.

## Identidad y tono

La identidad visual actual se denomina "L�piz y papel": fondos claros, tarjetas blancas, tinta oscura, acento terracota y formas suaves. La voz debe ser humana, directa, tranquila y concreta; nunca burocr�tica ni innecesariamente t�cnica.

## Posicionamiento provisional

Llamita Plus no se presenta solo como "un control de stock". Su propuesta es unir la operaci�n gastron�mica: lo que se compra, se reparte, se cuenta, se prepara, se vende y finalmente se descuenta.

## Fronteras importantes

- Llamita Plus y Caf� del Desierto / Llamita Stock son proyectos separados.
- El espejo de Fudo no es la identidad maestra del cat�logo local.
- Los datos heredados pueden existir por compatibilidad y no representan necesariamente el modelo futuro.
- El nombre "Llamita Plus" puede evolucionar dentro de un proceso de marca; hoy es el nombre del proyecto y no debe asumirse como marca definitiva sin confirmaci�n.

## Instrucciones para una IA que reciba este documento

1. Pregunta el objetivo concreto de la tarea y carga solo los anexos pertinentes.
2. Distingue implementaci�n actual, decisi�n aprobada y propuesta.
3. No inventes comportamientos organizacionales, recetas, �reas ni automatizaciones.
4. No describas capacidades pendientes como si estuvieran listas.
5. Prioriza claridad para personas no t�cnicas.
6. Si la tarea afecta datos o stock, consulta las reglas invariantes antes de proponer cambios.


