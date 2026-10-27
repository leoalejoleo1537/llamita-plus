# Glosario

| T�rmino | Significado en Llamita Plus |
|---|---|
| �rea | Unidad operativa interna de Local 1, por ejemplo Cafeter�a, Barra o Cocina fr�a |
| Bodega | Origen central de abastecimiento y cat�logo maestro operativo de insumos |
| Cat�logo neutral | Productos de venta locales que no dependen de un ID Fudo para existir |
| Comanda | Conjunto confirmado de productos solicitados en una mesa |
| Configuraci�n producto-�rea | Relaci�n que habilita un insumo en un �rea y guarda secci�n, m�nimos y m�ximos |
| Conteo | Cantidad f�sica observada por una persona |
| Existencia | Saldo derivado del ledger para producto + ubicaci�n + lote opcional |
| Fudo | POS externo; su cat�logo local es un espejo/adaptador, no el maestro universal |
| Insumo | Materia prima o art�culo controlable que una receta puede consumir |
| Lama / Mesas | M�dulo POS propio de mesas, comandas, pagos y cierre comercial |
| Ledger | Registro de movimientos de stock del que se derivan las existencias |
| Local 1 / plaza | Sede operativa que contiene �reas; `plaza` es una clave t�cnica heredada |
| Lote | Partida de un insumo, opcionalmente asociada a vencimiento |
| Maestro de Bodega | Identidad principal de un insumo en el modelo actual |
| Merma | P�rdida o descarte registrado de inventario |
| M�nimo/m�ximo | Par�metros por �rea para clasificar cr�tico, rango o sobre-stock |
| Origen POS | Configuraci�n que determina qu� sistema puede escribir consumos de venta |
| Panel de productos | Punto de mando para insumos, configuraciones, productos de venta y recetas |
| Producto de venta | Art�culo comercial que se ofrece al cliente y posee receta manual |
| Producto directo | Compatibilidad hist�rica donde una venta apunta a una fuente simple; no es el modelo neutral preferido |
| Proyecci�n | Campo/lectura compatible calculada desde el ledger; no una segunda fuente de verdad |
| Recepci�n | Confirmaci�n del �rea sobre la cantidad que realmente lleg� en un reparto |
| Receta | Lista manual de componentes, cantidades y �reas de origen de un producto de venta |
| Reparto | Documento de env�o desde Bodega hacia un �rea |
| Representaci�n plaza | Ficha interna enlazada al maestro que permite operar un insumo en Local 1 |
| Reserva | Compromiso temporal de ingredientes al confirmar una comanda |
| Secci�n | Ubicaci�n f�sica interna de un �rea, como Refrigerador, Congelador o Vitrina |
| Sin asignar | Ubicaci�n l�gica para stock a�n no distribuido a un �rea f�sica |
| Stock contado | Saldo final observado que origina un ajuste por diferencia |
| Urgencia | Prioridad manual asociada a producto + �rea para reposici�n |

## T�rminos hist�ricos que pueden confundir

- `productos.rubro`, `productos.tipo` y `public.secciones` mezclaron agrupaciones f�sicas y descriptivas. No deben asumirse como el cat�logo definitivo de secciones por �rea.
- `productos.stock_actual` sobrevive como compatibilidad, pero el ledger es la fuente de cantidades.
- Las "recetas heredadas" ligadas a Fudo son distintas de las recetas neutrales del Panel.
- La clave t�cnica `plaza` corresponde al Local 1 actual; no debe mostrarse necesariamente al usuario.


