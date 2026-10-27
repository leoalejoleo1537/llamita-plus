# Anexo de ingenier�a

## Prop�sito

Este anexo explica el modelo t�cnico suficiente para que una IA de desarrollo no confunda el sistema actual con sus capas heredadas. No reemplaza la lectura del c�digo o las migraciones que afecten una tarea concreta.

## Stack actual

- Aplicaci�n web/PWA servida por Vercel.
- Frontend basado principalmente en HTML, JavaScript y CSS sin un framework de componentes dominante.
- Supabase como PostgreSQL, Auth, RPC y Edge Functions.
- Migraciones SQL versionadas en el repositorio.
- Pruebas est�ticas/Node, SQL transaccional y escenarios Chromium cuando est� disponible.

## Separaci�n de proyectos

El repositorio y Supabase de Llamita Plus son independientes de Caf� del Desierto / Llamita Stock. Nunca usar credenciales, tablas o flujos de este �ltimo sin una autorizaci�n separada.

## Identidad de inventario

La convenci�n actual usa:

- `productos` en `central`: identidad maestra operativa de Bodega.
- Representaci�n `plaza`: ficha f�sica de Local 1 enlazada al maestro.
- `producto_enlace`: relaci�n expl�cita entre identidades hist�ricamente separadas.
- `producto_area_asignacion`: configuraci�n del producto en una o varias �reas, con secci�n y par�metros.
- `areas_operativas`: cat�logo din�mico de �reas.
- `area_secciones`: secciones f�sicas internas por �rea.

El Panel oculta esta complejidad y presenta una identidad �nica al usuario.

## Ledger

La cantidad f�sica se deriva de `stock_internal.movimientos` y `stock_internal.existencias`. `productos.stock_actual` es una proyecci�n/compatibilidad y no debe recuperarse como fuente independiente de escritura.

Propiedades esperadas:

- Movimientos inmutables o compensados.
- Origen y destino expl�citos.
- Lote opcional.
- Actor, motivo y referencia.
- Idempotencia para operaciones reintentables.
- Prohibici�n de saldos negativos.

## Operaciones construidas

### Ajuste manual

Recibe el saldo final contado; el servidor bloquea producto/ubicaci�n, calcula diferencia y escribe movimiento de ajuste. Para productos con lotes, el desglose conserva lote y vencimiento, incluyendo una l�nea "sin lote".

### Reparto

Documento de preparaci�n y recepci�n por �rea. El stock se mueve al recibir. La recepci�n superior al saldo usa lo disponible en Bodega y un ajuste positivo auditado para completar el total recibido, sin saldo negativo.

### Reserva y consumo Lama/Mesas

P4 introduce reservas de componentes de receta. Confirmar reserva el snapshot; cerrar consume; anular libera o compensa. Las operaciones son at�micas e idempotentes.

## Cat�logo comercial neutral

P3 separa el producto de venta del espejo Fudo. Una receta neutral posee componentes con insumo, cantidad y �rea expl�cita. Fudo y Mesas deben converger hacia este mismo cat�logo y motor.

El modelo heredado `recetas` ligado directamente a `fudo_product_id` sigue existiendo por compatibilidad. No debe elegirse autom�ticamente para nuevas funciones.

## Fudo

Estado conceptual:

- `fudo_productos` es un espejo externo, no el maestro local.
- El adaptador neutral P5 est� pendiente.
- La publicaci�n expl�cita P6 est� pendiente.
- No se deben crear recetas autom�ticamente al publicar un producto.
- Los reintentos remotos requieren un registro local de estado para evitar duplicados.
- `stock_internal.origen_pos` debe impedir que dos POS descuenten simult�neamente el mismo flujo.

## Seguridad

Existe un �nico propietario ra�z ligado a `auth.uid()`. `puede_ajustes` es administraci�n operativa y no equivale a gobierno de permisos. Las nuevas operaciones deben usar RPC protegidas, validar sesi�n/capacidad, fijar `search_path` seguro y evitar DML directo desde el navegador.

Persiste deuda heredada en objetos no migrados. No afirmar que toda la superficie hist�rica est� endurecida.

## Datos versus estructura

Una limpieza futura puede eliminar datos operativos, pero debe conservar:

- Auth y permisos.
- �reas/ubicaciones que se decida mantener.
- Esquemas, funciones, triggers y RPC del ledger.
- Motores de ajuste, reparto, urgencia y reserva.
- Configuraci�n necesaria de Mesas, caja y sedes.

`stock_internal.existencias` es una lectura derivada; no se "limpia" directamente.

## Pr�ctica de cambios

Antes de modificar:

1. Leer el mapa/bit�cora vigente y solo los archivos pertinentes.
2. Inspeccionar la definici�n instalada si se altera una funci�n o migraci�n.
3. Separar preflight, decisi�n e implementaci�n cuando exista riesgo de datos.
4. Mantener cambios en `origin/master` solo cuando el usuario lo solicite.

Despu�s de modificar:

1. Pruebas SQL con `BEGIN . ROLLBACK` cuando correspondan.
2. Roles autorizado/no autorizado/an�nimo.
3. Idempotencia y concurrencia.
4. Conteos pre/post de datos protegidos.
5. `npm test` y `git diff --check`.
6. Navegador real en escritorio y m�vil para cambios visibles.
7. Actualizar bit�cora y estado sin reescribir toda la historia.

## Deuda t�cnica visible

- Frontend monol�tico y capas visuales hist�ricas coexistentes.
- Rutas legacy de productos, enlaces, recetas o permisos que deben cerrarse progresivamente.
- Modelo Fudo anterior a�n separado del motor neutral.
- Advisors heredados de RLS, �ndices y `search_path` fuera de algunos alcances recientes.
- Necesidad de una restauraci�n ensayada antes de un reinicio productivo.

## Regla de compatibilidad

Una funci�n hist�rica puede seguir existiendo porque el producto la necesita temporalmente. Reutilizarla exige demostrar que respeta el ledger, los permisos S1 y la identidad neutral actual. Existencia no equivale a aprobaci�n arquitect�nica.


