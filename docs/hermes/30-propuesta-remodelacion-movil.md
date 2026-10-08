# Propuesta de remodelación móvil de Llamita Plus — v1

**Fecha:** 2026-10-08  
**Estado:** propuesta de diseño para revisión; **no autoriza implementación**.  
**Proyecto exclusivo:** `leoalejoleo1537/llamita-plus`, Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).  
**Límite:** no consultar ni tocar Café del Desierto / Llamita Stock.  
**Referencia visual interactiva:** [`docs/hermes/prototipos/llamita-movil-v1.html`](prototipos/llamita-movil-v1.html). Se abre como archivo HTML independiente; usa datos ilustrativos y **no** está conectado a la aplicación.

## 1. Por qué se abre este frente

Alejo probó manualmente B3.2a.2 en un teléfono: el área nueva **Heladería** apareció entre las tarjetas. Los pantallazos de Inventario y Mesas muestran, a la vez, una falla transversal de usabilidad móvil: la barra lateral de escritorio permanece fija y ocupa aproximadamente una quinta parte del ancho visible. En Inventario deja tarjetas apretadas y un recorrido vertical largo. En Mesas estrecha el bloque de caja, reduce el plano de mesas a una columna angosta y deja una gran zona vacía a la derecha. En estas condiciones, el móvil es difícil de operar.

El objetivo de este frente es una **distribución móvil nueva**, con la misma identidad visual y los mismos datos y acciones. No implica una reescritura del POS, de sus reglas comerciales, de seguridad, de inventario o del diseño de escritorio. La siguiente etapa de inventario B3.2b está pendiente y **no se activa mediante este documento**.

### Evidencia visual entregada por Alejo

1. Mesas: barra vertical persistente; aviso de caja de apenas unas palabras por línea; botones de mesa en una sola columna; área vacía sobrante; gesto de abrir mesa penalizado por scroll.
2. Inventario: navegación vertical persistente; tarjetas de áreas de una columna estrecha; repetición de texto y acciones; ya existe una nueva área Heladería, por lo que la navegación móvil debe seguir siendo dinámica.
3. El problema no se resuelve únicamente reduciendo tipografías: se necesita redistribuir navegación, jerarquía y disposición de contenido.

## 2. Norte de producto

Una persona trabajando en una cafetería debe poder abrir una mesa, consultar un producto y llegar a un reparto con pocos toques, sin hacer zoom, sin desplazamiento horizontal y sin perder la ubicación actual. El móvil debe utilizar todo el ancho del teléfono; la versión de escritorio conserva su navegación lateral existente.

| Componente | Escritorio | Propuesta móvil |
|---|---|---|
| Navegación principal | Barra lateral existente | Barra inferior fija de cinco accesos: Mesas, Inventario, Reparto, Mermas, Más |
| Navegación secundaria | Barra lateral, secciones y menús existentes | Menú de apertura temporal y sección Más; los módulos no desaparecen |
| Encabezado | Layout actual | Cabecera compacta: menú, sede y módulo, actualizar |
| Mesas | Plano/listado actual | Cuadrícula adaptable, idealmente tres columnas en teléfono estándar; estados legibles y áreas seleccionables |
| Caja en Mesas | Bloque apretado | Tarjeta horizontal compacta con hora/estado y acceso a detalle autorizado |
| Inventario | Portada de áreas actual | Tarjetas de áreas a dos columnas si caben; búsqueda y selección de área; vista de producto a ancho completo |
| Modales/paneles | Flujo actual | Hoja o pantalla móvil sin desbordes, teclado visible y acciones alcanzables |

La barra inferior debe respetar `safe-area-inset-bottom`, no tapar controles y mantener estados activos/permisos/modo demostración. El menú temporal debe cerrarse con botón, toque fuera y Escape cuando corresponda. No debe duplicarse una segunda barra lateral fija en el teléfono.

## 3. Pantallas y flujos que deben sobrevivir

### Mesas

- Al entrar se ve primero el estado de caja y el conjunto de mesas, no un aviso vacío que desplace el plano.
- Se mantiene el selector de zona/área de mesas existente, con accesos cómodos. **`lama_areas` no es `areas_operativas` de inventario**: son conceptos distintos.
- La cuadrícula ocupa el ancho completo y se adapta al tamaño; tres columnas como referencia en 375–430 CSS px, dos en teléfonos especialmente estrechos. El número de columnas definitivo debe validarse con tamaños reales y nombres/estados existentes.
- Mesa libre, ocupada y otros estados reales conservan la semántica vigente. El prototipo ilustra colores, no introduce estados de negocio.
- Tocar una mesa abre el flujo real de cuenta/comanda/cobro, sin modificar cuándo se registra caja ni cuándo se captura consumo de stock.
- Zonas, cierre y detalle de mesa no quedan inaccesibles detrás de la barra inferior o de un teclado abierto.

### Inventario

- Búsqueda disponible y claramente acotada al área seleccionada; vista global conserva desglose por ubicación.
- Las áreas son dinámicas desde la fuente actual; **no** regresar a códigos fijos. Sin asignar sigue siendo ubicación lógica especial y Bodega mantiene su interfaz propia.
- Tarjetas de áreas legibles, con cifras reales del ledger. Una tarjeta de área debe permitir entrar a su página completa, no solo cambiar una cifra de resumen.
- Área preferida y saldo físico son cosas distintas. Crear producto desde un área deja preferencia asignada, pero stock cero.
- No mostrar etiquetas “Bajo”, “OK” o “Crítico” basadas en mínimos que todavía no están configurados. El prototipo deliberadamente muestra “sin mínimos”.
- Cualquier control futuro para transferir cantidades pertenece a B3.2b y llamará únicamente la operación protegida correspondiente; este diseño no autoriza ejecutarlo.

### Resto de la navegación

- Reparto y Mermas son accesos inferiores propuestos porque están en el flujo operativo actual. Debe validarse con métricas/tareas del usuario antes de fijar orden definitivo.
- En “Más” o el menú temporal siguen accesibles Arqueo, Movimientos, Recetas, Historial, Ajustes, Cambiar sede, Apariencia, Actualizar y Cerrar sesión, además de cualquier módulo visible para la cuenta.
- Respetar permisos S1/S2 y modo demostración: un enlace oculto o no autorizado no debe abrir pantalla huérfana. Ocultar un enlace no constituye autorización.
- El encabezado de sede muestra claramente Local 1 o Bodega sin inventar una tercera sede. Cambio de sede mantiene los controles vigentes.

## 4. Reglas visuales y de interacción

- Mantener la paleta actual: azul marino, azul de acción, blanco, gris claro y estados semánticos moderados. No usar emojis ni convertir la aplicación en una nueva marca.
- Targets táctiles de al menos ~44×44 CSS px, espacios suficientes para dedos y textos con contraste legible. Soportar zoom de texto del sistema, teclado y orientación vertical; no fijar anchuras que provoquen scroll horizontal.
- Una sola región de scroll principal por pantalla cuando sea viable. La barra inferior permanece visible; el contenido deja espacio para no ocultar la última acción.
- Menú accesible por teclado, foco visible, `aria-expanded`, etiquetas de botones y estados anunciados. Bloquear el scroll detrás de diálogos reales si el diseño aprobado los usa.
- Los contadores de Reparto son datos/alertas, no parte del ícono. No trasladar datos sintéticos del HTML a la aplicación.
- La maqueta incluye interacciones demostrativas y textos/cifras ilustrativos; no es contrato de API, no contiene datos vivos, no es autorización para recrear tablas.

## 5. Alcance técnico propuesto para Codex: solo plan primero

Codex debe levantar un mapa del DOM/CSS y los scripts que gobiernan sidebar, fijar/desplegar, header, scroll, modales, Mesas, Inventario y Ajustes. Debe identificar breakpoints y restricciones existentes, estilos compartidos y cualquier regla que se aplique tanto a escritorio como a móvil. También debe inspeccionar el flujo real de zonas/mesas y la lista de módulos según permiso/modo demostración. Se solicita **modo plan de solo lectura** antes de modificar `index.html` o SQL.

El plan de ejecución deberá dividir como mínimo:

1. **M0 — Mapa y prueba basal móvil:** capturas o inspección en tamaños representativos, inventario de desbordes, flujos y regresiones. Si no hay navegador automático, especificar prueba manual en Safari iPhone y Chrome Android sin afirmar cobertura visual inexistente.
2. **M1 — Armazón móvil:** retirar sidebar fija solo en móviles; navegación inferior y menú temporal; cabecera y safe areas; preservación de escritorio, permisos y modo demostración. Validar navegación antes de seguir.
3. **M2 — Mesas y POS táctil:** corregir caja, selector de zona, cuadrícula de mesas y detalle/comanda/cobro sin alterar la lógica comercial ni el puente Lama–Stock.
4. **M3 — Inventario, áreas y formularios:** portada, búsqueda, páginas de área, producto y diálogos; respetar la lectura dinámica y la separación preferencia/existencia.
5. **M4 — Resto y regresión transversal:** Reparto, Mermas, Ajustes, Recetas, Historial, estados vacíos, errores, teclado, permisos, Bodega, modo demostración y dispositivos pequeños.

Los bloques son de **diseño y plan**, no tareas activadas automáticamente. Alejo revisará el plan de Codex y autorizará cada bloque de implementación por separado. Si B3.2b continúa en paralelo o se pospone, coordinar archivos compartidos para evitar cambios concurrentes a `index.html`.

## 6. Fuera de alcance y líneas rojas

- No cambiar esquemas, tablas, migraciones, RLS, permisos ni Auth por esta propuesta visual.
- No cambiar reglas de cobro, cierre, arqueo, comanda, descuento, stock, lotes, recetas ni Fudo/Lama.
- No activar origen POS, Fudo remoto ni Lama real.
- No modificar Bodega, `stock_transferir` ni escritores del ledger.
- No tocar Café del Desierto / Llamita Stock. La compatibilidad futura no autoriza cambios allí.
- No reemplazar la experiencia de escritorio ni alterar su sidebar fijable.

## 7. Criterios de aceptación para la futura implementación

1. A ~375 CSS px ninguna pantalla operativa común presenta sidebar fija o scroll horizontal accidental.
2. Mesas usa el ancho completo; estado de caja y mesa son legibles sin texto vertical fragmentado.
3. Abrir una mesa, consultar comanda y volver a la cuadrícula no pierde la zona ni obliga a navegar por decenas de mesas en una columna.
4. Inventario conserva áreas dinámicas —incluida Heladería creada por usuario—, Sin asignar y búsqueda global/local.
5. Todos los módulos permitidos siguen alcanzables en móvil; modo demostración y permisos se comportan como antes.
6. Bodega y Local 1 se distinguen; las cantidades siguen derivando del ledger donde corresponde.
7. El escritorio se compara antes/después y no sufre regresiones.
8. Pruebas unitarias/estáticas existentes pasan; pruebas manuales en dispositivo real documentan hallazgos y capturas; no atribuir pruebas de navegador no ejecutadas.

## 8. Decisiones de producto para revisión con Alejo

- ¿Reparto y Mermas son los dos accesos inferiores correctos, o conviene priorizar otra operación diaria? La v1 los propone, no los impone.
- ¿El plano de Mesas tiene zonas cuya representación exige una disposición espacial distinta de una cuadrícula? Codex debe documentar el comportamiento actual antes de implementarla.
- ¿La apertura del detalle de mesa será pantalla completa o hoja inferior? Debe elegirse tras revisar tamaños reales de comanda/cobro.
- ¿El inventario móvil muestra primero tarjetas de áreas o búsqueda global? La v1 abre en áreas, con búsqueda accesible en el primer viewport.

## 9. Entregable siguiente

Enviar a Codex el objetivo y este documento, solicitar **modo plan de solo lectura** y recibir propuesta técnica específica, archivos afectados, riesgos y pruebas. No activar M1 ni B3.2b hasta revisar el resultado con Alejo.
