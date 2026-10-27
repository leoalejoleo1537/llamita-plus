# Estado y horizonte del proyecto

## Corte de referencia

Este documento se construy� con el repositorio sincronizado hasta el commit `f8d4ad4` de `origin/master`. La aplicaci�n cambia con frecuencia; antes de tomar una decisi�n t�cnica debe verificarse el estado actual.

## Mapa resumido

| Dominio | Estado | Nota |
|---|---|---|
| Identidad ra�z y permisos S1 | IMPLEMENTADO | Propietario ra�z y capacidades operativas separadas |
| Inventario por �reas | IMPLEMENTADO | �reas din�micas, secciones y lectura desde ledger |
| Panel de insumos P1/P2 | IMPLEMENTADO | Altas humanas unificadas y saldo cero al crear |
| Ajustes manuales | IMPLEMENTADO | Auditados y compatibles con lotes/decimales |
| Repartos por �rea | IMPLEMENTADO | Recepci�n mueve stock y evita negativos |
| Urgencias | IMPLEMENTADO | Producto + �rea, visible desde Bodega |
| Productos de venta P3 | IMPLEMENTADO | Cat�logo neutral y recetas manuales |
| Mesas + recetas P4 | IMPLEMENTADO/VALIDADO | Reserva, consumo, liberaci�n y compensaci�n |
| Circuito Mocachino | VALIDADO | Escenario E2E y mejoras de interfaz recientes |
| Panel estilo Excel | APROBADO | Direcci�n de dise�o; no asumir completitud |
| Adaptador Fudo neutral P5 | PENDIENTE | El flujo heredado no es el modelo final |
| Publicaci�n expl�cita en Fudo P6 | PENDIENTE | Debe ser manual, idempotente y sin recetas autom�ticas |
| Respaldo/reinicio P7A | PENDIENTE | Requiere ensayo y autorizaci�n separada |
| Marca definitiva | EN DEFINICI�N | "Llamita Plus" es nombre operativo actual |

## Hitos terminados relevantes

- B2/B3: ledger, �reas y transferencias din�micas.
- S1/S2: gobierno de permisos y validaci�n de sesiones reales.
- Bloque 1A: producto-�rea-secci�n, m�nimos y m�ximos.
- Fases 1-3: ajustes, repartos y urgencias.
- Fase 4/P4: Mesas conectadas a recetas neutrales.
- P1/P2: Panel de productos y unificaci�n de altas.
- P3: cat�logo de venta y recetas manuales.
- Validaci�n E2E reforzada: simple, multi�rea, anulaci�n, insuficiencia e idempotencia.

## Evidencia reciente

Las validaciones documentadas cubren:

- SQL transaccional con `ROLLBACK`.
- Autorizaci�n de roles y rechazo an�nimo.
- Navegador real en escritorio y m�vil.
- Atomicidad e idempotencia.
- Ausencia de saldos negativos.
- Ausencia de datos sint�ticos persistentes al finalizar pruebas controladas.

Estas pruebas no sustituyen la revisi�n humana prolongada en operaci�n real.

## Pendiente prioritario

### 1. Revisi�n funcional del propietario

Recorrer toda la aplicaci�n, registrar fallas reproducibles y separar:

- Bug funcional.
- Fricci�n de UX.
- Deuda visual.
- Dato mal configurado.
- Funci�n todav�a no construida.

### 2. Refinamiento de experiencia

- Panel de productos en formato de tabla familiar.
- Menos sobrecarga en modales.
- Mejor continuidad m�vil.
- Estados de carga sin pantallas en blanco.
- Creaci�n contextual de secciones.

### 3. Respaldo y entorno limpio

Antes de borrar datos operativos:

- Crear respaldo completo y validado.
- Ensayar restauraci�n en un entorno aislado.
- Definir exactamente qu� estructura se conserva.
- Ejecutar limpieza real solo con autorizaci�n expl�cita.

### 4. Fudo

P5 debe convertir Fudo en adaptador del cat�logo comercial neutral y del mismo motor de recetas/ledger. P6 debe separar la publicaci�n comercial y evitar reintentos ciegos o recetas autom�ticas.

### 5. Preparaci�n comercial

- Nombre y marca.
- Capacitaci�n/onboarding.
- M�tricas de piloto.
- Pol�tica de soporte.
- Alcance contractual.

## Riesgos vivos

- C�digo y permisos heredados fuera del nuevo camino protegido.
- Convivencia de modelos antiguos y nuevos de recetas/Fudo.
- Interfaz extensa concentrada hist�ricamente en archivos grandes.
- Dependencia de configuraci�n humana correcta en �reas y recetas.
- Datos hist�ricos que pueden confundir una demostraci�n si no existe un reinicio controlado.
- Exceso de cambios por prompt sin una revisi�n integral peri�dica.

## Secuencia recomendada

1. Congelar nuevas ampliaciones por un ciclo corto.
2. Ejecutar revisi�n humana y registrar bugs.
3. Corregir lo que impide el circuito m�nimo.
4. Ensayar respaldo/restauraci�n.
5. Preparar un cat�logo peque�o y demostrable.
6. Validar el circuito completo con personas reales.
7. Reci�n despu�s ampliar Fudo, marca y comercializaci�n.

## Definici�n de "listo para piloto acompa�ado"

- Un usuario puede crear/configurar productos sin duplicarlos.
- Bodega y �reas pueden contar, repartir y recibir.
- Una receta puede venderse y descontarse correctamente.
- Los errores relevantes son visibles y recuperables.
- Existe respaldo restaurable.
- Hay gu�a de uso y responsable de soporte.
- La prueba se ejecuta con un conjunto de datos controlado.


