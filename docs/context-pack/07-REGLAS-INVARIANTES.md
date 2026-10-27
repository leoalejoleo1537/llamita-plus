# Reglas invariantes

Estas reglas condensan decisiones que no deben romperse accidentalmente. Una tarea puede proponer cambiarlas, pero debe identificar la contradicci�n y obtener una decisi�n expl�cita antes de implementar.

## Identidad y cat�logo

1. Un insumo tiene una identidad maestra visible.
2. Habilitarlo en varias �reas no crea identidades independientes.
3. Las relaciones hist�ricas distintas se enlazan expl�citamente; no por semejanza autom�tica de nombres.
4. Crear un insumo produce saldo cero.
5. Crear un insumo no crea receta, lote, movimiento, transferencia ni publicaci�n Fudo.
6. Todas las entradas humanas de alta deben converger en el Panel de productos.
7. Los duplicados no deben resolverse silenciosamente.
8. El costo de compra puede quedar pendiente/cero, pero debe distinguirse de un costo confirmado.

## �reas y secciones

9. Las �reas son din�micas y pertenecen al modelo operativo, no a una lista fija en c�digo.
10. Una nueva �rea activa debe tener una ubicaci�n coherente en el ledger.
11. "Sin asignar" es una ubicaci�n l�gica, no un �rea f�sica editable.
12. Una secci�n f�sica pertenece a un �rea.
13. Categor�a/grupo de producto y secci�n f�sica no son sin�nimos.
14. Cambiar configuraci�n, �rea preferida, secci�n o m�nimos no mueve stock.
15. Un producto puede configurarse en varias �reas con el mismo maestro.
16. Los m�nimos y m�ximos son por �rea cuando se calculan estados del �rea.

## Stock y ledger

17. La �nica fuente de cantidades es el ledger/existencias derivadas.
18. No reactivar escritura directa de `productos.stock_actual`.
19. Ninguna ubicaci�n puede quedar con saldo negativo.
20. Los ajustes humanos son v�lidos y permanentes como capacidad del sistema.
21. Todo ajuste registra actor, fecha, motivo, diferencia y referencia idempotente.
22. Los decimales est�n permitidos mientras no exista una pol�tica de unidad m�s restrictiva aprobada.
23. Los productos lotificados se ajustan por lote/vencimiento y saldo sin lote.
24. Un reintento id�ntico no duplica movimientos.
25. Un fallo parcial debe revertir la operaci�n completa, salvo la excepci�n comercial expl�citamente dise�ada.

## Repartos

26. Preparar o enviar un reparto no mueve stock.
27. Cada documento tiene un �rea destino inequ�voca.
28. Cada �rea recibe solo sus repartos.
29. La recepci�n mueve exactamente la cantidad declarada como llegada.
30. Una recepci�n parcial se cierra inmediatamente.
31. Si lo recibido supera Bodega, Bodega entrega hasta cero y el excedente entra auditado; nunca negativo.
32. Cantidad recibida cero cierra la l�nea sin movimiento.
33. La recepci�n es idempotente y no puede confirmarse dos veces.

## Urgencias

34. Una urgencia pertenece a producto + �rea.
35. Marcar urgente no modifica stock ni par�metros.
36. Bodega conserva el �rea destino al convertir una urgencia en reparto.

## Productos de venta y recetas

37. Producto de venta e insumo son identidades distintas.
38. Toda receta se define manualmente.
39. Un producto que se vende solo igualmente requiere receta expl�cita de una l�nea si debe consumir inventario.
40. Cada componente tiene cantidad y �rea de origen expl�cita.
41. Una receta sin origen o ambigua no descuenta desde un �rea predeterminada silenciosa.
42. Los borradores no deben venderse como productos listos.
43. Una receta lista requiere al menos un componente v�lido.

## Mesas/POS

44. Confirmar una comanda reserva todos los componentes at�micamente.
45. Cerrar consume la reserva exactamente una vez.
46. Anular antes de consumir libera; anular despu�s compensa y audita.
47. Stock insuficiente rechaza la comanda completa, no deja reservas parciales.
48. Una falla t�cnica de inventario durante el cierre no bloquea el cierre comercial; genera alerta auditable.
49. Solo un origen POS debe escribir consumo para evitar doble descuento.
50. Fudo debe adaptarse al cat�logo neutral; no gobernar la identidad local.

## Seguridad

51. La autorizaci�n usa `auth.uid()`, no correo o metadatos editables.
52. Solo el propietario ra�z gobierna permisos.
53. `puede_ajustes` permite administraci�n operativa, no elevar privilegios.
54. Nuevas escrituras pasan por operaciones backend protegidas, no DML directo desde el navegador.
55. La auditor�a relevante no debe poder editarse o borrarse desde la aplicaci�n.

## Experiencia

56. La complejidad t�cnica no debe convertirse en una explicaci�n interminable en pantalla.
57. Las acciones deben usar lenguaje de trabajo real.
58. Los errores importantes deben ser visibles; evitar fallas silenciosas y valores predeterminados que oculten ambig�edad.
59. M�vil y escritorio son superficies operativas, no solo adaptaciones visuales.
60. La interfaz debe tolerar usuarios con poca experiencia tecnol�gica.

## Fronteras y datos

61. No tocar Caf� del Desierto / Llamita Stock desde este proyecto.
62. No borrar datos operativos sin respaldo validado, restauraci�n ensayada y autorizaci�n expl�cita.
63. Las pruebas destructivas usan transacciones revertidas o datos sint�ticos identificables y eliminables.
64. No prometer que un m�dulo pendiente est� operativo.


